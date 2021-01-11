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
    use ieee.math_real.all;
library pll;
    use pll.all;
entity fft_top is
   generic(
      BITS       :  in  natural := 16
   );
   port(
      clk        :  in  std_logic;
      reset      :  in  std_logic;

      inverse    :  in  std_logic;
      in_real    :  in  std_logic_vector(BITS-1 downto 0);
      in_imag    :  in  std_logic_vector(BITS-1 downto 0);
      in_valid   :  in  std_logic;
      in_sop     :  in  std_logic;
      in_eop     :  in  std_logic;

      out_real   :  out std_logic_vector(BITS-1 downto 0);
      out_imag   :  out std_logic_vector(BITS-1 downto 0);
      out_error  :  out std_logic;
      out_valid  :  out std_logic;
      out_sop    :  out std_logic;
      out_eop    :  out std_logic
   );
end entity;

architecture arch of fft_top is
   signal clock : std_logic;
begin

   U_pll : entity pll.pll
      port map(
         refclk  => clk,
         rst     => '0',
         outclk_0 => clock,
         locked   => open
      );

   U_fft : entity work.fft(mult)
      generic map(
         N => 64,
         BITS => 16
      )
      port map(
      clock      => clock,
      reset      => reset,

      inverse    => inverse,
      in_real    => in_real,
      in_imag    => in_imag,
      in_valid   => in_valid,
      in_sop     => in_sop,
      in_eop     => in_eop,

      out_real   => out_real,
      out_imag   => out_imag,
      out_error  => out_error,
      out_valid  => out_valid,
      out_sop    => out_sop,
      out_eop    => out_eop
   );



end architecture;
