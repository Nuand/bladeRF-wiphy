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

entity wlan_dsss_peak_finder is
  generic (
    SAMPLE_WINDOW   :       integer := 20
  ) ;
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    despread        :   in  wlan_sample_t ;

    bin_idx         :   in  natural ;

    out_mode_bin    :   out natural
  ) ;
end entity ;

architecture arch of wlan_dsss_peak_finder is
    type peak_index_t is record
        idx     :   unsigned(4 downto 0) ;
        valid   :   std_logic ;
    end record ;

    type peak_index_array_t is array(0 to SAMPLE_WINDOW-1) of peak_index_t ;

    type peak_array_t is array(0 to SAMPLE_WINDOW-1) of unsigned(4 downto 0) ;

    type histo_comparison_t is array(0 to SAMPLE_WINDOW-1) of std_logic_vector(0 to SAMPLE_WINDOW-1) ;

    -- which bin had the peak over the past SAMPLE_WINDOW symbols
    signal peak_index    : peak_index_array_t ;

    -- histogram of how many peaks each bin has had over the past SAMPLE_WINDOW symbols
    signal peak_histo    : peak_array_t ;

    signal max_bin_idx   : natural ;
    signal max_bin_val   : unsigned( 31 downto 0 ) ;
    signal max_bin_valid : std_logic ;

    signal c_pow         : unsigned( 31 downto 0 ) ;
    signal c_pow_valid   : std_logic ;

    signal histo_update  : std_logic ;
    signal histo_comparisons : histo_comparison_t ;
    signal diff_complete : std_logic ;
begin

    -- calculate correlation peak
    process( clock )
    begin
        if( reset = '1' ) then
            c_pow <= ( others => '0' ) ;
            c_pow_valid <= '0' ;
        elsif( rising_edge( clock ) ) then
            if( despread.valid = '1' ) then
                c_pow <= unsigned(resize(shift_right(despread.i * despread.i + despread.q * despread.q, 5), 32)) ;
                c_pow_valid <= despread.valid ;
            end if ;
        end if ;
    end process ;

    -- find peak bin in the current symbol. In RAKE terms this is the strongest finger
    process( clock )
    begin
        if( reset = '1' ) then

            max_bin_val <= ( others => '0')  ;
            max_bin_idx <= 0 ;

            max_bin_valid <= '0' ;
        elsif( rising_edge( clock ) ) then
            max_bin_valid <= '0' ;

            if( c_pow_valid = '1' ) then
                if( max_bin_val < c_pow or bin_idx = 0) then
                    max_bin_val <= c_pow ;
                    max_bin_idx <= bin_idx ;
                end if ;

                if( bin_idx = 19 ) then
                    max_bin_valid <= '1' ;
                end if ;
            end if ;
        end if ;
    end process ;


    -- update histogram
    process( clock )
        variable last_index : integer ;
    begin
        if( reset = '1' ) then
            peak_index <= ( others => ( idx => ( others => '0' ), valid => '0' ) );
            peak_histo <= ( others => ( others => '0' ) );
            histo_update <= '0' ;
        elsif( rising_edge( clock ) ) then
            histo_update <= '0' ;
            if( max_bin_valid = '1' ) then
                for i in 0 to peak_index'high - 1 loop
                    peak_index(i+1) <= peak_index(i);
                end loop ;
                peak_index(0).idx <= to_unsigned(max_bin_idx, 5) ;
                peak_index(0).valid <= '1' ;

                histo_update <= '1' ;
                if( peak_index(peak_index'high).valid = '1' ) then
                    if( peak_index(peak_index'high).idx /= max_bin_idx ) then
                        last_index := to_integer(peak_index(peak_index'high).idx);
                        peak_histo(last_index)<= peak_histo(last_index) - 1 ;

                        peak_histo(max_bin_idx) <= peak_histo(max_bin_idx) + 1 ;
                    else
                        histo_update <= '0' ;
                    end if ;
                else
                    peak_histo(max_bin_idx) <= peak_histo(max_bin_idx) + 1 ;
                end if ;
            end if ;
        end if ;
    end process ;

    -- find histogram peak by performing (n)*(n-1)/2 comparisons
    process( clock )
    begin
        if( reset = '1' ) then
            histo_comparisons <= ( others => ( others => '0' ) ) ;
        elsif(rising_edge( clock ) ) then
            diff_complete <= '0' ;
            if( histo_update = '1' ) then

                -- comparsing against oneself can be optimzed out
                for ii in histo_comparisons'range loop
                    histo_comparisons(ii)(ii) <= '1' ;
                end loop ;

                for ii in 1 to histo_comparisons'high loop
                    for ij in 0 to ii-1 loop
                        if( peak_histo(ii) < peak_histo(ij) ) then
                            histo_comparisons(ii)(ij) <= '0' ;
                            histo_comparisons(ij)(ii) <= '1' ;
                        else
                            histo_comparisons(ii)(ij) <= '1' ;
                            histo_comparisons(ij)(ii) <= '0' ;
                        end if ;
                    end loop ;
                end loop ;
                diff_complete <= '1' ;
            end if ;
        end if ;
    end process ;

    -- bin that has all '1's in its comparison calculation is the mode
    process( clock )
    begin
        if( reset = '1' ) then
            out_mode_bin <= 0;
        elsif( rising_edge( clock ) ) then
            if( diff_complete = '1' ) then
                for ii in histo_comparisons'range loop
                    if( histo_comparisons(ii) = x"FFFFF" ) then
                        out_mode_bin <= ii ;
                    end if ;
                end loop ;
            end if ;
        end if ;
    end process ;

end architecture ;
