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

entity wlan_lfsr is
  generic (
    WIDTH       :       positive                        := 8
  ) ;
  port (
    clock       :   in  std_logic ;
    reset       :   in  std_logic ;

    init        :   in  unsigned(6 downto 0) ;
    init_valid  :   in  std_logic ;

    advance     :   in  std_logic ;
    data        :   out std_logic_vector(WIDTH-1 downto 0) ;
    data_valid  :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_lfsr is

    signal state : unsigned(6 downto 0) := (others =>'0') ;

begin

    lfsr : process(clock, reset)
        variable tempstate : unsigned(6 downto 0) := (others =>'0') ;
    begin
        if( reset = '1' ) then
            state <= (others =>'0') ;
            data <= (others =>'0') ;
            data_valid <= '0' ;
            tempstate := (others =>'0') ;
        elsif( rising_edge(clock) ) then
            data_valid <= '0' ;
            if( init_valid = '1' ) then
                tempstate := init ;
                -- Initialize output to the first word, like a look-ahead FIFO
                for i in 0 to data'high loop
                    tempstate := tempstate(5 downto 0) & (tempstate(6) xor tempstate(3)) ;
                    data(i) <= tempstate(0) ;
                end loop ;
                state <= tempstate ;
            else
                data_valid <= advance ;
                if( advance = '1' ) then
                    tempstate := state ;
                    for i in 0 to data'high loop
                        tempstate := tempstate(5 downto 0) & (tempstate(6) xor tempstate(3)) ;
                        data(i) <= tempstate(0) ;
                    end loop ;
                    state <= tempstate ;
                end if ;
            end if ;
        end if ;
    end process ;

end architecture ;

