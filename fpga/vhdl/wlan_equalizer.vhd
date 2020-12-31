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

library wlan ;
    use wlan.wlan_p.all ;
    use wlan.wlan_rx_p.all ;

entity wlan_equalizer is
    port (
      clock            :   in std_logic ;
      reset            :   in std_logic ;

      init             :   in std_logic ;

      dfe_sample       :   in wlan_sample_t ;

      in_sample        :   in wlan_sample_t ;
      in_done          :   in std_logic ;
      out_sample       :  out wlan_sample_t ;
      out_done         :   in std_logic
    ) ;
end entity;

architecture arch of wlan_equalizer is

    type equalizer_coefficient is record
        i            :   signed( 15 downto 0 ) ;
        q            :   signed( 15 downto 0 ) ;
    end record ;

    type equalizer_coefficients_t is array (integer range <>) of equalizer_coefficient ;

    constant T2 : integer_array_t( 0 to 63 ) := (
             0,  1, -1, -1,  1,  1, -1, 1,
            -1,  1, -1, -1, -1, -1, -1, 1,
             1, -1, -1,  1, -1,  1, -1, 1,
             1,  1,  1,  0,  0,  0,  0, 0,
             0,  0,  0,  0,  0,  0,  1, 1,
            -1, -1,  1,  1, -1,  1, -1, 1,
             1,  1,  1,  1,  1, -1, -1, 1,
             1, -1,  1, -1,  1,  1,  1, 1
     );

    type fsm_t is (IDLE, INITIAL_ESTIMATE, UPDATE_ESTIMATE) ;

    type state_t is record
        rfsm, wfsm      :   fsm_t ;
        eq              : equalizer_coefficients_t( 63 downto 0 ) ;
        update_index       :   unsigned( 5 downto 0 ) ;
        rupdate_index       :   unsigned( 5 downto 0 ) ;
        eq_chan, eq_ref : wlan_sample_t ;
        eq_first, eq_last : std_logic;

        rcupdate_index           :   unsigned( 5 downto 0 ) ;
        rcupdate_cur_eq_sample   :   wlan_sample_t ;
        rcupdate_new_eq_sample   :   wlan_sample_t ;
        rcupdate_result          :   wlan_sample_t ;
        rcupdate_result_index    :   unsigned( 5 downto 0 ) ;
    end record ;

    function NULL_STATE return state_t is
        variable rv : state_t ;
    begin
        for x in rv.eq'range loop
            rv.eq(x) := (others => (others => '0') ) ;
        end loop ;
        rv.eq_chan := NULL_SAMPLE ;
        rv.eq_ref  := NULL_SAMPLE ;
        rv.eq_first := '0' ;
        rv.eq_last := '0' ;
        rv.update_index := ( others => '0' ) ;
        rv.rfsm := IDLE ;
        rv.wfsm := IDLE ;
        rv.rupdate_index := ( others => '0' ) ;
        rv.rcupdate_index := ( others => '0' ) ;
        rv.rcupdate_cur_eq_sample := NULL_SAMPLE ;
        rv.rcupdate_new_eq_sample := NULL_SAMPLE ;
        rv.rcupdate_result := NULL_SAMPLE ;
        rv.rcupdate_result_index := ( others => '0' ) ;
        return rv ;
    end function ;


    signal equalizer :   wlan_sample_t ;

    signal last_sample   :   wlan_sample_t ;
    signal last_sample_r :   wlan_sample_t ;
    signal last_sample_rr :   wlan_sample_t ;
    signal last_sample_rrr :   wlan_sample_t ;
    signal eq_sample   :   wlan_sample_t ;

    signal bin_index       :   unsigned( 5 downto 0 ) ;
    signal in_sample_r     :   wlan_sample_t ;
    signal result_sample   :   wlan_sample_t ;
    signal equalizer_coeff_sample  : equalizer_coefficient ;

    signal current, future  :   state_t := NULL_STATE ;
    signal eq_chan, eq_ref, eq_out, eq_invd: wlan_sample_t ;
    signal eq_first, eq_last, eq_inv_done : std_logic;
