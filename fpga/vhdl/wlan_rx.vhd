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
    use wlan.nco_p.all ;
    use wlan.wlan_p.all ;
    use wlan.wlan_rx_p.all ;

library altera_mf ;
    use altera_mf.altera_mf_components.all ;

library wlan_pll ;

entity wlan_rx is
  port (
    -- 40MHz clock and async asserted, sync deasserted reset
    clock40m        :   in  std_logic ;
    reset40m        :   in  std_logic ;

    -- Baseband input signals
    bb_i            :   in  signed(15 downto 0) ;
    bb_q            :   in  signed(15 downto 0) ;
    bb_valid        :   in  std_logic ;

    equalized_i     :   out signed(15 downto 0) ;
    equalized_q     :   out signed(15 downto 0) ;
    equalized_valid :   out std_logic ;

    -- AGC control signal
    gain_inc_req    :   out std_logic ;
    gain_dec_req    :   out std_logic ;
    gain_rst_req    :   out std_logic ;
    gain_ack        :   in  std_logic ;
    gain_nack       :   in  std_logic ;
    gain_lock       :   in  std_logic ;
    gain_max        :   in  std_logic ;

    -- ACK signals
    ack_mac         :  out std_logic_vector( 47 downto 0 ) ;
    ack_valid       :  out std_logic ;

    acked_packet    :  out std_logic ;

    rx_quiet        :  out std_logic ;
    rx_block        :   in std_logic ;

    -- RX status signals
    rx_end_of_packet:   out std_logic ;
    rx_status       :   out wlan_rx_status_t ;
    rx_status_valid :   out std_logic ;

    rx_vector       :   out wlan_rx_vector_t ;
    rx_vector_valid :   out std_logic ;

    rx_data_req     :    in std_logic ;
    rx_data         :   out std_logic_vector( 7 downto 0 ) ;
    rx_data_valid   :   out std_logic ;
    mse             :   out unsigned(15 downto 0) ;
    mse_valid       :   out std_logic
  ) ;
end entity ;

