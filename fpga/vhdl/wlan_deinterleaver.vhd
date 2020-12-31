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

entity wlan_deinterleaver is
  port (
    clock               :   in  std_logic ;
    reset               :   in  std_logic ;

    modulation          :   in  wlan_modulation_t ;
    data                :   in  bsd_array_t(287 downto 0) ;
    in_valid            :   in  std_logic ;

    depuncturer_empty   :   in  std_logic ;

    deinterleaved_mod     :   out wlan_modulation_t ;
    deinterleaved         :   out bsd_array_t(287 downto 0) ;
    deinterleaved_valid   :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_deinterleaver is
    signal data_new : std_logic ;
    signal data_r : bsd_array_t(287 downto 0) ;
begin

    permute_bits : process(clock, reset)
    begin
        if( reset = '1' ) then
            deinterleaved <= (others =>(others =>'0')) ;
            deinterleaved_mod <= WLAN_BPSK ;
            deinterleaved_valid <= '0' ;
            data_new <= '0' ;
        elsif( rising_edge(clock) ) then
            deinterleaved_valid <= '0' ;
            if( in_valid = '1' ) then
                data_r <= data ;
                data_new <= '1' ;
            end if;
            if( depuncturer_empty = '1' and data_new = '1' ) then
                data_new <= '0' ;
                deinterleaved_valid <= '1' ;
                deinterleaved <= deinterleave(modulation, data) ;
                if( modulation = WLAN_BPSK ) then
                    deinterleaved( 287 downto 48 ) <= (others =>(others => '0' )) ;
                end if ;
                deinterleaved_mod <= modulation ;
            end if ;
        end if ;
    end process ;

end architecture ;

