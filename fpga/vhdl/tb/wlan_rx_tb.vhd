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

library wlan ;
    use wlan.wlan_p.all ;
    use work.nco_p.all ;
    use wlan.wlan_rx_p.all ;

library wlan;
entity wlan_rx_tb is
end entity ;

architecture arch of wlan_rx_tb is

    signal clock    :   std_logic    := '1' ;
    signal reset    :   std_logic    := '1' ;

    signal sample   :   wlan_sample_t ;
    signal sample_r :   wlan_sample_t ;
    signal eq       :   wlan_sample_t ;
    signal fopen    :   std_logic;

    signal i_sum    :   signed(63 downto 0);
    signal q_sum    :   signed(63 downto 0);
    signal sum      :   signed(127 downto 0);

    type SAMPLE_ARRAY is array (integer range <>) of wlan_sample_t;
    signal samples : SAMPLE_ARRAY(0 to 159);

    signal gain_inc_req       :   std_logic ;
    signal gain_dec_req       :   std_logic ;
    signal gain_rst_req       :   std_logic ;
    signal gain_ack           :   std_logic ;
    signal gain_nack          :   std_logic ;
    signal gain_lock          :   std_logic := '0' ;
    signal gain_max           :   std_logic ;

    signal nco_inputs   :   nco_input_t ;
    signal nco_outputs  :   nco_output_t ;
    signal nco_en       :   std_logic ;

begin

    sample_r.valid <= sample.valid;
    sample_r.i <= resize(shift_right(sample.i * nco_outputs.re - sample.q * nco_outputs.im, 11), 16);
    sample_r.q <= resize(shift_right(sample.i * nco_outputs.im + sample.q * nco_outputs.re, 11), 16);

    nco_inputs <= ( dphase => to_signed(-15, 16), valid => sample.valid) ;

    U_nco : entity work.nco
      port map (
        clock   => clock,
        reset   => reset,
        inputs  => nco_inputs,
        outputs => nco_outputs
      ) ;


    clock <= not clock after 12.5 ns;
    reset <= '1', '0' after 100 ns ;
    fopen <= '0', '1' after 100 ns;

    U_sample_loader: entity wlan.wlan_sample_loader
      port map (
        clock   => clock,
        fopen   => fopen,
        sample  => sample
      );

    gain_ack <= '0' ;
    gain_max <= '1' ;
    gain_nack <= '1' ;
--    U_agc : entity wlan.wlan_agc_drv
--      port map (
--        clock   => clock,
--        reset   => reset,
--
--        enable  => '1',
--        gain_inc_req => gain_inc_req,
--        gain_dec_req => gain_dec_req,
--        gain_rst_req => gain_rst_req,
--        gain_ack     => gain_ack,
--        gain_nack    => gain_nack,
--
--        gain_high    => gain_max,
--        gain_mid     => open,
--        gain_low     => open,
--
--        sclk         => open,
--        miso         => '0',
--        mosi         => open,
--        cs_n         => open
--      ) ;


    U_rx : entity wlan.wlan_rx
      port map (
        clock40m        => clock,
        reset40m        => reset,
        bb_i            => sample.i,
        bb_q            => sample.q,
        bb_valid        => sample.valid,

        equalized_i     =>  eq.i,
        equalized_q     =>  eq.q,
        equalized_valid =>  eq.valid,

        gain_inc_req        => gain_inc_req,
        gain_dec_req        => gain_dec_req,
        gain_rst_req        => gain_rst_req,
        gain_ack            => gain_ack,
        gain_nack           => gain_nack,
        gain_lock           => gain_lock,
        gain_max            => gain_max,

        rx_block   => '0',
        rx_data_req => '1',
        rx_data       => open,
        rx_data_valid => open,

        rx_end_of_packet=> open,
        rx_status       => open,
        rx_status_valid => open,

        rx_vector       => open,
        rx_vector_valid => open,

        mse             => open,
        mse_valid       => open
      );

    process(clock)
        variable tsum : signed(127 downto 0);
        variable isum : signed(63 downto 0);
        variable qsum : signed(63 downto 0);
    begin
        if( rising_edge( clock ) ) then
            if( sample.valid = '1' ) then
                for i in 0 to samples'high - 1 loop
                    samples(i+1) <= samples(i);
                end loop ;
                samples(0) <= sample;

                isum := (others => '0');
                qsum := (others => '0');
                for i in 0 to 79 loop
                    isum := isum + samples(i).i * samples(i + 80).i + samples(i).q * samples(i + 80).q;
                    qsum := qsum - samples(i).i * samples(i + 80).q + samples(i).q * samples(i + 80).i;
                end loop ;
                i_sum <= isum;
                q_sum <= qsum;
                tsum := isum * isum + qsum * qsum;
                sum <= tsum;
            end if;
        end if ;
    end process ;

    U_sample_saver : entity work.wlan_sample_saver
      generic map (
        FILENAME    =>  "eq"
      ) port map (
        clock       =>  clock,
        fopen       =>  '1',
        sample      =>  eq,
        done        =>  '0'
      ) ;
end architecture ;

