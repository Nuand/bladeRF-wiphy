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

entity wlan_peak_finder is
  generic (
    SAMPLE_WINDOW   :       integer := 31
  ) ;
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    sample          :   in  unsigned(127 downto 0 ) ;
    sample_valid    :   in  std_logic;
    peak            :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_peak_finder is

    type peak_array_t is array(0 to SAMPLE_WINDOW-1) of unsigned(sample'range) ;

    signal samples : peak_array_t ;

begin

    process( clock )
        variable highest : std_logic;
    begin
        if( rising_edge( clock ) ) then
            if( sample_valid = '1' ) then
                for i in 0 to samples'high - 1 loop
                    samples(i+1) <= samples(i) ;
                end loop ;
                samples(0) <= sample ;

                highest := '1';
                for i in samples'range loop
                    if (i /= 15 and samples(i) > samples(15)) then
                        highest := '0';
                    end if;
                end loop;
                if (samples(15) < 300000000) then
                    highest := '0';
                end if;

                peak <= highest;

            end if ;
        end if ;
    end process ;

end architecture ;

