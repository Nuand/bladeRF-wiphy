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
    use work.wlan_tables_p.all ;

entity wlan_modulator_tb is
end entity ;

architecture arch of wlan_modulator_tb is

    signal clock            :   std_logic                           := '1' ;
    signal reset            :   std_logic                           := '1' ;

    signal init             :   std_logic                           := '0' ;

    signal data             :   std_logic_vector(287 downto 0)      := TABLE_L_19 ;
    signal modulation       :   wlan_modulation_t                   := WLAN_16QAM ;
    signal in_valid         :   std_logic                           := '0' ;

    signal symbol_start     :   std_logic ;
    signal symbol_end       :   std_logic ;
    signal symbol_sample    :   wlan_sample_t ;

    signal ifft_sample      :   wlan_sample_t ;
    signal ifft_valid_cp    :   std_logic ;
    signal ifft_done        :   std_logic ;

begin

    clock <= not clock after (0.5 sec / 40.0e6) ;

    U_modulator : entity work.wlan_modulator
      port map (
        clock           =>  clock,
        reset           =>  reset,

        init            =>  init,

        data            =>  data,
        modulation      =>  modulation,
        in_valid        =>  in_valid,

        ifft_ready      =>  '1',

        symbol_start    =>  symbol_start,
        symbol_end      =>  symbol_end,
        symbol_sample   =>  symbol_sample
      ) ;

    U_ifft : entity work.wlan_ifft64
      port map (
        clock           =>  clock,
        reset           =>  reset,

        symbol_start    =>  symbol_start,
        symbol_end      =>  symbol_end,
        in_sample       =>  symbol_sample,

        out_sample      =>  ifft_sample,
        out_valid_cp    =>  ifft_valid_cp,
        done            =>  ifft_done
      ) ;

    tb : process
    begin
        reset <= '1' ;
        nop( clock, 100 ) ;

        reset <= '0' ;
        nop( clock, 100 ) ;

        init <= '1' ;
        nop( clock, 1 ) ;
        init <= '0' ;
        nop( clock, 10 ) ;

        for i in 1 to 10 loop
            in_valid <= '1' ;
            nop( clock, 1 ) ;
            in_valid <= '0' ;
            nop( clock, 1 ) ;
            wait until rising_edge(clock) and symbol_end = '1' ;
            nop( clock, 1 ) ;
        end loop ;

        nop( clock, 1000 ) ;
        report "-- End of Simulation --" severity failure ;
    end process ;

end architecture ;

