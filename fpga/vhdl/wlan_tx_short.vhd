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

entity wlan_tx_short is
  port (
    clock       :   in  std_logic ;
    reset       :   in  std_logic ;
    start       :   in  std_logic ;
    done        :   out std_logic ;
    out_sample  :   out wlan_sample_t
  ) ;
end entity ;

architecture arch of wlan_tx_short is

    function create_short_sequence return sample_array_t is
        variable rv : sample_array_t(SHORT_SEQ_TIME'range) ;
    begin
        for i in rv'range loop
            rv(i).i := to_signed(integer(round(SHORT_SEQ_TIME(i).re*4.0*4096.0)),rv(i).i'length) ;
            rv(i).q := to_signed(integer(round(SHORT_SEQ_TIME(i).im*4.0*4096.0)),rv(i).i'length) ;
            rv(i).valid := '1' ;
        end loop ;
        return rv ;
    end function ;

    constant SHORT_SEQ : sample_array_t := create_short_sequence ;

    type fsm_t is (IDLE, COUNTING) ;

    type state_t is record
        fsm     :   fsm_t ;
        repeat  :   natural range 1 to 10 ;
        index   :   natural range short_seq'range ;
        sample  :   wlan_sample_t ;
        done    :   std_logic ;
    end record ;

    constant NULL_STATE : state_t := (
        fsm     =>  IDLE,
        repeat  =>  10,
        index   =>  0,
        sample  =>  NULL_SAMPLE,
        done    =>  '0'
    ) ;

    -- FSM state
    signal current, future  :   state_t := NULL_STATE ;

begin

    done <= current.done ;
    out_sample <= current.sample ;

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
                    future.fsm <= COUNTING ;
                end if ;

            when COUNTING =>
                future.sample <= short_seq(current.index) ;
                if( current.index < short_seq'high ) then
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

