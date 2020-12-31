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
    use ieee.math_real.all ;

library wlan ;
    use wlan.wlan_p.all ;
    use wlan.wlan_rx_p.all ;
    use wlan.cordic_p.all ;

entity wlan_cfo_estimate is
  generic (
    DELAY           :       integer := 64 ;
    MOVING_WINDOW   :       integer := 64
  ) ;
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    in_sample       :   in  wlan_sample_t ;

    atan_average    :   out signed( 31 downto 0 ) ;

    out_sample      :   out wlan_sample_t
    ) ;
end entity;

architecture arch of wlan_cfo_estimate is
    -- I need a sample history, correlation history, atan history
    -- history helps insert new correlation history
    -- correlation history helps when averaging atan2 values of corelation history
    type wlan_sample_history_t is array( natural range 0 to DELAY - 1 ) of wlan_sample_t ;
    signal wlan_sample_history : wlan_sample_history_t ;

    type wlan_corr_t is record
        i       :   signed(31 downto 0) ;
        q       :   signed(31 downto 0) ;
    end record ;

    type wlan_correlation_history_t is array( natural range 0 to DELAY - 1 ) of wlan_corr_t ;
    signal wlan_correlation_history : wlan_correlation_history_t ;

    type wlan_atan_history_t is array( natural range 0 to MOVING_WINDOW - 1 ) of signed(15 downto 0) ;
    signal wlan_atan_history : wlan_atan_history_t ; 

    signal cordic_inputs : cordic_xyz_t ;
    signal cordic_outputs : cordic_xyz_t ;

    signal sum : signed( 31 downto 0 ) ;
begin

    -- save sample history
    process( clock )
    begin
        if( reset = '1' ) then
            for x in wlan_sample_history'range loop
                wlan_sample_history(x).i <= ( others => '0' ) ;
                wlan_sample_history(x).q <= ( others => '0' ) ;
            end loop ;
        elsif( rising_edge( clock ) ) then
            if( in_sample.valid = '1' ) then
                for i in 0 to wlan_sample_history'high - 1 loop
                    wlan_sample_history( i + 1 ) <= wlan_sample_history( i ) ;
                end loop ;
                wlan_sample_history(0) <= in_sample ;
            end if ;
        end if ;
    end process ;

    -- perform delay correlation on samples 64 samples apart
    process( clock )
        variable isum : signed( 31 downto 0 ) ;
        variable qsum : signed( 31 downto 0 ) ;
    begin
        if( reset = '1' ) then
            wlan_correlation_history <= ( others => ( i => ( others => '0'), q => ( others => '0' ) ) ) ;
        elsif( rising_edge( clock ) ) then
            if( in_sample.valid = '1' ) then
                for i in 0 to wlan_correlation_history'high - 1 loop
                    wlan_correlation_history( i + 1 ) <= wlan_correlation_history( i ) ;
                end loop ;
                isum := in_sample.i * wlan_sample_history(DELAY - 1).i + in_sample.q * wlan_sample_history(DELAY - 1).q ;
                qsum := resize( -1 * in_sample.i * wlan_sample_history(DELAY - 1).q +
                                    in_sample.q * wlan_sample_history(DELAY - 1).i, 32) ;
                wlan_correlation_history(0).i <= isum ;
                wlan_correlation_history(0).q <= qsum ;
            end if ;
        end if ;
    end process ;

    -- take atan2() of delay correlator using CORDIC
    cordic_inputs <= (  x => resize(shift_right(wlan_correlation_history(0).i, 7), 16),
                        y => resize(shift_right(wlan_correlation_history(0).q, 7), 16),
                        z => (others => '0'),
                        valid => in_sample.valid ) ;

    U_cordic : entity work.cordic
      port map (
        clock   =>  clock,
        reset   =>  reset,
        mode    => CORDIC_VECTORING,
        inputs  => cordic_inputs,
        outputs => cordic_outputs
      ) ;

    -- save atan2 history
    process( clock )
    begin
        if( reset = '1' ) then
            wlan_atan_history <= ( others => ( others => '0' ) ) ;
            sum <= ( others => '0' );
        elsif( rising_edge( clock ) ) then
            if ( cordic_outputs.valid = '1' ) then
                for i in 0 to wlan_atan_history'high - 1 loop
                    wlan_atan_history( i + 1 ) <= wlan_atan_history( i ) ;
                end loop ;
                wlan_atan_history(0) <= cordic_outputs.z ;
                sum <= sum + cordic_outputs.z - wlan_atan_history(MOVING_WINDOW - 1);
            end if ;
        end if ;
    end process ;

    -- perform atan2 average
    process( clock )
    begin
        if( rising_edge( clock ) ) then
            atan_average <= shift_right( sum, integer(ceil(log2(real(MOVING_WINDOW)))) ) ;
        end if ;
    end process ;

    out_sample <= in_sample ;
end architecture ;
