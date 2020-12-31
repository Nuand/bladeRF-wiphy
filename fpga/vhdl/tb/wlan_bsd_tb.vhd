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

entity wlan_bsd_tb is
end entity ;

architecture arch of wlan_bsd_tb is

    signal clock        :   std_logic       := '1' ;
    signal reset        :   std_logic       := '1' ;

    signal init         :   std_logic       := '0' ;

    signal modulation   :   wlan_modulation_t   := WLAN_BPSK ;

    signal data         :   std_logic_vector(287 downto 0) := (others =>'0') ;
    signal data_valid   :   std_logic       := '0' ;

    signal mod_start    :   std_logic ;
    signal mod_end      :   std_logic ;
    signal mod_sample   :   wlan_sample_t ;

    signal bsds         :   wlan_bsds_t ;

    procedure nop( signal clock : in std_logic ; count : in natural ) is
    begin
        for i in 1 to count loop
            wait until rising_edge(clock) ;
        end loop ;
    end procedure ;

begin

    clock <= not clock after 1 ns ;

    U_modulator : entity work.wlan_modulator
      port map (
        clock           =>  clock,
        reset           =>  reset,

        init            =>  init,

        data            =>  data,
        modulation      =>  modulation,
        in_valid        =>  data_valid,

        ifft_ready      =>  '1',

        symbol_start    =>  mod_start,
        symbol_end      =>  mod_end,
        symbol_sample   =>  mod_sample
      ) ;

    U_bsd : entity work.wlan_bsd
      port map (
        clock       =>  clock,
        reset       =>  reset,

        modulation  =>  modulation,

        in_sample   =>  mod_sample,

        bsds        =>  bsds
      ) ;

    tb : process
    begin
        reset <= '1' ;
        nop( clock, 10 ) ;

        reset <= '0' ;
        nop( clock, 10 ) ;

        init <= '1' ;
        nop( clock, 1 ) ;
        init <= '0' ;
        nop( clock, 1 ) ;

        -- Run through modulations and populate data
        for m in 0 to wlan_modulation_t'pos(WLAN_64QAM) loop
            modulation <= wlan_modulation_t'val(m) ;
            data <= (others =>'0') ;
            data_valid <= '1' ;
            nop( clock, 1 ) ;
            data_valid <= '0' ;
            wait until rising_edge(clock) and mod_start = '1' ;
            wait until rising_edge(clock) and mod_end = '1' ;
            nop( clock, 10 ) ;
        end loop ;

        nop( clock, 100 ) ;
        report "-- End of Simulation --" severity failure ;
    end process ;

end architecture ;

