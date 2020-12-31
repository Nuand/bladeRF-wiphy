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

entity wlan_rx_framer is
    port (
      clock              :   in std_logic ;
      reset              :   in std_logic ;

      framer_quiet_reset :   in std_logic ;
      init               :   in std_logic ;

      bss_mac            :   in std_logic_vector( 47 downto 0 ) ;

      ack_mac            :  out std_logic_vector( 47 downto 0 ) ;
      ack_valid          :  out std_logic ;

      acked_packet       :  out std_logic ;

      params             :  out wlan_rx_params_t ;
      params_valid       :  out std_logic ;

      in_data            :   in std_logic_vector( 7 downto 0 ) ;
      in_valid           :   in std_logic ;

      signal_dec         :  out std_logic ;

      descrambler_bypass :  out std_logic ;

      crc_correct        :  out std_logic ;

      depunct_done           :   in std_logic ;

      decoder_done           :   in std_logic ;

      framer_done            :  out std_logic
    ) ;
end entity;

architecture arch of wlan_rx_framer is

    function calculate_params( x : wlan_rx_vector_t; service : boolean ) return wlan_rx_params_t is
        variable rv : wlan_rx_params_t ;
    begin
        rv.packet_valid := '0' ;
        rv.datarate := x.datarate ;
        rv.length   := x.length ;
        rv.bandwidth := x.bandwidth ;
        rv.lfsr_init := "1011101" ;

        case x.datarate is
            when WLAN_RATE_6    =>
                -- BPSK R=1/2
                rv.n_bpsc := 1 ;
                rv.n_dbps := 24 ;
                rv.n_cbps := 48 ;
                rv.modulation := WLAN_BPSK ;

            when WLAN_RATE_9    =>
                -- BPSK R=3/4
                rv.n_bpsc := 1 ;
                rv.n_dbps := 36 ;
                rv.n_cbps := 48 ;
                rv.modulation := WLAN_BPSK ;

            when WLAN_RATE_12   =>
                -- QPSK R=1/2
                rv.n_bpsc := 2 ;
                rv.n_dbps := 48 ;
                rv.n_cbps := 96 ;
                rv.modulation := WLAN_QPSK ;

            when WLAN_RATE_18   =>
                -- QPSK R=3/4
                rv.n_bpsc := 2 ;
                rv.n_dbps := 72 ;
                rv.n_cbps := 96 ;
                rv.modulation := WLAN_QPSK ;

            when WLAN_RATE_24   =>
                -- 16-QAM R=1/2
                rv.n_bpsc := 4 ;
                rv.n_dbps := 96 ;
                rv.n_cbps := 192 ;
                rv.modulation := WLAN_16QAM ;

            when WLAN_RATE_36   =>
                -- 16-QAM R=3/4
                rv.n_bpsc := 4 ;
                rv.n_dbps := 144 ;
                rv.n_cbps := 192 ;
                rv.modulation := WLAN_16QAM ;

            when WLAN_RATE_48   =>
                -- 64-QAM R=2/3
                rv.n_bpsc := 6 ;
                rv.n_dbps := 192 ;
                rv.n_cbps := 288 ;
                rv.modulation := WLAN_64QAM ;

            when WLAN_RATE_54   =>
                -- 64-QAM R=3/4
                rv.n_bpsc := 6 ;
                rv.n_dbps := 216 ;
                rv.n_cbps := 288;
                rv.modulation := WLAN_64QAM ;

            when others =>
                report "Invalid params" severity failure ;
        end case ;

        case x.bandwidth is
            when WLAN_BW_5  =>
                null ;

            when WLAN_BW_10 =>
                null ;

            when WLAN_BW_20 =>
                null ;

            when others =>
                report "Invalid bandwidth" severity failure ;
        end case ;

        rv.num_decoded_bits := rv.length * 8 ;
        if (service) then
            rv.num_data_symbols := rv.num_decoded_bits;-- (16 + rv.num_decoded_bits + rv.n_dbps - 1) / rv.n_dbps ;
        else
            rv.num_data_symbols := rv.num_decoded_bits; --+ rv.n_dbps - 1) / rv.n_dbps ;
        end if;

        return rv ;
    end function ;
    type fsm_t is (IDLE, PRIME_DEPUNCT_FOR_SIGNAL, CAPTURE_SIGNAL, DECODE_PARITY, DECODE_SIGNAL, CAPTURE_DATA, DECODE_DATA, CAPTURE_CRC, COMPARE_CRC) ;

    type state_t is record
        fsm                 :   fsm_t ;
        bytes_captured      :   natural range 0 to 8 ;
        decoded_signal      :   std_logic_vector( 23 downto 0) ;
        signal_valid        :   std_logic ;
        params              :   wlan_rx_params_t ;
        params_valid        :   std_logic ;
        num_coded_bits         :   unsigned(  13 downto 0 ) ;
        num_coded_bits_valid   :   std_logic ;
        num_decoded_bits       :   unsigned(  13 downto 0 ) ;
        num_decoded_bits_valid :   std_logic ;
        num_bytes           :   natural range 0 to 4096 ;
        length              :   natural range 0 to 4096 ;
        packet_crc          :   std_logic_vector( 31 downto 0) ;
        crc_correct         :   std_logic ;
        done                :   std_logic ;

        frame_control       :   std_logic_vector( 15 downto 0 ) ;
        frame_duration      :   std_logic_vector( 15 downto 0 ) ;
        a0                  :   std_logic_vector( 47 downto 0 ) ;
        a1                  :   std_logic_vector( 47 downto 0 ) ;
        a2                  :   std_logic_vector( 47 downto 0 ) ;
        frame_id            :   std_logic_vector( 15 downto 0 ) ;

        ack_mac             :   std_logic_vector( 47 downto 0 ) ;
        ack_valid           :   std_logic ;
        acked_packet        :   std_logic ;
        parity_bit          :   std_logic ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := IDLE ;
        rv.bytes_captured := 0 ;
        rv.decoded_signal := ( others => '0' ) ;
        rv.signal_valid := '0' ;
        rv.params_valid := '0' ;
        rv.num_coded_bits        := ( others => '0' ) ;
        rv.num_coded_bits_valid  := '0' ;
        rv.num_decoded_bits        := ( others => '0' ) ;
        rv.num_decoded_bits_valid  := '0' ;
        rv.num_bytes := 0 ;
        rv.length := 0 ;
        rv.params.packet_valid := '0' ;
        rv.packet_crc := ( others => '0' ) ;
        rv.crc_correct := '0' ;
        rv.done := '0' ;
        rv.frame_control := ( others => '0' ) ;
        rv.frame_duration := ( others => '0' ) ;
        rv.a0 := ( others => '0' ) ;
        rv.a1 := ( others => '0' ) ;
        rv.a2 := ( others => '0' ) ;
        rv.ack_valid := '0' ;
        rv.acked_packet := '0' ;
        rv.frame_id := ( others => '0' ) ;
        rv.parity_bit := '0' ;
        return rv ;
    end function ;

    signal current, future  :   state_t := NULL_STATE ;

    signal payload_data     :   std_logic ;
    signal calculated_crc   :   std_logic_vector( 31 downto 0 ) ;
