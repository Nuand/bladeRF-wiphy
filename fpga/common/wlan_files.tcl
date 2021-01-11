if { $modelsim == 1 } {
    if { [info exists wlan_path ] } {
        set here $wlan_path
    } else {
        set here ""
    }
} else {
    set here $::quartus(qip_path)
}

set wlan_common [list \
    [file normalize [ file join $here ../vhdl/wlan_p.vhd] ]             \
    [file normalize [ file join $here ../ip/nuand/fft/vhdl/dual_port_ram.vhd] ]    \
    [file normalize [ file join $here ../ip/nuand/fft/vhdl/fft.vhd] ]   \
    [file normalize [ file join $here ../ip/nuand/viterbi_decoder/vhdl/viterbi_p.vhd] ]        \
    [file normalize [ file join $here ../ip/nuand/viterbi_decoder/vhdl/branch_compare.vhd] ]   \
    [file normalize [ file join $here ../ip/nuand/viterbi_decoder/vhdl/comp2.vhd] ]            \
    [file normalize [ file join $here ../ip/nuand/viterbi_decoder/vhdl/r2_comparator.vhd] ]    \
    [file normalize [ file join $here ../ip/nuand/viterbi_decoder/vhdl/tracer.vhd] ]           \
    [file normalize [ file join $here ../ip/nuand/viterbi_decoder/vhdl/traceback.vhd] ]        \
    [file normalize [ file join $here ../ip/nuand/viterbi_decoder/vhdl/viterbi_decoder.vhd] ]  \
    [file normalize [ file join $here ../vhdl/wlan_tx_p.vhd] ]          \
    [file normalize [ file join $here ../vhdl/wlan_rx_p.vhd] ]          \
    [file normalize [ file join $here ../vhdl/wlan_interleaver_p.vhd] ] \
    [file normalize [ file join $here ../vhdl/wlan_lfsr.vhd] ]          \
    [file normalize [ file join $here ../vhdl/clock_sync_logic.vhd] ]   \
    [file normalize [ file join $here ../vhdl/clock_sync_params.vhd] ]  \
    [file normalize [ file join $here ../vhdl/clock_sync_logic_vector.vhd] ]   \
] ;

set wlan_synthesis_tx [list \
    [file normalize [ file join $here ../vhdl/wlan_descrambler.vhd] ]       \
    [file normalize [ file join $here ../vhdl/wlan_viterbi_encoder.vhd] ]   \
    [file normalize [ file join $here ../vhdl/wlan_scrambler.vhd] ]         \
    [file normalize [ file join $here ../vhdl/wlan_crc.vhd] ]               \
    [file normalize [ file join $here ../vhdl/wlan_framer.vhd] ]            \
    [file normalize [ file join $here ../vhdl/wlan_encoder.vhd] ]           \
    [file normalize [ file join $here ../vhdl/wlan_modulator.vhd] ]         \
    [file normalize [ file join $here ../vhdl/wlan_interleaver.vhd] ]       \
    [file normalize [ file join $here ../vhdl/wlan_ifft64.vhd] ]            \
    [file normalize [ file join $here ../vhdl/wlan_tx_short.vhd] ]          \
    [file normalize [ file join $here ../vhdl/wlan_tx_long.vhd] ]           \
    [file normalize [ file join $here ../vhdl/wlan_tx_controller.vhd] ]     \
    [file normalize [ file join $here ../vhdl/wlan_sample_buffer.vhd] ]     \
    [file normalize [ file join $here ../vhdl/wlan_symbol_shaper.vhd] ]     \
    [file normalize [ file join $here ../vhdl/wlan_tx.vhd] ]                \
] ;

