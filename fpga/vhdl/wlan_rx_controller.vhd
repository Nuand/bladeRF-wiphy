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

entity wlan_rx_controller is
    port (
      clock            :   in std_logic ;
      reset            :   in std_logic ;

      framer_quiet_reset:  out std_logic ;

      params           :   in  wlan_rx_params_t ;
      params_valid     :   in  std_logic ;

      sample_valid     :   in std_logic ;
      end_of_packet    :  out std_logic ;
      rx_packet_init   :  out std_logic ;

      rx_quiet         :   in std_logic ;
      rx_framer_done   :   in std_logic ;
      acquired         :   in std_logic ;
      p_mag            :   in signed( 23 downto 0 ) ;

      atan_average     :   in signed( 15 downto 0 ) ;

      c_dphase         :  out signed( 15 downto 0 ) ;
      c_dphase_valid   :  out std_logic ;
      c_p_mag          :  out signed( 23 downto 0 ) ;
      c_p_mag_valid    :  out std_logic ;

      symbol_start     :  out std_logic
    ) ;
end entity;

architecture arch of wlan_rx_controller is

    type fsm_t is (ACQUIRING, INIT_EQ, WAIT_FOR_CFO, DEC_SIGNAL, DEMOD, WAIT_EOP) ;

    type state_t is record
        fsm            :  fsm_t ;
        pkt_time       :  unsigned( 23 downto 0 ) ;
        sym_time       :  unsigned( 23 downto 0 ) ;
        c_dphase       :  signed( 15 downto 0 ) ;
        c_dphase_valid :  std_logic ;
        c_p_mag        :  signed( 23 downto 0 ) ;
        c_p_mag_valid  :  std_logic ;
        end_of_packet  :  std_logic ;
        packet_init    :  std_logic ;
        symbol_start   :  std_logic ;
        decoded_bits   :  natural range 0 to 12000 ;
        bit_index      :  natural range 0 to 12000 ;
        n_dbps         :  natural range 24 to 216 ;
        symbol_count   :  natural range 0 to 1366 ;
        symbol_index   :  natural range 0 to 1366 ;
        framer_reset   :  std_logic ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := ACQUIRING ;
        rv.pkt_time := ( others => '0' );
        rv.c_dphase := ( others => '0' ) ;
        rv.c_dphase_valid := '0' ;
        rv.c_p_mag := ( others => '0' ) ;
        rv.c_p_mag_valid := '0' ;
        rv.end_of_packet := '0' ;
        rv.packet_init := '0' ;
        rv.symbol_start := '0' ;
        rv.decoded_bits := 0 ;
        rv.bit_index := 0 ;
        rv.n_dbps := 24 ;
        rv.symbol_count := 0 ;
        rv.symbol_index := 0 ;
        rv.framer_reset := '1' ;
        return rv ;
    end function ;

    signal current, future  :   state_t := NULL_STATE ;
begin

    rx_packet_init <= current.packet_init ;

    c_dphase <= current.c_dphase ;
    c_dphase_valid <= current.c_dphase_valid ;
    c_p_mag <= current.c_p_mag ;
    c_p_mag_valid <= current.c_p_mag_valid ;

    symbol_start <= current.symbol_start ;

    end_of_packet <= current.end_of_packet ;
    framer_quiet_reset <= current.framer_reset ;

    sync : process( clock )
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
        elsif( rising_edge( clock ) ) then
            current <= future ;
        end if ;
    end process ;

    comb: process(all)
    begin
        future <= current ;
        future.symbol_start <= '0' ;
        future.packet_init <= '0' ;

        case current.fsm is
            when ACQUIRING =>
                if( acquired = '1' ) then
                    -- it takes the acquisition core 201 samples after the actual
                    -- start of packet until it asserts acquired
                    future.pkt_time <= to_unsigned( 212+1, future.pkt_time'length ) ;
                    future.c_p_mag <= p_mag ;
                    future.c_p_mag_valid <= '1' ;
                    future.fsm <= INIT_EQ ;
                    future.symbol_index <= 1 ;
                    future.symbol_count <= 0 ;
                    future.packet_init <= '1' ;
                    future.framer_reset <= '0' ;
                else
                    future <= NULL_STATE ;
                end if ;

            when INIT_EQ =>
                if( rx_quiet = '1' ) then
                    future.fsm <= ACQUIRING ;
                end if ;
                if( sample_valid = '1' ) then
                    future.pkt_time <= current.pkt_time + 1 ;
                    if( current.pkt_time = 256 ) then
                        future.symbol_start <= '1' ;
                        future.fsm <= WAIT_FOR_CFO ;
                    end if ;
                end if ;

            when WAIT_FOR_CFO =>
                if( rx_quiet = '1' ) then
                    future.fsm <= ACQUIRING ;
                end if ;
                if( sample_valid = '1' ) then
                    future.pkt_time <= current.pkt_time + 1 ;
                    if( current.pkt_time > 300 ) then
                        future.c_dphase <= shift_right( - atan_average, 6 ) ;
                        future.c_dphase_valid <= '1' ;
                        future.sym_time <= to_unsigned(336, future.sym_time'length);
                        future.fsm <= DEC_SIGNAL ;
                    end if ;
                end if ;

            when DEC_SIGNAL =>
                if( rx_quiet = '1' ) then
                    future.fsm <= ACQUIRING ;
                    future.end_of_packet <= '1' ;
                end if ;
                if( params_valid = '1' ) then
                    if( params.packet_valid = '1' ) then
                        future.decoded_bits <= params.num_data_symbols ;
                        future.n_dbps <= params.n_dbps ;
                        future.bit_index <= params.n_dbps ;
                        future.fsm <= DEMOD ;
                    else
                        future.fsm <= ACQUIRING ;
                        future.end_of_packet <= '1' ;
                    end if ;
                end if ;

                if( sample_valid = '1' ) then
                    future.pkt_time <= current.pkt_time + 1 ;
                    if( current.sym_time = current.pkt_time) then
                        future.sym_time <= current.sym_time + 80;
                        future.symbol_start <= '1' ;
                    end if ;
                end if ;

            when DEMOD =>
                if( rx_quiet = '1' ) then
                    future.fsm <= ACQUIRING ;
                    future.end_of_packet <= '1' ;
                elsif( sample_valid = '1' ) then
                    future.pkt_time <= current.pkt_time + 1 ;
                    if( current.pkt_time = current.sym_time ) then
                        future.sym_time <= current.sym_time + 80;
                        future.bit_index <= current.bit_index + current.n_dbps ;
                        future.symbol_start <= '1' ;
                    end if ;

                    if (current.bit_index >= current.decoded_bits ) then
                        future.sym_time <= to_unsigned(5000, future.sym_time'length);
                        future.fsm <= WAIT_EOP ;
                    end if ;
                end if ;

            when WAIT_EOP =>
                if( rx_framer_done = '1' or current.sym_time = 0) then
                    future.fsm <= ACQUIRING ;
                    future.end_of_packet <= '1' ;
                end if ;
                future.sym_time <= current.sym_time - 1 ;

            when others =>
                future.fsm <= ACQUIRING ;
        end case ;
    end process ;
end architecture ;
