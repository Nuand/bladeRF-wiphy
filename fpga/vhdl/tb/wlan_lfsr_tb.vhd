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

entity wlan_lfsr_tb is
end entity ;

architecture arch of wlan_lfsr_tb is

    signal clock        :   std_logic                       := '1' ;
    signal reset        :   std_logic                       := '1' ;

    signal init         :   unsigned(6 downto 0)            := (others =>'1') ;
    signal init_valid   :   std_logic                       := '0' ;

    signal advance      :   std_logic                       := '0' ;
    signal data         :   std_logic_vector(7 downto 0) ;
    signal data_valid   :   std_logic ;

    function reverse(x : in std_logic_vector) return std_logic_vector is
        variable rv : std_logic_vector(x'range) ;
    begin
        for i in x'range loop
            rv(rv'high-i) := x(i) ;
        end loop ;
        return rv ;
    end function ;

begin

    clock <= not clock after 0.5 ns ;

    U_lfsr : entity work.wlan_lfsr
      generic map (
        WIDTH       =>  data'length
      ) port map (
        clock       =>  clock,
        reset       =>  reset,

        init        =>  init,
        init_valid  =>  init_valid,

        advance     =>  advance,
        data        =>  data,
        data_valid  =>  data_valid
      ) ;

    tb : process
    begin
        nop( clock, 100 ) ;
        reset <= '0' ;

        nop( clock, 100 ) ;

        init <= "1011101" ; -- L-14 from standard
        init_valid <= '1' ;
        nop( clock, 1 ) ;

        init_valid <= '0' ;
        nop( clock, 100 ) ;

        for i in TABLE_L_13'range loop
            advance <= '1' ;
            nop( clock, 1 ) ;
        end loop ;

        advance <= '0' ;
        nop( clock, 100 ) ;

        report "-- End of Simulation --" severity failure ;

    end process ;

    verification : process
        variable indata : std_logic_vector(data'range) ;
        variable result : std_logic_vector(data'range) ;
        variable rev_result : std_logic_vector(data'range) ;
    begin
        result := (others =>'0') ;
        indata := (others =>'0') ;
        rev_result := (others =>'0') ;
        for i in 0 to TABLE_L_15'high loop
            wait until rising_edge(clock) and data_valid = '1' ;
            indata := std_logic_vector(to_unsigned(TABLE_L_13(i),data'length));
            result := data xor indata ;
            -- Location of tail bits that have to be 0 going into Viterbi Encoder
            if( i = 102 ) then
                result(5 downto 0) := (others =>'0') ;
            end if ;
            rev_result := reverse(result) ;
            assert rev_result = std_logic_vector(to_unsigned(TABLE_L_15(i),result'length))
                report "Incorrect scrambling sequence at index " & integer'image(i)
                severity error ;
        end loop ;
        wait ;
    end process ;

end architecture ;

