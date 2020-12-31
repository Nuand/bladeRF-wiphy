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

entity wlan_dsss_p_norm is
  port (
    -- 40MHz clock and async asserted, sync deasserted reset
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    in_sample       :   in  wlan_sample_t ;
    p_normed        :  out  wlan_sample_t
  ) ;
end entity ;

architecture arch of wlan_dsss_p_norm is
    signal pow_set  :   signed( 31 downto 0 ) ;
    signal iir      :   signed( 31 downto 0 ) ;
    signal dat      :   signed( 31 downto 0 ) ;
    signal log2     :   unsigned ( 8 downto 0 ) ;
    signal ptemp    :   signed( 31 downto 0 ) ;
    signal p_mag    :   signed( 23 downto 0 ) ;
    signal timer    :   unsigned( 8 downto 0 ) ;

    signal second_blip  : std_logic ;

    type unsigned_array_t is array (natural range 0 to 511) of signed( 23 downto 0 ) ;

    function calc_lut return unsigned_array_t is
        variable rv : unsigned_array_t ;
        variable i : real ;
        variable two : real ;
    begin
        for x in rv'range loop
            i := ( 24.0 - (real(x) / 16.0) ) / 2.0 + 12.0; -- i is in log2
            report integer'image(x) & " LUT " & real'image(i);
            two := 2 ** i ;
            if (real(two) > 5.7e5) then
                two := 5.7e5;
            end if;
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
                exit ;
            end if ;
        end loop ;
        return bits ;
    end log2x ;

    function run_iir( x : signed( 31 downto 0); y : signed ( 31 downto 0) )
    return signed
    is
        variable ret : signed(31 downto 0) ;
    begin
        ret := resize( x - shift_right(x, 4) + shift_right(y, 4), 32 );
        return ret;
    end;

begin
    process( clock )
        variable gain_req : std_logic ;
    begin
        if( reset = '1' ) then
            iir     <= ( others => '0' ) ;
            ptemp   <= ( others => '0' ) ;
            p_mag   <= ( others => '0' ) ;
            timer   <= ( others => '0' ) ;
            pow_set <= ( others => '0' ) ;
            second_blip <= '0' ;
        elsif( rising_edge( clock )) then
            p_mag <= signed(resize(mult_lut(to_integer(log2x(pow_set))), 24)) ;
            p_normed.valid <= '0' ;
            if (in_sample.valid = '1') then
                ptemp <= in_sample.i * in_sample.i + in_sample.q * in_sample.q ;
                iir <= run_iir(iir, ptemp) ;

                gain_req := '0' ;
                if( iir*2 < pow_set or iir > pow_set*2 ) then
                    gain_req := '1' ;
                end if ;

                if( timer = 59 ) then
                    timer <= ( others => '0' ) ;
                    if( gain_req = '1' ) then
                        second_blip <= '1' ;
                    end if ;
                else
                    timer <= timer + 1 ;
                end if;

                if( second_blip = '1' ) then
                    if( gain_req = '1' ) then
                        pow_set <= iir ;
                    end if ;
                    second_blip <= '0' ;
                end if ;

                p_normed.i <= resize(shift_right(in_sample.i * p_mag, 16), 16) ;
                p_normed.q <= resize(shift_right(in_sample.q * p_mag, 16), 16) ;
                p_normed.valid <= '1' ;
            end if ;
        end if ;
    end process ;
end architecture ;
