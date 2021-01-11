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

entity r2_comparator_tb is
end entity;

architecture behv of r2_comparator_tb is
   signal clock    : std_logic := '0';
   signal reset    : std_logic;
   signal valid    : std_logic;
   signal paths    : path_arr_t(63 downto 0);

begin
   clock <= not clock after 10 ns;
   reset <= '1', '0' after 100 ns;
   valid <= '0', '1' after 198 ns, '0' after 548 ns;

   process
      variable i : integer;
      variable t_cost : integer;
   begin
      for i in paths'range loop
         if (i = 51) then
            t_cost := 10;
         else
            t_cost := 100 + i;
         end if;
         paths(i).cost   <= to_unsigned(t_cost, paths(i).cost'high + 1);
         paths(i).active <= '0';
      end loop;
      wait;
   end process;
      
   
   U_uut: entity work.r2_comparator
      port map(
         clock       => clock,
         reset       => reset,

         paths       => paths,
         path_valid  => valid,

         label_out   => open,
         valid_out   => open
      );
end architecture;

