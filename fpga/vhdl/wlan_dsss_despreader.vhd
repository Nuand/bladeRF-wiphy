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

entity wlan_dsss_despreader is
    port (
      clock            :   in std_logic ;
      reset            :   in std_logic ;

      sample           :   in wlan_sample_t ;
      despread         :   out wlan_sample_t
    ) ;
end entity ;

architecture arch of wlan_dsss_despreader is

    constant preamble : sample_array_t( 19 downto 0 ) := (
        (valid => '1', i => to_signed( 128, 16), q => to_signed( 128, 16)),
        (valid => '1', i => to_signed( -14, 16), q => to_signed( -14, 16)),
        (valid => '1', i => to_signed(-135, 16), q => to_signed(-135, 16)),
        (valid => '1', i => to_signed( -20, 16), q => to_signed( -20, 16)),
        (valid => '1', i => to_signed( 197, 16), q => to_signed( 197, 16)),
        (valid => '1', i => to_signed( 210, 16), q => to_signed( 210, 16)),
        (valid => '1', i => to_signed(   1, 16), q => to_signed(   1, 16)),
        (valid => '1', i => to_signed(-135, 16), q => to_signed(-135, 16)),
        (valid => '1', i => to_signed( -34, 16), q => to_signed( -34, 16)),
        (valid => '1', i => to_signed( 120, 16), q => to_signed( 120, 16)),
        (valid => '1', i => to_signed( 147, 16), q => to_signed( 147, 16)),
        (valid => '1', i => to_signed( 128, 16), q => to_signed( 128, 16)),
        (valid => '1', i => to_signed( 148, 16), q => to_signed( 148, 16)),
        (valid => '1', i => to_signed( 102, 16), q => to_signed( 102, 16)),
        (valid => '1', i => to_signed( -54, 16), q => to_signed( -54, 16)),
        (valid => '1', i => to_signed(-159, 16), q => to_signed(-159, 16)),
        (valid => '1', i => to_signed(-142, 16), q => to_signed(-142, 16)),
        (valid => '1', i => to_signed(-119, 16), q => to_signed(-119, 16)),
        (valid => '1', i => to_signed(-130, 16), q => to_signed(-130, 16)),
        (valid => '1', i => to_signed( -86, 16), q => to_signed( -86, 16))
    );

    type despreader_result_t is record
        i       :   signed(15 downto 0) ;
        q       :   signed(15 downto 0) ;
        valid   :   std_logic ;
    end record ;

    type eq_array_t is array(natural range <>) of despreader_result_t ;
    signal accum : eq_array_t(19 downto 0);

begin

    process( clock )
    begin
        if( reset = '1' ) then
        elsif( rising_edge( clock ) ) then
            despread.valid <= '0' ;
            if( sample.valid = '1' ) then
                for i in accum'range loop
                    if i = accum'high then
                        accum(i).i <= resize(shift_right(preamble(i).i*sample.i, 9), 16);
                        accum(i).q <= resize(shift_right(preamble(i).q*sample.q, 9), 16);
                        accum(i).valid <= '1';
                    else
                        accum(i).i <= resize(accum(i+1).i + shift_right(preamble(i).i*sample.i, 9), 16);
                        accum(i).q <= resize(accum(i+1).q + shift_right(preamble(i).q*sample.q, 9), 16);
                        accum(i).valid <= accum(i+1).valid;
                    end if;
                end loop;
                despread.i <= accum(0).i ;
                despread.q <= accum(0).q ;
                despread.valid <= accum(0).valid ;
            end if ;
        end if ;
    end process ;

end architecture ;
