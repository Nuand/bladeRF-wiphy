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

entity r2_comparator is
   generic(
      NUM_PATHS  :  in  natural := 64;
      STATE_BITS :  in  natural := 6
   );
   port(
      clock      :  in  std_logic;
      reset      :  in  std_logic;

      paths      :  in  path_arr_t(NUM_PATHS-1 downto 0);
      path_valid :  in  std_logic;

      label_out  :  out unsigned(STATE_BITS-1 downto 0);
      valid_out  :  out std_logic
   );
end entity;

architecture arch of r2_comparator is
   type path_name_arr_arr_t is array(natural range <>) of path_name_arr_t(NUM_PATHS-1 downto 0);

   signal r2_matrix  : path_name_arr_arr_t(STATE_BITS downto 0);

   signal valid_out_r : std_logic_vector(STATE_BITS - 1 downto 1);
begin
   gen_init_path: for i in paths'range generate
      r2_matrix(0)(i).path <= paths(i);
      r2_matrix(0)(i).name <= to_unsigned(i, 6);
   end generate;

   process(clock, reset)
   begin
      if (reset = '1') then
         valid_out_r <= ( others => '0' );
         valid_out <= '0';
      elsif (rising_edge(clock)) then
         if (path_valid = '1') then
            valid_out_r <= path_valid & valid_out_r(valid_out_r'high downto 2);
            valid_out <= valid_out_r(1);
         else
            valid_out <= '0';
         end if;
      end if;
   end process;

   gen_cs: for cs_i in 1 to STATE_BITS generate
      gen_rs: for rs_i in 0 to NUM_PATHS/(2**cs_i)-1 generate
         U_comp2 : entity work.comp2
            port map(
               clock          => clock,
               reset          => reset,

               path_name_a    => r2_matrix(cs_i-1)(rs_i * 2),
               path_name_b    => r2_matrix(cs_i-1)(rs_i * 2 + 1),
               path_valid     => path_valid,
               path_name_out  => r2_matrix(cs_i)(rs_i)
            );
      end generate;
   end generate;

   label_out <= r2_matrix(r2_matrix'high)(0).name;

end architecture;
