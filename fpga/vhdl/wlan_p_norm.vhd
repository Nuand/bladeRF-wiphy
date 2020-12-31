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

entity wlan_p_norm is
  port (
    -- 40MHz clock and async asserted, sync deasserted reset
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;
    quiet           :   in  std_logic ;


    sample          :   in  wlan_sample_t ;
    p_normed        :  out  wlan_sample_t ;

    p_mag           :  out signed( 23 downto 0 )
  ) ;
end entity ;

architecture arch of wlan_p_norm is
    signal iir      :   signed( 31 downto 0 ) ;
    signal saved_iir:   signed( 31 downto 0 ) ;
    signal dat      :   signed( 31 downto 0 ) ;
    signal log2     :   unsigned ( 8 downto 0 ) ;
    signal ptemp    :   signed( 31 downto 0 ) ;
    signal timer    :   unsigned( 8 downto 0 ) ;
    type unsigned_array_t is array (natural range 0 to 511) of signed( 23 downto 0 ) ;

    function calc_lut return unsigned_array_t is
        variable rv : unsigned_array_t ;
        variable i : real ;
        variable two : real ;
    begin
        for x in rv'range loop
            i := ( 24.0 - (real(x) / 16.0) ) / 2.0 + 12.0; -- i is in log2
            report integer'image(x) & " LUT " & real'image(i);
--            if (i > 5.0) then
--                i := 5.0;
--            end if;
            two := 2 ** i ;
            if (real(two) > 5.7e5) then
                two := 5.7e5;
            end if;
            report integer'image(x) & " pow " & real'image(two);
            rv(x) := to_signed(integer(round(two)), 24) ;
        end loop ;
        return rv ;
    end;
    constant mult_lut : unsigned_array_t := calc_lut;

    function log2x( x : signed( 31 downto 0) )
    return unsigned is
        variable bits  : unsigned( 8 downto 0 ) ;
    begin
        bits := (others => '0') ;
        for i in x'range loop
            if (x(i) = '1') then
                bits(8 downto 4) := to_unsigned(i, 5) ;
                if (real(i) < 4.0) then
                    bits(3 downto 4 - i) := unsigned(x(i - 1 downto 0)) ;
                else
                    bits(3 downto 0) := unsigned(x(i - 1 downto i - 4)) ;
                end if;
--                bits(3 downto 0) <= 
                exit ;
            end if ;
        end loop ;
        return bits ;
    end log2x ;

    function run_iir( x : signed( 31 downto 0); y : signed ( 31 downto 0) )
    return signed
    is
        variable amrea : signed(31 downto 0) ;
    begin
        amrea := resize( x - shift_right(x, 6) + shift_right(y, 6), 32 );
        return amrea;
    end;
begin
    process( clock )
        variable t : signed( 31 downto 0 ) ;
    begin
        if( reset = '1' ) then
            iir <= ( others => '0' ) ;
            saved_iir <= ( others => '0' ) ;
            ptemp <= ( others => '0' ) ;
            timer <= ( others => '0' ) ;
            p_mag <= ( others => '0' ) ;
        elsif( rising_edge( clock )) then
            if( quiet = '1' ) then
                ptemp <= ( others => '0' ) ;
                timer <= ( others => '0' ) ;
            else
                if( timer < 200 ) then
                    timer <= timer + 1 ;
                end if ;
                if( timer = 18 ) then
                    iir <= ptemp;
                end if ;
                if( timer = 30 ) then
                    saved_iir <= iir ;
                end if ;
            end if ;
            if (sample.valid = '1') then 
                ptemp <= sample.i * sample.i + sample.q * sample.q ;
                iir <= run_iir(iir, ptemp) ;
                p_normed.i <= resize(shift_right(sample.i * mult_lut(to_integer(log2x(saved_iir))) ,12),16);
                p_normed.q <= resize(shift_right(sample.q * mult_lut(to_integer(log2x(saved_iir))) ,12),16);
                p_mag <= signed(resize(mult_lut(to_integer(log2x(saved_iir))), 24));
                --p_normed.q <= sample.q * mult_lut(log2x(t));
                --dat <= log2x(t) * ;
                log2 <= log2x(iir) ;
            end if ;
            if (timer < 30 ) then
                p_normed.valid <= '0' ;
            else
                p_normed.valid <= sample.valid ;
            end if ;
        end if ;
    end process ;
end architecture ;
