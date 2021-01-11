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

entity tracer is
   generic(
      STATE_BITS  :  in  integer;
      NUM_STATES  :  in  integer
   );
   port(
      clock       :  in  std_logic;
      reset       :  in  std_logic;

      state_in    :  in  unsigned(STATE_BITS-1 downto 0);
      state_valid :  in  std_logic;
      acs_reg     :  in  std_logic_vector(NUM_STATES-1 downto 0);
      acs_valid   :  in  std_logic;

      state_out   :  out unsigned(STATE_BITS-1 downto 0);
      valid_out   :  out std_logic
   );
end entity;

architecture arch of tracer is
begin
   process(clock, reset)
      variable s_bit : std_logic;
   begin
      if (reset='1') then
         state_out <= ( others => '0' );
         valid_out <= '0';
      elsif (rising_edge(clock)) then
         s_bit := acs_reg(to_integer(state_in));
         if (acs_valid = '1') then
            state_out <= s_bit & state_in(state_in'high downto 1);
            valid_out <= state_valid;
         end if;
      end if;
   end process;
end architecture;
