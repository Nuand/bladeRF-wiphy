ip-generate --file-set=QUARTUS_SYNTH --component-name=altera_pll --output-name=wlan_pll \
            --component-param=gui_reference_clock_frequency="40MHz" \
            --component-param=gui_output_clock_frequency0="80MHz"   \
            --component-param=gui_phase_shift0="0ps"                \
            --component-param=gui_duty_cycle0="50%"