begin

    payload_data <= '1' when (current.fsm = DECODE_DATA and (current.num_bytes <= current.length - 4 )) else '0' ;

    signal_dec <= current.signal_valid ;
    descrambler_bypass <= not(current.signal_valid);
    
    params <= current.params ;
    params_valid <= current.params_valid ;

    framer_done <= current.done;

    crc_correct <= current.crc_correct ;

    ack_valid <= current.ack_valid ;
    ack_mac <= current.ack_mac ;

    acked_packet <= current.acked_packet;

    sync : process(clock, reset)
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
        elsif( rising_edge(clock) ) then
            if( framer_quiet_reset = '1' ) then
                current <= NULL_STATE ;
            else
                current <= future ;
            end if ;
        end if ;
    end process ;

    comb : process(all)
        variable rx_vec : wlan_rx_vector_t ;
        variable parity_bit : std_logic ;
    begin
        future <= current ;

        future.crc_correct <= '0' ;
        future.num_coded_bits_valid   <= '0' ;
        future.num_decoded_bits_valid <= '0' ;
        future.params_valid <= '0' ;
        future.ack_valid <= '0' ;
        future.acked_packet <= '0' ;

        case current.fsm is
            when IDLE =>
                future.signal_valid <= '0' ;
                if( init = '1' ) then
                    future.fsm <= PRIME_DEPUNCT_FOR_SIGNAL ;
                else
                    future <= NULL_STATE ;
                end if ;

            when PRIME_DEPUNCT_FOR_SIGNAL =>
                rx_vec.datarate := WLAN_RATE_6 ;
                rx_vec.length := 3 ;
                future.params <= calculate_params( rx_vec, false );
                future.params_valid <= '1' ;

                future.fsm <= CAPTURE_SIGNAL ;

            when CAPTURE_SIGNAL =>
                if( in_valid = '1' ) then
                    future.bytes_captured <= current.bytes_captured + 1 ;
                    if ( current.bytes_captured = 2 ) then
                        future.fsm <= DECODE_PARITY ;
                        future.signal_valid <= '1' ;
                    end if ;
                    future.decoded_signal <= in_data & current.decoded_signal( 23 downto 8 ) ;
                end if ;

            when DECODE_PARITY =>

                parity_bit := current.decoded_signal(0) ;
                for i in 1 to 16 loop
                    parity_bit := parity_bit xor current.decoded_signal( i ) ;
                end loop ;
                future.parity_bit <= parity_bit;
                future.fsm <= DECODE_SIGNAL ;

            when DECODE_SIGNAL =>
                if( current.parity_bit = current.decoded_signal(17) ) then
                    future.fsm <= DECODE_DATA ;
                    future.params.packet_valid <= '1' ;
                    rx_vec.datarate := WLAN_RATE_6 ;
                    if( current.decoded_signal( 3 downto 0 ) = "1011" ) then
                       rx_vec.datarate := WLAN_RATE_6 ;
                    elsif( current.decoded_signal( 3 downto 0 ) = "1111" ) then
                       rx_vec.datarate := WLAN_RATE_9 ;
                    elsif( current.decoded_signal( 3 downto 0 ) = "1010" ) then
                       rx_vec.datarate := WLAN_RATE_12 ;
                    elsif( current.decoded_signal( 3 downto 0 ) = "1110" ) then
                       rx_vec.datarate := WLAN_RATE_18 ;
                    elsif( current.decoded_signal( 3 downto 0 ) = "1001" ) then
                       rx_vec.datarate := WLAN_RATE_24 ;
                    elsif( current.decoded_signal( 3 downto 0 ) = "1101" ) then
                       rx_vec.datarate := WLAN_RATE_36 ;
                    elsif( current.decoded_signal( 3 downto 0 ) = "1000" ) then
                       rx_vec.datarate := WLAN_RATE_48 ;
                    elsif( current.decoded_signal( 3 downto 0 ) = "1100" ) then
                       rx_vec.datarate := WLAN_RATE_54 ;
                    else
                       rx_vec.datarate := WLAN_RATE_6 ;
                       report "Bad rate" severity warning ;
                    end if ;

                    -- length consist of the length field encoded in the SIGNAL field,
                    -- plus 2 bytes for the SERVICE field
                    rx_vec.length := to_integer( unsigned( current.decoded_signal( 16 downto 5 ) ) ) + 2 ;

                    if( rx_vec.length > 1600 ) then
                        future.fsm <= IDLE ;
                    else
                        future.length <= to_integer( unsigned( current.decoded_signal( 16 downto 5 ) ) ) ;
                        future.num_bytes <= 1 ;
                        future.params <= calculate_params( rx_vec, true );
                        future.params.packet_valid <= '1' ;
                    end if ;
                else
                    future.fsm <= IDLE ;
                    future.params.packet_valid <= '0' ;
                end if ;
                future.params_valid <= '1' ;


            when DECODE_DATA =>
                if( in_valid = '1' ) then
                    future.num_bytes <= current.num_bytes + 1 ;
                    if( current.num_bytes >= (current.length - 4 ) ) then
                        future.num_bytes <= 0 ;
                        future.fsm <= CAPTURE_CRC ;
                    end if ;
                    if (current.num_bytes <= 2 ) then
                        future.frame_control <= current.frame_control( 7 downto 0 ) & in_data ;
                    end if ;
                    if (current.num_bytes > 2 and current.num_bytes <= 4 ) then
                        future.frame_id <= current.frame_id( 7 downto 0 ) & in_data ;
                    end if ;
                    if (current.num_bytes > 4 and current.num_bytes <= 10 ) then
                        future.a0 <= current.a0( 39 downto 0 ) & in_data ;
                    end if ;
                    if (current.num_bytes > 10 and current.num_bytes <= 16 ) then
                        future.a1 <= current.a1( 39 downto 0 ) & in_data ;
                    end if ;
                    if (current.num_bytes > 16 and current.num_bytes <= 22 ) then
                        future.a2 <= current.a2( 39 downto 0 ) & in_data ;
                    end if ;
                    if (current.num_bytes > 22 and current.num_bytes <= 24 ) then
                        future.frame_id <= current.frame_id( 7 downto 0 ) & in_data ;
                    end if ;

                end if ;

            when CAPTURE_CRC =>
                if( in_valid = '1' ) then
                    future.num_bytes <= current.num_bytes + 1 ;
                    future.packet_crc <= in_data & current.packet_crc( 31 downto 8 ) ;
                    if( current.num_bytes = (4 - 1) ) then
                        future.fsm <= COMPARE_CRC ;
                    end if ;
                end if ;

            when COMPARE_CRC =>
                if( current.packet_crc = calculated_crc ) then
                    future.crc_correct <= '1' ;
                    if( current.frame_control(11 downto 10) = "01" and current.frame_control(15 downto 12) = "1101" and current.a0 = bss_mac ) then
                        future.acked_packet <= '1' ;
                    end if;
                    if( current.frame_control(10) = '0' ) then
                        if( current.frame_control(1 downto 1) = "0" and current.a0 = bss_mac ) then
                           future.ack_mac <= current.a1 ;
                           future.ack_valid <= '1' ;
                        elsif(current.frame_control(1 downto 0) = "10" and current.a1 = bss_mac ) then
                           future.ack_mac <= current.a2 ;
                           future.ack_valid <= '1' ;
                        end if;
                    end if ;
                end if ;
                future.done <= '1' ;
                future.fsm <= IDLE ;

            when others =>
                future <= NULL_STATE ;
            
        end case ;

    end process ;

    U_crc : entity wlan.wlan_crc
      port map (
        clock     => clock,
        reset     => reset or init,

        in_data   => in_data,
        in_valid  => in_valid and payload_data,
        crc       => calculated_crc
      ) ;
end architecture ;

