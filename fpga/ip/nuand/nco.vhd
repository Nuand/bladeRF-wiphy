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

package nco_p is

    type nco_input_t is record
        dphase  :   signed(15 downto 0) ;
        valid   :   std_logic ;
    end record ;

    type nco_output_t is record
        re      :   signed(15 downto 0) ;
        im      :   signed(15 downto 0) ;
        valid   :   std_logic ;
    end record ;

end package ; -- nco_p

library ieee ;
    use ieee.std_logic_1164.all ;
    use ieee.numeric_std.all ;

library work ;
    use work.cordic_p.all ;
    use work.nco_p.all ;

entity nco is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;
    inputs          :   in  nco_input_t ;
    outputs         :   out nco_output_t
  ) ;
end entity ; -- nco

architecture arch of nco is

    signal phase : signed(15 downto 0) ;

    signal cordic_inputs : cordic_xyz_t ;
    signal cordic_outputs : cordic_xyz_t ;

begin

    accumulate_phase : process(clock, reset)
        variable temp : signed(15 downto 0) ;
    begin
        if( reset = '1' ) then
            phase <= (others =>'0') ;
        elsif( rising_edge( clock ) ) then
            if( inputs.valid = '1' ) then
                temp := phase + inputs.dphase ;
                if( temp > 16384 ) then
                    temp := temp - 32768 ;
                elsif( temp < -16384 ) then
                    temp := temp + 32768 ;
                end if ;
                phase <= temp ;
            end if ;
        end if ;
    end process ;

    cordic_inputs <= ( x => to_signed(1234,16), y => to_signed(0,16),  z => phase, valid => inputs.valid ) ;

    U_cordic : entity work.cordic
      port map (
        clock   =>  clock,
        reset   =>  reset,
        mode    => CORDIC_ROTATION,
        inputs  => cordic_inputs,
        outputs => cordic_outputs
      ) ;

    outputs.re <= cordic_outputs.x ;
    outputs.im <= cordic_outputs.y ;
    outputs.valid <= cordic_outputs.valid ;

end architecture ; -- arch
