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

library work ;
    use work.wlan_rx_p.all ;
    use work.wlan_p.all ;

entity wlan_descrambler is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    init            :   in  std_logic ;

    params          :   in  wlan_rx_params_t ;
    params_valid    :   in  std_logic ;

    bypass          :   in  std_logic ;

    in_data         :   in  std_logic ;
    in_valid        :   in  std_logic ;

    out_data        :   out std_logic_vector(7 downto 0) ;
    out_valid       :   out std_logic ;
    out_done        :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_descrambler is

    signal lfsr_advance :   std_logic ;
    signal lfsr_data    :   std_logic_vector(out_data'range) ;
    signal lfsr_valid   :   std_logic ;


    type fsm_t is (CAPTURE_BITS, CAPTURED_BYTE, INIT_SCRAMBLER, INIT_SCRAMBLER_2, INIT_SCRAMBLER_3, DESCRAMBLE_DATA) ;

    type state_t is record
        fsm                 :   fsm_t ;
        bits                :   std_logic_vector(7 downto 0) ;
        bits_valid          :   std_logic ;
        data                :   std_logic_vector(7 downto 0) ;
        data_valid          :   std_logic ;
        done                :   std_logic ;
        lfsr_initialized    :   std_logic ;
        lfsr_init_val       :   unsigned( 6 downto 0 ) ;
        lfsr_init           :   std_logic ;
        service_bytes       :   natural range 0 to 2 ;
        bit_index           :   natural range 0 to 7 ;
        symbol_bytes_left   :   natural range 0 to 27 ;
        bytes_per_symbol    :   natural range 3 to 27 ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := CAPTURE_BITS ;
        rv.bits := (others =>'0') ;
        rv.bits_valid := '0' ;
        rv.data := (others =>'0') ;
        rv.data_valid := '0' ;
        rv.done := '0' ;
        rv.lfsr_initialized := '0' ;
        rv.service_bytes := 2 ;
        rv.bit_index := 0 ;
        rv.symbol_bytes_left := 3 ;
        return rv ;
    end function ;

    signal current, future  :   state_t := NULL_STATE ;

    function reverse(x : std_logic_vector) return std_logic_vector is
        variable rv : std_logic_vector(x'range) ;
    begin
        for i in x'range loop
            rv(x'high-i) := x(i) ;
        end loop ;
        return rv ;
    end function ;

    signal data_reversed : std_logic_vector(7 downto 0) ;

    constant descrambler_table : integer_array_t(0 to 127) := (
                0, 73, 36, 109, 18, 91, 54, 127,
                9, 64, 45, 100, 27, 82, 63, 118,
                77, 4, 105, 32, 95, 22, 123, 50,
                68, 13, 96, 41, 86, 31, 114, 59,
                38, 111, 2, 75, 52, 125, 16, 89,
                47, 102, 11, 66, 61, 116, 25, 80,
                107, 34, 79, 6, 121, 48, 93, 20,
                98, 43, 70, 15, 112, 57, 84, 29,
                19, 90, 55, 126, 1, 72, 37, 108,
                26, 83, 62, 119, 8, 65, 44, 101,
                94, 23, 122, 51, 76, 5, 104, 33,
                87, 30, 115, 58, 69, 12, 97, 40,
                53, 124, 17, 88, 39, 110, 3, 74,
                60, 117, 24, 81, 46, 103, 10, 67,
                120, 49, 92, 21, 106, 35, 78, 7,
                113, 56, 85, 28, 99, 42, 71, 14
            ) ;

begin

    data_reversed <= reverse(current.data) ;

    out_data <= current.data ;
    out_valid <= current.data_valid ;
    out_done <= current.done ;

    U_lfsr : entity work.wlan_lfsr
      generic map (
        WIDTH       =>  out_data'length
      ) port map (
        clock       =>  clock,
        reset       =>  reset,

        init        =>  current.lfsr_init_val,
        init_valid  =>  current.lfsr_init,

        advance     =>  lfsr_advance,
        data        =>  lfsr_data,
        data_valid  =>  lfsr_valid
      ) ;

    sync : process(clock, reset)
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
        elsif( rising_edge(clock) ) then
            if( init = '1' ) then
                current <= NULL_STATE ;
            else
                current <= future ;
            end if ;
        end if ;
    end process ;

    comb : process(all)
    begin
        future <= current ;
        future.bits_valid <= '0' ;
        future.data_valid <= '0' ;
        future.done <= '0' ;
        lfsr_advance <= '0' ;
        future.lfsr_init <= '0' ;

        if( in_valid = '1') then
            future.bits <= current.bits(6 downto 0) & in_data ;
            if( current.bit_index = 7 ) then
                future.bit_index <= 0 ;
                future.bits_valid <= '1' ;
            else
                future.bit_index <= current.bit_index + 1;
            end if ;
        end if ;

        case current.fsm is

            when CAPTURE_BITS =>
                if( params_valid = '1' ) then
                    future.service_bytes <= 2 ;
                end if ;
                if( current.bits_valid = '1') then
                    future.data <= current.bits ;
                    future.fsm <= CAPTURED_BYTE ;
                end if ;

            when CAPTURED_BYTE =>
                if( bypass = '1' ) then
                    future.data <= reverse( current.data ) ;
                    future.data_valid <= '1' ;
                    future.fsm <= CAPTURE_BITS ;
                else
                    if( current.service_bytes = 0 ) then
                        future.data <= reverse( current.data ) ;
                        future.fsm <= DESCRAMBLE_DATA ;
                    else
                        future.fsm <= INIT_SCRAMBLER ;
                        future.service_bytes <= current.service_bytes - 1 ;
                    end if ;

                end if ;

            when INIT_SCRAMBLER =>
                if( current.service_bytes = 1 ) then
                    future.lfsr_init_val <= unsigned(reverse(std_logic_vector(to_unsigned(descrambler_table(to_integer(unsigned(current.data(7 downto 1)))), 7 ) )));
                    future.lfsr_init <= '1' ;
                    future.fsm <= INIT_SCRAMBLER_2 ;
                else
                    lfsr_advance <= '1' ;
                    future.fsm <= CAPTURE_BITS ;
                end if ;

            when INIT_SCRAMBLER_2 =>
                future.fsm <= INIT_SCRAMBLER_3 ;

            when INIT_SCRAMBLER_3 =>
                lfsr_advance <= '1' ;
                future.fsm <= CAPTURE_BITS ;

            when DESCRAMBLE_DATA =>
                lfsr_advance <= '1' ;
                future.data <= current.data xor lfsr_data ;
                future.data_valid <= '1' ;
                future.fsm <= CAPTURE_BITS ;

            when others =>
                future.fsm <= CAPTURE_BITS ;
        end case ;
    end process ;

end architecture ;


