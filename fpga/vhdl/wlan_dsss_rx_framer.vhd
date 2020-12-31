-- This file is part of bladeRF-wiphy.
--
-- Copyright (C) 2020 Nuand, LLC.
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

library ieee ;
    use ieee.std_logic_1164.all ;
    use ieee.numeric_std.all ;

library wlan ;
    use wlan.wlan_p.all ;
    use wlan.wlan_rx_p.all ;

entity wlan_dsss_rx_framer is
    port (
      clock            :   in std_logic ;
      reset            :   in std_logic ;

      mode_bin         :   in natural ;

      demod_idx        :   in natural ;
      demod_bits       :   in std_logic_vector( 1 downto 0 ) ;
      demod_valid      :   in std_logic ;

      params           :  out wlan_rx_params_t ;
      params_valid     :  out std_logic ;

      data             :  out std_logic_vector( 7 downto 0 ) ;
      data_valid       :  out std_logic ;

      framer_done      :  out std_logic ;
      crc_correct      :  out std_logic
    ) ;
end entity ;

architecture arch of wlan_dsss_rx_framer is

    type counter_t is array(0 to 19) of unsigned(4 downto 0) ;

    type fsm_t is (ACQUIRING, SEARCH_FOR_SFD, CAPTURE_PLCP, VERIFY_PLCP_CRC, CAPTURE_PAYLOAD, VERIFY_FCS, COMMIT_PKT) ;

    type state_t is record
        fsm                 :   fsm_t ;
        mode_bin            :   natural range 0 to 20 ;
        sfd_attempt         :   natural range 0 to 120 ;

        byte_ready          :   std_logic ;
        byte_count          :   natural range 0 to 1200 ;
        pkt_len             :   natural range 0 to 1200 ;
        payload_len         :   natural range 0 to 1200 ;

        fcs                 :   std_logic_vector( 31 downto 0 ) ;

        bit_count           :   natural range 0 to 60 ;
        recv_reg            :   std_logic_vector( 47 downto 0 ) ;
        consecutive_ones    :   counter_t ;

        plcp_crc_bit        :   std_logic ;
        plcp_crc_bit_valid  :   std_logic ;
        plcp_crc_init       :   std_logic ;

        params              :   wlan_rx_params_t ;
        params_valid        :   std_logic ;

        framer_done         :   std_logic ;
        crc_correct         :   std_logic ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := ACQUIRING ;
        rv.mode_bin    := 0 ;
        rv.sfd_attempt := 0 ;
        rv.byte_ready  := '0' ;
        rv.byte_count  := 0 ;
        rv.pkt_len     := 0 ;
        rv.payload_len := 0 ;

        rv.fcs         := ( others => '0' ) ;
        rv.bit_count   := 0 ;
        rv.recv_reg    := ( others => '0' ) ;
        rv.consecutive_ones := ( others => ( others => '0' ) ) ;

        rv.plcp_crc_bit       := '0' ;
        rv.plcp_crc_bit_valid := '0' ;
        rv.plcp_crc_init      := '0' ;

        rv.params_valid := '0' ;
        rv.params.packet_valid := '0' ;

        rv.framer_done := '0' ;
        return rv ;
    end function ;

    signal current, future  :   state_t := NULL_STATE ;

    signal  plcp_crc             : std_logic_vector( 15 downto 0 ) ;
    signal  plcp_crc_endian      : std_logic_vector( 15 downto 0 ) ;

    signal  calculated_fcs       : std_logic_vector( 31 downto 0 ) ;
