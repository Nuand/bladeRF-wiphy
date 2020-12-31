# Library
vlib wlan

if { ! [info exists wlan_path] } {
    set wlan_path "."
}

set modelsim 1

vlib nuand
vcom -work nuand -2008 [file join $wlan_path ../../../bladeRF/hdl/fpga/ip/nuand/synthesis/fifo_readwrite_p.vhd ]

# altera ip simulation models
vlib fft64

set QSYS_SIMDIR [file normalize [ file join $wlan_path ../ip/altera/fft64/fft64/simulation/ ] ]
source [file normalize [ file join $wlan_path $QSYS_SIMDIR/mentor/msim_setup.tcl ] ]
dev_com
com
vmap fft64 libraries/fft_ii_0/

vlog -work fft64 [ file join $wlan_path ../ip/altera/fft64/fft64/simulation/fft64.v ]
set hexfiles [glob [file join $wlan_path "../ip/altera/fft64/fft64/simulation/submodules/*.hex"] ]
foreach f $hexfiles {
    file copy -force $f .
}

vlib viterbi_decoder
set QSYS_SIMDIR [file normalize [ file join $wlan_path ../ip/altera/viterbi_decoder/viterbi_decoder/simulation/ ] ]
source [file normalize [ file join $wlan_path $QSYS_SIMDIR/mentor/msim_setup.tcl ] ]
dev_com
com
vmap viterbi_decoder libraries/viterbi_ii_0/

vlog -work viterbi_decoder [ file join $wlan_path ../ip/altera/viterbi_decoder/viterbi_decoder/simulation/viterbi_decoder.v ]
vlog -work viterbi_decoder [ file join $wlan_path ../ip/altera/viterbi_decoder/viterbi_decoder/simulation/submodules/viterbi_decoder_viterbi_ii_0.v ]


vlib wlan_pll
vlog -work wlan_pll [ file join $wlan_path ../ip/altera/wlan_pll/wlan_pll/wlan_pll.v ]

source [file normalize [ file join $wlan_path ../common/wlan_files.tcl ] ]

# Common packages
foreach f $wlan_common {
    vcom -work wlan -2008 $f
}

# TX Synthesis
foreach f $wlan_synthesis_tx {
    vcom -work wlan -2008 $f
}

# RX Synthesis
foreach f $wlan_synthesis_rx {
    vcom -work wlan -2008 $f
}

# Top Level Synthesis
foreach f $wlan_synthesis_top {
    vcom -work wlan -2008 $f
}

# Simulation
foreach f $wlan_sim {
    vcom -work wlan -2008 $f
}

proc wlan_sim_entity { entity } {
   vsim -t ps   -L work -L work_lib -L fft_ii_0 -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L wlan -L fft64 -L viterbi_decoder -L altera_lnsim_ver $entity
}

alias tb_wlan_rx {
   wlan_sim_entity wlan_rx_tb
}
