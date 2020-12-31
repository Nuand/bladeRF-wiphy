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
    use ieee.math_real.all ;

library work ;
    use work.wlan_p.all ;

package wlan_interleaver_p is

    -- Deferred initialization in package body after function definition
    constant WLAN_INTERLEAVER_BPSK  : integer_array_t ;
    constant WLAN_INTERLEAVER_QPSK  : integer_array_t ;
    constant WLAN_INTERLEAVER_16QAM : integer_array_t ;
    constant WLAN_INTERLEAVER_64QAM : integer_array_t ;

    -- Interleaving occurs on bits
    function interleave( modulation : wlan_modulation_t ; x : std_logic_vector(287 downto 0) ) return std_logic_vector ;

    -- Deinterleaving occurs on bit soft decisions
    function deinterleave( modulation : wlan_modulation_t ; x : bsd_array_t(287 downto 0) ) return bsd_array_t ;

end package ;

package body wlan_interleaver_p is

    function get_table( modulation : wlan_modulation_t ) return integer_array_t is
    begin
        case modulation is
            when WLAN_BPSK => return WLAN_INTERLEAVER_BPSK ;
            when WLAN_QPSK => return WLAN_INTERLEAVER_QPSK ;
            when WLAN_16QAM => return WLAN_INTERLEAVER_16QAM ;
            when WLAN_64QAM => return WLAN_INTERLEAVER_64QAM ;
            when others     => return WLAN_INTERLEAVER_BPSK ;
        end case ;
        report "get_table: Could not figure out modulation" severity failure ;
    end function ;

    function interleave( modulation : wlan_modulation_t ; x : std_logic_vector(287 downto 0) ) return std_logic_vector is
        variable t : integer_array_t(0 to 287) ;
        variable y : std_logic_vector(287 downto 0) := (others =>'-') ;
    begin
        t := get_table( modulation ) ;
        for i in t'range loop
            -- 0 only happens for the 0 entry, so stop there
            if( i > 0 and t(i) = 0 ) then
                exit ;
            else
                y(t(i)) := x(i) ;
            end if ;
        end loop ;
        return y ;
    end function ;

    function deinterleave( modulation : wlan_modulation_t ; x : bsd_array_t(287 downto 0) ) return bsd_array_t is
        variable t : integer_array_t(0 to 287) ;
        variable y : bsd_array_t(287 downto 0) ;
    begin
        y := (others => (others => '0' )) ;
        t := get_table( modulation ) ;
        for i in t'range loop
            -- Stop at the next 0 entry
            if( i > 0 and t(i) = 0 ) then
                exit ;
            else
                y(i) := x(t(i)) ;
            end if ;
        end loop ;
        return y ;
    end function ;

    function calculate_interleaver_table( modulation : wlan_modulation_t ) return integer_array_t is
        variable n_cbps : natural ;
        variable n_bpsc : natural ;
        variable i : natural ;
        variable j : natural ;
        variable s : natural ;
        variable rv : integer_array_t(0 to 287) := (others => 0) ;
    begin
        case modulation is
            when WLAN_BPSK =>
                n_bpsc := 1 ;
                n_cbps := 48 ;
                s := 1 ;
            when WLAN_QPSK =>
                n_bpsc := 2 ;
                n_cbps := 96 ;
                s := 1 ;
            when WLAN_16QAM =>
                n_bpsc := 4 ;
                n_cbps := 192 ;
                s := 2 ;
            when WLAN_64QAM =>
                n_bpsc := 6 ;
                n_cbps := 288 ;
                s := 3 ;
            when others =>
        end case ;

        for k in 0 to n_cbps-1 loop
            i := (n_cbps/16)*(k mod 16) + k/16 ;
            j := s*integer(floor(real(i)/real(s))) + ((i + n_cbps - (16*i)/n_cbps) mod s) ;
            rv(k) := j ;
        end loop ;

        return rv ;
    end function ;

    -- Deferred initialization of table
    constant WLAN_INTERLEAVER_BPSK  : integer_array_t := calculate_interleaver_table( WLAN_BPSK ) ;
    constant WLAN_INTERLEAVER_QPSK  : integer_array_t := calculate_interleaver_table( WLAN_QPSK ) ;
    constant WLAN_INTERLEAVER_16QAM : integer_array_t := calculate_interleaver_table( WLAN_16QAM ) ;
    constant WLAN_INTERLEAVER_64QAM : integer_array_t := calculate_interleaver_table( WLAN_64QAM ) ;

end package body ;

