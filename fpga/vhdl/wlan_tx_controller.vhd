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
    use work.wlan_tx_p.all ;

entity wlan_tx_controller is
  port (
    clock               :   in  std_logic ;
    reset               :   in  std_logic ;

    -- Control from the MAC
    tx_vector           :   in  wlan_tx_vector_t ;
    tx_vector_valid     :   in  std_logic ;

    -- Caculated parameters
    params              :   out wlan_tx_params_t ;
    params_valid        :   out std_logic ;

    -- TX status generation
    status              :   out wlan_tx_status_t ;
    status_valid        :   out std_logic ;

    -- Encoder from MAC
    encoder_start       :   out std_logic ;
    encoder_done        :   in  std_logic ;

    -- Short preamble control and status
    short_start         :   out std_logic ;
    short_done          :   in  std_logic ;

    -- Long preamble control and status
    long_done           :   in  std_logic ;

    -- Modulator control and status
    mod_init            :   out std_logic ;
    mod_end             :   in  std_logic ;

    -- TX done
    tx_done             :   in  std_logic
  ) ;
end entity ;

architecture arch of wlan_tx_controller is

    type fsm_t is (IDLE, START_TRANSMISSION, START_ENCODING_DATA, WAIT_FOR_PREAMBLE_DONE, WAIT_FOR_TX_DONE) ;

    type state_t is record
        fsm             :   fsm_t ;
        params          :   wlan_tx_params_t ;
        params_valid    :   std_logic ;
        short_start     :   std_logic ;
        encoder_start   :   std_logic ;
        mod_init        :   std_logic ;
        status_valid    :   std_logic ;
    end record ;

    function calculate_params( x : wlan_tx_vector_t ) return wlan_tx_params_t is
        variable rv : wlan_tx_params_t ;
    begin
        rv.datarate := x.datarate ;
        rv.length   := x.length ;
        rv.lfsr_init := "1011101" ;

        case x.datarate is
            when WLAN_RATE_6    =>
                -- BPSK R=1/2
                rv.n_bpsc := 1 ;
                rv.n_dbps := 24 ;
                rv.n_cbps := 48 ;
                rv.modulation := WLAN_BPSK ;

            when WLAN_RATE_9    =>
                -- BPSK R=3/4
                rv.n_bpsc := 1 ;
                rv.n_dbps := 36 ;
                rv.n_cbps := 48 ;
                rv.modulation := WLAN_BPSK ;

            when WLAN_RATE_12   =>
                -- QPSK R=1/2
                rv.n_bpsc := 2 ;
                rv.n_dbps := 48 ;
                rv.n_cbps := 96 ;
                rv.modulation := WLAN_QPSK ;

            when WLAN_RATE_18   =>
                -- QPSK R=3/4
                rv.n_bpsc := 2 ;
                rv.n_dbps := 72 ;
                rv.n_cbps := 96 ;
                rv.modulation := WLAN_QPSK ;

            when WLAN_RATE_24   =>
                -- 16-QAM R=1/2
                rv.n_bpsc := 4 ;
                rv.n_dbps := 96 ;
                rv.n_cbps := 192 ;
                rv.modulation := WLAN_16QAM ;

            when WLAN_RATE_36   =>
                -- 16-QAM R=3/4
                rv.n_bpsc := 4 ;
                rv.n_dbps := 144 ;
                rv.n_cbps := 192 ;
                rv.modulation := WLAN_16QAM ;

            when WLAN_RATE_48   =>
                -- 64-QAM R=2/3
                rv.n_bpsc := 6 ;
                rv.n_dbps := 192 ;
                rv.n_cbps := 288 ;
                rv.modulation := WLAN_64QAM ;

            when WLAN_RATE_54   =>
                -- 64-QAM R=3/4
                rv.n_bpsc := 6 ;
                rv.n_dbps := 216 ;
                rv.n_cbps := 288;
                rv.modulation := WLAN_64QAM ;

            when others =>
                report "Invalid params" severity failure ;
        end case ;

        case x.bandwidth is
            when WLAN_BW_5  =>
                null ;

            when WLAN_BW_10 =>
                null ;

            when WLAN_BW_20 =>
                null ;

            when others =>
                report "Invalid bandwidth" severity failure ;
        end case ;

        return rv ;
    end function ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := IDLE ;
        rv.params_valid := '0' ;
        rv.short_start := '0' ;
        rv.encoder_start := '0' ;
        rv.mod_init := '0' ;
        rv.status_valid := '0' ;
        return rv ;
    end function ;

    signal current, future  :   state_t := NULL_STATE ;

begin

    params <= current.params ;
    params_valid <= current.params_valid ;
    short_start <= current.short_start ;
    encoder_start <= current.encoder_start ;
    mod_init <= current.mod_init ;

    sync : process(clock, reset)
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
        elsif( rising_edge(clock) ) then
            current <= future ;
        end if ;
    end process ;

    comb : process(all)
    begin
        future <= current ;
        future.params_valid <= '0' ;
        future.short_start <= '0' ;
        future.encoder_start <= '0' ;
        future.mod_init <= '0' ;
        future.status_valid <= '0' ;
        case current.fsm is
            when IDLE =>
                future.params_valid <= tx_vector_valid ;
                if( tx_vector_valid = '1' ) then
                    future.params <= calculate_params(tx_vector) ;
                    future.fsm <= START_TRANSMISSION ;
                end if ;

            when START_TRANSMISSION =>
                future.short_start <= '1' ;
                future.fsm <= START_ENCODING_DATA ;

            when START_ENCODING_DATA =>
                future.fsm <= WAIT_FOR_PREAMBLE_DONE ;

            when WAIT_FOR_PREAMBLE_DONE =>
                if( long_done = '1' ) then
                    future.fsm <= WAIT_FOR_TX_DONE ;
                    future.encoder_start <= '1' ;
                    future.mod_init <= '1' ;
                end if ;

            when WAIT_FOR_TX_DONE =>
                if( tx_done = '1' ) then
                    future.fsm <= IDLE ;
                end if ;

        end case ;
    end process ;

end architecture ;

