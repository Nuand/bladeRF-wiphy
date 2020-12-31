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

library work ;
    use work.wlan_p.all ;

package wlan_tx_p is

    type wlan_tx_vector_t is record
        length      :   positive range 1 to 4095 ;
        datarate    :   wlan_datarate_t ;
        bandwidth   :   wlan_bandwidth_t ;
    end record ;

    type wlan_tx_params_t is record
        n_bpsc              :   natural range 1 to 6 ;
        n_cbps              :   natural range 48 to 288 ;
        n_dbps              :   natural range 24 to 216 ;
        modulation          :   wlan_modulation_t ;
        datarate            :   wlan_datarate_t ;
        length              :   natural range 1 to 4095 ;
        lfsr_init           :   unsigned(6 downto 0) ;
        num_decoded_bits    :   natural range 8 to 11224 ;
        num_data_symbols    :   natural range 1 to 1366 ;
        num_padding_bits    :   natural range 0 to 287 ;
    end record ;

    function NULL_PARAMS return wlan_tx_params_t ;
    function NULL_TX_VECTOR return wlan_tx_vector_t ;

    type wlan_tx_status_t is (TX_IDLE, TX_SHORT, TX_LONG, TX_DATA, TX_FAULT_NODATA, TX_FAULT_UNDERRUN) ;

end package ;

package body wlan_tx_p is

    function NULL_PARAMS return wlan_tx_params_t is
        variable rv : wlan_tx_params_t ;
    begin
        rv.n_bpsc := 1 ;
        rv.n_cbps := 48 ;
        rv.n_dbps := 24 ;
        rv.modulation := WLAN_BPSK ;
        rv.datarate := WLAN_RATE_6 ;
        rv.length := 1 ;
        rv.lfsr_init := (others =>'1') ;
        rv.num_data_symbols := 0 ;
        rv.num_data_symbols := 1 ;
        rv.num_padding_bits := 0 ;
        return rv ;
    end function ;

    function NULL_TX_VECTOR return wlan_tx_vector_t is
        variable rv : wlan_tx_vector_t ;
    begin
        rv.length := 1 ;
        rv.datarate := WLAN_RATE_6 ;
        rv.bandwidth := WLAN_BW_20 ;
        return rv ;
    end function ;

end package body ;
