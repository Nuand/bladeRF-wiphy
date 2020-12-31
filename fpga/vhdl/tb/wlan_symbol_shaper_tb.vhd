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

entity wlan_symbol_shaper_tb is
end entity ;

architecture arch of wlan_symbol_shaper_tb is

    signal clock            :   std_logic           := '1' ;
    signal reset            :   std_logic           := '1' ;

    signal cp_i             :   signed(15 downto 0) := (others =>'0') ;
    signal cp_q             :   signed(15 downto 0) := (others =>'0') ;
    signal cp_re            :   std_logic ;
    signal cp_empty         :   std_logic           := '1' ;

    signal sample_i         :   signed(15 downto 0) := (others =>'0') ;
    signal sample_q         :   signed(15 downto 0) := (others =>'0') ;
    signal sample_re        :   std_logic ;
    signal sample_empty     :   std_logic           := '1' ;

    signal out_sample       :   wlan_sample_t ;
    signal done             :   std_logic ;

begin

    clock <= not clock after (0.5 / 40.0e6) * 1 sec ;

    U_shaper : entity work.wlan_symbol_shaper
      port map (
        clock           =>  clock,
        reset           =>  reset,

        cp_i            =>  cp_i,
        cp_q            =>  cp_q,
        cp_re           =>  cp_re,
        cp_empty        =>  cp_empty,

        sample_i        =>  sample_i,
        sample_q        =>  sample_q,
        sample_re       =>  sample_re,
        sample_empty    =>  sample_empty,

        out_sample      =>  out_sample,
        done            =>  done
      ) ;

    tb : process
    begin
        reset <= '1' ;
        nop(clock, 100) ;

        reset <= '0' ;
        nop(clock, 100) ;

        nop(clock,10000) ;

        report "-- End of Simulation --" severity failure ;
    end process ;

    emulate_cp : process
        variable count : natural := 1 ;
    begin
        wait until rising_edge(clock) and reset = '0' ;
        nop(clock, 100) ;
        cp_empty <= '0' ;
        -- Long sequence CP
        cp_i <= to_signed(1, cp_i'length) ;
        cp_q <= to_signed(1, cp_q'length) ;
        for i in 1 to 32 loop
            wait until rising_edge(clock) and cp_re = '1' ;
        end loop ;

        -- 10 data symbols
        for i in 1 to 10 loop
            cp_i <= cp_i + 1 ;
            cp_q <= cp_q + 1 ;
            for i in 1 to 16 loop
                wait until rising_edge(clock) and cp_re = '1' ;
            end loop ;
        end loop ;

        -- 11th data symbol is the last
        cp_i <= cp_i + 1 ;
        cp_q <= cp_q + 1 ;
        for i in 1 to 15 loop
            wait until rising_edge(clock) and cp_re = '1' ;
        end loop ;
        cp_empty <= '1' ;
        wait until rising_edge(clock) and cp_re = '1' ;
        nop(clock, 100) ;
        wait ;
    end process ;

    emulate_sample : process
        variable count : natural := 0 ;
    begin
        wait until rising_edge(clock) and reset = '0' ;
        nop(clock, 100) ;
        -- Short sequence
        count := 160 ;
        sample_empty <= '0' ;
        sample_i <= to_signed(0, sample_i'length) ;
        sample_q <= to_signed(0, sample_q'length) ;
        for i in 1 to 160 loop
            wait until rising_edge(clock) and sample_re = '1' ;
        end loop ;
        -- Long sequence
        sample_i <= sample_i + 1 ;
        sample_q <= sample_q + 1 ;
        for i in 1 to 128 loop
            wait until rising_edge(clock) and sample_re = '1' ;
        end loop ;

        -- 10 data symbols
        for i in 1 to 10 loop
            sample_i <= sample_i + 1 ;
            sample_q <= sample_q + 1 ;
            for i in 1 to 64 loop
                wait until rising_edge(clock) and sample_re = '1' ;
            end loop ;
        end loop ;

        -- 11th symbol is the last one
        sample_i <= sample_i + 1 ;
        sample_q <= sample_q + 1 ;
        for i in 1 to 63 loop
            wait until rising_edge(clock) and sample_re = '1' ;
        end loop ;
        sample_empty <= '1' ;
        wait until rising_edge(clock) and sample_re = '1' ;

        nop(clock, 100) ;
        wait ;
    end process ;

end architecture ;

