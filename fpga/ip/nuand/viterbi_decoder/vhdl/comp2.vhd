-- This file is part of bladeRF-wiphy.
--
-- Copyright (C) 2021 Nuand, LLC.
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

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.viterbi_p.all;

entity comp2 is
   port(
      clock       :  in  std_logic;
      reset       :  in  std_logic;

      path_name_a  :  in  path_name_t;
      path_name_b  :  in  path_name_t;
      path_valid   :  in  std_logic;

      path_name_out : out path_name_t
   );
end entity;

architecture arch of comp2 is
begin
   process(clock, reset)
   begin
      if (reset = '1') then
         path_name_out.name <= (others => '0');
         path_name_out.path <= NULL_PATH_T;
      elsif (rising_edge(clock)) then
         if (path_valid = '1') then
            if (path_name_b.path.cost < path_name_a.path.cost) then
               path_name_out <= path_name_b;
            else
               path_name_out <= path_name_a;
            end if;
         end if;
      end if;
   end process;
end architecture;
