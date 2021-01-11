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

entity traceback is
   generic(
      STATE_BITS :  in  integer;
      NUM_STATES :  in  integer;
      TB_LEN     :  in  integer
   );
   port(
      clock      :  in  std_logic;
      reset      :  in  std_logic;

      acs_reg    :  in  std_logic_vector(NUM_STATES-1 downto 0);
      acs_valid  :  in  std_logic;

      best_idx   :  in  unsigned(STATE_BITS-1 downto 0);
      best_valid :  in  std_logic;

      bit_out    :  out std_logic;
      valid_out  :  out std_logic
   );
end entity;

architecture arch of traceback is
   type history_t is array(7 + TB_LEN*2 downto 0) of std_logic_vector(NUM_STATES-1 downto 0);

   type fsm_t is (IDLE, START_TRACER);

   type state_t is record
      fsm        : fsm_t;
      loaded     : std_logic;
      history    : history_t;
      acs_count  : natural range 0 to TB_LEN+STATE_BITS*2;
      acs_enough : std_logic;
      bit_out    : std_logic;
      valid_out  : std_logic;
   end record;

   function NULL_STATE_T return state_t is
      variable ret : state_t;
   begin
      ret.fsm    := IDLE;
      ret.loaded := '0';
      for i in ret.history'range loop
         ret.history(i) := ( others => '0' );
      end loop;
      ret.acs_count  := 0;
      ret.acs_enough := '0';
      ret.bit_out    := '0';
      ret.valid_out  := '0';
      return(ret);
   end function;

   signal current, future : state_t := NULL_STATE_T;
      
   type trace_state_t is array(TB_LEN downto 0) of unsigned(STATE_BITS-1 downto 0);

   signal trace_state : trace_state_t;
   signal trace_state_valid : std_logic_vector(TB_LEN downto 0);
begin
   sync : process(clock, reset)
   begin
      if (reset = '1') then
         current <= NULL_STATE_T;
      elsif (rising_edge(clock)) then
         current <= future;
      end if;
   end process;

   trace_state(0)       <= best_idx;
   trace_state_valid(0) <= current.acs_enough;

   gen_tracers: for i in 0 to TB_LEN-1 generate
      U_tracer: entity work.tracer
         generic map(
            STATE_BITS  => STATE_BITS,
            NUM_STATES  => NUM_STATES
         )
         port map(
            clock       => clock,
            reset       => reset,

            state_in    => trace_state(i),
            state_valid => trace_state_valid(i),
            acs_reg     => current.history(6 + 2 * i),
            acs_valid   => acs_valid,

            state_out   => trace_state(i+1),
            valid_out   => trace_state_valid(i+1)
         );
   end generate;
            

   bit_out   <= current.bit_out;
   valid_out <= current.valid_out;

   comb : process(all)
   begin
      future <= current;

      future.bit_out   <= '0';
      future.valid_out <= '0';

      if (acs_valid = '1') then
         if (current.acs_enough = '0') then
            if (current.acs_count = TB_LEN + 6 + 5) then
               future.acs_enough <= '1';
            else
               future.acs_count <= current.acs_count + 1;
            end if;
         end if;
         future.history <= current.history(current.history'high-1 downto 0) & acs_reg;
      end if;

      case current.fsm is
         when IDLE =>
            if (current.acs_enough = '1' and acs_valid = '1') then
               future.fsm <= START_TRACER;
            end if;
         when START_TRACER =>
            if (acs_valid = '1') then
               -- the bit that is about to be shifted out is actually the uncoded bit
               -- the new bit that is shifted in is from the current branch, the historical ACS reg basically determines the LSB of the new state
               future.bit_out   <= trace_state(TB_LEN)(5);
               future.valid_out <= trace_state_valid(TB_LEN);
            end if;
         when others =>
            future <= NULL_STATE_T;
      end case;
   end process;
   
end architecture;
