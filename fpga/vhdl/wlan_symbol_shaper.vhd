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

entity wlan_symbol_shaper is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;
    cp_i            :   in  signed(15 downto 0) ;
    cp_q            :   in  signed(15 downto 0) ;
    cp_re           :   out std_logic ;
    cp_empty        :   in  std_logic ;
    sample_i        :   in  signed(15 downto 0) ;
    sample_q        :   in  signed(15 downto 0) ;
    sample_re       :   out std_logic ;
    sample_empty    :   in  std_logic ;
    out_sample      :   out wlan_sample_t ;
    done            :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_symbol_shaper is

    type fsm_t is (IDLE, SHORT_SEQUENCE, GI2, LONG_SEQUENCE, SIGNAL_GI, SIGNAL_SYMBOL, DATA_GI, DATA_SYMBOL, FINISH) ;

    type state_t is record
        fsm         :   fsm_t ;
        enable      :   std_logic ;
        sample      :   wlan_sample_t ;
        sample_re   :   std_logic ;
        cp_re       :   std_logic ;
        downcount   :   natural range 0 to 160 ;
        done        :   std_logic ;
    end record ;

    function init return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := IDLE ;
        rv.enable := '0' ;
        rv.sample := NULL_SAMPLE ;
        rv.downcount := 160 ;
        rv.sample_re := '0' ;
        rv.cp_re := '0' ;
        rv.done := '0' ;
        return rv ;
    end function ;

    signal current, future  :   state_t := init ;

begin

    out_sample <= current.sample ;
    sample_re <= current.sample_re ;
    cp_re <= current.cp_re ;
    done <= current.done ;

    sync : process(clock, reset)
    begin
        if( reset = '1' ) then
            current <= init ;
        elsif( rising_edge(clock) ) then
            current <= future ;
        end if ;
    end process ;

    comb : process(all)
    begin
        -- Save all current state
        future <= current ;

        -- Reset valids
        future.sample.valid <= '0' ;
        future.sample_re <= '0' ;
        future.cp_re <= '0' ;
        future.done <= '0' ;

        -- Get the FSM kicked off
        case current.fsm is
            when IDLE =>
                future.downcount <= 160-1 ;
                if( sample_empty = '0' ) then
                    future.fsm <= SHORT_SEQUENCE ;
                end if ;
            when others =>
                null ;
        end case ;

        -- Advance the FSM once every other clock cycle
        if( current.fsm /= IDLE ) then
            future.enable <= not current.enable ;
        end if ;

        -- Meat and potatoes of the FSM which advances
        -- once every other clock cycle
        if current.enable = '1' then
            case current.fsm is

                when SHORT_SEQUENCE =>
                    future.sample.i <= sample_i ;
                    future.sample.q <= sample_q ;
                    future.sample.valid <= '1' ;
                    future.sample_re <= '1' ;
                    if( current.downcount = 0 ) then
                        future.downcount <= 32-1 ;
                        future.fsm <= GI2 ;
                    else
                        future.downcount <= current.downcount - 1 ;
                    end if ;

                when GI2 =>
                    future.sample.i <= cp_i ;
                    future.sample.q <= cp_q ;
                    future.sample.valid <= '1' ;
                    future.cp_re <= '1' ;
                    if( current.downcount = 0 ) then
                        future.downcount <= 128-1 ;
                        future.fsm <= LONG_SEQUENCE ;
                    else
                        future.downcount <= current.downcount - 1 ;
                    end if ;

                when LONG_SEQUENCE =>
                    future.sample.i <= sample_i ;
                    future.sample.q <= sample_q ;
                    future.sample.valid <= '1' ;
                    future.sample_re <= '1' ;
                    if( current.downcount = 0 ) then
                        future.downcount <= 16-1 ;
                        future.fsm <= SIGNAL_GI ;
                    else
                        future.downcount <= current.downcount - 1 ;
                    end if ;

                when SIGNAL_GI =>
                    future.sample.i <= cp_i ;
                    future.sample.q <= cp_q ;
                    future.sample.valid <= '1' ;
                    future.cp_re <= '1' ;
                    if( current.downcount = 0 ) then
                        future.downcount <= 64-1 ;
                        future.fsm <= SIGNAL_SYMBOL ;
                    else
                        future.downcount <= current.downcount - 1 ;
                    end if ;

                when SIGNAL_SYMBOL =>
                    future.sample.i <= sample_i ;
                    future.sample.q <= sample_q ;
                    future.sample.valid <= '1' ;
                    future.sample_re <= '1' ;
                    if( current.downcount = 0 ) then
                        future.downcount <= 16-1 ;
                        future.fsm <= DATA_GI ;
                    else
                        future.downcount <= current.downcount - 1 ;
                    end if ;

                when DATA_GI =>
                    future.sample.i <= cp_i ;
                    future.sample.q <= cp_q ;
                    future.sample.valid <= '1' ;
                    future.cp_re <= '1' ;
                    if( current.downcount = 0 ) then
                        future.downcount <= 64-1 ;
                        future.fsm <= DATA_SYMBOL ;
                    else
                        future.downcount <= current.downcount - 1 ;
                    end if ;

                when DATA_SYMBOL =>
                    future.sample.i <= sample_i ;
                    future.sample.q <= sample_q ;
                    future.sample.valid <= '1' ;
                    future.sample_re <= '1' ;
                    if( current.downcount = 0 ) then
                        if( sample_empty = '1' ) then
                            future.downcount <= 160-1 ;
                            future.fsm <= FINISH ;
                        else
                            if( cp_empty = '1' ) then
                                future.downcount <= 160-1 ;
                                future.fsm <= FINISH ;
                            else
                                future.downcount <= 16-1 ;
                                future.fsm <= DATA_GI ;
                            end if ;
                        end if ;
                    else
                        future.downcount <= current.downcount - 1 ;
                    end if ;

                when FINISH =>
                    future.sample.i <= (others =>'0') ;
                    future.sample.q <= (others =>'0') ;
                    future.sample.valid <= '1' ;
                    future.done <= '1' ;
                    future.fsm <= IDLE ;

                when others =>
                    null ;

            end case ;
        end if ;
    end process ;

end architecture ;

