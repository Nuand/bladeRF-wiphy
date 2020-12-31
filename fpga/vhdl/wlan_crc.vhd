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

entity wlan_crc is
  port (
    clock       :   in  std_logic ;
    reset       :   in  std_logic ;

    in_data     :   in  std_logic_vector(7 downto 0) ;
    in_valid    :   in  std_logic ;

    crc         :   out std_logic_vector(31 downto 0)
  ) ;
end entity ;

architecture arch of wlan_crc is

    signal crc_next : std_logic_vector(31 downto 0);

begin

    process( reset, clock )
    begin
        if( reset = '1' ) then
            crc_next <= ( others => '1' ) ;
        elsif( rising_edge( clock ) ) then
            if (in_valid = '1' ) then
                crc_next(0) <= crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(1) <= crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(2) <= crc_next(26) xor in_data(5) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(3) <= crc_next(27) xor in_data(4) xor crc_next(26) xor in_data(5) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6);
                crc_next(4) <= crc_next(28) xor in_data(3) xor crc_next(27) xor in_data(4) xor crc_next(26) xor in_data(5) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(5) <= crc_next(29) xor in_data(2) xor crc_next(28) xor in_data(3) xor crc_next(27) xor in_data(4) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(6) <= crc_next(30) xor in_data(1) xor crc_next(29) xor in_data(2) xor crc_next(28) xor in_data(3) xor crc_next(26) xor in_data(5) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6);
                crc_next(7) <= crc_next(31) xor in_data(0) xor crc_next(30) xor in_data(1) xor crc_next(29) xor in_data(2) xor crc_next(27) xor in_data(4) xor crc_next(26) xor in_data(5) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(8) <= crc_next(0) xor crc_next(31) xor in_data(0) xor crc_next(30) xor in_data(1) xor crc_next(28) xor in_data(3) xor crc_next(27) xor in_data(4) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(9) <= crc_next(1) xor crc_next(31) xor in_data(0) xor crc_next(29) xor in_data(2) xor crc_next(28) xor in_data(3) xor crc_next(26) xor in_data(5) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6);
                crc_next(10) <= crc_next(2) xor crc_next(30) xor in_data(1) xor crc_next(29) xor in_data(2) xor crc_next(27) xor in_data(4) xor crc_next(26) xor in_data(5) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(11) <= crc_next(3) xor crc_next(31) xor in_data(0) xor crc_next(30) xor in_data(1) xor crc_next(28) xor in_data(3) xor crc_next(27) xor in_data(4) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(12) <= crc_next(4) xor crc_next(31) xor in_data(0) xor crc_next(29) xor in_data(2) xor crc_next(28) xor in_data(3) xor crc_next(26) xor in_data(5) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(13) <= crc_next(5) xor crc_next(30) xor in_data(1) xor crc_next(29) xor in_data(2) xor crc_next(27) xor in_data(4) xor crc_next(26) xor in_data(5) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6);
                crc_next(14) <= crc_next(6) xor crc_next(31) xor in_data(0) xor crc_next(30) xor in_data(1) xor crc_next(28) xor in_data(3) xor crc_next(27) xor in_data(4) xor crc_next(26) xor in_data(5);
                crc_next(15) <= crc_next(7) xor crc_next(31) xor in_data(0) xor crc_next(29) xor in_data(2) xor crc_next(28) xor in_data(3) xor crc_next(27) xor in_data(4);
                crc_next(16) <= crc_next(8) xor crc_next(30) xor in_data(1) xor crc_next(29) xor in_data(2) xor crc_next(28) xor in_data(3) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(17) <= crc_next(9) xor crc_next(31) xor in_data(0) xor crc_next(30) xor in_data(1) xor crc_next(29) xor in_data(2) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6);
                crc_next(18) <= crc_next(10) xor crc_next(31) xor in_data(0) xor crc_next(30) xor in_data(1) xor crc_next(26) xor in_data(5);
                crc_next(19) <= crc_next(11) xor crc_next(31) xor in_data(0) xor crc_next(27) xor in_data(4);
                crc_next(20) <= crc_next(12) xor crc_next(28) xor in_data(3);
                crc_next(21) <= crc_next(13) xor crc_next(29) xor in_data(2);
                crc_next(22) <= crc_next(14) xor crc_next(30) xor in_data(1) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(23) <= crc_next(15) xor crc_next(31) xor in_data(0) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(24) <= crc_next(16) xor crc_next(26) xor in_data(5) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6);
                crc_next(25) <= crc_next(17) xor crc_next(27) xor in_data(4) xor crc_next(26) xor in_data(5);
                crc_next(26) <= crc_next(18) xor crc_next(28) xor in_data(3) xor crc_next(27) xor in_data(4) xor crc_next(24) xor crc_next(30) xor in_data(1) xor in_data(7);
                crc_next(27) <= crc_next(19) xor crc_next(29) xor in_data(2) xor crc_next(28) xor in_data(3) xor crc_next(25) xor crc_next(31) xor in_data(0) xor in_data(6);
                crc_next(28) <= crc_next(20) xor crc_next(30) xor in_data(1) xor crc_next(29) xor in_data(2) xor crc_next(26) xor in_data(5);
                crc_next(29) <= crc_next(21) xor crc_next(31) xor in_data(0) xor crc_next(30) xor in_data(1) xor crc_next(27) xor in_data(4);
                crc_next(30) <= crc_next(22) xor crc_next(31) xor in_data(0) xor crc_next(28) xor in_data(3);
                crc_next(31) <= crc_next(23) xor crc_next(29) xor in_data(2);
            end if;
        end if;
    end process;

    process(crc_next)
    begin
       for i in 0 to 31 loop
          crc(i) <= crc_next(31 - i) xor '1';
       end loop;
    end process;

end architecture ;

