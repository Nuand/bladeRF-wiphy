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

entity wlan_viterbi_encoder is
  generic (
    WIDTH       :       positive    := 4
  ) ;
  port (
    clock       :   in  std_logic ;
    reset       :   in  std_logic ;

    init        :   in  std_logic ;

    in_data     :   in  std_logic_vector(WIDTH-1 downto 0) ;
    in_valid    :   in  std_logic ;
    in_done     :   in  std_logic ;

    out_a       :   out std_logic_vector(WIDTH-1 downto 0) ;
    out_b       :   out std_logic_vector(WIDTH-1 downto 0) ;
    out_done    :   out std_logic ;
    out_valid   :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_viterbi_encoder is

    signal state : unsigned(5 downto 0) := (others =>'0') ;

begin

    encode : process(clock, reset)
        variable tempstate : unsigned(state'range) := (others =>'0') ;
    begin
        if( reset = '1' ) then
            state <= (others =>'0') ;
            out_a <= (others =>'0') ;
            out_b <= (others =>'0') ;
            out_valid <= '0' ;
            out_done <= '0' ;
            tempstate := (others =>'0') ;
        elsif( rising_edge(clock) ) then
            out_valid <= '0' ;
            out_done <= in_done ;
            if( init = '1' ) then
                state <= (others =>'0') ;
            else
                out_valid <= in_valid ;
                if( in_valid = '1' ) then
                    tempstate := state ;
                    for i in 0 to in_data'high loop
                        out_a(i) <= tempstate(5) xor tempstate(4) xor tempstate(2) xor tempstate(1) xor in_data(i) ;
                        out_b(i) <= tempstate(5) xor tempstate(2) xor tempstate(1) xor tempstate(0) xor in_data(i) ;
                        tempstate := tempstate(4 downto 0) & in_data(i) ;
                    end loop ;
                    state <= tempstate ;
                end if ;
            end if ;
        end if ;
    end process ;

end architecture ;

