onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {Local bus}
add wave -noupdate -radix hexadecimal /tb_spec/u1/l2p_clkp
add wave -noupdate -radix hexadecimal /tb_spec/u1/l2p_clkn
add wave -noupdate -radix hexadecimal /tb_spec/u1/l2p_data
add wave -noupdate -radix hexadecimal /tb_spec/u1/l2p_valid
add wave -noupdate -radix hexadecimal /tb_spec/u1/l2p_dframe
add wave -noupdate -radix hexadecimal /tb_spec/u1/l2p_edb
add wave -noupdate -radix hexadecimal /tb_spec/u1/l2p_rdy
add wave -noupdate -radix hexadecimal /tb_spec/u1/l_wr_rdy
add wave -noupdate -radix hexadecimal /tb_spec/u1/p2l_clkn
add wave -noupdate -radix hexadecimal /tb_spec/u1/p2l_clkp
add wave -noupdate -radix hexadecimal /tb_spec/u1/p2l_data
add wave -noupdate -radix hexadecimal /tb_spec/u1/p2l_valid
add wave -noupdate -radix hexadecimal /tb_spec/u1/p2l_dframe
add wave -noupdate -radix hexadecimal /tb_spec/u1/p2l_pll_locked
add wave -noupdate -radix hexadecimal /tb_spec/u1/p2l_rdy
add wave -noupdate -radix hexadecimal /tb_spec/u1/p_rd_d_rdy
add wave -noupdate -radix hexadecimal /tb_spec/u1/p_wr_rdy
add wave -noupdate -radix hexadecimal /tb_spec/u1/p_wr_req
add wave -noupdate -radix hexadecimal /tb_spec/u1/rx_error
add wave -noupdate -radix hexadecimal /tb_spec/u1/tx_error
add wave -noupdate -radix hexadecimal /tb_spec/u1/vc_rdy
add wave -noupdate -divider {P2L des}
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_p2l_des/p2l_data_i
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_p2l_des/p2l_dframe_i
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_p2l_des/p2l_valid_i
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_p2l_des/p2l_data_o
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_p2l_des/p2l_dframe_o
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_p2l_des/p2l_valid_o
add wave -noupdate -divider {L2P ser}
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_l2p_ser/rst_n_i
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_l2p_ser/l2p_data_i
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_l2p_ser/l2p_dframe_i
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_l2p_ser/l2p_valid_i
add wave -noupdate /tb_spec/u1/cmp_gn4124_core/cmp_l2p_ser/l2p_clk_p_o
add wave -noupdate /tb_spec/u1/cmp_gn4124_core/cmp_l2p_ser/l2p_clk_n_o
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_l2p_ser/l2p_data_o
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_l2p_ser/l2p_valid_o
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_l2p_ser/l2p_dframe_o
add wave -noupdate -divider {Gennum core arbiter}
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/pdm_arb_req
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/pdm_arb_data
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/pdm_arb_dframe
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/pdm_arb_valid
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/ldm_arb_req
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/ldm_arb_data
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/ldm_arb_dframe
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/ldm_arb_valid
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/wbm_arb_req
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/wbm_arb_data
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/wbm_arb_dframe
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/wbm_arb_valid
add wave -noupdate -divider {CSR wishbone master}
add wave -noupdate /tb_spec/u1/cmp_gn4124_core/cmp_wbmaster32/wishbone_current_state
add wave -noupdate -radix hexadecimal /tb_spec/u1/wbm_ack
add wave -noupdate -radix hexadecimal /tb_spec/u1/wbm_adr
add wave -noupdate -radix hexadecimal /tb_spec/u1/wbm_cyc
add wave -noupdate -radix hexadecimal /tb_spec/u1/wbm_dat_i
add wave -noupdate -radix hexadecimal /tb_spec/u1/wbm_dat_o
add wave -noupdate -radix hexadecimal /tb_spec/u1/wbm_sel
add wave -noupdate -radix hexadecimal /tb_spec/u1/wbm_stall
add wave -noupdate -radix hexadecimal /tb_spec/u1/wbm_stb
add wave -noupdate -radix hexadecimal /tb_spec/u1/wbm_we
add wave -noupdate -divider {Wishbone address decoder}
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_csr_wb_addr_decoder/s_wb_periph_addr
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_csr_wb_addr_decoder/wb_periph_addr
add wave -noupdate /tb_spec/u1/cmp_csr_wb_addr_decoder/s_wb_periph_select
add wave -noupdate /tb_spec/u1/cmp_csr_wb_addr_decoder/s_wb_ack_muxed
add wave -noupdate /tb_spec/u1/cmp_csr_wb_addr_decoder/s_wb_cyc_demuxed
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_csr_wb_addr_decoder/s_wb_dat_i_muxed
add wave -noupdate -divider {CSR wishbone}
add wave -noupdate -radix hexadecimal /tb_spec/u1/wb_ack(0)
add wave -noupdate -radix hexadecimal /tb_spec/u1/wb_ack(1)
add wave -noupdate /tb_spec/u1/wb_ack(2)
add wave -noupdate -radix hexadecimal /tb_spec/u1/wb_adr
add wave -noupdate -radix hexadecimal /tb_spec/u1/wb_cyc(0)
add wave -noupdate -radix hexadecimal /tb_spec/u1/wb_cyc(1)
add wave -noupdate /tb_spec/u1/wb_cyc(2)
add wave -noupdate -radix hexadecimal /tb_spec/u1/wb_dat_i
add wave -noupdate -radix hexadecimal /tb_spec/u1/wb_dat_o
add wave -noupdate -radix hexadecimal /tb_spec/u1/wb_sel
add wave -noupdate -radix hexadecimal /tb_spec/u1/wb_stb
add wave -noupdate -radix hexadecimal /tb_spec/u1/wb_we
add wave -noupdate /tb_spec/u1/wb_stall(0)
add wave -noupdate /tb_spec/u1/wb_stall(1)
add wave -noupdate /tb_spec/u1/wb_stall(2)
add wave -noupdate -divider {DMA wishbone}
add wave -noupdate -radix hexadecimal /tb_spec/u1/dma_dat_i
add wave -noupdate -radix hexadecimal /tb_spec/u1/dma_dat_o
add wave -noupdate -divider {DMA ctrl}
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_dma_controller/dma_ctrl_current_state
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_dma_controller/dma_done_irq
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_dma_controller/dma_error_irq
add wave -noupdate -divider L2P_DMA
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_l2p_dma_master/l2p_lbe_header
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_l2p_dma_master/l2p_len_header
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_l2p_dma_master/s_l2p_header
add wave -noupdate /tb_spec/u1/cmp_gn4124_core/cmp_l2p_dma_master/ldm_arb_dframe_o
add wave -noupdate /tb_spec/u1/cmp_gn4124_core/cmp_l2p_dma_master/ldm_arb_valid_o
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_l2p_dma_master/ldm_arb_data_o
add wave -noupdate -divider P2L_DMA
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_p2l_dma_master/l2p_lbe_header
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_p2l_dma_master/l2p_len_header
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_p2l_dma_master/s_l2p_header
add wave -noupdate /tb_spec/u1/cmp_gn4124_core/cmp_p2l_dma_master/pdm_arb_dframe_o
add wave -noupdate /tb_spec/u1/cmp_gn4124_core/cmp_p2l_dma_master/pdm_arb_valid_o
add wave -noupdate -radix hexadecimal /tb_spec/u1/cmp_gn4124_core/cmp_p2l_dma_master/pdm_arb_data_o
add wave -noupdate -divider LEDs
add wave -noupdate -radix hexadecimal /tb_spec/u1/led_green_o
add wave -noupdate /tb_spec/u1/led_red_o
add wave -noupdate -radix hexadecimal /tb_spec/u1/aux_leds_o
add wave -noupdate -radix hexadecimal /tb_spec/u1/led_cnt
add wave -noupdate -radix hexadecimal /tb_spec/u1/led_en
add wave -noupdate -radix hexadecimal /tb_spec/u1/led_k2000
add wave -noupdate -radix hexadecimal /tb_spec/u1/led_pps
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {631250 ps} 0}
configure wave -namecolwidth 395
configure wave -valuecolwidth 120
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
configure wave -timelineunits ns
update
WaveRestoreZoom {581738 ps} {643262 ps}
