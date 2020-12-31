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

entity wlan_peak_finder_tb is
end entity ;

architecture arch of wlan_peak_finder_tb is

    signal clock        :   std_logic                       := '1' ;
    signal reset        :   std_logic                       := '1' ;

    signal init         :   unsigned(6 downto 0)            := (others =>'1') ;
    signal init_valid   :   std_logic                       := '0' ;

    signal advance      :   std_logic                       := '0' ;
    signal data         :   std_logic_vector(7 downto 0) ;
    signal data_valid   :   std_logic ;

    signal sample       :   unsigned( 127 downto 0 ) ;
    signal inc          :   std_logic := '1';
begin

    clock <= not clock after 0.5 ns ;
    reset <= '1', '0' after 10 ns;
    U_peak_finder : entity work.wlan_peak_finder
      port map (
        clock       =>  clock,
        reset       =>  reset,

        sample      =>  sample,
        sample_valid=>  '1',
        peak        =>  open
      ) ;

    process(clock)
    begin
        if( reset = '1' ) then
            sample <= (others => '0') ;
        elsif( rising_edge( clock ) ) then
            if( inc = '1' ) then
                sample <= sample + 1 ;
                if (sample = 45) then
                    inc <= '0';
                end if;
            else
                sample <= sample - 1 ;
            end if;
        end if;
    end process;

end architecture ;


