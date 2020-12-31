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
    use work.wlan_interleaver_p.all ;
    use work.wlan_rx_p.all ;

entity wlan_depuncturer is
  port (
    clock               :   in  std_logic ;
    reset               :   in  std_logic ;

    init                :   in  std_logic ;

    modulation          :   in  wlan_modulation_t ;
    data                :   in  bsd_array_t(287 downto 0) ;
    in_valid            :   in  std_logic ;

    params          :   in  wlan_rx_params_t ;
    params_valid    :   in  std_logic ;

    end_zero_pad        :   in  std_logic ;
    empty               :   out std_logic ;

    out_soft_a          :   out signed(7 downto 0) ;
    out_soft_b          :   out signed(7 downto 0) ;
    out_erasure         :   out std_logic_vector(1 downto 0) ;
    out_valid           :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_depuncturer is
    signal bit_count   :   unsigned( 11 downto 0 ) ;

    type puncture_3_4_t is (STATE_A, STATE_B, STATE_C) ;
    type fsm_t is (IDLE, WAIT_FOR_DATA, DEPUNCTURING, ZEROS) ;
    type state_t is record
        fsm             :   fsm_t ;
        bit_count       :   unsigned( 13 downto 0 ) ;
        n_cbps          :   natural range 0 to 288 ;
        num_symbols     :   natural range 0 to 1366 ;
--        bit_count_saved :   unsigned( 13 downto 0 ) ;
        decoded_bits    :  natural range 0 to 12000 ;
        bit_index       :  natural range 0 to 12000 ;
        n_dbps          :  natural range 24 to 216 ;
        data            :   bsd_array_t( 287 downto 0 ) ;
        soft_a          :   signed( 7 downto 0 ) ;
        soft_b          :   signed( 7 downto 0 ) ;
        erasure         :   std_logic_vector( 1 downto 0 ) ;
        soft_valid      :   std_logic ;
        params          :   wlan_rx_params_t ;
        datarate        :   wlan_datarate_t ;
        p_3_4           :   puncture_3_4_t ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        rv.fsm := IDLE ;
        rv.bit_count := to_unsigned( 0, rv.bit_count'length ) ;
        rv.n_cbps := 48 ;
--        rv.bit_count_saved := to_unsigned( 0, rv.bit_count_saved'length ) ;
        rv.decoded_bits := 0 ;
        rv.bit_index := 0 ;
        rv.n_dbps := 24 ;
        rv.data := ( others => (others => '0' ) ) ;
        rv.soft_a := ( others => '0' ) ;
        rv.soft_b := ( others => '0' ) ;
        rv.erasure := ( others => '0' ) ;
        rv.soft_valid := '0' ;
        rv.datarate := WLAN_RATE_6 ;
        rv.p_3_4 := STATE_A ;
        return rv ;
    end function ;

    signal current, future  :   state_t := NULL_STATE ;

begin

    empty <= '0' when ( current.fsm = DEPUNCTURING ) else '1' ;
    out_soft_a <= current.soft_a ;
    out_soft_b <= current.soft_b ;
    out_erasure <= current.erasure ;

    out_valid  <= current.soft_valid ;

    sync : process(clock, reset)
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
        elsif( rising_edge(clock) ) then
            if( init = '1' ) then
                current <= NULL_STATE ;
            else
                current <= future ;
            end if ;
        end if ;
    end process ;

    comb : process(all)
    begin
        future <= current ;
        future.soft_valid <= '0' ;

        case current.fsm is
            when IDLE =>
                if( params_valid = '1' ) then
--                    future.bit_count <= current.bit_count_saved ;
                    future.decoded_bits <= params.num_data_symbols ;
                    future.bit_index <= 0 ;
                    future.n_dbps <= params.n_dbps ;
                    future.datarate <= params.datarate;
                    future.n_cbps <= params.n_dbps ;
                    future.fsm <= WAIT_FOR_DATA ;
                else
                    future <= NULL_STATE ;
                end if ;
            when WAIT_FOR_DATA =>
                if( in_valid = '1' )  then
                    future.data <= data ;
                    future.fsm <= DEPUNCTURING ;
                    future.bit_index <= current.bit_index + 1 ;
                    future.bit_count <= to_unsigned( current.n_cbps - 1, future.bit_count'length ) ;
                end if ;
            when DEPUNCTURING =>
                if( current.bit_count = 0 ) then
                    if( current.bit_index >= current.decoded_bits ) then
                        future.fsm <= ZEROS ;
                    else
                        future.fsm <= WAIT_FOR_DATA ;
                    end if ;
                else
                    future.bit_index <= current.bit_index + 1 ;
                    future.bit_count <= current.bit_count - 1 ;
                end if;

                -- r=1/2
                if( current.datarate = WLAN_RATE_6 or current.datarate = WLAN_RATE_12 or
                        current.datarate = WLAN_RATE_24 ) then
                    future.soft_a <= current.data(0);
                    future.soft_b <= current.data(1);
                    future.erasure <= "00";
                    future.data <= current.data(1 downto 0) & current.data( 287 downto 2 );
                    future.soft_valid <= '1' ;
                end if ;

                -- r=3/4
                if( current.datarate = WLAN_RATE_9 or current.datarate = WLAN_RATE_18 or
                        current.datarate = WLAN_RATE_36 or current.datarate = WLAN_RATE_54 ) then
                    if( current.p_3_4 = STATE_A ) then
                        future.soft_a <= current.data(0);
                        future.soft_b <= current.data(1);
                        future.erasure <= "00";
                        future.p_3_4 <= STATE_B;
                        future.data <= current.data(1 downto 0) & current.data( 287 downto 2 );
                    elsif( current.p_3_4 = STATE_B ) then
                        future.soft_a <= current.data(0);
                        future.soft_b <= (others => '0');
                        future.erasure <= "01";
                        future.p_3_4 <= STATE_C;
                        future.data <= current.data(0) & current.data( 287 downto 1 );
                    elsif( current.p_3_4 = STATE_C ) then
                        future.soft_a <= (others => '0');
                        future.soft_b <= current.data(0);
                        future.erasure <= "10";
                        future.p_3_4 <= STATE_A;
                        future.data <= current.data(0) & current.data( 287 downto 1 );
                    end if;

                    future.soft_valid <= '1' ;
                end if ;

                -- r=2/3
                if( current.datarate = WLAN_RATE_48 ) then
                    if( current.p_3_4 = STATE_A ) then
                        future.soft_a <= current.data(0);
                        future.soft_b <= current.data(1);
                        future.erasure <= "00";
                        future.p_3_4 <= STATE_B;
                        future.data <= current.data(1 downto 0) & current.data( 287 downto 2 );
                    elsif( current.p_3_4 = STATE_B ) then
                        future.soft_a <= current.data(0);
                        future.soft_b <= (others => '0');
                        future.erasure <= "01";
                        future.p_3_4 <= STATE_A;
                        future.data <= current.data(0) & current.data( 287 downto 1 );
                    end if ;
                    future.soft_valid <= '1' ;
                end if ;
            when ZEROS =>
                if( end_zero_pad = '1' ) then
                    future.fsm <= IDLE ;
                end if ;

                future.soft_a <= ( others => '0' ) ;
                future.soft_b <= ( others => '0' ) ;
                future.erasure <= ( others => '1' ) ;
                future.soft_valid <= '1' ;

        end case ;
    end process ;


end architecture ;


