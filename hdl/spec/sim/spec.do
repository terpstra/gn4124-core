vsim -novopt -t 1ps tb_spec
log -r /*
do wave.do

view wave
view transcript

run 15000 ns
##run 25057 ns
##force -freeze sim:/tb_lambo/l2p_rdy 0 0 -cancel {80 ns}
##run 1 us


