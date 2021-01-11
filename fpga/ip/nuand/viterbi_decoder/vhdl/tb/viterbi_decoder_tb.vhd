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

entity viterbi_decoder_tb is
end entity;

architecture behv of viterbi_decoder_tb is
   signal clock    : std_logic := '0';
   signal reset    : std_logic;

   type int_arr_t is array(natural range <>) of integer;
   constant recv : int_arr_t(0 to 47) := (
   -125, -122, -126, 127, 120, -127,
   -126, -128, -126, 127, 124, -127,
   118, -127, 122, -127, -120, -125,
   -123, 127, -117, -125, -124, -127,
   -127, -127, 122, -127, 127, 119,
   -127, 119, 127, -122, 128, -120,
   127, 127, 127, 124, 122, 127,
   127, 119, 122, 125, 126, 121);



   type LUT_sl  is array(natural range <>) of std_logic;
   constant LUT    : LUT_sl := ( '1', '1', '1', '0',
                             '0', '1', '0', '1',
                             '0', '1', '1', '0',
                             '0', '1', '1', '1',
                             '0', '1', '1', '0',
                             '0', '0', '1', '0',
                             '0', '0', '0', '0',
                             '0', '1', '0', '1',
                             '0', '1', '1', '0',
                             '0', '1', '1', '1',
                             '0', '1', '1', '0',
                             '0', '0', '1', '0',
                             '0', '0', '0', '0',
                             '0', '1', '0', '1',
                             '0', '1', '1', '0',
                             '0', '1', '1', '1',
                             '0', '1', '1', '0',
                             '0', '0', '1', '0',
                             '0', '0', '0', '0',
                             '1', '1', '1', '1',
                             '1', '1', '1', '1',
                             '1', '1', '1', '1',
                             '1', '1', '1', '1'
                      );

   --signal t_state               : std_logic_vector(6 downto 0);

   signal t_valid             : std_logic := '0';
   signal t_bit_a, t_bit_b    : std_logic_vector(7 downto 0) := ( others => '0' );
   signal t_erasure           : std_logic_vector(1 downto 0) := ( others => '0' );


   function generate_out_bit(code : std_logic_vector(6 downto 0); state : std_logic_vector(6 downto 0); in_bit : std_logic)
      return std_logic
   is
      variable ret : std_logic;
      variable i   : natural;
   begin
      ret := '0';
      for i in 0 to code'high loop
         if(code(i) = '1') then
            if(i = code'high) then
               ret := ret xor in_bit;
            else
               ret := ret xor state(code'high-1-i);
            end if;
         end if;
      end loop;
      return ret;
   end function;

   constant G_A : integer :=  91;
   constant G_B : integer := 121;
   constant K   : integer := 7;

   function G_A_VEC_GEN return std_logic_vector is
   begin
      return std_logic_vector(to_unsigned(G_A, K));
   end function;

   function G_B_VEC_GEN return std_logic_vector is
   begin
      return std_logic_vector(to_unsigned(G_B, K));
   end function;

   constant G_A_VEC : std_logic_vector(K-1 downto 0) := G_A_VEC_GEN;
   constant G_B_VEC : std_logic_vector(K-1 downto 0) := G_B_VEC_GEN;

begin
   clock <= not clock after 10 ns;
   reset <= '1', '0' after 100 ns, '1' after 5 us, '0' after 6 us;

   process
      variable state    : std_logic_vector(6 downto 0) := ( others => '0' );
      variable b_a, b_b : std_logic;
      variable idx      : integer := 0;
   begin
      wait for 500 ns;
      for iz in 0 to 23 loop
      for i in 0 to 23 loop
         wait until rising_edge(clock);
         t_valid <= '1';
         t_bit_a <= not(std_logic_vector(127 + to_signed(recv(2*i), t_bit_a'high +1)));
         t_bit_b <= not(std_logic_vector(127 + to_signed(recv(2*i+1), t_bit_b'high +1)));
         --if (recv(i*2) < 0) then
         --   t_bit_a <= ( others => '1' );
         --else
         --   t_bit_a <= ( others => '0' );
         --end if;
         --if (recv(i*2+1) < 0) then
         --   t_bit_b <= ( others => '1' );
         --else
         --   t_bit_b <= ( others => '0' );
         --end if;
      end loop;
      t_erasure <= ( others => '1' );
      wait until reset = '1';
      t_valid <= '0';
      wait for 30 us;
      end loop;
      --for i in LUT'range loop
      --   wait until rising_edge(clock);
      --   b_a := generate_out_bit(G_A_VEC, state, LUT(idx));
      --   b_b := generate_out_bit(G_B_VEC, state, LUT(idx));
      --   t_bit_a <= ( others => b_a );
      --   t_bit_b <= ( others => b_b );
      --   t_valid <= '1';
      --   state := state(5 downto 0) & LUT(idx);
      --   wait until rising_edge(clock);
      --   t_valid <= '0';

      --   idx   := idx + 1;
      --   if (idx > 90) then
      --      t_bit_a <= ( others => '0' );
      --      t_bit_b <= ( others => '0' );
      --      for i in 0 to 900 loop
      --         t_valid <= '1';
      --         wait until rising_edge(clock);
      --         t_valid <= '0';
      --         if (i = 10 or i = 50) then
      --            wait for 10 us;
      --         end if;
      --         wait until rising_edge(clock);
      --      end loop;
      --      t_valid <= '0';
      --      wait;
      --   end if;


      --end loop;
   end process;

   U_uut: entity work.viterbi_decoder
      port map(
         clock       => clock,
         reset       => reset,

         in_a        => t_bit_a,
         in_b        => t_bit_b,
         erasure     => (others => '0'),
         bsd_valid   => t_valid,

         out_bit     => open,
         out_valid   => open
      );
end architecture;
