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

package viterbi_p is
   type path_t is record
      --- path metric stuff
      cost           :  unsigned(23 downto 0);
      active         :  std_logic;
   end record;
   type path_arr_t is array(natural range <>) of path_t;

   type path_name_t is record
      path           :  path_t;
      name           :  unsigned(5 downto 0);
   end record;

   type path_name_arr_t is array(natural range <>) of path_name_t;


   type branch_t is record
      -- starting conditions
      start_state : natural;
      u_bit       : std_logic;

      -- internal state keeping
      bit_s       : std_logic;
      set         : boolean;

      -- output
      bit_a       : std_logic;
      bit_b       : std_logic;
      bm_idx      : integer;

      -- final state
      prev_state  : integer;
      next_state  : integer;
   end record;

   type branch_inputs_t is array(1 downto 0) of branch_t;

   type bsd_t is array(natural range <>) of unsigned(7 downto 0);

   type bm_t  is array(natural range <>) of unsigned(15 downto 0);

   function NULL_PATH_RST(init_state : boolean) return path_t;
   function NULL_PATH_T return path_t;
end package;

package body viterbi_p is
   function NULL_PATH_RST(init_state : boolean) return path_t is
      variable ret : path_t;
   begin
      if (init_state) then
         ret.cost   := ( others => '0' );
      else
         ret.cost   := ( others => '1' );
      end if;
      ret.active := '0';
      return ret;
   end function;

   function NULL_PATH_T return path_t is
   begin
      return NULL_PATH_RST(false);
   end function;
end package body;
