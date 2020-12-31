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

entity wlan_acquisition is
  port (
    clock           :   in  std_logic ;
    reset           :   in  std_logic ;

    in_sample       :   in  wlan_sample_t ;
    quiet           :   in  std_logic ;
    burst           :   in  std_logic ;

    acquired        :   out std_logic ;
    p_mag           :   buffer signed( 23 downto 0 ) ;

    out_sample      :   out wlan_sample_t
  ) ;
end entity;

architecture arch of wlan_acquisition is

    type sample_history_t is array (natural range 31 downto 0 ) of wlan_sample_t ;
    signal sample_history : sample_history_t ;
    signal sample_counter : unsigned( 9 downto 0 );

    signal power_accum : unsigned( 31 downto 0 ) ;
    signal ptemp : unsigned( 31 downto 0 ) ;
    signal itemp : signed( 31 downto 0 ) ;
    signal qtemp : signed( 31 downto 0 ) ;
    signal i_accum : signed( 31 downto 0 ) ;
    signal q_accum : signed( 31 downto 0 ) ;
    signal accum_valid : std_logic ;

    signal i_sum : signed( 31 downto 0 ) ;
    signal q_sum : signed( 31 downto 0 ) ;

    signal div_i_power : signed( 31 downto 0 ) ;
    signal div_q_power : signed( 31 downto 0 ) ;
    signal div_power_valid : std_logic ;

    signal div_i_power_r : signed( 31 downto 0 ) ;
    signal div_q_power_r : signed( 31 downto 0 ) ;
    signal div_power_valid_r : std_logic ;

    signal div_i_squared : unsigned( 31 downto 0 ) ;
    signal div_q_squared : unsigned( 31 downto 0 ) ;
    signal div_squared_valid : std_logic ;

    signal div : unsigned( 31 downto 0 ) ;
    signal burst_counter : unsigned( 31 downto 0 ) ;
    signal div_valid : std_logic ;

    signal p_valid : std_logic ;
    signal iq_valid : std_logic ;

    signal max : unsigned( 31 downto 0 ) ;
    signal max_counter : unsigned( 7 downto 0 ) ;
    signal min : unsigned( 31 downto 0 ) ;
    signal min_found : std_logic ;
    signal peak_found : std_logic ;

    signal p_sample : wlan_sample_t ;

    signal peak_match : std_logic ;
    signal first_peak : std_logic ;
