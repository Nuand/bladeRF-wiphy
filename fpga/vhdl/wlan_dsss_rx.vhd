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
    use wlan.nco_p.all ;
    use wlan.wlan_p.all ;
    use wlan.wlan_rx_p.all ;

library altera_mf ;
    use altera_mf.altera_mf_components.all ;

library wlan_pll ;

entity wlan_dsss_rx is
  port (
    -- 40MHz clock and async asserted, sync deasserted reset
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    -- Baseband input signals
    sample          :   in  wlan_sample_t ;

    params          :  out  wlan_rx_params_t ;
    params_valid    :  out  std_logic ;

    data            :  out  std_logic_vector( 7 downto 0 ) ;
    data_valid      :  out  std_logic ;

    framer_done     :  out  std_logic ;
    crc_correct     :  out  std_logic
  ) ;
end entity ;

architecture arch of wlan_dsss_rx is
   signal despread      :  wlan_sample_t ;
   signal p_norm_sample :  wlan_sample_t ;
   signal modulation    :  wlan_modulation_t ;
   signal bin_idx       :  natural range 0 to 20 ;
   signal mode_bin      :  natural range 0 to 20 ;

   signal demod_bits    :  std_logic_vector( 1 downto 0 ) ;
   signal demod_idx     :  natural range 0 to 20 ;
   signal demod_valid   :  std_logic ;

begin
    U_dsss_rx_controller : entity work.wlan_dsss_rx_controller
      port map (
        clock   => clock,
        reset   => reset,

        in_sample   => sample,
        modulation  => modulation,
        out_bin_idx => bin_idx
      ) ;

    U_dsss_p_norm : entity work.wlan_dsss_p_norm
      port map (
        clock   => clock,
        reset   => reset,

        in_sample  => sample,
        p_normed   => p_norm_sample
      ) ;

    U_dsss_despreader : entity work.wlan_dsss_despreader
      port map (
        clock   => clock,
        reset   => reset,

        sample   => p_norm_sample,
        despread => despread
      ) ;

    U_dsss_peak_finder : entity work.wlan_dsss_peak_finder
      port map (
        clock   => clock,
        reset   => reset,

        despread      => despread,

        bin_idx       => bin_idx,

        out_mode_bin  => mode_bin
     ) ;

    U_dsss_demodulator : entity work.wlan_dsss_demodulator
      port map (
        clock   => clock,
        reset   => reset,

        modulation  => modulation,

        in_bin_idx  => bin_idx,
        despread    => despread,

        out_bin_idx => demod_idx,
        out_bits    => demod_bits,
        out_valid   => demod_valid
      ) ;

    U_dsss_rx_framer : entity work.wlan_dsss_rx_framer
      port map (
        clock   => clock,
        reset   => reset,

        mode_bin    => mode_bin,

        demod_idx   => demod_idx,
        demod_bits  => demod_bits,
        demod_valid => demod_valid,

        params        => params,
        params_valid  => params_valid,
        data          => data,
        data_valid    => data_valid,

        framer_done   => framer_done,
        crc_correct   => crc_correct
      ) ;

end architecture ;
