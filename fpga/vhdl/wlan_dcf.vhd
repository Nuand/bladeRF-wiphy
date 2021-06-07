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

library wlan;
    use wlan.wlan_p.all ;
    use wlan.wlan_tx_p.all ;
    use wlan.wlan_rx_p.all ;

entity wlan_dcf is
  port (
    rx_clock           :   in  std_logic ;
    rx_reset           :   in  std_logic ;
    rx_enable          :   in  std_logic ;

    rand_lsb           :   in  std_logic ;
    rand_valid         :   in  std_logic ;

    rx_quiet           :   in  std_logic ;
    rx_block           :  out  std_logic ;

    tx_clock           :   in  std_logic ;
    tx_reset           :   in  std_logic ;
    tx_enable          :   in  std_logic ;

    tx_req             :   in  std_logic ;
    tx_idle            :   in  std_logic ;

    tx_sifs_ready      :  out  std_logic ;
    tx_difs_ready      :  out  std_logic
  ) ;
end entity ;

architecture arch of wlan_dcf is

    type fsm_t is (IDLE, CAPTURE_CW, LOOK_FOR_SILENCE, WAIT_END_TX ) ;

    type state_t is record
        fsm                  :  fsm_t;

        timer                :  unsigned( 15 downto 0 ) ;

        rand                 :  std_logic_vector( 7 downto 0 ) ;
        cw_mask              :  std_logic_vector( 7 downto 0 ) ;

        cw_timer             :  unsigned( 15 downto 0 ) ;

        rx_block             :  std_logic ;

        difs                 :  std_logic ;
        sifs                 :  std_logic ;
    end record;

    function NULL_STATE return state_t is
        variable rv : state_t;
    begin
        rv.fsm := IDLE ;
        rv.timer := (others => '0' ) ;
        rv.rand := (others => '0' ) ;
        rv.cw_mask := (others => '0' ) ;

        rv.cw_timer := (others => '0' ) ;

        rv.rx_block := '0' ;

        rv.difs := '0' ;
        rv.sifs := '0' ;
        return rv ;
    end function ;


    signal current          :  state_t ;
    signal future           :  state_t ;

    signal rx_quiet_r       :  std_logic_vector( 3 downto 0 );
    signal rand_lsb_r       :  std_logic_vector( 3 downto 0 );
    signal rand_valid_r     :  std_logic_vector( 3 downto 0 );

    signal rx_block_r       :  std_logic_vector( 3 downto 0 );

begin

    tx_sifs_ready <= current.sifs ;
    tx_difs_ready <= current.difs ;

    rx_block <= rx_block_r(0) ;
    process( rx_clock, rx_reset )
    begin
        if( rx_reset = '1' ) then
            rx_block_r <= ( others => '0' ) ;
        elsif( rising_edge(rx_clock) ) then
            rx_block_r <= current.rx_block & rx_block_r( 3 downto 1 ) ;
        end if ;
    end process ;

    process( tx_clock, tx_reset )
    begin
        if( tx_reset = '1' ) then
            rx_quiet_r <= ( others => '0' ) ;
            rand_lsb_r <= ( others => '0' ) ;
            rand_valid_r <= ( others => '0' ) ;
            current <= NULL_STATE ;
        elsif( rising_edge(rx_clock) ) then
            rx_quiet_r <= rx_quiet & rx_quiet_r( 3 downto 1 ) ;
            rand_lsb_r <= rand_lsb & rand_lsb_r( 3 downto 1 ) ;
            rand_valid_r <= rand_valid & rand_valid_r( 3 downto 1 ) ;
            current <= future ;
        end if ;
    end process ;

    state_comb : process(all)
    begin
        future <= current;

        future.rand <= rand_lsb_r(0) & current.rand( 7 downto 1 ) ;
        future.rx_block <= '0' ;

        case current.fsm is
            when IDLE =>
                future.fsm <= CAPTURE_CW ;

            when CAPTURE_CW =>
                future.sifs <= '0' ;
                future.difs <= '0' ;

                future.timer <= ( others => '0' ) ;
                future.cw_timer <= 360 + to_unsigned(to_integer(unsigned(current.cw_mask and current.rand)) * 180, 16) ;
                future.fsm <= LOOK_FOR_SILENCE ;

            when LOOK_FOR_SILENCE =>
                --if( rand_valid_r(0) = '1' ) then
                if( true ) then
                    if( rx_quiet_r(0) = '1' ) then
                        if ( current.timer <= current.cw_timer ) then
                            future.timer <= current.timer + 1 ;
                        end if ;
                        if( current.timer = current.cw_timer ) then
                            future.cw_mask <= ( others => '0' ) ;
                            future.difs <= '1' ;
                            future.sifs <= '1' ;
                        end if ;
                    else
                        if( ( current.timer > current.cw_timer ) and tx_req = '1' ) then
                            future.cw_mask <= '1' & current.cw_mask( 7 downto 1 ) ;
                        end if ;
                        future.fsm <= IDLE ;
                        future.sifs <= '0' ;
                        future.difs <= '0' ;
                    end if ;

                    if( current.timer >= 40 ) then
                        future.sifs <= '1' ;
                    end if ;

                end if ;

                if( tx_idle = '0' ) then
                    future.fsm <= WAIT_END_TX ;
                    future.sifs <= '0' ;
                    future.difs <= '0' ;
                    future.rx_block <= '1' ;
                end if ;

            when WAIT_END_TX =>
                future.rx_block <= '1' ;
                if( tx_idle = '1' ) then
                    future.fsm <= CAPTURE_CW ;
                    future.rx_block <= '0' ;
                end if ;

        end case ;
    end process ;

end architecture ;


