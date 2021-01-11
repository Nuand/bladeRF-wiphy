onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /viterbi_decoder_tb/U_uut/G_A
add wave -noupdate /viterbi_decoder_tb/U_uut/G_A_VEC
add wave -noupdate /viterbi_decoder_tb/U_uut/G_B
add wave -noupdate /viterbi_decoder_tb/U_uut/G_B_VEC
add wave -noupdate /viterbi_decoder_tb/U_uut/K
add wave -noupdate /viterbi_decoder_tb/U_uut/TB_LEN
add wave -noupdate /viterbi_decoder_tb/U_uut/acs_reg
add wave -noupdate /viterbi_decoder_tb/U_uut/acs_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/best_idx
add wave -noupdate /viterbi_decoder_tb/U_uut/bm
add wave -noupdate /viterbi_decoder_tb/U_uut/bm_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/bsd_in
add wave -noupdate /viterbi_decoder_tb/U_uut/bsd_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/clock
add wave -noupdate /viterbi_decoder_tb/U_uut/erasure
add wave -noupdate /viterbi_decoder_tb/U_uut/in_a
add wave -noupdate /viterbi_decoder_tb/U_uut/in_b
add wave -noupdate /viterbi_decoder_tb/U_uut/lut
add wave -noupdate /viterbi_decoder_tb/U_uut/out_bit
add wave -noupdate /viterbi_decoder_tb/U_uut/out_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/paths
add wave -noupdate /viterbi_decoder_tb/U_uut/reset
add wave -noupdate /viterbi_decoder_tb/U_uut/U_r2_comp/NUM_PATHS
add wave -noupdate /viterbi_decoder_tb/U_uut/U_r2_comp/STATE_BITS
add wave -noupdate /viterbi_decoder_tb/U_uut/U_r2_comp/clock
add wave -noupdate /viterbi_decoder_tb/U_uut/U_r2_comp/label_out
add wave -noupdate /viterbi_decoder_tb/U_uut/U_r2_comp/path_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/U_r2_comp/paths
add wave -noupdate /viterbi_decoder_tb/U_uut/U_r2_comp/r2_matrix
add wave -noupdate /viterbi_decoder_tb/U_uut/U_r2_comp/reset
add wave -noupdate /viterbi_decoder_tb/U_uut/U_r2_comp/valid_out
add wave -noupdate /viterbi_decoder_tb/U_uut/U_r2_comp/valid_out_r
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/NUM_STATES
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/STATE_BITS
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/TB_LEN
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/acs_reg
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/acs_valid
add wave -noupdate -radix unsigned /viterbi_decoder_tb/U_uut/U_traceback/best_idx
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/best_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/bit_out
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/clock
add wave -noupdate -expand /viterbi_decoder_tb/U_uut/U_traceback/current
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/future
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/reset
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/trace_state
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/trace_state_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(0)/U_tracer/NUM_STATES
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(0)/U_tracer/STATE_BITS
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(0)/U_tracer/acs_reg
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(0)/U_tracer/acs_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(0)/U_tracer/clock
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(0)/U_tracer/reset
add wave -noupdate -radix unsigned /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(0)/U_tracer/state_in
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(0)/U_tracer/state_valid
add wave -noupdate -radix unsigned /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(0)/U_tracer/state_out
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(0)/U_tracer/valid_out
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/NUM_STATES
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/STATE_BITS
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/TB_LEN
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/acs_reg
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/acs_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/best_idx
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/best_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/bit_out
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/valid_out
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/clock
add wave -noupdate -expand /viterbi_decoder_tb/U_uut/U_traceback/current
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/future
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/reset
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/trace_state
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/trace_state_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/valid_out
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(1)/U_tracer/acs_reg
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(1)/U_tracer/acs_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(1)/U_tracer/clock
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(1)/U_tracer/NUM_STATES
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(1)/U_tracer/reset
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(1)/U_tracer/STATE_BITS
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(1)/U_tracer/state_in
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(1)/U_tracer/state_out
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(1)/U_tracer/state_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(1)/U_tracer/valid_out
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(19)/U_tracer/acs_reg
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(19)/U_tracer/acs_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(19)/U_tracer/clock
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(19)/U_tracer/NUM_STATES
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(19)/U_tracer/reset
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(19)/U_tracer/STATE_BITS
add wave -noupdate -radix unsigned /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(19)/U_tracer/state_in
add wave -noupdate -radix unsigned /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(19)/U_tracer/state_out
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(19)/U_tracer/state_valid
add wave -noupdate /viterbi_decoder_tb/U_uut/U_traceback/gen_tracers(19)/U_tracer/valid_out
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {3754327 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 518
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {52500 ns}
