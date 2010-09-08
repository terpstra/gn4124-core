---------------------------------------------------------------------------------------
-- Title          : Wishbone slave core for GN4124 core DMA controller 
---------------------------------------------------------------------------------------
-- File           : ../testbench_lotus/fpga_project/lotus/rtl/dma_controller_wb_slave.vhd
-- Author         : auto-generated by wbgen2 from ../testbench_lotus/fpga_project/lotus/rtl/dma_controller_wb_slave.wb
-- Created        : Wed Jul 21 10:09:30 2010
-- Standard       : VHDL'87
---------------------------------------------------------------------------------------
-- THIS FILE WAS GENERATED BY wbgen2 FROM SOURCE FILE ../testbench_lotus/fpga_project/lotus/rtl/dma_controller_wb_slave.wb
-- DO NOT HAND-EDIT UNLESS IT'S ABSOLUTELY NECESSARY!
---------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dma_controller_wb_slave is
  port (
    rst_n_i                                  : in     std_logic;
    wb_clk_i                                 : in     std_logic;
    wb_addr_i                                : in     std_logic_vector(3 downto 0);
    wb_data_i                                : in     std_logic_vector(31 downto 0);
    wb_data_o                                : out    std_logic_vector(31 downto 0);
    wb_cyc_i                                 : in     std_logic;
    wb_sel_i                                 : in     std_logic_vector(3 downto 0);
    wb_stb_i                                 : in     std_logic;
    wb_we_i                                  : in     std_logic;
    wb_ack_o                                 : out    std_logic;
-- Port for std_logic_vector field: 'DMA engine control' in reg: 'DMACTRLR'
    dma_ctrl_o                               : out    std_logic_vector(31 downto 0);
    dma_ctrl_i                               : in     std_logic_vector(31 downto 0);
    dma_ctrl_load_o                          : out    std_logic;
-- Port for std_logic_vector field: 'DMA engine status' in reg: 'DMASTATR'
    dma_stat_o                               : out    std_logic_vector(31 downto 0);
    dma_stat_i                               : in     std_logic_vector(31 downto 0);
    dma_stat_load_o                          : out    std_logic;
-- Port for std_logic_vector field: 'DMA start address in the carrier' in reg: 'DMACSTARTR'
    dma_cstart_o                             : out    std_logic_vector(31 downto 0);
    dma_cstart_i                             : in     std_logic_vector(31 downto 0);
    dma_cstart_load_o                        : out    std_logic;
-- Port for std_logic_vector field: 'DMA start address (low) in the host' in reg: 'DMAHSTARTLR'
    dma_hstartl_o                            : out    std_logic_vector(31 downto 0);
    dma_hstartl_i                            : in     std_logic_vector(31 downto 0);
    dma_hstartl_load_o                       : out    std_logic;
-- Port for std_logic_vector field: 'DMA start address (high) in the host' in reg: 'DMAHSTARTHR'
    dma_hstarth_o                            : out    std_logic_vector(31 downto 0);
    dma_hstarth_i                            : in     std_logic_vector(31 downto 0);
    dma_hstarth_load_o                       : out    std_logic;
-- Port for std_logic_vector field: 'DMA read length in bytes' in reg: 'DMALENR'
    dma_len_o                                : out    std_logic_vector(31 downto 0);
    dma_len_i                                : in     std_logic_vector(31 downto 0);
    dma_len_load_o                           : out    std_logic;
-- Port for std_logic_vector field: 'Pointer (low) to next item in list' in reg: 'DMANEXTLR'
    dma_nextl_o                              : out    std_logic_vector(31 downto 0);
    dma_nextl_i                              : in     std_logic_vector(31 downto 0);
    dma_nextl_load_o                         : out    std_logic;
-- Port for std_logic_vector field: 'Pointer (high) to next item in list' in reg: 'DMANEXTHR'
    dma_nexth_o                              : out    std_logic_vector(31 downto 0);
    dma_nexth_i                              : in     std_logic_vector(31 downto 0);
    dma_nexth_load_o                         : out    std_logic;
-- Port for std_logic_vector field: 'DMA chain control' in reg: 'DMAATTRIBR'
    dma_attrib_o                             : out    std_logic_vector(31 downto 0);
    dma_attrib_i                             : in     std_logic_vector(31 downto 0);
    dma_attrib_load_o                        : out    std_logic
  );
end dma_controller_wb_slave;

architecture syn of dma_controller_wb_slave is

signal ack_sreg                                 : std_logic_vector(9 downto 0);
signal rddata_reg                               : std_logic_vector(31 downto 0);
signal wrdata_reg                               : std_logic_vector(31 downto 0);
signal bwsel_reg                                : std_logic_vector(3 downto 0);
signal rwaddr_reg                               : std_logic_vector(3 downto 0);
signal ack_in_progress                          : std_logic      ;
signal wr_int                                   : std_logic      ;
signal rd_int                                   : std_logic      ;
signal bus_clock_int                            : std_logic      ;
signal allones                                  : std_logic_vector(31 downto 0);
signal allzeros                                 : std_logic_vector(31 downto 0);

