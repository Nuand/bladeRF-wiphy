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

entity wlan_correlator is
    port (
      clock            :   in std_logic ;
      reset            :   in std_logic ;

      sample           :   in wlan_sample_t ;
      value            :   out signed( 31 downto 0 )
    ) ;
end entity ;

architecture arch of wlan_correlator is

    constant preamble : sample_array_t( 15 downto 0 ) := (
        (valid => '1', i => to_signed( 269, 16), q => to_signed( 269, 16)),
        (valid => '1', i => to_signed(-775, 16), q => to_signed(  14, 16)),
        (valid => '1', i => to_signed( -79, 16), q => to_signed(-460, 16)),
        (valid => '1', i => to_signed( 835, 16), q => to_signed( -74, 16)),
        (valid => '1', i => to_signed( 538, 16), q => to_signed(   0, 16)),
        (valid => '1', i => to_signed( 835, 16), q => to_signed( -74, 16)),
        (valid => '1', i => to_signed( -79, 16), q => to_signed(-460, 16)),
        (valid => '1', i => to_signed(-775, 16), q => to_signed(  14, 16)),
        (valid => '1', i => to_signed( 269, 16), q => to_signed( 269, 16)),
        (valid => '1', i => to_signed(  14, 16), q => to_signed(-775, 16)),
        (valid => '1', i => to_signed(-460, 16), q => to_signed( -79, 16)),
        (valid => '1', i => to_signed( -74, 16), q => to_signed( 835, 16)),
        (valid => '1', i => to_signed(   0, 16), q => to_signed( 538, 16)),
        (valid => '1', i => to_signed( -74, 16), q => to_signed( 835, 16)),
        (valid => '1', i => to_signed(-460, 16), q => to_signed( -79, 16)),
        (valid => '1', i => to_signed(  14, 16), q => to_signed(-775, 16))
    );

    type correlator_result_t is record
        i       :   signed(15 downto 0) ;
        q       :   signed(15 downto 0) ;
        valid   :   std_logic ;
    end record ;

    type eq_array_t is array(natural range <>) of correlator_result_t ;
    signal accum : eq_array_t(15 downto 0);

begin

    process( clock )
        variable isum : signed( 100 downto 0 ) ;
        variable qsum : signed( 100 downto 0 ) ;
    begin
        if( reset = '1' ) then
            value <= ( others => '0' ) ;
        elsif( rising_edge( clock ) ) then
            if( sample.valid = '1' ) then
                for i in accum'range loop
                    if i = accum'high then
                        accum(i).i <= resize(shift_right(preamble(i).i*sample.i + preamble(i).q*sample.q, 14),16);
                        accum(i).q <= resize(shift_right(- preamble(i).q*sample.i + preamble(i).i*sample.q, 14),16);
                    else
                        accum(i).i <= resize(accum(i+1).i + shift_right(preamble(i).i*sample.i + preamble(i).q*sample.q, 14),16);
                        accum(i).q <= resize(accum(i+1).q + shift_right(- preamble(i).q*sample.i + preamble(i).i*sample.q, 14),16);
                    end if;
                end loop;
                value <= resize(accum(0).i * accum(0).i + accum(0).q * accum(0).q,32);

            end if ;
        end if ;
    end process ;

end architecture ;
