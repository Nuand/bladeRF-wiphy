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
    use work.wlan_rx_p.all ;

entity wlan_bsd is
  port (
    clock       :   in  std_logic ;
    reset       :   in  std_logic ;

    modulation  :   in  wlan_modulation_t ;

    in_sample   :   in  wlan_sample_t ;
    out_sample  :   out wlan_sample_t ;

    bsds        :   out wlan_bsds_t
  ) ;
end entity ;

architecture arch of wlan_bsd is

    -- Expected to be nominally +/- 4096, so shift and clamp to +/-15
    -- TODO: Move this to being LLR instead of euclidean distance?
    function compress(x : in signed(15 downto 0)) return signed is
        variable rv : signed(bsds.bsds(0)'range) ;
    begin
        if( x > 4095 ) then
            rv := to_signed(2**rv'high-1, rv'length) ;
        elsif( x < -4095 ) then
            rv := to_signed(-(2**rv'high-1), rv'length) ;
        else
            rv := resize(shift_right(x,5),rv'length) ;
        end if ;
        return rv ;
    end function ;

begin

    calculate_bsd : process(clock, reset)
    begin
        if( reset = '1' ) then
            for i in bsds.bsds'range loop
                bsds.bsds(i) <= (others =>'0') ;
            end loop ;
            out_sample.valid <= '0' ;
            bsds.valid <= '0' ;
        elsif(rising_edge(clock)) then
            out_sample <= in_sample ;
            bsds.valid <= in_sample.valid ;
            if( in_sample.valid = '1' ) then
                -- Please check Figure 18-10 from WLAN standard for decisions
                -- made here.
                -- Note that downstream, the Viterbi decoder wants positive values
                -- to represent probabilities that a '0' was transmitted, and negative
                -- values to represent probabilities that a '1' was transmitted.
                --
                -- Therefore, the following is true of the BSD calculator:
                --
                --  +15     Most likely a 0
                --  ...
                --  +4      Soft likeliness of a 0
                --  ...
                --  0       Neither a 0 or a 1
                --  ...
                --  -4      Soft likeliness of a 1
                --  ...
                --  -15     Most likely a 1
                --
                case modulation is
                    when WLAN_BPSK =>
                        -- b0
                        -- Decision region is the Y axis, 0 is negative,
                        -- and 1 is positive
                        bsds.bsds(0) <= compress(-in_sample.i) ;

                        -- b1, b2, b3, b4, b5 not transmitted
                        for i in 1 to 5 loop
                            bsds.bsds(i) <= (others =>'0') ;
                        end loop ;

                    when WLAN_QPSK =>
                        -- b0
                        -- Decision region is the Y axis, 0 is negative,
                        -- and 1 is positive
                        bsds.bsds(0) <= compress(-in_sample.i) ;

                        -- b1
                        -- Decision region is the X axis, 0 is negative,
                        -- and 1 is positive
                        bsds.bsds(1) <= compress(-in_sample.q) ;

                        -- b2, b3, b4, b5 not transmitted
                        for i in 2 to 5 loop
                            bsds.bsds(i) <= (others =>'0') ;
                        end loop ;

                    when WLAN_16QAM =>
                        -- b0
                        -- Decision region is the Y axis, 0 is negative,
                        -- and 1 is positive
                        bsds.bsds(0) <= compress(-in_sample.i) ;

                        -- b1
                        -- Decision region is the Y axis, -2 < x < 2 is 1,
                        -- and 0 is outside of that region
                        bsds.bsds(1) <= compress(abs(in_sample.i)-2590) ;

                        -- b2
                        -- Decision region is the X axis, 0 is negative,
                        -- and 1 is positive
                        bsds.bsds(2) <= compress(-in_sample.q) ;

                        -- b3
                        -- Decision region is the X axis, -2 < y < 2 is 1,
                        -- and 0 is outside of that region
                        bsds.bsds(3) <= compress(abs(in_sample.q)-2590) ;

                        -- b4 and b5 not transmitted
                        for i in 4 to 5 loop
                            bsds.bsds(i) <= (others =>'0') ;
                        end loop ;

                    when WLAN_64QAM =>
                        -- b0
                        -- Decision region is the Y axis, 0 is negative
                        -- and 1 is positive
                        bsds.bsds(0) <= compress(-in_sample.i) ;

                        -- b1
                        -- Decision region is the Y axis, -4 < x < 4 is 1,
                        -- and 0 is outside of that region
                        bsds.bsds(1) <= compress(abs(in_sample.i)-2528) ;

                        -- b2
                        -- Decision region is the Y axis, -6 < x < -2 or 2 < x < 6 is 0,
                        -- and 1 is outside of that region
                        bsds.bsds(2) <= compress(abs(abs(in_sample.i)-2528)-2528/2) ;

                        -- b3
                        -- Decision region is the X axis, 0 is negative
                        -- and 1 is positive
                        bsds.bsds(3) <= compress(-in_sample.q) ;

                        -- b4
                        -- Decision region is the X axis, -4 < y < 4 is 1,
                        -- and 0 is outside of that region
                        bsds.bsds(4) <= compress(abs(in_sample.q)-2528) ;

                        -- b5
                        -- Decision region is the X axis, -6 < y < -2 or 2 < y < 6 is 0,
                        -- and 1 is outside of that region
                        bsds.bsds(5) <= compress(abs(abs(in_sample.q)-2528)-2528/2) ;

                    when others =>
                end case ;
            end if ;
        end if ;
    end process ;

end architecture ;