begin

    eq_ref <= current.eq_ref;
    eq_chan <= current.eq_chan;

    eq_first <= current.eq_first;
    eq_last <= current.eq_last;

    eq_out.i <= shift_right(eq_invd.i, 2);
    eq_out.q <= shift_right(eq_invd.q, 2);

    u_chan_inverter: entity work.wlan_channel_inverter
        port map (
            clock           =>  clock,
            reset           =>  reset,

            first           =>  eq_first,
            last            =>  eq_last,

            in_channel      =>  eq_chan,
            in_reference    =>  eq_ref,

            out_inverted    =>  eq_invd,
            done            =>  eq_inv_done
        ) ;


    out_sample <= eq_sample ;

    comb : process(all)
        variable idx, ridx : integer ;
    begin
        future <= current ;
        case current.wfsm is
            when IDLE =>
                future.wfsm <= INITIAL_ESTIMATE ;

            when INITIAL_ESTIMATE =>
                future.eq_first <= '0';
                future.eq_last <= '0';

                future.eq_chan.valid <= '0';
                future.eq_ref.valid <= '0';
                if( in_done = '1' ) then
                    future.wfsm <= UPDATE_ESTIMATE ;
                    future.update_index <= ( others => '0' ) ;
                end if ;
                if( in_sample.valid = '1' ) then
                    idx := to_integer( current.update_index ) ;
                    future.update_index <= current.update_index + 1 ;
                    future.eq_chan.i <= in_sample.i;
                    future.eq_chan.q <= in_sample.q;
                    future.eq_chan.valid <= in_sample.valid;

                    future.eq_ref.i <= to_signed(T2(idx) * 4096, 16);
                    future.eq_ref.q <= to_signed(0, 16);

                    if( idx = 0 ) then
                        future.eq_first <= '1' ;
                    else
                        future.eq_first <= '0' ;
                    end if ;
                    if( idx = 63 ) then
                        future.eq_last <= '1' ;
                    else
                        future.eq_last <= '0' ;
                    end if ;
                end if ;

            when UPDATE_ESTIMATE =>
                future.eq_first <= '0';
                future.eq_last <= '0';
                future.eq_chan.valid <= '0';
                future.eq_ref.valid <= '0';
                if( dfe_sample.valid = '0' ) then
                    future.update_index <= ( others => '0' ) ;
                end if ;
                if( dfe_sample.valid = '1' ) then
                    idx := to_integer( current.update_index ) ;
                    future.update_index <= current.update_index + 1 ;
                    future.eq_chan.i <= last_sample.i;
                    future.eq_chan.q <= last_sample.q;
                    future.eq_chan.valid <= last_sample.valid;

                    future.eq_ref.i <= dfe_sample.i;
                    future.eq_ref.q <= dfe_sample.q;
                    future.eq_ref.valid <= dfe_sample.valid;

                    if( idx = 0 ) then
                        future.eq_first <= '1' ;
                    else
                        future.eq_first <= '0' ;
                    end if ;
                    if( idx = 63 ) then
                        future.eq_last <= '1' ;
                    else
                        future.eq_last <= '0' ;
                    end if ;

                end if ;

                if( init = '1' ) then
                    future.wfsm <= IDLE ;
                end if;
        end case ;

        future.rcupdate_new_eq_sample.valid <= '0' ;
        case current.rfsm is
            when IDLE =>
                future.rfsm <= INITIAL_ESTIMATE ;

            when INITIAL_ESTIMATE =>
                if( eq_inv_done = '1' ) then
                    future.rfsm <= UPDATE_ESTIMATE ;
                end if ;
                if( eq_invd.valid = '1' ) then
                    ridx := to_integer( current.rupdate_index ) ;
                    future.rupdate_index <= current.rupdate_index + 1 ;

                    future.eq(ridx).i <= resize(shift_right(eq_invd.i, 0), 16 ) ;
                    future.eq(ridx).q <= resize(shift_right(eq_invd.q, 0), 16 ) ;
                end if;

            when UPDATE_ESTIMATE =>
                if( eq_invd.valid = '0' ) then
                    future.rupdate_index <= ( others => '0' ) ;
                end if ;

                if( eq_invd.valid = '1' ) then
                    ridx := to_integer( current.rupdate_index ) ;
                    future.rupdate_index <= current.rupdate_index + 1 ;

                    future.rcupdate_index <= to_unsigned(ridx, future.rcupdate_index'length);
                    future.rcupdate_cur_eq_sample.i <= current.eq(ridx).i ;
                    future.rcupdate_cur_eq_sample.q <= current.eq(ridx).q ;
                    future.rcupdate_new_eq_sample <= eq_invd ;
                    --future.eq(ridx).i <= current.eq(ridx).i / 2 + eq_invd.i / 2 ;
                    --future.eq(ridx).q <= current.eq(ridx).q / 2 + eq_invd.q / 2 ;
                    --future.eq(ridx).i <=  eq_invd.i / 2 ;
                    --future.eq(ridx).q <=  eq_invd.q / 2 ;
                end if ;

                if( init = '1' ) then
                    future.rfsm <= IDLE ;
                end if;
        end case ;

        if( current.rcupdate_new_eq_sample.valid = '1' ) then
            future.rcupdate_result_index <= current.rcupdate_index ;
            future.rcupdate_result.i <= current.rcupdate_cur_eq_sample.i / 2 + current.rcupdate_new_eq_sample.i / 2 ;
            future.rcupdate_result.q <= current.rcupdate_cur_eq_sample.q / 2 + current.rcupdate_new_eq_sample.q / 2 ;
            future.rcupdate_result.valid <= '1' ;
        else
            future.rcupdate_result.valid <= '0' ;
        end if ;

        if( current.rcupdate_result.valid = '1' ) then
            if( current.rcupdate_result_index /= 7 and current.rcupdate_result_index /= 21 and
                current.rcupdate_result_index /= 43 and current.rcupdate_result_index /= 57 ) then
                future.eq(to_integer(current.rcupdate_result_index)).i <= current.rcupdate_result.i ;
                future.eq(to_integer(current.rcupdate_result_index)).q <= current.rcupdate_result.q ;
            end if ;
        end if ;

    end process ;

    process( clock )
        variable idx : integer ;
    begin
        if( reset = '1' ) then
            current <= NULL_STATE ;
            in_sample_r <= NULL_SAMPLE ;
            result_sample <= NULL_SAMPLE ;
        elsif( rising_edge( clock ) ) then
            last_sample_r <= in_sample ;
            last_sample_rr <= last_sample_r ;
            last_sample_rrr <= last_sample_rr ;
            last_sample <= last_sample_rrr ;
            in_sample_r.valid <= '0' ;

            if( init = '1' ) then
                current <= NULL_STATE ;
                bin_index <= ( others => '0' ) ;
            else
                current <= future ;
            end if ;

            if( in_sample.valid = '1' ) then
                if( current.rfsm = UPDATE_ESTIMATE ) then
                    --eq_sample.valid <= in_sample.valid ;
                    in_sample_r <= in_sample ;
                    idx := to_integer( bin_index ) ;
                    bin_index <= bin_index + 1 ;
                    equalizer_coeff_sample <= current.eq(idx);
                    --eq_sample.i <= resize(shift_right(in_sample.i * current.eq(idx).i - in_sample.q * current.eq(idx).q, 12), 16 ) ;
                    --eq_sample.q <= resize(shift_right(in_sample.i * current.eq(idx).q + in_sample.q * current.eq(idx).i, 12), 16 ) ;
                    --eq_sample.i <= in_sample.i;--resize(shift_right(in_sample.i * current.eq(idx).i - in_sample.q * current.eq(idx).q, 12), 16 ) ;
                    --eq_sample.q <= in_sample.q;--resize(shift_right(in_sample.i * current.eq(idx).q + in_sample.q * current.eq(idx).i, 12), 16 ) ;
                end if ;
            end if ;

            if( in_sample_r.valid = '1' ) then
                result_sample.i <= resize(shift_right(in_sample_r.i * equalizer_coeff_sample.i - in_sample_r.q * equalizer_coeff_sample.q, 12), 16 ) ;
                result_sample.q <= resize(shift_right(in_sample_r.i * equalizer_coeff_sample.q + in_sample_r.q * equalizer_coeff_sample.i, 12), 16 ) ;
                result_sample.valid <= '1' ;
            else
                result_sample.valid <= '0' ;
            end if ;

            eq_sample <= result_sample ;
        end if ;
    end process ;

end architecture ;
