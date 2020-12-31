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
    use ieee.math_real.all ;

library work ;
    use work.wlan_p.all ;
    use work.wlan_tx_p.all ;

entity wlan_tx_long is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;
    start           :   in  std_logic ;
    done            :   out std_logic ;
    out_sample      :   out wlan_sample_t ;
    out_valid_cp    :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_tx_long is

    function create_long_sequence return sample_array_t is
        variable rv : sample_array_t(LONG_SEQ_TIME'range) ;
    begin
        for i in rv'range loop
            rv(i).i := to_signed(integer(round(LONG_SEQ_TIME(i).re*4096.0*4.0)),rv(i).i'length) ;
            rv(i).q := to_signed(integer(round(LONG_SEQ_TIME(i).im*4096.0*4.0)),rv(i).q'length) ;
            rv(i).valid := '1' ;
        end loop;
        return rv ;
    end function ;

    constant LONG_SEQ : sample_array_t := create_long_sequence ;

    type fsm_t is (IDLE, CYCLIC_PREFIX, T_SEQ) ;

    type state_t is record
        fsm         :   fsm_t ;
        repeat      :   natural range 1 to 2 ;
        index       :   natural range LONG_SEQ'range ;
        sample      :   wlan_sample_t ;
        valid_cp    :   std_logic ;
        done        :   std_logic ;
    end record ;

    constant NULL_STATE : state_t := (
        fsm         =>  IDLE,
        repeat      =>  2,
        index       =>  32,
        sample      =>  NULL_SAMPLE,
        valid_cp    =>  '0',
        done        =>  '0'
    ) ;

    -- FSM state
    signal current, future  :   state_t := NULL_STATE ;

begin

    done <= current.done ;
    out_sample <= current.sample ;
    out_valid_cp <= current.valid_cp ;

    seq : process(clock, reset)
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
        case current.fsm is
            when IDLE =>
                future <= NULL_STATE ;
                if( start = '1' ) then
                    future.fsm <= CYCLIC_PREFIX ;
                end if ;

            when CYCLIC_PREFIX =>
                future.sample <= LONG_SEQ(current.index) ;
                future.valid_cp <= '1' ;
                future.sample.valid <= '0' ;
                if( current.index < LONG_SEQ'high ) then
                    future.index <= current.index + 1 ;
                else
                    future.fsm <= T_SEQ ;
                    future.index <= 0 ;
                end if ;

            when T_SEQ =>
                future.sample <= LONG_SEQ(current.index) ;
                future.valid_cp <= '0' ;
                if( current.index < LONG_SEQ'high ) then
                    future.index <= current.index + 1 ;
                else
                    if( current.repeat = 1 ) then
                        future.fsm <= IDLE ;
                        future.done <= '1' ;
                    else
                        future.repeat <= current.repeat - 1 ;
                        future.index <= 0 ;
                    end if ;
                end if ;

            when others =>
                future <= NULL_STATE ;

        end case ;
    end process ;

end architecture ;

