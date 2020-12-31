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
    use work.wlan_interleaver_p.all ;

entity wlan_interleaver is
  port (
    clock               :   in  std_logic ;
    reset               :   in  std_logic ;

    modulation          :   in  wlan_modulation_t ;
    data                :   in  std_logic_vector(287 downto 0) ;
    in_valid            :   in  std_logic ;

    interleaved         :   out std_logic_vector(287 downto 0) ;
    interleaved_mod     :   out wlan_modulation_t ;
    interleaved_valid   :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_interleaver is

begin

    permute_bits : process(clock, reset)
    begin
        if( reset = '1' ) then
            interleaved <= (others =>'0') ;
            interleaved_mod <= WLAN_BPSK ;
            interleaved_valid <= '0' ;
        elsif( rising_edge(clock) ) then
            interleaved_valid <= in_valid ;
            if( in_valid = '1' ) then
                interleaved <= interleave(modulation, data) ;
                interleaved_mod <= modulation ;
            end if ;
        end if ;
    end process ;

end architecture ;