set wlan_synthesis_rx [ list \
    [file normalize [ file join $here ../ip/nuand/cordic.vhd] ]             \
    [file normalize [ file join $here ../ip/nuand/nco.vhd] ]                \
    [file normalize [ file join $here ../vhdl/wlan_agc.vhd] ]               \
    [file normalize [ file join $here ../vhdl/wlan_agc_drv.vhd] ]       \
    [file normalize [ file join $here ../vhdl/wlan_dsss_despreader.vhd] ]   \
    [file normalize [ file join $here ../vhdl/wlan_dsss_plcp_crc.vhd] ]     \
    [file normalize [ file join $here ../vhdl/wlan_dsss_p_norm.vhd] ]       \
    [file normalize [ file join $here ../vhdl/wlan_dsss_demodulator.vhd] ]  \
    [file normalize [ file join $here ../vhdl/wlan_dsss_peak_finder.vhd] ]  \
    [file normalize [ file join $here ../vhdl/wlan_dsss_rx_controller.vhd] ]\
    [file normalize [ file join $here ../vhdl/wlan_dsss_rx_framer.vhd] ]    \
    [file normalize [ file join $here ../vhdl/wlan_dsss_rx.vhd] ]           \
    [file normalize [ file join $here ../vhdl/wlan_divide.vhd] ]            \
    [file normalize [ file join $here ../vhdl/wlan_channel_inverter.vhd] ]  \
    [file normalize [ file join $here ../vhdl/wlan_clamper.vhd] ]           \
    [file normalize [ file join $here ../vhdl/wlan_crc.vhd] ]               \
    [file normalize [ file join $here ../vhdl/wlan_rx_packet_buffer.vhd] ]  \
    [file normalize [ file join $here ../vhdl/wlan_rx_framer.vhd] ]         \
    [file normalize [ file join $here ../vhdl/wlan_csma.vhd] ]              \
    [file normalize [ file join $here ../vhdl/wlan_bsd.vhd] ]               \
    [file normalize [ file join $here ../vhdl/wlan_clamper.vhd] ]           \
    [file normalize [ file join $here ../vhdl/wlan_viterbi_decoder.vhd] ]   \
    [file normalize [ file join $here ../vhdl/wlan_depuncturer.vhd] ]       \
    [file normalize [ file join $here ../vhdl/wlan_deinterleaver.vhd] ]     \
    [file normalize [ file join $here ../vhdl/wlan_phase_correction.vhd] ]  \
    [file normalize [ file join $here ../vhdl/wlan_demodulator.vhd] ]       \
    [file normalize [ file join $here ../vhdl/wlan_equalizer.vhd] ]         \
    [file normalize [ file join $here ../vhdl/wlan_fft64.vhd] ]             \
    [file normalize [ file join $here ../vhdl/wlan_rx_controller.vhd] ]     \
    [file normalize [ file join $here ../vhdl/wlan_cfo_correction.vhd] ]    \
    [file normalize [ file join $here ../vhdl/wlan_cfo_estimate.vhd] ]      \
    [file normalize [ file join $here ../vhdl/wlan_peak_finder.vhd] ]       \
    [file normalize [ file join $here ../vhdl/wlan_delay_correlator.vhd] ]  \
    [file normalize [ file join $here ../vhdl/wlan_correlator.vhd] ]        \
    [file normalize [ file join $here ../vhdl/wlan_p_norm.vhd] ]            \
    [file normalize [ file join $here ../vhdl/wlan_acquisition.vhd] ]       \
    [file normalize [ file join $here ../vhdl/wlan_rx.vhd] ]                \
] ;

set wlan_synthesis_top [ list \
    [file normalize [ file join $here ../vhdl/wlan_ack_generator.vhd] ] \
    [file normalize [ file join $here ../vhdl/wlan_dcf.vhd] ]           \
    [file normalize [ file join $here ../vhdl/wlan_top.vhd] ]           \
] ;

set wlan_sim [ list \
    [file normalize [ file join $here ../vhdl/tb/wlan_clock_tb.vhd] ]           \
    [file normalize [ file join $here ../vhdl/tb/wlan_viterbi_tb.vhd] ]         \
    [file normalize [ file join $here ../vhdl/tb/wlan_dsss_plcp_crc_tb.vhd] ]   \
    [file normalize [ file join $here ../vhdl/tb/wlan_sample_loader.vhd] ]      \
    [file normalize [ file join $here ../vhdl/tb/wlan_sample_saver.vhd] ]       \
    [file normalize [ file join $here ../vhdl/tb/wlan_tables_p.vhd] ]           \
    [file normalize [ file join $here ../vhdl/tb/wlan_peak_finder_tb.vhd] ]     \
    [file normalize [ file join $here ../vhdl/tb/wlan_symbol_shaper_tb.vhd] ]   \
    [file normalize [ file join $here ../vhdl/tb/wlan_viterbi_encoder_tb.vhd] ] \
    [file normalize [ file join $here ../vhdl/tb/wlan_lfsr_tb.vhd] ]            \
    [file normalize [ file join $here ../vhdl/tb/wlan_modulator_tb.vhd] ]       \
    [file normalize [ file join $here ../vhdl/tb/wlan_interleaver_tb.vhd] ]     \
    [file normalize [ file join $here ../vhdl/tb/wlan_tx_short_tb.vhd] ]        \
    [file normalize [ file join $here ../vhdl/tb/wlan_tx_long_tb.vhd] ]         \
    [file normalize [ file join $here ../vhdl/tb/wlan_ack_generator_tb.vhd] ]   \
    [file normalize [ file join $here ../vhdl/tb/wlan_acquisition_tb.vhd] ]     \
    [file normalize [ file join $here ../vhdl/tb/wlan_tx_tb.vhd] ]              \
    [file normalize [ file join $here ../vhdl/tb/wlan_rx_tb.vhd] ]              \
    [file normalize [ file join $here ../vhdl/tb/wlan_top_tb.vhd] ]             \
    [file normalize [ file join $here ../vhdl/tb/wlan_channel_inverter_tb.vhd] ]\
    [file normalize [ file join $here ../vhdl/tb/wlan_tb.vhd] ]                 \
] ;

