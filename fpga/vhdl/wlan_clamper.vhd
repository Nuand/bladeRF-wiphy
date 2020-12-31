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
    use work.wlan_rx_p.all ;

entity wlan_clamper is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    in_mod          :   in  wlan_modulation_t ;
    in_ssd          :   in  wlan_sample_t;

    out_ssd         :   out wlan_sample_t ;
    out_clamped     :   out wlan_sample_t ;
    out_error       :   out unsigned(31 downto 0)
  ) ;
end entity ;

architecture arch of wlan_clamper is

begin

    clamp : process(clock, reset)
        variable symbol : wlan_sample_t ;
    begin
        if( reset = '1' ) then
            out_ssd <= ( (others =>'0'), (others =>'0'), '0' ) ;
            out_clamped <= ( (others =>'0'), (others =>'0'), '0' ) ;
            out_error <= (others =>'0') ;
            symbol := ( (others =>'0'), (others =>'0'), '0' ) ;
        elsif( rising_edge(clock) ) then
            out_ssd <= in_ssd ;
            if( in_ssd.valid = '1' ) then
                case in_mod is
                    when WLAN_BPSK =>
                        symbol.q := (others =>'0') ;
                        if( in_ssd.i < 0 ) then
                            symbol.i := to_signed( -4096, symbol.i'length ) ;
                        else
                            symbol.i := to_signed( 4096, symbol.i'length ) ;
                        end if ;

                    when WLAN_QPSK =>
                        if( in_ssd.i < 0 ) then
                            symbol.i := to_signed( -2896, symbol.i'length ) ;
                        else
                            symbol.i := to_signed( 2896, symbol.i'length ) ;
                        end if ;

                        if( in_ssd.q < 0 ) then
                            symbol.q := to_signed( -2896, symbol.q'length ) ;
                        else
                            symbol.q := to_signed( 2896, symbol.q'length ) ;
                        end if ;

                    when WLAN_16QAM =>
                        -- I
                        if( in_ssd.i < 0 ) then
                            if( in_ssd.i < -2590 ) then
                                symbol.i := to_signed( -3886, symbol.i'length ) ;
                            else
                                symbol.i := to_signed( -1295, symbol.i'length ) ;
                            end if ;
                        else
                            if( in_ssd.i > 2590 ) then
                                symbol.i := to_signed( 3886, symbol.i'length ) ;
                            else
                                symbol.i := to_signed( 1295, symbol.i'length ) ;
                            end if ;
                        end if ;

                        -- Q
                        if( in_ssd.q < 0 ) then
                            if( in_ssd.q < -2590 ) then
                                symbol.q := to_signed( -3886, symbol.q'length ) ;
                            else
                                symbol.q := to_signed( -1295, symbol.q'length ) ;
                            end if ;
                        else
                            if( in_ssd.q > 2590 ) then
                                symbol.q := to_signed( 3886, symbol.q'length ) ;
                            else
                                symbol.q := to_signed( 1295, symbol.q'length ) ;
                            end if ;
                        end if ;

                    when WLAN_64QAM =>
                        -- I
                        case to_integer(in_ssd.i) is
                            when -32768 to  -3792 => symbol.i := to_signed(-4424, symbol.i'length ) ;
                            when  -3791 to  -2528 => symbol.i := to_signed(-3160, symbol.i'length ) ;
                            when  -2527 to  -1264 => symbol.i := to_signed(-1896, symbol.i'length ) ;
                            when  -1263 to     -1 => symbol.i := to_signed( -632, symbol.i'length ) ;
                            when      0 to   1263 => symbol.i := to_signed(  632, symbol.i'length ) ;
                            when   1264 to   2527 => symbol.i := to_signed( 1896, symbol.i'length ) ;
                            when   2528 to   3791 => symbol.i := to_signed( 3160, symbol.i'length ) ;
                            when   3792 to  32767 => symbol.i := to_signed( 4424, symbol.i'length ) ;
                            when others           => symbol.i := (others =>'0') ;
                        end case ;

                        -- Q
                        case to_integer(in_ssd.q) is
                            when -32768 to  -3792 => symbol.q := to_signed(-4424, symbol.q'length ) ;
                            when  -3791 to  -2528 => symbol.q := to_signed(-3160, symbol.q'length ) ;
                            when  -2527 to  -1264 => symbol.q := to_signed(-1896, symbol.q'length ) ;
                            when  -1263 to     -1 => symbol.q := to_signed( -632, symbol.q'length ) ;
                            when      0 to   1263 => symbol.q := to_signed(  632, symbol.q'length ) ;
                            when   1264 to   2527 => symbol.q := to_signed( 1896, symbol.q'length ) ;
                            when   2528 to   3791 => symbol.q := to_signed( 3160, symbol.q'length ) ;
                            when   3792 to  32767 => symbol.q := to_signed( 4424, symbol.q'length ) ;
                            when others           => symbol.q := (others =>'0') ;
                        end case ;

                    when others =>
                end case ;
            end if ;
            -- TODO: Check to see if this is too much logic and needs to be pipelined
--            out_error <= unsigned(std_logic_vector(((symbol.i - in_ssd.i)*(symbol.i - in_ssd.i)) +
--                         (symbol.q - in_ssd.q)*(symbol.q - in_ssd.q))) ;
            out_clamped.i <= symbol.i ;
            out_clamped.q <= symbol.q ;
            out_clamped.valid <= in_ssd.valid ;
        end if ;
    end process ;

end architecture ;