architecture arch of wlan_rx is
    signal rx_vector_rr            :   std_logic_vector( 3 downto 0 ) ;
    signal rx_vector_r             :   std_logic_vector( 3 downto 0 ) ;
    signal rx_end_of_packet_r      :   std_logic_vector( 3 downto 0 ) ;

    signal params                   :   wlan_rx_params_t ;
    signal params_valid             :   std_logic ;

    signal bb_sample                :   wlan_sample_t ;
    signal bb_sample40              :   wlan_sample_t ;
    signal sample                   :   wlan_sample_t ;
    signal fft_sample               :   wlan_sample_t ;
    signal dfe_sample               :   wlan_sample_t ;
    signal eq_sample                :   wlan_sample_t ;
    signal phase_corr_sample        :   wlan_sample_t ;
    signal cfo_atan_average         :   signed( 31 downto 0 ) ;
    signal cfo_est_sample           :   wlan_sample_t ;
    signal p_mag                    :   signed( 23 downto 0 ) ;

    signal acquired_packet          :   std_logic ;
    signal end_of_packet            :   std_logic ;
    signal acquired_sample          :   wlan_sample_t ;

    signal correction_dphase        :   signed( 15 downto 0 ) ;
    signal correction_dphase_valid  :   std_logic ;
    signal correction_p_mag         :   signed( 23 downto 0 ) ;
    signal correction_p_mag_valid   :   std_logic ;

    signal symbol_start             :   std_logic ;

    signal fft_done                 :   std_logic ;
    signal eq_done                  :   std_logic ;
    signal phase_corr_done          :   std_logic ;

    signal demod_modulation         :   wlan_modulation_t ;
    signal demod_data               :   std_logic_vector( 287 downto 0 ) ;
    signal demod_bsds               :   bsd_array_t(287 downto 0) ;
    signal demod_valid              :   std_logic ;

    signal deinter_modulation       :   wlan_modulation_t ;
    signal deinter_data             :   std_logic_vector( 287 downto 0 ) ;
    signal deinter_bsds             :   bsd_array_t(287 downto 0) ;
    signal deinter_valid            :   std_logic ;

    signal depunct_done             :   std_logic ;

    signal depunct_empty            :   std_logic ;
    signal depunct_soft_a           :   signed( 7 downto 0 ) ;
    signal depunct_soft_b           :   signed( 7 downto 0 ) ;
    signal depunct_erasure          :   std_logic_vector( 1 downto 0 ) ;
    signal depunct_valid            :   std_logic ;

    signal num_decoded_bits         :   unsigned( 13 downto 0 ) ;
    signal num_decoded_bits_valid   :   std_logic ;
    signal decoder_done             :   std_logic ;

    signal rx_packet_init           :   std_logic ;

    signal decoded_bit              :   std_logic;
    signal decoded_valid            :   std_logic;

    signal descrambled_data         :   std_logic_vector( 7 downto 0 ) ;
    signal descrambled_valid        :   std_logic ;

    signal descrambler_bypass       :   std_logic ;
    signal signal_dec               :   std_logic ;

    signal rx_framer_done           :   std_logic ;
    -- Block Diagram of the modem
    --   acquisition -> cfo est/removal -> equalizer -> demod -> depuncture -> fec -> framer
    --                                         ^-----------------------------------------'
    --
    -- The equalizer can't move onward until there is the feedback from
    -- the framer to understand the SIGNAL field, so FFT frames are buffered
    -- until the actual payload size and length is known and at least seems
    -- plausible.

    signal clock                    :   std_logic ;
    signal bb_valid_80m             :   std_logic ;
    signal bb_valid_r               :   std_logic ;

    signal rst_gains                :   std_logic ;
    signal burst                    :   std_logic ;

    signal framer_quiet_reset       :   std_logic ;

    signal rx_data_rdempty          :   std_logic ;

    signal crc_correct              :   std_logic ;

    signal ack_valid_r              :   std_logic ;
    signal ack_valid_rr80           :   std_logic_vector( 3 downto 0 ) ;
    signal ack_valid_rr             :   std_logic_vector( 3 downto 0 ) ;

    signal acked_packet_r           :   std_logic ;
    signal acked_packet_rr80        :   std_logic_vector( 3 downto 0 ) ;
    signal acked_packet_rr          :   std_logic_vector( 3 downto 0 ) ;

    signal buf_params               :   wlan_rx_params_t ;
    signal buf_params_valid         :   std_logic ;

    signal buf_data                 :   std_logic_vector( 7 downto 0 ) ;
    signal buf_data_valid           :   std_logic ;

    signal buf_end_of_packet        :   std_logic ;

    signal dsss_params              :   wlan_rx_params_t ;
    signal dsss_params_valid        :   std_logic ;

    signal dsss_data                :   std_logic_vector( 7 downto 0 ) ;
    signal dsss_data_valid          :   std_logic ;

    signal dsss_framer_done         :   std_logic ;
    signal dsss_crc_correct         :   std_logic ;

    signal dsss_params_80m          :   wlan_rx_params_t ;
    signal dsss_params_valid_80m    :   std_logic ;

    signal dsss_data_80m            :   std_logic_vector( 7 downto 0 ) ;
    signal dsss_data_valid_80m      :   std_logic ;

    signal dsss_framer_done_80m     :   std_logic ;
    signal dsss_crc_correct_80m     :   std_logic ;

    component wlan_pll
       port (
          refclk   : in  std_logic;
          rst      : in  std_logic;
          outclk_0 : out std_logic;
          locked   : out std_logic
       );
    end component;

    signal r_bb_i            :   signed(15 downto 0) ;
    signal r_bb_q            :   signed(15 downto 0) ;
    signal r_bb_valid        :   std_logic ;

    signal wfull             :   std_logic ;
    signal rempty            :   std_logic ;
    signal fvalid            :   std_logic ;
    signal fdata             :   std_logic_vector(31 downto 0) ;
    signal f_bb_i            :   signed(15 downto 0) ;
    signal f_bb_q            :   signed(15 downto 0) ;
    signal rst_rr            :   std_logic_vector(2 downto 0);
    signal reset             :   std_logic ;
    signal fifo_rst          :   std_logic ;
