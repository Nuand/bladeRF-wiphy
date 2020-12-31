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
    use wlan.nco_p.all ;

entity wlan_cfo_correction is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    dphase          :   in  signed( 15 downto 0 ) ;
    dphase_valid    :   in  std_logic ;

    p_mag           :   in  signed( 23 downto 0 ) ;
    p_mag_valid     :   in  std_logic ;

    in_sample       :   in  wlan_sample_t ;
    out_sample      :   out wlan_sample_t
  ) ;
end entity;

architecture arch of wlan_cfo_correction is
    signal nco_inputs   :   nco_input_t ;
    signal nco_outputs  :   nco_output_t ;
begin

    U_nco : entity work.nco
      port map (
        clock   => clock,
        reset   => reset,
        inputs  => nco_inputs,
        outputs => nco_outputs
      ) ;

    process( clock )
    begin
        if( rising_edge( clock ) ) then
            nco_inputs.valid <= in_sample.valid ;
            out_sample.valid <= in_sample.valid ;
            if( in_sample.valid = '1' ) then
                if( p_mag_valid = '0' ) then
                    out_sample.i <= in_sample.i ;
                    out_sample.q <= in_sample.q ;
                else
                    out_sample.i <= resize( shift_right( in_sample.i * p_mag , 15 ), 16 ) ;
                    out_sample.q <= resize( shift_right( in_sample.q * p_mag , 15 ), 16 ) ;
                end if ;
            end if ;
        end if ;
    end process ;
end architecture ;
