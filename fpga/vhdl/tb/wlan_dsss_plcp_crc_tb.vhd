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
    use wlan.wlan_rx_p.all ;

entity wlan_dsss_plcp_crc_tb is
end entity ;

architecture arch of wlan_dsss_plcp_crc_tb is

    signal clock        :   std_logic         := '1' ;
    signal reset        :   std_logic         := '1' ;

    signal in_data      :   std_logic         := '1' ;

begin

    clock <= not clock after 5 ns ;
    reset <= '1', '0' after 55 ns ;
    in_data <= '0',
        '1' after 65 ns,
        '0' after 75 ns,
        '1' after 85 ns,
        '0' after 95 ns;


    U_plcp_crc : entity wlan.wlan_dsss_plcp_crc
      port map (
        clock     => clock,
        reset     => reset,

        in_data   => in_data,
        in_valid  => '1',
        crc       => open
      ) ;

end architecture ;