begin
    crc_correct <= current.crc_correct ;
    framer_done <= current.framer_done ;
    data <= current.recv_reg( 7 downto 0 ) ;
    data_valid <= current.byte_ready ;
    params_valid <= current.params_valid ;
    params <= current.params;

    U_plcp_crc : entity wlan.wlan_dsss_plcp_crc
      port map (
        clock     => clock,
        reset     => reset or current.plcp_crc_init,

        in_data   => current.plcp_crc_bit,
        in_valid  => current.plcp_crc_bit_valid,
        crc       => plcp_crc
      ) ;

    U_crc : entity wlan.wlan_crc
      port map (
        clock     => clock,
        reset     => reset or current.plcp_crc_init,

        in_data   => current.recv_reg( 7 downto 0 ),
        in_valid  => current.byte_ready,
        crc       => calculated_fcs
      ) ;


    sync : process(clock, reset)
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
        elsif( rising_edge(clock) ) then
            current <= future ;
        end if ;
    end process ;

    comb : process( clock )
    begin
        for i in 0 to 7 loop
            plcp_crc_endian(i) <= plcp_crc(15 - i );
            plcp_crc_endian(8+i) <= plcp_crc(7 - i );
        end loop ;

        future <= current ;
        future.byte_ready <= '0' ;
        future.plcp_crc_bit_valid <= '0' ;
        future.plcp_crc_init <= '0' ;

        future.params_valid <= '0' ;
        future.params.packet_valid <= '0' ;

        future.framer_done <= '0' ;
        future.crc_correct <= '0' ;

        case current.fsm is
            when ACQUIRING =>
                if( demod_valid = '1' ) then
                    if( demod_bits(0) = '1' ) then
                        if(future.consecutive_ones(demod_idx) = 27 ) then
                            future.consecutive_ones <= ( others => ( others => '0' ) ) ;
                            future.mode_bin <= mode_bin ;
                            future.sfd_attempt <= 0 ;
                            future.plcp_crc_init <= '1' ;
                            future.fsm <= SEARCH_FOR_SFD ;
                        else
                            future.consecutive_ones(demod_idx) <= current.consecutive_ones(demod_idx) + 1 ;
                        end if ;
                    else
                        future.consecutive_ones(demod_idx) <= ( others => '0' ) ;
                    end if ;
                end if ;

             when SEARCH_FOR_SFD =>
                if( demod_valid = '1' ) then
                    if( demod_idx = current.mode_bin ) then
                        future.recv_reg(15 downto 0) <= demod_bits(0) & current.recv_reg(15 downto 1) ;
                        future.sfd_attempt <= current.sfd_attempt + 1 ;
                    end if;
                end if;
                if( current.recv_reg(15 downto 0) = x"F3A0" ) then
                    future.fsm <= CAPTURE_PLCP ;
                    future.bit_count <= 1 ;
                elsif( current.sfd_attempt >= 130 ) then
                    future.fsm <= ACQUIRING ;
                end if ;

             when CAPTURE_PLCP =>
                if( demod_valid = '1' and demod_idx = current.mode_bin ) then
                    if( current.bit_count <= 32 ) then
                        future.plcp_crc_bit <= demod_bits(0) ;
                        future.plcp_crc_bit_valid <= '1' ;
                    end if ;

                    future.recv_reg <= demod_bits(0) & current.recv_reg(47 downto 1) ;
                    if( current.bit_count = 48 ) then
                        future.fsm <= VERIFY_PLCP_CRC ;
                    end if ;
                    future.bit_count <= current.bit_count + 1 ;
                end if ;

            when VERIFY_PLCP_CRC =>
                if( plcp_crc_endian = current.recv_reg(47 downto 32) ) then
                    future.fsm <= CAPTURE_PAYLOAD ;

                    future.byte_count <= 1 ;
                    future.pkt_len <= to_integer(unsigned(current.recv_reg(31 downto 19))) ;
                    future.payload_len <= to_integer(unsigned(current.recv_reg(31 downto 19))) - 4 ;

                    future.bit_count <= 1 ;

                    future.params_valid <= '1' ;
                    future.params.datarate <= WLAN_RATE_1 ;
                    future.params.length <= to_integer(unsigned(current.recv_reg(31 downto 19))) - 4 ;
                else
                    future.fsm <= ACQUIRING ;
                end if ;
                future.recv_reg <= ( others => '0' ) ;

            when CAPTURE_PAYLOAD =>
                if( demod_valid = '1' and demod_idx = current.mode_bin ) then
                    future.recv_reg(7 downto 0) <= demod_bits(0) & current.recv_reg(7 downto 1) ;
                    if( current.bit_count = 8 ) then
                        future.bit_count <= 1 ;
                        if( current.byte_count > current.payload_len ) then
                            future.fcs <= demod_bits(0) & current.recv_reg(7 downto 1) & current.fcs(31 downto 8) ;
                        else
                            future.byte_ready <= '1' ;
                        end if ;
                        if( current.byte_count = current.pkt_len ) then
                            future.fsm <= VERIFY_FCS ;
                        else
                            future.byte_count <= current.byte_count + 1 ;
                        end if ;

                    else
                        future.bit_count <= current.bit_count + 1 ;
                    end if ;
                end if ;

            when VERIFY_FCS =>
                future.framer_done <= '1' ;
                if( current.fcs = calculated_fcs ) then
                    future.crc_correct <= '1' ;
                    future.fsm <= COMMIT_PKT ;
                else
                    future.fsm <= ACQUIRING ;
                end if ;

            when COMMIT_PKT =>
                future.fsm <= ACQUIRING ;

        end case ;
    end process ;

end architecture ;