begin
-- Some internal signals assignments. For (foreseen) compatibility with other bus standards.
  wrdata_reg <= wb_data_i;
  bwsel_reg <= wb_sel_i;
  --bus_clock_int <= wb_clk_i;
  rd_int <= wb_cyc_i and (wb_stb_i and (not wb_we_i));
  wr_int <= wb_cyc_i and (wb_stb_i and wb_we_i);
  allones <= (others => '1');
  allzeros <= (others => '0');
-- 
-- Main register bank access process.
  process (wb_clk_i, rst_n_i)
  begin
    if (rst_n_i = '0') then 
      ack_sreg <= "0000000000";
      ack_in_progress <= '0';
      rddata_reg <= "00000000000000000000000000000000";
      dma_ctrl_load_o <= '0';
      dma_stat_load_o <= '0';
      dma_cstart_load_o <= '0';
      dma_hstartl_load_o <= '0';
      dma_hstarth_load_o <= '0';
      dma_len_load_o <= '0';
      dma_nextl_load_o <= '0';
      dma_nexth_load_o <= '0';
      dma_attrib_load_o <= '0';
    elsif rising_edge(wb_clk_i) then
 -- advance the ACK generator shift register
      ack_sreg(8 downto 0) <= ack_sreg(9 downto 1);
      ack_sreg(9) <= '0';
      if (ack_in_progress = '1') then
        if (ack_sreg(0) = '1') then
          dma_ctrl_load_o <= '0';
          dma_stat_load_o <= '0';
          dma_cstart_load_o <= '0';
          dma_hstartl_load_o <= '0';
          dma_hstarth_load_o <= '0';
          dma_len_load_o <= '0';
          dma_nextl_load_o <= '0';
          dma_nexth_load_o <= '0';
          dma_attrib_load_o <= '0';
          ack_in_progress <= '0';
        else
          dma_ctrl_load_o <= '0';
          dma_stat_load_o <= '0';
          dma_cstart_load_o <= '0';
          dma_hstartl_load_o <= '0';
          dma_hstarth_load_o <= '0';
          dma_len_load_o <= '0';
          dma_nextl_load_o <= '0';
          dma_nexth_load_o <= '0';
          dma_attrib_load_o <= '0';
        end if;
      else
        if ((wb_cyc_i = '1') and (wb_stb_i = '1')) then
          case rwaddr_reg(3 downto 0) is
          when "0000" => 
            if (wb_we_i = '1') then
              dma_ctrl_load_o <= '1';
            else
              rddata_reg(31 downto 0) <= dma_ctrl_i;
            end if;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "0001" => 
            if (wb_we_i = '1') then
              dma_stat_load_o <= '1';
            else
              rddata_reg(31 downto 0) <= dma_stat_i;
            end if;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "0010" => 
            if (wb_we_i = '1') then
              dma_cstart_load_o <= '1';
            else
              rddata_reg(31 downto 0) <= dma_cstart_i;
            end if;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "0011" => 
            if (wb_we_i = '1') then
              dma_hstartl_load_o <= '1';
            else
              rddata_reg(31 downto 0) <= dma_hstartl_i;
            end if;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "0100" => 
            if (wb_we_i = '1') then
              dma_hstarth_load_o <= '1';
            else
              rddata_reg(31 downto 0) <= dma_hstarth_i;
            end if;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "0101" => 
            if (wb_we_i = '1') then
              dma_len_load_o <= '1';
            else
              rddata_reg(31 downto 0) <= dma_len_i;
            end if;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "0110" => 
            if (wb_we_i = '1') then
              dma_nextl_load_o <= '1';
            else
              rddata_reg(31 downto 0) <= dma_nextl_i;
            end if;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "0111" => 
            if (wb_we_i = '1') then
              dma_nexth_load_o <= '1';
            else
              rddata_reg(31 downto 0) <= dma_nexth_i;
            end if;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "1000" => 
            if (wb_we_i = '1') then
              dma_attrib_load_o <= '1';
            else
              rddata_reg(31 downto 0) <= dma_attrib_i;
            end if;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when others =>
-- prevent the slave from hanging the bus on invalid address
            ack_in_progress <= '1';
            ack_sreg(0) <= '1';
          end case;
        end if;
      end if;
    end if;
  end process;
  
  
-- Drive the data output bus
  wb_data_o <= rddata_reg;
-- DMA engine control
  dma_ctrl_o <= wrdata_reg(31 downto 0);
-- DMA engine status
  dma_stat_o <= wrdata_reg(31 downto 0);
-- DMA start address in the carrier
  dma_cstart_o <= wrdata_reg(31 downto 0);
-- DMA start address (low) in the host
  dma_hstartl_o <= wrdata_reg(31 downto 0);
-- DMA start address (high) in the host
  dma_hstarth_o <= wrdata_reg(31 downto 0);
-- DMA read length in bytes
  dma_len_o <= wrdata_reg(31 downto 0);
-- Pointer (low) to next item in list
  dma_nextl_o <= wrdata_reg(31 downto 0);
-- Pointer (high) to next item in list
  dma_nexth_o <= wrdata_reg(31 downto 0);
-- DMA chain control
  dma_attrib_o <= wrdata_reg(31 downto 0);
  rwaddr_reg <= wb_addr_i;
-- ACK signal generation. Just pass the LSB of ACK counter.
  wb_ack_o <= ack_sreg(0);
end syn;