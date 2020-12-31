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

entity wlan_dsss_rx_controller is
    port (
      clock            :   in std_logic ;
      reset            :   in std_logic ;

      in_sample        :   in wlan_sample_t ;

      modulation       :   out wlan_modulation_t;
      out_bin_idx      :   out natural
    ) ;
end entity;

architecture arch of wlan_dsss_rx_controller is

    type fsm_t is (IDLE) ;

    type state_t is record
        fsm            :  fsm_t ;
        bin_idx        :  natural range 0 to 20 ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := IDLE ;
        rv.bin_idx := 0 ;
        return rv ;
    end function ;

    signal current, future  :   state_t := NULL_STATE ;
begin
    out_bin_idx <= current.bin_idx ;
    modulation <= WLAN_DBPSK ;

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
        if( in_sample.valid = '1' ) then
            if( current.bin_idx = 19 ) then
                future.bin_idx <= 0 ;
            else
                future.bin_idx <= current.bin_idx + 1 ;
            end if ;
        end if ;
    end process ;
end architecture ;
