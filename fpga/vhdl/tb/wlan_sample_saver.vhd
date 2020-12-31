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

library std ;
    use std.textio.all ;

library work ;
    use work.wlan_p.all ;

entity wlan_sample_saver is
  generic (
    FILENAME    :       string      := "samples"
  ) ;
  port (
    clock       :   in  std_logic ;
    fopen       :   in  std_logic ;
    sample      :   in  wlan_sample_t ;
    done        :   in  std_logic
  ) ;
end entity ;

architecture arch of wlan_sample_saver is

begin

    save : process
        file f : text ;
        variable l : line ;
        variable status : file_open_status ;
        variable fcount :   natural := 0 ;
        variable scount :   natural := 0 ;
        function fname( b : string ; count : natural ) return string is
        begin
            return b & "-" & integer'image(count) & ".csv" ;
        end function ;
    begin
        wait until rising_edge(clock) and fopen = '1' ;
        file_open(status, f, fname( FILENAME, fcount ), write_mode) ;
        assert status = OPEN_OK
            report "Could not open file: " & fname( FILENAME, fcount )
            severity failure ;
        scount := 0 ;
        while true loop
            wait until rising_edge(clock) and sample.valid = '1' ;
            write( l, to_integer(sample.i) ) ;
            write( l, ',' ) ;
            write( l, to_integer(sample.q) ) ;
            writeline( f, l ) ;
            flush( f ) ;
            scount := scount + 1 ;
            if( done = '1' ) then
                file_close( f ) ;
                write( output, "Wrote " & integer'image(scount) & " samples to " & fname( FILENAME, fcount ) & CR ) ;
                fcount := fcount + 1 ;
                exit ;
            end if ;
        end loop ;
    end process ;

end architecture ;

