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

library work ;
    use work.wlan_p.all ;

entity wlan_channel_inverter is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    first           :   in  std_logic ;
    last            :   in  std_logic ;

    in_channel      :   in  wlan_sample_t ;
    in_reference    :   in  wlan_sample_t ;

    out_inverted    :   out wlan_sample_t ;
    done            :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_channel_inverter is

    -- Sequence is either -1, 0 or 1, so no need to store extra precision
    type seq_lut_t is array(natural range <>) of integer range -1 to 1 ;

    -- Convert from real type to LUT type
    function create_long_seq_lut return seq_lut_t is
        variable rv : seq_lut_t(LONG_SEQ_FREQ'range) ;
    begin
        for i in rv'range loop
            rv(i) := integer(LONG_SEQ_FREQ(i).re) ;
        end loop ;
        return rv ;
    end function ;

    constant LONG_SEQ_LUT : seq_lut_t := create_long_seq_lut ;

    -- TODO: Make this a feedback signal
    signal snr_bias     :   unsigned(15 downto 0) := to_unsigned( 1, 16 ) ;

    signal ref_x_conjh_i        :   signed(31 downto 0) ;
    signal ref_x_conjh_q        :   signed(31 downto 0) ;
    signal ref_x_conjh_valid    :   std_logic ;

    signal magsq                :   unsigned(31 downto 0) ;
    signal magsq_valid          :   std_logic ;

    signal last_reg             :   std_logic ;

    signal div_i                :   signed(31 downto 0) ;
    signal div_q                :   signed(31 downto 0) ;
    signal div_valid            :   std_logic ;
    signal div_done             :   std_logic ;

begin

    -- Incoming channel is in the frequency domain, H(t),
    -- with the reference signal, T2(t).  The inversion of this
    -- is to then take T2(t) * H*(t) / ( |H(t)|^2 + NSR )
    calc_ref_x_conjh : process(clock, reset)
        variable count : natural range 0 to LONG_SEQ_FREQ'high := 0 ;
    begin
        if( reset = '1' ) then
            count := 0 ;
            ref_x_conjh_i <= (others =>'0') ;
            ref_x_conjh_q <= (others =>'0') ;
            ref_x_conjh_valid <= '0' ;
            last_reg <= '0' ;
        elsif( rising_edge(clock) ) then
            last_reg <= last ;
            ref_x_conjh_valid <= in_channel.valid ;
            ref_x_conjh_i <= in_channel.i*in_reference.i + in_channel.q*in_reference.q ;
            ref_x_conjh_q <= in_channel.i*in_reference.q - in_channel.q*in_reference.i ;
            if( in_channel.valid = '1' ) then
                if( first = '1' ) then
                    count := 1 ;
                else
                    if( count < LONG_SEQ_LUT'high ) then
                        count := count + 1 ;
                    else
                        assert last = '1'
                            report "Last not high when expected for channel estimate"
                            severity error ;
                        count := 0 ;
                    end if ;
                end if ;
            end if ;
        end if ;
    end process ;

    calc_magsq : process(clock, reset)
        variable sample : wlan_sample_t := ( (others =>'0'), (others =>'0'), '0' );
    begin
        if( reset = '1' ) then
            magsq <= (others =>'0') ;
            magsq_valid <= '0' ;
            sample := ( (others =>'0'), (others =>'0'), '0' ) ;
        elsif( rising_edge(clock) ) then
            magsq_valid <= in_channel.valid ;
            if( in_channel.valid = '1' ) then
                sample.i := resize(in_channel.i,sample.i'length) ;
                sample.q := resize(in_channel.q,sample.q'length) ;
                magsq <= resize(shift_right(unsigned(std_logic_vector(in_channel.i*in_channel.i + in_channel.q*in_channel.q)),12),magsq'length)+snr_bias ;
            end if ;
        end if ;
    end process ;

    -- Divide each value
    U_div : entity work.wlan_divide
      generic map (
        SAMPLE_WIDTH    =>  ref_x_conjh_i'length,
        DENOM_WIDTH     =>  magsq'length,
        NUM_PIPELINE    =>  magsq'length
      ) port map (
        clock           =>  clock,
        reset           =>  reset,

        in_i            =>  ref_x_conjh_i,
        in_q            =>  ref_x_conjh_q,
        in_denom        =>  magsq,
        in_valid        =>  magsq_valid,
        in_done         =>  last_reg,

        out_i           =>  div_i,
        out_q           =>  div_q,
        out_valid       =>  div_valid,
        out_done        =>  div_done
      ) ;

    -- Outputs
    out_inverted.i <= resize(div_i,out_inverted.i'length) ;
    out_inverted.q <= resize(div_q,out_inverted.q'length) ;
    out_inverted.valid <= div_valid ;
    done <= div_done ;

end architecture ;

