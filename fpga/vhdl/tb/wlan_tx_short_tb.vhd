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
    use work.wlan_tx_p.all ;

entity wlan_tx_short_tb is
end entity ;

architecture arch of wlan_tx_short_tb is

    signal clock    :   std_logic       := '1' ;
    signal reset    :   std_logic       := '1' ;
    signal start    :   std_logic       := '0' ;
    signal done     :   std_logic ;
    signal sample   :   wlan_sample_t ;

begin

    clock <= not clock after 1 ns ;

    U_tx_short : entity work.wlan_tx_short
      port map (
        clock           =>  clock,
        reset           =>  reset,
        start           =>  start,
        done            =>  done,
        out_sample      =>  sample
      ) ;

    tb : process
    begin
        reset <= '1' ;
        nop(clock, 100) ;

        reset <= '0' ;
        nop(clock, 100) ;

        start <= '1' ;
        nop(clock, 1) ;
        start <= '0' ;
        nop(clock, 1) ;

        nop(clock, 1000 ) ;

        report "-- End of Simulation --" severity failure ;
    end process ;

end architecture ;