begin
    rx_quiet <= not burst ;
    equalized_i <= phase_corr_sample.i( 15 downto 0 ) ;
    equalized_q <= phase_corr_sample.q( 15 downto 0 ) ;
    equalized_valid <= phase_corr_sample.valid;

    process(all)
    begin
        if( rising_edge( clock ) ) then
            rst_rr <= reset40m & rst_rr(rst_rr'high downto 1);
        end if;
    end process;
    reset <= rst_rr(0);

    U_rx_data_dc_fifo: dcfifo
      generic map (
        lpm_width       =>  32,
        lpm_widthu      =>  5,
        lpm_numwords    =>  32,
        lpm_showahead   =>  "ON"
      )
      port map (
        aclr            => reset,

        wrclk           => clock40m,
        wrreq           => bb_valid and not wfull,
        data            => std_logic_vector(bb_i) & std_logic_vector(bb_q),

        wrfull          => wfull,
        wrempty         => open,
        wrusedw         => open,

        rdclk           => clock,
        rdreq           => fvalid,
        q               => fdata,

        rdfull          => open,
        rdempty         => rempty,
        rdusedw         => open
      ) ;
    fvalid <= not rempty;
    f_bb_i <= signed(fdata(31 downto 16));
    f_bb_q <= signed(fdata(15 downto 0));



    process(clock40m, reset)
    begin
        if( reset = '1' ) then
          r_bb_i <= ( others => '0' ) ;
          r_bb_q <= ( others => '0' ) ;
          r_bb_valid <= '0';
       elsif( rising_edge( clock40m ) ) then
          r_bb_i <= bb_i ;
          r_bb_q <= bb_q ;
          r_bb_valid <=  bb_valid ;
       end if;
    end process;

    process(clock, reset)
    begin
        if( reset = '1' ) then
            bb_valid_r <= '0' ;
            bb_valid_80m <= '0' ;
        elsif( rising_edge( clock ) ) then
            bb_valid_r <= r_bb_valid ;
            if( r_bb_valid = '1' and bb_valid_r = '0' ) then
                bb_valid_80m <= '1' ;
            else
                bb_valid_80m <= '0' ;
            end if ;
        end if ;
    end process ;

    U_80mhz_clock: component wlan_pll
      port map (
        refclk      =>  clock40m,
        rst         =>  '0',
        outclk_0    =>  clock,
        locked      =>  open
      );

    -- Input sample assignment
    bb_sample.i     <= f_bb_i;
    bb_sample.q     <= f_bb_q;
    bb_sample.valid <= fvalid;

    bb_sample40.i     <= r_bb_i;
    bb_sample40.q     <= r_bb_q;
    bb_sample40.valid <= r_bb_valid;

    U_agc : entity work.wlan_agc
      port map (
        clock   => clock40m,
        reset   => reset40m,

        agc_hold_req => '0',

        gain_inc_req => gain_inc_req,
        gain_dec_req => gain_dec_req,
        gain_rst_req => gain_rst_req,
        gain_ack     => gain_ack,
        gain_nack    => gain_nack,
        gain_max     => gain_max,

        rst_gains    => rst_gains,
        burst        => burst,

        sample_i     => bb_i,
        sample_q     => bb_q,
        sample_valid => bb_valid
      ) ;

    U_csma : entity wlan.wlan_csma
      port map (
        clock           =>  clock,
        reset           =>  reset,

        in_sample       =>  acquired_sample,

        quiet           =>  open
      ) ;

    U_dsss : entity wlan.wlan_dsss_rx
      port map (
        clock           =>  clock40m,
        reset           =>  reset40m,

        sample          =>  bb_sample40,

        params          =>  dsss_params,
        params_valid    =>  dsss_params_valid,

        data            =>  dsss_data,
        data_valid      =>  dsss_data_valid,

        framer_done     =>  dsss_framer_done,
        crc_correct     =>  dsss_crc_correct
      ) ;

    U_dsss_sync_params : entity wlan.clock_sync_params
      port map (
        from_signal  =>  dsss_params,

        to_clock     =>  clock,
        to_reset     =>  reset,

        to_signal    =>  dsss_params_80m
      ) ;

    U_dsss_sync_params_valid : entity wlan.clock_sync_logic
      port map (
        from_signal  =>  dsss_params_valid,

        to_clock     =>  clock,
        to_reset     =>  reset,

        to_signal    =>  dsss_params_valid_80m
      ) ;

    U_dsss_sync_data : entity wlan.clock_sync_logic_vector
      port map (
        from_signal  =>  dsss_data,

        to_clock     =>  clock,
        to_reset     =>  reset,

        to_signal    =>  dsss_data_80m
      ) ;

    U_dsss_sync_data_valid : entity wlan.clock_sync_logic
      port map (
        from_signal  =>  dsss_data_valid,

        to_clock     =>  clock,
        to_reset     =>  reset,

        to_signal    =>  dsss_data_valid_80m
      ) ;

    U_dsss_sync_framer_done : entity wlan.clock_sync_logic
      port map (
        from_signal  =>  dsss_framer_done,

        to_clock     =>  clock,
        to_reset     =>  reset,

        to_signal    =>  dsss_framer_done_80m
      ) ;

    U_dsss_sync_crc_correct : entity wlan.clock_sync_logic
      port map (
        from_signal  =>  dsss_crc_correct,

        to_clock     =>  clock,
        to_reset     =>  reset,

        to_signal    =>  dsss_crc_correct_80m
      ) ;

    U_acquisition : entity wlan.wlan_acquisition
      port map (
        clock       =>  clock40m,
        reset       =>  reset40m,

        acquired    =>  acquired_packet,
        p_mag       =>  p_mag,

        in_sample   =>  bb_sample40,
        quiet       =>  not burst or gain_lock,
        burst       =>  burst,

        out_sample  =>  acquired_sample
      );

    U_cfo : entity wlan.wlan_cfo_estimate
      port map (
        clock           =>  clock40m,
        reset           =>  reset40m,

        in_sample       =>  acquired_sample,

        out_sample      =>  cfo_est_sample,
        atan_average    =>  cfo_atan_average
      ) ;

    U_cfo_correction : entity wlan.wlan_cfo_correction
      port map (
        clock           =>  clock,
        reset           =>  reset,

        dphase          =>  correction_dphase,
        dphase_valid    =>  '0',

        p_mag           =>  correction_p_mag,
        p_mag_valid     =>  correction_p_mag_valid,

        in_sample       =>  bb_sample,
        out_sample      =>  sample
      ) ;

    U_rx_controller : entity wlan.wlan_rx_controller
      port map (
        clock           => clock,
        reset           => reset,

       framer_quiet_reset  => framer_quiet_reset,
       params           => params,
       params_valid     => params_valid,
       rx_packet_init   => rx_packet_init,

       rx_quiet         => not burst,
       rx_framer_done   => rx_framer_done,
       sample_valid     => sample.valid,
       end_of_packet    => end_of_packet,

       -- acquistion
       acquired         => acquired_packet and not rx_block,
       p_mag            => p_mag,

       -- CFO estimation
       atan_average     => resize( cfo_atan_average, 16 ),

       -- CFO correction
       c_dphase         => correction_dphase,
       c_dphase_valid   => correction_dphase_valid,
       c_p_mag          => correction_p_mag,
       c_p_mag_valid    => correction_p_mag_valid,

       -- FFT
       symbol_start     => symbol_start
      ) ;

    U_fft: entity wlan.wlan_fft64
      port map (
        clock           => clock,
        reset           => reset,

        init            => rx_packet_init,
        signal_dec      => signal_dec,

        dphase          => correction_dphase,

        symbol_start    => symbol_start,

        in_sample       => sample,
        out_sample      => fft_sample,
        done            => fft_done
        ) ;

    -- Insert buffer here?
    -- Equalizer need to know what modulation it's equalizin
    U_eq: entity wlan.wlan_equalizer
      port map (
        clock       => clock,
        reset       => reset,

        init        => rx_packet_init,

        dfe_sample  => dfe_sample,

        in_sample   => fft_sample,
        in_done     => fft_done,
        out_sample  => eq_sample,
        out_done    => eq_done
      ) ;

    U_phase_correct: entity wlan.wlan_phase_correction
      port map (
        clock       => clock,
        reset       => reset,

        init        => rx_packet_init,

        in_sample   => eq_sample,
        in_done     => eq_done,

        out_sample  => phase_corr_sample,
        out_done    => phase_corr_done
      ) ;

    U_demod: entity wlan.wlan_demodulator
      port map (
        clock           => clock,
        reset           => reset,

        init            => rx_packet_init,

        params          => params,
        params_valid    => params_valid,

        in_sample       => phase_corr_sample,
        in_done         => phase_corr_done,

        dfe_sample      => dfe_sample,

        out_mod         => demod_modulation,
        -- FIXME: Change to output BSDs
        out_data        => demod_bsds,
        out_valid       => demod_valid
      ) ;

    U_deinterleaver: entity wlan.wlan_deinterleaver
      port map (
        clock               => clock,
        reset               => reset,

        modulation          => demod_modulation,
        data                => demod_bsds,
        in_valid            => demod_valid,

        depuncturer_empty   => depunct_empty,

        deinterleaved_mod   => deinter_modulation,
        deinterleaved       => deinter_bsds,
        deinterleaved_valid => deinter_valid
      ) ;

    U_depunct : entity wlan.wlan_depuncturer
      port map (
        clock           => clock,
        reset           => reset,

        init            => rx_packet_init,

        modulation      => deinter_modulation,
        data            => deinter_bsds,
        in_valid        => deinter_valid,

        params          => params,
        params_valid    => params_valid,

        end_zero_pad    => decoder_done,
        empty           => depunct_empty,

        out_soft_a      => depunct_soft_a,
        out_soft_b      => depunct_soft_b,
        out_erasure     => depunct_erasure,
        out_valid       => depunct_valid
      ) ;

    U_decoder : entity wlan.wlan_viterbi_decoder
      port map (
        clock           => clock,
        reset           => reset,

        init            => rx_packet_init,

        in_soft_a       => depunct_soft_a,
        in_soft_b       => depunct_soft_b,
        in_erasure      => depunct_erasure,
        in_valid        => depunct_valid,

        params          => params,
        params_valid    => params_valid,

        done            => decoder_done,

        out_dec_bit     => decoded_bit,
        out_dec_valid   => decoded_valid
      ) ;

    U_descrambler : entity wlan.wlan_descrambler
      port map (
        clock           => clock,
        reset           => reset,

        init            => rx_packet_init,

        params          => params,
        params_valid    => params_valid,

        bypass          => descrambler_bypass,

        in_data         => decoded_bit,
        in_valid        => decoded_valid,

        out_data        => descrambled_data,
        out_valid       => descrambled_valid,
        out_done        => open
      ) ;

    fifo_rst <= '1' when (rx_vector_r = "0000" and buf_params_valid = '1') else '0';
    U_rx_sample_fifo: dcfifo
      generic map (
        lpm_width       =>  8,
        lpm_widthu      =>  11,
        lpm_numwords    =>  1600,
        lpm_showahead   =>  "ON"
      )
      port map (
        aclr            => reset or fifo_rst,

        wrclk           => clock,
        wrreq           => buf_data_valid,
        data            => buf_data,

        wrfull          => open,
        wrempty         => open,
        wrusedw         => open,

        rdclk           => clock40m,
        rdreq           => (not rx_data_rdempty) and rx_data_req,
        q               => rx_data,

        rdfull          => open,
        rdempty         => rx_data_rdempty,
        rdusedw         => open
      ) ;
    rx_data_valid <= (not rx_data_rdempty) and rx_data_req ;

    rx_vector.length <= buf_params.length;
    rx_vector.datarate <= buf_params.datarate;
    rx_vector.bandwidth <= buf_params.bandwidth;
    rx_vector_valid <= rx_vector_rr(0) ;
    rx_end_of_packet <= rx_data_rdempty ;

    process(all)
    begin
        if( reset = '1' ) then
            rx_vector_r <= ( others => '0' ) ;
            rx_end_of_packet_r <= ( others => '0' ) ;
        elsif( rising_edge( clock ) ) then
            if( buf_params_valid = '1' ) then
                rx_vector_r <= ( others => '1' ) ;
            else
                rx_vector_r <= '0' & rx_vector_r(3 downto 1) ;
            end if ;

            if( buf_end_of_packet = '1' ) then
                rx_end_of_packet_r <= ( others => '1' ) ;
            else
                rx_end_of_packet_r <= '0' & rx_end_of_packet_r(3 downto 1) ;
            end if ;
        end if ;
    end process ;

    process(all)
    begin
        if( reset = '1' ) then
            rx_vector_rr <= ( others => '0' ) ;
            acked_packet_rr <= ( others => '0' ) ;
        elsif( rising_edge( clock40m ) ) then
            rx_vector_rr <= rx_vector_r(0) & rx_vector_rr(3 downto 1) ;

            ack_valid_rr <= ack_valid_rr80(0) & ack_valid_rr(3 downto 1) ;
            if( ack_valid_rr(1 downto 0) = "10" ) then
                ack_valid <= '1' ;
            else
                ack_valid <= '0' ;
            end if ;

            acked_packet_rr <= acked_packet_rr80(0) & acked_packet_rr(3 downto 1) ;
            if( acked_packet_rr(1 downto 0) = "10" ) then
                acked_packet <= '1' ;
            else
                acked_packet <= '0' ;
            end if ;
        end if ;
    end process ;

    process(all)
    begin
        if( reset = '1' ) then
            ack_valid_rr80 <= ( others => '0' ) ;
            acked_packet_rr80 <= (others => '0' ) ;
        elsif( rising_edge( clock ) ) then
            if( ack_valid_r = '1' ) then
                ack_valid_rr80 <= ( others => '1' ) ;
            else
                ack_valid_rr80 <= '0' & ack_valid_rr80( 3 downto 1 ) ;
            end if ;
            if( acked_packet_r = '1' ) then
                acked_packet_rr80 <= ( others => '1' ) ;
            else
                acked_packet_rr80 <= '0' & acked_packet_rr80( 3 downto 1 ) ;
            end if ;
        end if ;
    end process ;



    U_framer : entity wlan.wlan_rx_framer
      port map (
        clock               => clock,
        reset               => reset,

        framer_quiet_reset  => framer_quiet_reset,
        init                => rx_packet_init,

        bss_mac             => x"70B3D57D8001",

        ack_mac             => ack_mac,
        ack_valid           => ack_valid_r,

        acked_packet        => acked_packet_r,

        params              => params,
        params_valid        => params_valid,

        in_data             => descrambled_data,
        in_valid            => descrambled_valid,

        signal_dec          => signal_dec,

        descrambler_bypass  => descrambler_bypass,

        crc_correct         => crc_correct,

        depunct_done        => depunct_done,

        decoder_done        => decoder_done,

        framer_done         => rx_framer_done
      ) ;

    U_rx_packet_buffer : entity wlan.wlan_rx_packet_buffer
      port map (
        clock               => clock,
        reset               => reset,

        framer_quiet_reset  => framer_quiet_reset,
        framer_done         => rx_framer_done,
        crc_correct         => crc_correct,

        in_params           => params,
        in_params_valid     => params_valid and signal_dec,

        in_data             => descrambled_data,
        in_data_valid       => descrambled_valid and signal_dec,

        dsss_params         => dsss_params_80m,
        dsss_params_valid   => dsss_params_valid_80m,

        dsss_data           => dsss_data_80m,
        dsss_data_valid     => dsss_data_valid_80m,

        dsss_framer_done    => dsss_framer_done_80m,
        dsss_crc_correct    => dsss_crc_correct_80m,

        out_params          => buf_params,
        out_params_valid    => buf_params_valid,

        out_data            => buf_data,
        out_data_valid      => buf_data_valid,

        out_end_of_packet   => buf_end_of_packet
      ) ;

end architecture ;

