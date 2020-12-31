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

entity wlan_viterbi_encoder_tb is
end entity ;

architecture arch of wlan_viterbi_encoder_tb is

    signal clock        :   std_logic                       := '1' ;
    signal reset        :   std_logic                       := '1' ;

    signal init         :   std_logic                       := '0' ;

    signal in_data      :   std_logic_vector(7 downto 0)    := (others =>'0') ;
    signal in_valid     :   std_logic                       := '0' ;
    signal in_done      :   std_logic                       := '0' ;

    signal out_a        :   std_logic_vector(7 downto 0) ;
    signal out_b        :   std_logic_vector(7 downto 0) ;
    signal out_done     :   std_logic ;
    signal out_valid    :   std_logic ;

    signal r34          :   std_logic_vector(11 downto 0) ;

    function reverse( x : in integer ; len : in positive ) return std_logic_vector is
        constant val : unsigned(len-1 downto 0) := to_unsigned(x,len) ;
        variable rv : unsigned(len-1 downto 0) ;
    begin
        for i in val'range loop
            rv(val'high-i) := val(i) ;
        end loop ;
        return std_logic_vector(rv) ;
    end ;

begin

    -- 40 MHz clock rate
    clock <= not clock after (0.5 / 40.0e6) * 1 sec ;

    U_encoder : entity work.wlan_viterbi_encoder
      generic map (
        WIDTH       =>  in_data'length
      ) port map (
        clock       =>  clock,
        reset       =>  reset,

        init        =>  init,

        in_data     =>  in_data,
        in_valid    =>  in_valid,
        in_done     =>  in_done,

        out_a       =>  out_a,
        out_b       =>  out_b,
        out_done    =>  out_done,
        out_valid   =>  out_valid
      ) ;

    tb : process
    begin
        reset <= '1' ;
        nop( clock, 100 ) ;

        reset <= '0' ;
        nop( clock, 100 ) ;

        for x in 1 to 2 loop
            init <= '1' ;
            nop( clock, 1 ) ;
            init <= '0' ;
            nop( clock, 1 ) ;
            for i in TABLE_L_15'range loop
                in_data <= reverse(TABLE_L_15(i), in_data'length) ;
                in_valid <= '1' ;
                if( i = TABLE_L_15'high ) then
                    in_done <= '1' ;
                end if ;
                nop( clock, 1 ) ;
            end loop ;
            in_valid <= '0' ;
            in_done <= '0' ;
            nop( clock, 100 ) ;
        end loop ;

        report "-- End of Simulation --" severity failure ;
    end process ;

    -- R=3/4 verification
    verify : process
        variable idx : natural range 0 to TABLE_L_16'length ;
        variable downcount : natural range 0 to 8 ;
        variable accum : std_logic_vector(7 downto 0) ;
        type puncture_t is (AB, A, B) ;
        variable puncture : puncture_t ;
        variable check : std_logic_vector(7 downto 0) ;
    begin
        idx := 0 ;
        accum := (others =>'0') ;
        puncture := AB ;
        check := (others =>'0') ;
        downcount := 8 ;
        while idx < TABLE_L_16'length loop
            wait until rising_edge(clock) and out_valid = '1' ;
            -- Need to consume A and B and, after 8 bits accumulated, check index
            for i in 0 to out_a'high loop
                case puncture is
                    when AB =>
                        accum := accum(6 downto 0) & out_a(i) ;
                        downcount := downcount - 1 ;
                        if( downcount = 0 ) then
                            -- Verify
                            check := std_logic_vector(to_unsigned(TABLE_L_16(idx),check'length)) ;
                            assert check = accum
                                report "Incorrect Viterbi Encoding @ " & integer'image(idx)
                                severity error ;
                            downcount := 8 ;
                            idx := idx + 1 ;
                        end if ;
                        accum := accum(6 downto 0) & out_b(i) ;
                        downcount := downcount - 1 ;
                        if( downcount = 0 ) then
                            -- Verify
                            check := std_logic_vector(to_unsigned(TABLE_L_16(idx),check'length)) ;
                            assert check = accum
                                report "Incorrect Viterbi Encoding @ " & integer'image(idx)
                                severity error ;
                            downcount := 8 ;
                            idx := idx + 1 ;
                        end if ;
                        puncture := A ;
                    when A =>
                        accum := accum(6 downto 0) & out_a(i) ;
                        downcount := downcount - 1 ;
                        if( downcount = 0 ) then
                            -- Verify
                            check := std_logic_vector(to_unsigned(TABLE_L_16(idx),check'length)) ;
                            assert check = accum
                                report "Incorrect Viterbi Encoding @ " & integer'image(idx)
                                severity error ;
                            downcount := 8 ;
                            idx := idx + 1 ;
                        end if ;
                        puncture := B ;
                    when B =>
                        accum := accum(6 downto 0) & out_b(i) ;
                        downcount := downcount - 1 ;
                        if( downcount = 0 ) then
                            -- Verify
                            check := std_logic_vector(to_unsigned(TABLE_L_16(idx),check'length)) ;
                            assert check = accum
                                report "Incorrect Viterbi Encoding @ " & integer'image(idx)
                                severity error ;
                            downcount := 8 ;
                            idx := idx + 1 ;
                        end if ;
                        puncture := AB ;
                end case ;
            end loop ;
        end loop ;
        wait ;
    end process ;

end architecture ;