begin
    process( clock )
    begin
        if( reset = '1' ) then
            burst_counter <= ( others => '0' );
        elsif( rising_edge( clock ) ) then
            if( in_sample.valid = '1' ) then
                if( burst = '1' ) then
                    burst_counter <= burst_counter + 1 ;
                else
                    burst_counter <= ( others => '0' ) ;
                end if;
            end if;
        end if ;
    end process ;

    process( clock )
    begin
        if( reset = '1' ) then
            sample_counter <= ( others => '0' ) ;
            power_accum <= ( others => '0' ) ;
            i_accum <= ( others => '0' ) ;
            q_accum <= ( others => '0' ) ;
        elsif( rising_edge( clock ) ) then
            accum_valid <= '0' ;
            if( burst = '0' or quiet = '1' ) then
                sample_counter <= ( others => '0' ) ;
                power_accum <= ( others => '0' ) ;
                i_accum <= ( others => '0' ) ;
                q_accum <= ( others => '0' ) ;
                iq_valid <= '0';
                p_valid <= '0';
            elsif( in_sample.valid = '1' and sample_counter < 650 ) then
                sample_counter <= sample_counter + 1 ;

                for i in 0 to sample_history'high - 1 loop
                    sample_history( i + 1 ) <= sample_history( i ) ;
                end loop ;
                sample_history(0).i <= in_sample.i ;
                sample_history(0).q <= - in_sample.q ;

                ptemp <= unsigned((resize(in_sample.i * in_sample.i + in_sample.q * in_sample.q, 32))) ;
                p_valid <= '1';
                if( p_valid = '1') then
                    power_accum <= power_accum + ptemp ;-- unsigned((resize(in_sample.i * in_sample.i + in_sample.q * in_sample.q, 32))) ;
                end if;


                if( sample_counter > 30 ) then
                    i_sum <= resize(sample_history(14).i + sample_history(30).i, 32);
                    q_sum <= resize(sample_history(14).q + sample_history(30).q, 32);
                end if ;

                if( sample_counter > 31 ) then
                    iq_valid <= '1';
                    itemp <= signed(resize(shift_right(i_sum * in_sample.i - q_sum * in_sample.q, 6), 32));
                    qtemp <= signed(resize(shift_right(i_sum * in_sample.q + q_sum * in_sample.i, 6), 32));
                    if( iq_valid = '1' ) then
                        i_accum <= i_accum + itemp;
                        q_accum <= q_accum + qtemp;
                        accum_valid <= '1' ;
                    end if;
                end if ;
            end if ;
        end if ;
    end process ;

    process( clock )
    begin
        if( reset = '1' ) then
            div_power_valid_r <= '0' ;
            div_i_power_r <= ( others => '0' ) ;
            div_q_power_r <= ( others => '0' ) ;
        elsif( rising_edge( clock ) ) then
            div_power_valid_r <= div_power_valid ;
            div_i_power_r <= div_i_power ;
            div_q_power_r <= div_q_power ;
        end if ;
    end process ;

    process( clock )
    begin
        if( reset = '1' ) then
            max <= ( others => '0' ) ;
            max_counter <= ( others => '0' ) ;
            peak_found <= '0' ;
        elsif( rising_edge( clock ) ) then
            div_squared_valid <= '0' ;
            div_valid <= '0' ;
            if( quiet = '1' ) then
                max <= ( others => '0' ) ;
                max_counter <= ( others => '0' ) ;
                peak_found <= '0' ;
            else
                if( div_power_valid_r = '1' ) then
                    div_i_squared <= unsigned(resize(div_i_power_r * div_i_power_r, 32)) ;
                    div_q_squared <= unsigned(resize(div_q_power_r * div_q_power_r, 32)) ;
                    div_squared_valid <= '1' ;
                end if ;

                if( div_squared_valid = '1' ) then
                    div <= unsigned(resize(div_i_squared + div_q_squared, 32)) ;
                    div_valid <= '1';
                end if ;

                if( div_valid = '1' ) then
                    if( div > max ) then
                        max <= div ;
                        max_counter <= to_unsigned(31, max_counter'length) ;
                    else
                        if( max_counter = 0 ) then
                            peak_found <= '1' ;
                            min <= div ;
                        else
                            max_counter <= max_counter - 1 ;
                        end if ;
                    end if ;
                end if ;
            end if ;
        end if ;
    end process ;


    U_power_div : entity work.wlan_divide
        generic map (
            SAMPLE_WIDTH => 32,
            DENOM_WIDTH => 32,
            NUM_PIPELINE => 32
        ) port map (
            clock => clock,
            reset => reset,

            in_i => resize(shift_left(i_accum, 8), 32),
            in_q => resize(shift_left(q_accum, 8), 32),
            in_denom => resize(shift_right(power_accum, 12), 32),

            in_valid => accum_valid,
            in_done => '0',

            out_i => div_i_power,
            out_q => div_q_power,
            out_valid => div_power_valid,
            out_done => open
        ) ;

    process(all)
    begin
        if( burst_counter > 192 and burst_counter < 254 ) then
            acquired <= peak_found ; --and peak_match and first_peak;
        else
            acquired <= '0';
        end if;
    end process ;

    U_p_norm : entity wlan.wlan_p_norm
        port map (
            clock         => clock,
            reset         => reset,
            quiet         => quiet,

            sample        => in_sample,
            p_normed      => p_sample,

            p_mag         => p_mag
        );

    out_sample <= in_sample;
end architecture ;
