# Reset assertion is asynchronous; release is synchronized in the receiving
# clock domain. Exempt only the asynchronous clear pins of those synchronizers.
# Their interstage data paths and all downstream recovery/removal remain timed.
# Both DCFIFOs enable write_aclr_synch AND read_aclr_synch in wlan_rx.vhd.
# https://docs.altera.com/r/docs/683522/25.1.1/fifo-ip-user-guide/recovery-and-removal-timing-violation-warnings-when-compiling-a-dcfifo

set wlan_reset_pins [get_pins -compatibility_mode -nowarn {*wlan_rx:*|rst_rr*|clrn}]
if {[get_collection_size $wlan_reset_pins] > 0} {
    set_false_path -to $wlan_reset_pins
}
foreach wlan_fifo {U_rx_data_dc_fifo U_rx_sample_fifo} {
    set wlan_reset_pins [get_pins -compatibility_mode -nowarn "*wlan_rx:*|dcfifo:${wlan_fifo}|*|dffpipe_*:*aclr|*|clrn"]
    if {[get_collection_size $wlan_reset_pins] > 0} {
        set_false_path -to $wlan_reset_pins
    }
}
unset wlan_reset_pins wlan_fifo
