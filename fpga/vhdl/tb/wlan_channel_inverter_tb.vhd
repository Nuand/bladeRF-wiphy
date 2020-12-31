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
    use ieee.math_complex.all ;

library work ;
    use work.wlan_p.all ;

entity wlan_channel_inverter_tb is
end entity ;

architecture arch of wlan_channel_inverter_tb is

    constant TAVG : complex_array_t := (
      (     4.0,     2.0),
      (  5736.0,  2073.0),
      ( -5700.0, -1798.0),
      ( -5569.0, -1564.0),
      (  5389.0,  1404.0),
      (  5180.0,  1331.0),
      ( -4986.0, -1341.0),
      (  4837.0,  1414.0),
      ( -4750.0, -1520.0),
      (  4742.0,  1628.0),
      ( -4780.0, -1702.0),
      ( -4854.0, -1728.0),
      ( -4923.0, -1696.0),
      ( -4965.0, -1620.0),
      ( -4964.0, -1522.0),
      (  4909.0,  1427.0),
      (  4818.0,  1362.0),
      ( -4710.0, -1344.0),
      ( -4600.0, -1372.0),
      (  4533.0,  1441.0),
      ( -4515.0, -1527.0),
      (  4532.0,  1595.0),
      ( -4609.0, -1631.0),
      (  4684.0,  1605.0),
      (  4753.0,  1521.0),
      (  4773.0,  1388.0),
      (  4717.0,  1230.0),
      (     1.0,     0.0),
      (     4.0,     1.0),
      (    -1.0,     0.0),
      (     4.0,     1.0),
      (     1.0,     0.0),
      (     2.0,     1.0),
      (     0.0,     0.0),
      (     1.0,     1.0),
      (    -1.0,    -1.0),
      (     1.0,     0.0),
      (     1.0,     1.0),
      (  4206.0,  2466.0),
      (  4354.0,  2392.0),
      ( -4440.0, -2287.0),
      ( -4446.0, -2177.0),
      (  4406.0,  2102.0),
      (  4336.0,  2079.0),
      ( -4268.0, -2110.0),
      (  4222.0,  2185.0),
      ( -4227.0, -2285.0),
      (  4283.0,  2381.0),
      (  4373.0,  2445.0),
      (  4480.0,  2462.0),
      (  4586.0,  2433.0),
      (  4660.0,  2367.0),
      (  4682.0,  2282.0),
      ( -4654.0, -2210.0),
      ( -4590.0, -2179.0),
      (  4500.0,  2200.0),
      (  4438.0,  2286.0),
      ( -4423.0, -2422.0),
      (  4474.0,  2578.0),
      ( -4602.0, -2721.0),
      (  4801.0,  2816.0),
      (  5040.0,  2830.0),
      (  5300.0,  2758.0),
      (  5523.0,  2591.0)
    ) ;

    signal clock        :   std_logic                   := '1' ;
    signal reset        :   std_logic                   := '1' ;

    signal first        :   std_logic                   := '0' ;
    signal last         :   std_logic                   := '0' ;

    signal channel      :   wlan_sample_t     := (i => (others =>'0'), q => (others =>'0'), valid => '0') ;
    signal reference    :   wlan_sample_t     := (i => (others =>'0'), q => (others =>'0'), valid => '0') ;

    signal inverted     :   wlan_sample_t ;

    signal done         :   std_logic ;

    procedure nop( signal clock : in std_logic ; x : natural ) is
    begin
        for i in 1 to x loop
            wait until rising_edge(clock) ;
        end loop ;
    end procedure ;

begin

    clock <= not clock after 1 ns ;

    U_channel_inverter : entity work.wlan_channel_inverter
      port map (
        clock           =>  clock,
        reset           =>  reset,

        first           =>  first,
        last            =>  last,

        in_channel      =>  channel,
        in_reference    =>  reference,

        out_inverted    =>  inverted,
        done            =>  done
      ) ;

    tb : process
    begin
        reset <= '1' ;
        nop( clock, 10 ) ;

        reset <= '0' ;
        nop( clock, 10 ) ;

        for i in TAVG'range loop
            reference.i <= to_signed(integer(LONG_SEQ_FREQ(i).re*4096.0), reference.i'length) ;
            reference.q <= to_signed(integer(LONG_SEQ_FREQ(i).im*4096.0), reference.q'length) ;
            channel.i <= to_signed(integer(TAVG(i).re), channel.i'length) ;
            channel.q <= to_signed(integer(TAVG(i).im), channel.q'length) ;
            channel.valid <= '1' ;
            if( i = 0 ) then
                first <= '1' ;
            else
                first <= '0' ;
            end if ;

            if( i = TAVG'high ) then
                last <= '1' ;
            else
                last <= '0' ;
            end if ;
            nop( clock, 1 ) ;
        end loop ;
        last <= '0' ;
        channel.valid <= '0' ;

        wait until rising_edge(clock) and done = '1' ;
        nop( clock, 100 ) ;
        report "-- End of Simulation --" severity failure ;
    end process ;

    equalize : process
        variable expected : complex := (0.0, 0.0) ;
        variable finished : boolean := false ;
        variable cinverted : complex := (0.0, 0.0);
        variable idx : natural range TAVG'range := 0 ;
        variable error_squared : real := 0.0 ;
        variable equalized : complex := (0.0, 0.0) ;
    begin
        while finished = false loop
            wait until rising_edge(clock) and inverted.valid = '1' ;
            cinverted.re := real(to_integer(inverted.i)) ;
            cinverted.im := real(to_integer(inverted.q)) ;
            cinverted := cinverted ;
            equalized := (TAVG(idx) * cinverted) / 4096.0 ;
            expected := LONG_SEQ_FREQ(idx) * 4096.0 ;
            error_squared := (expected.re - equalized.re) * (expected.re - equalized.re) +
                             (expected.im - equalized.im) * (expected.im - equalized.im) +
                             1.0e-100;
            if( done = '1' ) then
                finished := true ;
            else
                idx := idx + 1 ;
            end if ;
        end loop ;
        wait ;
    end process ;

end architecture ;

