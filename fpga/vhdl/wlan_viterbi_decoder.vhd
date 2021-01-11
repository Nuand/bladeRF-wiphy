-- This file is part of bladeRF-wiphy.
--
-- Copyright (C) 2020 Nuand, LLC.
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

library ieee ;
    use ieee.std_logic_1164.all ;
    use ieee.numeric_std.all ;

library wlan ;
    use wlan.wlan_p.all ;
    use wlan.wlan_rx_p.all ;

library work ;
library viterbi_decoder ;

entity wlan_viterbi_decoder is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    init            :   in  std_logic ;

    in_soft_a       :   in  signed(7 downto 0) ;
    in_soft_b       :   in  signed(7 downto 0) ;
    in_erasure      :   in  std_logic_vector(1 downto 0) ;
    in_valid        :   in  std_logic ;

    params          :   in  wlan_rx_params_t ;
    params_valid    :   in  std_logic ;

    done            :  out std_logic ;

    out_dec_bit     :   out std_logic ;
    out_dec_valid   :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_viterbi_decoder is

    type fsm_t is (IDLE, DECODE, RESET_CORE ) ;

    type state_t is record
        fsm                 :   fsm_t ;
        num_decoded_bits    :   unsigned( 13 downto 0 ) ;
        done                :   std_logic ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm  := IDLE ;
        rv.num_decoded_bits := ( others => '0' );
        rv.done := '0' ;
        return rv ;
    end function ;

    signal sink_rdy         :   std_logic ;
    signal sink_val         :   std_logic ;

    signal source_rdy       :   std_logic ;
    signal source_val       :   std_logic ;

    signal rr               :   std_logic_vector(15 downto 0) ;

    signal decbit           :   std_logic ;

    signal normalizations   :   std_logic_vector(7 downto 0) ;

    signal core_reset       :   std_logic ;

    signal current, future  :   state_t := NULL_STATE ;

    function fix_var( x : signed(7 downto 0) ) return std_logic_vector is
      variable ret : std_logic_vector(7 downto 0);
    begin
      ret(6 downto 0) := not(std_logic_vector(x(6 downto 0)));
      ret(7) := x(7);
      return (ret);
    end function;

begin

    done <= current.done ;

    sync : process(clock, reset)
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
        elsif( rising_edge(clock) ) then
            if( init = '1' ) then
                current <= NULL_STATE ;
            else
                current <= future ;
            end if ;
        end if ;
    end process ;

    comb : process(all)
    begin
        future <= current ;
        future.done <= '0' ;

        case current.fsm is
            when IDLE =>
                if( params_valid = '1' ) then
                    future.num_decoded_bits <= to_unsigned(params.num_decoded_bits - 1, future.num_decoded_bits'length ) ;
                    future.fsm <= DECODE ;
                end if ;

            when DECODE =>
                if( source_val = '1' ) then
                    future.num_decoded_bits <= current.num_decoded_bits - 1;
                end if ;
                if( current.num_decoded_bits = 0 ) then
                    future.done <= '1' ;
                    future.fsm <= RESET_CORE ;
                end if ;

            when RESET_CORE =>
                future.fsm <= IDLE ;
        end case ;
    end process ;

    core_reset <= '1' when current.fsm = RESET_CORE or current.fsm = IDLE or reset = '1' else '0' ;
    rr <= std_logic_vector(in_soft_a) & std_logic_vector(in_soft_b) ;
    sink_val <= in_valid ;

    --U_altera_decoder : entity viterbi_decoder.viterbi_decoder
    --  port map (
    --    clk             =>  clock,
    --    reset           =>  core_reset,

    --    sink_val        =>  sink_val,
    --    sink_rdy        =>  sink_rdy,
    --    rr              =>  rr,
    --    eras_sym        =>  in_erasure,

    --    source_rdy      =>  source_rdy,
    --    source_val      =>  source_val,
    --    decbit          =>  decbit,
    --    normalizations  =>  normalizations
    --  ) ;
    U_vit : entity work.viterbi_decoder
      generic map(
         TB_LEN        => 60
      )
      port map(
         clock         => clock,
         reset         => core_reset,
         in_a          => (fix_var(in_soft_a)),
         in_b          => (fix_var(in_soft_b)),
         erasure       => in_erasure(0) & in_erasure(1),
         bsd_valid     => in_valid,

         out_bit       => decbit,
         out_valid     => source_val
    );



    out_dec_bit <= decbit ;
    out_dec_valid <= source_val ;
    source_rdy <= '1' ;

end architecture ;

