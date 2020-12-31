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

library work ;
    use work.wlan_p.all ;
    use work.wlan_tables_p.all ;
    use work.wlan_tx_p.all ;

library std ;
    use std.textio.all ;

entity wlan_tx_tb is
end entity ;

architecture arch of wlan_tx_tb is

    signal clock                :   std_logic                       := '1' ;
    signal reset                :   std_logic                       := '1' ;

    signal tx_vector            :   wlan_tx_vector_t ;
    signal tx_vector_valid      :   std_logic                       := '0' ;

    signal tx_status            :   wlan_tx_status_t ;
    signal tx_status_valid      :   std_logic ;

    signal fifo_re              :   std_logic ;
    signal fifo_data            :   std_logic_vector(7 downto 0)    := (others =>'0') ;
    signal fifo_empty           :   std_logic                       := '0' ;
    signal fifo_reset           :   std_logic                       := '0' ;

    signal bb                   :   wlan_sample_t ;
    signal bb_scaled            :   wlan_sample_t ;
    signal done                 :   std_logic ;

    type wlan_tx_vectors_t is array(natural range <>) of wlan_tx_vector_t ;

    constant VECTORS : wlan_tx_vectors_t := (
        (length => TABLE_L_1'length, bandwidth => WLAN_BW_20, datarate => WLAN_RATE_6),
        (length => TABLE_L_1'length, bandwidth => WLAN_BW_20, datarate => WLAN_RATE_9),
        (length => TABLE_L_1'length, bandwidth => WLAN_BW_20, datarate => WLAN_RATE_12),
        (length => TABLE_L_1'length, bandwidth => WLAN_BW_20, datarate => WLAN_RATE_18),
        (length => TABLE_L_1'length, bandwidth => WLAN_BW_20, datarate => WLAN_RATE_24),
        (length => TABLE_L_1'length, bandwidth => WLAN_BW_20, datarate => WLAN_RATE_36),
        (length => TABLE_L_1'length, bandwidth => WLAN_BW_20, datarate => WLAN_RATE_48),
        (length => TABLE_L_1'length, bandwidth => WLAN_BW_20, datarate => WLAN_RATE_54)
    ) ;

    function "/"( L : wlan_sample_t ; R : real ) return wlan_sample_t is
        variable rv : wlan_sample_t := L ;
    begin
        rv.i := to_signed(integer(real(to_integer(L.i))/R),rv.i'length) ;
        rv.q := to_signed(integer(real(to_integer(L.q))/R),rv.q'length) ;
        return rv ;
    end function ;

begin

    -- Actual 40MHz clock
    clock <= not clock after (0.5/40.0e6) * 1 sec ;

    fifo : process(clock, reset, fifo_reset)
        variable index : natural range TABLE_L_1'range := TABLE_L_1'low ;
    begin
        if( reset = '1' or fifo_reset = '1' ) then
            index := TABLE_L_1'low ;
            fifo_empty <= '0' ;
            fifo_data <= std_logic_vector(to_unsigned(TABLE_L_1(index),fifo_data'length)) ;
        elsif( rising_edge(clock) ) then
            fifo_empty <= '0' ;
            if( fifo_re = '1' ) then
                if( index < TABLE_L_1'high ) then
                    index := index + 1 ;
                end if ;
            end if ;
            fifo_data <= std_logic_vector(to_unsigned(TABLE_L_1(index),fifo_data'length)) ;
            if( index = TABLE_L_1'high ) then
                fifo_empty <= '1' ;
            end if ;
        end if ;
    end process ;

    U_wlan_tx : entity work.wlan_tx
      port map (
        clock               =>  clock,
        reset               =>  reset,

        tx_vector           =>  tx_vector,
        tx_vector_valid     =>  tx_vector_valid,

        tx_status           =>  tx_status,
        tx_status_valid     =>  tx_status_valid,

        fifo_re             =>  fifo_re,
        fifo_data           =>  fifo_data,
        fifo_empty          =>  fifo_empty,

        bb                  =>  bb,
        done                =>  done
      ) ;

    tb : process
        variable clock_count : natural ;
    begin
        reset <= '1' ;
        nop( clock, 100 ) ;

        reset <= '0' ;
        nop( clock, 100 ) ;

        -- Setup for a transmission
        for i in VECTORS'range loop
            clock_count := 10_000 ;
            tx_vector <= VECTORS(i) ;

            -- Kick it off
            tx_vector_valid <= '1' ;
            nop( clock, 1 ) ;
            tx_vector_valid <= '0' ;

            -- Wait for a while or until we've timed out
            inner : while true loop
                wait until rising_edge(clock) ;
                if done = '1' then
                    write( output, "Continuing on..." & CR ) ;
                    exit inner ;
                else
                    if( clock_count = 0 ) then
                        report "Never finished - exiting early"
                            severity failure ;
                    else
                        clock_count := clock_count - 1 ;
                    end if ;
                end if ;
            end loop ;
            fifo_reset <= '1' ;
            nop( clock, 1 ) ;
            fifo_reset <= '0' ;
            nop( clock, 100 ) ;
        end loop ;

        -- Done
        report "-- End of Simulation --" severity failure ;
    end process ;

    bb_scaled <= bb ;

    U_sample_saver : entity work.wlan_sample_saver
      generic map (
        FILENAME    =>  "tx"
      ) port map (
        clock       =>  clock,
        fopen       =>  tx_vector_valid,
        sample      =>  bb_scaled,
        done        =>  done
      ) ;

end architecture ;

