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

library std ;
    use std.textio.all ;

entity wlan_interleaver_tb is
end entity ;

architecture arch of wlan_interleaver_tb is

    procedure print( table : integer_array_t ; n : natural ) is
    begin
        for i in 0 to n-1 loop
            write(output, integer'image(i) & " -> " & integer'image(table(i)) & CR ) ;
        end loop ;
    end procedure ;

begin

    tb : process
        variable l : line ;
    begin

        write( output, "-- BPSK Table --" & CR ) ;
        print( WLAN_INTERLEAVER_BPSK, 48 ) ;
        wait ;

    end process ;

end architecture ;

