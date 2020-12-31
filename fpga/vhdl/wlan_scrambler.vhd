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
    use work.wlan_p.all ;
    use work.wlan_tx_p.all ;

entity wlan_scrambler is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    params          :   wlan_tx_params_t ;
    params_valid    :   in  std_logic ;

    in_data         :   in  std_logic_vector(7 downto 0) ;
    in_valid        :   in  std_logic ;
    in_done         :   in  std_logic ;

    out_data        :   out std_logic_vector(7 downto 0) ;
    out_valid       :   out std_logic ;
    done            :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_scrambler is

    signal lfsr_advance :   std_logic ;
    signal lfsr_data    :   std_logic_vector(in_data'range) ;
    signal lfsr_valid   :   std_logic ;

    type fsm_t is (IDLE, SKIP_SIGNAL_FIELD, SCRAMBLE_DATA, INSERT_TAIL_BITS, SCRAMBLE_PADDING) ;

    type state_t is record
        fsm                 :   fsm_t ;
        data                :   std_logic_vector(7 downto 0) ;
        data_valid          :   std_logic ;
        done                :   std_logic ;
        symbol_bytes_left   :   natural range 0 to 27 ;
        bytes_per_symbol    :   natural range 3 to 27 ;
        puncturing_nibble   :   std_logic ;
        extra_byte          :   std_logic ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := IDLE ;
        rv.data := (others =>'0') ;
        rv.data_valid := '0' ;
        rv.done := '0' ;
        rv.symbol_bytes_left := 3 ;
        rv.puncturing_nibble   := '0' ;
        rv.extra_byte   := '0' ;
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

begin

    data_reversed <= reverse(current.data) ;

    out_data <= current.data ;
    out_valid <= current.data_valid ;
    done <= current.done ;

    U_lfsr : entity work.wlan_lfsr
      generic map (
        WIDTH       =>  in_data'length
      ) port map (
        clock       =>  clock,
        reset       =>  reset,

        init        =>  params.lfsr_init,
        init_valid  =>  params_valid,

        advance     =>  lfsr_advance,
        data        =>  lfsr_data,
        data_valid  =>  lfsr_valid
      ) ;

    sync : process(clock, reset)
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
        elsif( rising_edge(clock) ) then
            current <= future ;
        end if ;
    end process ;

    comb : process(all)
    begin
        future <= current ;
        future.data_valid <= '0' ;
        future.done <= '0' ;
        lfsr_advance <= '0' ;
        case current.fsm is

            when IDLE =>
                if( params_valid = '1' ) then
                    future.fsm <= SKIP_SIGNAL_FIELD ;
                    future.symbol_bytes_left <= 3-1 ;
                    future.bytes_per_symbol <= params.n_dbps/8 ;
                    if( params.datarate = WLAN_RATE_9) then
                        future.puncturing_nibble <= '1' ;
                        future.extra_byte <= '1' ;
                    else
                        future.extra_byte <= '0' ;
                        future.puncturing_nibble <= '0' ;
                    end if ;
                end if ;

            when SKIP_SIGNAL_FIELD =>
                if( in_valid = '1' ) then
                    future.data <= in_data ;
                    future.data_valid <= '1' ;
                    if( current.symbol_bytes_left = 0 ) then
                        future.fsm <= SCRAMBLE_DATA ;
                        if( current.puncturing_nibble = '1' ) then
                           if( current.extra_byte <= '1' ) then
                               future.symbol_bytes_left <= current.bytes_per_symbol ;
                               future.extra_byte <= '0' ;
                           else
                               future.symbol_bytes_left <= current.bytes_per_symbol - 1 ;
                           end if;
                        else
                            future.symbol_bytes_left <= current.bytes_per_symbol - 1 ;
                        end if;
                    else
                        future.symbol_bytes_left <= current.symbol_bytes_left - 1 ;
                    end if ;
                end if ;

            when SCRAMBLE_DATA =>
                lfsr_advance <= in_valid ;
                if( in_valid = '1' ) then
                    future.data <= in_data xor lfsr_data ;
                    future.data_valid <= '1' ;
                    --needs to keep track if it's going to read an extra nibble or if it's going to save one
                    if ( current.symbol_bytes_left = 0 ) then
                        if( current.extra_byte = '0' ) then
                            future.symbol_bytes_left <= current.bytes_per_symbol - 1 ;
                        else
                            future.symbol_bytes_left <= current.bytes_per_symbol ;
                        end if ;
                        if( current.puncturing_nibble = '1' ) then
                            future.extra_byte <= not current.extra_byte ;
                        end if ;
                    else
                        future.symbol_bytes_left <= current.symbol_bytes_left - 1 ;
                    end if ;
                    if( in_done = '1' ) then
                        future.fsm <= INSERT_TAIL_BITS ;
                    end if ;
                end if ;

            when INSERT_TAIL_BITS =>
                lfsr_advance <= '1' ;
                future.data <= (others =>'0') ;
                future.data_valid <= '1' ;
                if( current.symbol_bytes_left = 0 ) then
                    future.fsm <= IDLE ;
                    -- Last byte in the symbol so we're good!
                    future.done <= '1' ;
                else
                    future.symbol_bytes_left <= current.symbol_bytes_left - 1 ;
                    future.fsm <= SCRAMBLE_PADDING ;
                end if ;

            when SCRAMBLE_PADDING =>
                lfsr_advance <= '1' ;
                future.data <= lfsr_data ;
                future.data_valid <= '1' ;
                if( current.symbol_bytes_left = 0 ) then
                    future.fsm <= IDLE ;
                    future.done <= '1' ;
                else
                    future.symbol_bytes_left <= current.symbol_bytes_left - 1 ;
                end if ;

            when others =>
                future.fsm <= IDLE ;
        end case ;
    end process ;

end architecture ;

