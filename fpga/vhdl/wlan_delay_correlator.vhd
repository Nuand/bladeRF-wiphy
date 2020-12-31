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

entity wlan_delay_correlator is
  generic (
    SAMPLE_DELTA    :       integer
  ) ;
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    sample          :   in  wlan_sample_t ;
    value           :   out signed( 127 downto 0 )
  ) ;
end entity ;

architecture arch of wlan_delay_correlator is

    signal samples : sample_array_t( 0 to SAMPLE_DELTA * 2 - 1 ) ;

begin

    process( clock )
        variable isum : signed( 63 downto 0 ) ;
        variable qsum : signed( 63 downto 0 ) ;
    begin
        if( rising_edge( clock ) ) then
            if( sample.valid = '1' ) then
                for i in 0 to samples'high - 1 loop
                    samples(i+1) <= samples(i) ;
                end loop ;
                samples(0) <= sample ;

                isum := (others => '0') ;
                qsum := (others => '0') ;
                for i in 0 to SAMPLE_DELTA - 1 loop
                    isum := isum + samples(i).i * samples(i + SAMPLE_DELTA).i +
                                        samples(i).q * samples(i + SAMPLE_DELTA).q ;
                    qsum := qsum - samples(i).i * samples(i + SAMPLE_DELTA).q +
                                        samples(i).q * samples(i + SAMPLE_DELTA).i ;
                end loop ;
                value <= isum * isum + qsum * qsum ;
            end if ;
        end if ;
    end process ;

end architecture ;

