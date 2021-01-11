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

entity branch_compare is
   generic(
      RESET_ACTIVE : boolean     :=  false;
      REG_UNCODED  : boolean     :=  false
   );
   port(
      clock      :  in  std_logic;
      reset      :  in  std_logic;

      bm_a       :  in  unsigned(15 downto 0);
      bm_b       :  in  unsigned(15 downto 0);
      bm_valid   :  in  std_logic;

      path_in_a  :  in  path_t;
      path_in_b  :  in  path_t;

      branch     :  in  branch_inputs_t;
      path_out   :  out path_t;

      win        :  out std_logic
   );
end entity;

architecture arch of branch_compare is
begin

   process(reset, clock)
      variable cost_a, cost_b : unsigned(path_in_a.cost'range);
   begin
      if (reset = '1') then
         path_out <= NULL_PATH_RST(RESET_ACTIVE);
         win      <= '0';
      elsif (rising_edge(clock)) then
         if (bm_valid = '1') then
            cost_a := path_in_a.cost + bm_a;
            cost_b := path_in_b.cost + bm_b;

            if ((path_in_a.cost = (path_in_a.cost'range => '1')) and
               (path_in_b.cost = (path_in_b.cost'range => '1'))) then
               win <= '0';
               path_out.cost <= ( others => '1' );
            elsif (path_in_a.cost = (path_in_a.cost'range => '1')) then
               win <= '1';
               path_out.cost <= cost_b;
            elsif (path_in_b.cost = (path_in_b.cost'range => '1')) then
               win <= '0';
               path_out.cost <= cost_a;
            else
               if (cost_b < cost_a) then
                  win <= '1';
                  path_out.cost <= cost_b;
               else
                  win <= '0';
                  path_out.cost <= cost_a;
               end if;
            end if;
         end if;
      end if;
   end process;
end architecture;
