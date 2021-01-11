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

entity viterbi_decoder is
   generic(
      K          :  in  natural := 7;
      G_A        :  in  natural := 91;
      G_B        :  in  natural := 121;
      TB_LEN     :  in  natural := 42
   );
   port(
      clock      :  in  std_logic;
      reset      :  in  std_logic;

      in_a       :  in  std_logic_vector(7 downto 0);
      in_b       :  in  std_logic_vector(7 downto 0);
      erasure    :  in  std_logic_vector(1 downto 0);
      bsd_valid  :  in  std_logic;

      out_bit    :  out std_logic;
      out_valid  :  out std_logic
   );
end entity;

architecture arch of viterbi_decoder is
   function STATE_BITS return natural is
   begin
      return K-1;
   end function;

   function NUM_STATES return natural is
   begin
      return (2**STATE_BITS);
   end function;


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

   type branch_lut_t is array(NUM_STATES-1 downto 0) of branch_inputs_t;

   function generate_out_bit(code : std_logic_vector(K-1 downto 0); state : std_logic_vector(STATE_BITS-1 downto 0); in_bit : std_logic)
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

   function generate_next_state(state : std_logic_vector(STATE_BITS-1 downto 0); in_bit : std_logic)
      return std_logic_vector is
   begin
      return state(state'high - 1 downto 0) & in_bit;
   end function;

   -- if the convolution encoder's initial state is 0, some states are
   -- "impossible" at least for K-1 bits
   function is_state_active( t_idx : integer ; state : integer ) return boolean is
   begin
      if (t_idx < 0) then
         return true;
      end if;
      return ( (state) <= (2**t_idx - 1) );
   end function;


   -- cast std_logic vector to integer
   function sl_to_integer( x : std_logic ) return integer is
   begin
      if (x = '1') then
         return 1;
      end if;
      return 0;
   end function;

   function gen_branch_t( i : integer ; in_bit : std_logic ) return branch_t is
      variable t_state_slv    : std_logic_vector(STATE_BITS-1 downto 0);
      variable next_state_slv : std_logic_vector(STATE_BITS-1 downto 0);
      variable t_bit_a : std_logic;
      variable t_bit_b : std_logic;
      variable t_bit_slv : std_logic_vector(1 downto 0);
      variable ret : branch_t;
   begin
      t_state_slv := std_logic_vector(to_unsigned(i, STATE_BITS));

      t_bit_a   := generate_out_bit(G_A_VEC, t_state_slv, in_bit);
      t_bit_b   := generate_out_bit(G_B_VEC, t_state_slv, in_bit);
      next_state_slv := t_state_slv(t_state_slv'high-1 downto 0) & in_bit;

      ret.set := true;
      ret.start_state := i;
      ret.u_bit := in_bit;
      ret.bit_a := t_bit_a;
      ret.bit_b := t_bit_b;
      ret.bit_s := t_state_slv(t_state_slv'high);
      t_bit_slv := t_bit_b & t_bit_a;
      ret.bm_idx     := to_integer(unsigned(t_bit_slv));
      ret.prev_state := i;
      ret.next_state := to_integer(unsigned(next_state_slv));
      --report "S[" & integer'image(i) & "] -- bit=" & to_string(in_bit) &
      --            " coded=" & to_string(t_bit_a) & "," & to_string(t_bit_b) &
      --            " -- D[" & integer'image(to_integer(unsigned(next_state_slv))) & "]";
      return ret;
   end function;

   function generate_branch_table return branch_lut_t is
      variable tmp_branch : branch_t;
      variable ret : branch_lut_t;
   begin
      for i in 0 to NUM_STATES-1 loop
         ret(i)(0).set := false;
         ret(i)(1).set := false;
      end loop;

      for i in 0 to NUM_STATES-1 loop

         -- uncoded bit is 0?
         tmp_branch := gen_branch_t(i, '0');
         if (ret(tmp_branch.next_state)(sl_to_integer(tmp_branch.bit_s)).set) then
            report "ERROR BUILDING BRANCH TABLE, INPUTS MUST BE UNIQUE" severity error;
         end if;
         ret(tmp_branch.next_state)(sl_to_integer(tmp_branch.bit_s)) := tmp_branch;


         -- uncoded bit is 1?
         tmp_branch := gen_branch_t(i, '1');
         if (ret(tmp_branch.next_state)(sl_to_integer(tmp_branch.bit_s)).set) then
            report "ERROR BUILDING BRANCH TABLE, INPUTS MUST BE UNIQUE" severity error;
         end if;
         ret(tmp_branch.next_state)(sl_to_integer(tmp_branch.bit_s)) := tmp_branch;

      end loop;
      return ret;
   end function;


   --function NULL_EDGE is return edge_t

   constant lut : branch_lut_t := generate_branch_table;

   signal bsd_in : bsd_t(1 downto 0);


   signal paths          : path_arr_t(NUM_STATES-1 downto 0);

   signal bm       : bm_t(3 downto 0);
   signal bm_valid : std_logic;

   function single_bit_loss_function(received : unsigned; expected : std_logic) return unsigned is
      variable expanded : unsigned(received'range);
   begin
      if (expected = '0') then
         return(received);
      end if;

      expanded := (others => '1');
      return expanded - received;
   end function;

   function loss_function(received_bsd : bsd_t ; expected : unsigned ; erasure : std_logic_vector) return unsigned is
      variable loss : unsigned(15 downto 0);
   begin
      loss := ( others => '0' );

      for i in received_bsd'range loop
         if (erasure(i) = '0') then
            loss := loss + single_bit_loss_function(received_bsd(i), expected(i));
         end if;
      end loop;

      return loss;
   end function;

   signal acs_reg   : std_logic_vector(NUM_STATES-1 downto 0);

   signal acs_valid : std_logic;

   signal best_idx  : unsigned(STATE_BITS-1 downto 0);
begin

   bsd_in(0) <= unsigned(in_a);
   bsd_in(1) <= unsigned(in_b);

   process(clock, reset)
   begin
      if (reset = '1') then
         for i in bm'range loop
            bm(i) <= ( others => '0' );
         end loop;
         bm_valid <= '0';
      elsif (rising_edge(clock)) then
         if (bsd_valid = '1') then
            bm_valid <= '1';
            for i in bm'range loop
               bm(i) <= loss_function(bsd_in, to_unsigned(i,2), erasure);
            end loop;
         else
            bm_valid <= '0';
         end if;
      end if;
   end process;

   gen_bm_loop: for t_state in 0 to (NUM_STATES-1) generate
      gen_bc: entity work.branch_compare
         generic map(
            RESET_ACTIVE   => (t_state = 0)
         )
         port map(
            clock     => clock,
            reset     => reset,

            bm_a      => bm(lut(t_state)(0).bm_idx),
            bm_b      => bm(lut(t_state)(1).bm_idx),
            bm_valid  => bm_valid,

            path_in_a => paths(lut(t_state)(0).prev_state),
            path_in_b => paths(lut(t_state)(1).prev_state),

            branch    => lut(t_state),

            path_out  => paths(t_state),

            win       => acs_reg(t_state)
         );
   end generate;

   process(clock, reset)
   begin
      if (reset = '1') then
         acs_valid <= '0';
      elsif (rising_edge(clock)) then
         acs_valid <= bm_valid;
      end if;
   end process;

   U_r2_comp: entity work.r2_comparator
      port map(
         clock       => clock,
         reset       => reset,

         paths       => paths,
         path_valid  => acs_valid,

         label_out   => best_idx
      );


   U_traceback: entity work.traceback
      generic map(
         STATE_BITS  => STATE_BITS,
         NUM_STATES  => NUM_STATES,
         TB_LEN      => TB_LEN
      )
      port map(
         clock       => clock,
         reset       => reset,

         acs_reg     => acs_reg,
         acs_valid   => acs_valid,

         best_idx    => best_idx,
         best_valid  => '0',

         bit_out     => out_bit,
         valid_out   => out_valid
      );

end architecture;
