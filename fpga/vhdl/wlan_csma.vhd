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

entity wlan_csma is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    in_sample       :   in  wlan_sample_t ;

    quiet           :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_csma is
    type fsm_t is (IDLE, CAPTURE_PHY_NOISE, CSMA) ;

    type unsigned_array_t is array (natural range 0 to 79) of unsigned( 31 downto 0 ) ;
    type state_t is record
        fsm                 :   fsm_t ;
        quiet               :   std_logic ;
        timer               :   unsigned( 23 downto 0 ) ;
        powersum            :   unsigned( 31 downto 0 ) ;
        min_phy_noise       :   unsigned( 31 downto 0 ) ;
        history             :   unsigned_array_t ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := IDLE ;
        rv.timer := ( others => '0' ) ;
        rv.min_phy_noise := ( others => '1' ) ;
        rv.powersum := ( others => '0' ) ;
        for i in rv.history'range loop
            rv.history(i) := ( others => '0' ) ;
        end loop ;
        return rv ;
    end function ;

    signal current, future  :   state_t := NULL_STATE ;

begin

    quiet <= current.quiet ;

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

        case current.fsm is
            when IDLE =>
                future.fsm <= CAPTURE_PHY_NOISE ;
                future.quiet <= '0' ;
            when CAPTURE_PHY_NOISE =>
                future.quiet <= '0' ;
                --if( current.timer > 100000 ) then
                if( current.timer > 110 ) then
                    future.fsm <= CSMA ;
                    future.powersum <= ( others => '0' ) ;
                    for i in future.history'range loop
                        future.history(i) <= ( others => '0' ) ;
                    end loop ;
                    future.timer <= ( others => '0' ) ;
                end if ;

                if( in_sample.valid = '1' ) then
                    future.timer <= current.timer + 1 ;
                    for i in 0 to current.history'high - 1 loop
                        future.history( i + 1 ) <= current.history( i ) ;
                    end loop ;
                    future.history(0) <= unsigned(resize(in_sample.i * in_sample.i + in_sample.q * in_sample.q, 32 ));
                    future.powersum <= current.powersum + current.history(0)
                                        - current.history(79);
                    if( current.timer > 100 ) then
                        if( current.powersum < current.min_phy_noise ) then
                            future.min_phy_noise <= current.powersum ;
                        end if ;
                    end if ;
                end if ;
            when CSMA =>
                if( in_sample.valid = '1' ) then
                    for i in 0 to current.history'high - 1 loop
                        future.history( i + 1 ) <= current.history( i ) ;
                    end loop ;
                    future.history(0) <= unsigned(resize(in_sample.i * in_sample.i + in_sample.q * in_sample.q, 32 ));
                    future.powersum <= current.powersum + current.history(0)
                                        - current.history(9);

                    if( current.timer > 20 ) then
                        if( (current.min_phy_noise / 8 ) * 4 > current.powersum ) then
                            future.quiet <= '1' ;
                        else 
                            future.quiet <= '0' ;
                        end if ;
                    else
                        future.timer <= current.timer + 1 ;
                    end if ;
                end if ;
        end case ;
    end process ;
end architecture ;
