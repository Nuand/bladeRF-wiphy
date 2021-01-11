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

entity fft_tb is
end entity;

architecture arch of fft_tb is
   signal clock    : std_logic := '0';
   signal reset    : std_logic;

   signal in_real  : std_logic_vector(15 downto 0);
   signal in_imag  : std_logic_vector(15 downto 0);
   signal in_valid : std_logic;
   signal in_sop   : std_logic;
   signal in_eop   : std_logic;

   type lut_t is array(natural range <>) of integer;

   signal lut : lut_t(0 to 127) := (
   750, 402, 700, -439, -96, 909, -496, -7, -711, 76, 601, 764, 315, -192, -633, 411,
   -139, -540, -640, -360, -172, 821, 291, 160, -678, 9, -241, -679, -293, 69, -172, 565,
   999, -356, -19, 515, -498, 438, 693, 78, 209, -276, 131, -865, 487, 465, 35, 454,
   437, -480, -45, -324, -991, -86, 2, -471, -38, -805, -621, 543, 397, 170, 606, -797,
   369, 546, 591, 150, -17, -1095, -684, 109, -450, 760, -478, -573, -409, -66, 484, 682,
   201, -826, -192, -695, 819, 16, 172, -403, -660, -342, 14, 443, -389, 544, -339, -734,
   -141, -366, -626, 381, 382, 280, 235, 624, -980, -218, 54, 333, 506, 333, 114, -944,
   566, 46, -48, 305, -20, 457, 740, -56, 197, -919, 295, 522, 20, -2, -712, 438
   );

   signal ilut : lut_t(0 to 63) := (
      0, 1, -1, -1, -1, 1, -1, 1, -1, -1, -1, 1, 1, -1, -1, 1, -1, 1, 1, -1, -1, -1, -1,
      -1, 1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, -1, 1, 1, 1, -1, 1, 1, -1,
      -1, -1, -1, 1, -1, -1, -1, -1, -1, 1, 1, -1, -1, 1, 1, -1 );




   constant N : integer := 64;
begin
   clock <= not clock after 6.25 ns;
   reset <= '1', '0' after 50 ns;

   process
   begin
      in_real    <= ( others => '0' );
      in_imag    <= ( others => '0' );
      in_valid   <= '0';
      in_sop     <= '0';
      in_eop     <= '0';
      wait for 100 ns;
      for iz in 0 to 80 loop
         for i in 0 to N-1 loop
            wait until rising_edge(clock);
            in_real    <= std_logic_vector(to_signed(4096*ilut(i), in_real'high + 1));
            in_imag    <= ( others => '0' ); --std_logic_vector(to_signed(lut(i*2+1), in_real'high + 1));
            in_valid   <= '1';
            if (i = 0) then
               in_sop     <= '1';
            else
               in_sop     <= '0';
            end if;

            if (i = N-1) then
               in_eop     <= '1';
            else
               in_eop     <= '0';
            end if;
         end loop;

         wait until rising_edge(clock);
         in_valid   <= '0';
         in_sop <= '0';
         in_eop <= '0';
         wait for 500 ns;
      end loop;
      wait for 5 ms;
   end process;

   U_uut: entity work.fft(mult)
      generic map(
         N          => N
      )
      port map(
         clock      => clock,
         reset      => reset,

         inverse    => '1',
         in_real    => in_real,
         in_imag    => in_imag,
         in_valid   => in_valid,
         in_sop     => in_sop,
         in_eop     => in_eop,

         out_real   => open,
         out_imag   => open,
         out_error  => open,
         out_valid  => open
      );

end architecture;

