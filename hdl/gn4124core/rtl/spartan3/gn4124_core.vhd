--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: Gn4124 core main block (gn4124_core.vhd)
--
-- authors: Simon Deprez (simon.deprez@cern.ch)
--          Matthieu Cattin (matthieu.cattin@cern.ch)
--
-- date: 31-08-2010
--
-- version: 0.3
--
-- description: GN4124 core top level.
--
--
-- dependencies:
--
--------------------------------------------------------------------------------
-- GNU LESSER GENERAL PUBLIC LICENSE
--------------------------------------------------------------------------------
-- This source file is free software; you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by the
-- Free Software Foundation; either version 2.1 of the License, or (at your
-- option) any later version. This source is distributed in the hope that it
-- will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
-- of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU Lesser General Public License for more details. You should have
-- received a copy of the GNU Lesser General Public License along with this
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html
--------------------------------------------------------------------------------
-- last changes: see svn log
--------------------------------------------------------------------------------
-- TODO: - DMA wishbone bus address map
--       - reset and clock signals
--       - wishbone timeout generic ??
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gn4124_core_pkg.all;

library UNISIM;
use UNISIM.vcomponents.all;


--==============================================================================
-- Entity declaration for GN4124 core (gn4124_core)
--==============================================================================
entity gn4124_core is
  generic(
    g_IS_SPARTAN6       : boolean := false;  -- This generic is used to instanciate spartan6 specific primitives
    g_BAR0_APERTURE     : integer := 20;     -- BAR0 aperture, defined in GN4124 PCI_BAR_CONFIG register (0x80C)
                                             -- => number of bits to address periph on the board
    g_CSR_WB_SLAVES_NB  : integer := 1;      -- Number of CSR wishbone slaves
    g_DMA_WB_SLAVES_NB  : integer := 1;      -- Number of DMA wishbone slaves
    g_DMA_WB_ADDR_WIDTH : integer := 26      -- DMA wishbone address bus width
    );
  port
    (
      ---------------------------------------------------------
      -- Control and status
      --
      -- Asynchronous reset from GN4124
      rst_n_a_i      : in  std_logic;
      -- P2L clock PLL locked
      p2l_pll_locked : out std_logic;
      -- Debug ouputs
      debug_o        : out std_logic_vector(7 downto 0);

      ---------------------------------------------------------
      -- P2L Direction
      --
      -- Source Sync DDR related signals
      p2l_clk_p_i  : in  std_logic;                      -- Receiver Source Synchronous Clock+
      p2l_clk_n_i  : in  std_logic;                      -- Receiver Source Synchronous Clock-
      p2l_data_i   : in  std_logic_vector(15 downto 0);  -- Parallel receive data
      p2l_dframe_i : in  std_logic;                      -- Receive Frame
      p2l_valid_i  : in  std_logic;                      -- Receive Data Valid
      -- P2L Control
      p2l_rdy_o    : out std_logic;                      -- Rx Buffer Full Flag
      p_wr_req_i   : in  std_logic_vector(1 downto 0);   -- PCIe Write Request
      p_wr_rdy_o   : out std_logic_vector(1 downto 0);   -- PCIe Write Ready
      rx_error_o   : out std_logic;                      -- Receive Error
      vc_rdy_i     : in  std_logic_vector(1 downto 0);   -- Virtual channel ready

      ---------------------------------------------------------
      -- L2P Direction
      --
      -- Source Sync DDR related signals
      l2p_clk_p_o  : out std_logic;                      -- Transmitter Source Synchronous Clock+
      l2p_clk_n_o  : out std_logic;                      -- Transmitter Source Synchronous Clock-
      l2p_data_o   : out std_logic_vector(15 downto 0);  -- Parallel transmit data
      l2p_dframe_o : out std_logic;                      -- Transmit Data Frame
      l2p_valid_o  : out std_logic;                      -- Transmit Data Valid
      l2p_edb_o    : out std_logic;                      -- Packet termination and discard
      -- L2P Control
      l2p_rdy_i    : in  std_logic;                      -- Tx Buffer Full Flag
      l_wr_rdy_i   : in  std_logic_vector(1 downto 0);   -- Local-to-PCIe Write
      p_rd_d_rdy_i : in  std_logic_vector(1 downto 0);   -- PCIe-to-Local Read Response Data Ready
      tx_error_i   : in  std_logic;                      -- Transmit Error

      ---------------------------------------------------------
      -- Interrupt interface
      dma_irq_o : out std_logic_vector(1 downto 0);  -- Interrupts sources to IRQ manager
      irq_p_i   : in  std_logic;                     -- Interrupt request pulse from IRQ manager
      irq_p_o   : out std_logic;                     -- Interrupt request pulse to GN4124 GPIO

      ---------------------------------------------------------
      -- Target interface (CSR wishbone master)
      wb_clk_i : in  std_logic;
      wb_adr_o : out std_logic_vector(g_BAR0_APERTURE-log2_ceil(g_CSR_WB_SLAVES_NB+1)-1 downto 0);
      wb_dat_o : out std_logic_vector(31 downto 0);                         -- Data out
      wb_sel_o : out std_logic_vector(3 downto 0);                          -- Byte select
      wb_stb_o : out std_logic;
      wb_we_o  : out std_logic;
      wb_cyc_o : out std_logic_vector(g_CSR_WB_SLAVES_NB-1 downto 0);
      wb_dat_i : in  std_logic_vector((32*g_CSR_WB_SLAVES_NB)-1 downto 0);  -- Data in
      wb_ack_i : in  std_logic_vector(g_CSR_WB_SLAVES_NB-1 downto 0);

      ---------------------------------------------------------
      -- DMA interface (Pipelined wishbone master)
      dma_clk_i   : in  std_logic;
      dma_adr_o   : out std_logic_vector(31 downto 0);
      dma_dat_o   : out std_logic_vector(31 downto 0);                         -- Data out
      dma_sel_o   : out std_logic_vector(3 downto 0);                          -- Byte select
      dma_stb_o   : out std_logic;
      dma_we_o    : out std_logic;
      dma_cyc_o   : out std_logic;                                             --_vector(g_DMA_WB_SLAVES_NB-1 downto 0);
      dma_dat_i   : in  std_logic_vector((32*g_DMA_WB_SLAVES_NB)-1 downto 0);  -- Data in
      dma_ack_i   : in  std_logic;                                             --_vector(g_DMA_WB_SLAVES_NB-1 downto 0);
      dma_stall_i : in  std_logic--_vector(g_DMA_WB_SLAVES_NB-1 downto 0)        -- for pipelined Wishbone
      );
end gn4124_core;


--==============================================================================
-- Architecture declaration for GN4124 core (gn4124_core)
--==============================================================================
architecture rtl of gn4124_core is


  ------------------------------------------------------------------------------
  -- Signals declaration
  ------------------------------------------------------------------------------

  -- Clock
  signal clk_p         : std_logic;
  signal clk_n         : std_logic;
  signal clk_p_buf     : std_logic;
  signal clk_n_buf     : std_logic;
  signal clk_p_io      : std_logic;
  signal clk_n_io      : std_logic;
  signal clk_sys_buf   : std_logic;
  signal clk_sys       : std_logic;
  signal clk_sys_n_buf : std_logic;
  signal clk_sys_n     : std_logic;
  -- Reset for all clk_p logic
  signal rst_reg       : std_logic;
  signal rst_n         : std_logic;

  -------------------------------------------------------------
  -- P2L DataPath (from deserializer to packet decoder)
  -------------------------------------------------------------
  signal des_pd_valid  : std_logic;
  signal des_pd_dframe : std_logic;
  signal des_pd_data   : std_logic_vector(31 downto 0);

  -- Local bus control
  signal p_wr_rdy    : std_logic;
  signal p2l_rdy_wbm : std_logic;
  signal p2l_rdy_pdm : std_logic;

  -------------------------------------------------------------
  -- P2L DataPath (from packet decoder to Wishbone master and P2L DMA master)
  -------------------------------------------------------------
  signal p2l_hdr_start   : std_logic;
  signal p2l_hdr_length  : std_logic_vector(9 downto 0);
  signal p2l_hdr_cid     : std_logic_vector(1 downto 0);
  signal p2l_hdr_last    : std_logic;
  signal p2l_hdr_stat    : std_logic_vector(1 downto 0);
  signal p2l_target_mrd  : std_logic;
  signal p2l_target_mwr  : std_logic;
  signal p2l_master_cpld : std_logic;
  signal p2l_master_cpln : std_logic;
  signal p2l_d_valid     : std_logic;
  signal p2l_d_last      : std_logic;
  signal p2l_d           : std_logic_vector(31 downto 0);
  signal p2l_be          : std_logic_vector(3 downto 0);
  signal p2l_addr        : std_logic_vector(31 downto 0);
  signal p2l_addr_start  : std_logic;

  -------------------------------------------------------------
  -- L2P DataPath (from arbiter to serializer)
  -------------------------------------------------------------
  signal arb_ser_valid  : std_logic;
  signal arb_ser_dframe : std_logic;
  signal arb_ser_data   : std_logic_vector(31 downto 0);

  -- Local bus control
  signal l_wr_rdy_t    : std_logic_vector(1 downto 0);
  signal l_wr_rdy_t2   : std_logic_vector(1 downto 0);
  signal l_wr_rdy      : std_logic_vector(1 downto 0);
  signal p_rd_d_rdy_t  : std_logic_vector(1 downto 0);
  signal p_rd_d_rdy_t2 : std_logic_vector(1 downto 0);
  signal p_rd_d_rdy    : std_logic_vector(1 downto 0);
  signal l2p_rdy_t     : std_logic;
  signal l2p_rdy_t2    : std_logic;
  signal l2p_rdy       : std_logic;
  signal l2p_edb       : std_logic;
  signal l2p_edb_t     : std_logic;
  signal l2p_edb_t2    : std_logic;

  -------------------------------------------------------------
  -- CSR wishbone master to arbiter
  -------------------------------------------------------------
  signal wbm_arb_valid  : std_logic;
  signal wbm_arb_dframe : std_logic;
  signal wbm_arb_data   : std_logic_vector(31 downto 0);
  signal wbm_arb_req    : std_logic;
  signal arb_wbm_gnt    : std_logic;

  -------------------------------------------------------------
  -- L2P DMA master to arbiter
  -------------------------------------------------------------
  signal ldm_arb_req    : std_logic;
  signal arb_ldm_gnt    : std_logic;
  signal ldm_arb_valid  : std_logic;
  signal ldm_arb_dframe : std_logic;
  signal ldm_arb_data   : std_logic_vector(31 downto 0);

  -------------------------------------------------------------
  -- P2L DMA master to arbiter
  -------------------------------------------------------------
  signal pdm_arb_valid  : std_logic;
  signal pdm_arb_dframe : std_logic;
  signal pdm_arb_data   : std_logic_vector(31 downto 0);
  signal pdm_arb_req    : std_logic;
  signal arb_pdm_gnt    : std_logic;

  -------------------------------------------------------------
  -- DMA controller
  -------------------------------------------------------------
  signal dma_ctrl_carrier_addr : std_logic_vector(31 downto 0);
  signal dma_ctrl_host_addr_h  : std_logic_vector(31 downto 0);
  signal dma_ctrl_host_addr_l  : std_logic_vector(31 downto 0);
  signal dma_ctrl_len          : std_logic_vector(31 downto 0);
  signal dma_ctrl_start_l2p    : std_logic;
  signal dma_ctrl_start_p2l    : std_logic;
  signal dma_ctrl_start_next   : std_logic;

  signal dma_ctrl_done      : std_logic;
  signal dma_ctrl_error     : std_logic;
  signal dma_ctrl_l2p_done  : std_logic;
  signal dma_ctrl_l2p_error : std_logic;
  signal dma_ctrl_p2l_done  : std_logic;
  signal dma_ctrl_p2l_error : std_logic;
  signal dma_ctrl_byte_swap : std_logic_vector(1 downto 0);
  signal dma_ctrl_abort     : std_logic;

  signal next_item_carrier_addr : std_logic_vector(31 downto 0);
  signal next_item_host_addr_h  : std_logic_vector(31 downto 0);
  signal next_item_host_addr_l  : std_logic_vector(31 downto 0);
  signal next_item_len          : std_logic_vector(31 downto 0);
  signal next_item_next_l       : std_logic_vector(31 downto 0);
  signal next_item_next_h       : std_logic_vector(31 downto 0);
  signal next_item_attrib       : std_logic_vector(31 downto 0);
  signal next_item_valid        : std_logic;

  ------------------------------------------------------------------------------
  -- CSR wishbone bus
  ------------------------------------------------------------------------------
  signal wb_adr              : std_logic_vector(g_BAR0_APERTURE-log2_ceil(g_CSR_WB_SLAVES_NB+1)-1 downto 0);
  signal wb_dat_s2m          : std_logic_vector((32*(g_CSR_WB_SLAVES_NB+1))-1 downto 0);
  signal wb_dat_m2s          : std_logic_vector(31 downto 0);
  signal wb_sel              : std_logic_vector(3 downto 0);
  signal wb_cyc              : std_logic_vector(g_CSR_WB_SLAVES_NB downto 0);
  signal wb_stb              : std_logic;
  signal wb_we               : std_logic;
  signal wb_ack              : std_logic_vector(g_CSR_WB_SLAVES_NB downto 0);
  signal wb_ack_dma_ctrl     : std_logic;
  signal wb_dat_s2m_dma_ctrl : std_logic_vector(31 downto 0);

  ------------------------------------------------------------------------------
  -- DMA wishbone bus
  ------------------------------------------------------------------------------
  signal l2p_dma_adr     : std_logic_vector(31 downto 0);
  signal l2p_dma_dat_s2m : std_logic_vector(31 downto 0);
  signal l2p_dma_dat_m2s : std_logic_vector(31 downto 0);
  signal l2p_dma_sel     : std_logic_vector(3 downto 0);
  signal l2p_dma_cyc     : std_logic;
  signal l2p_dma_stb     : std_logic;
  signal l2p_dma_we      : std_logic;
  signal l2p_dma_ack     : std_logic;
  signal l2p_dma_stall   : std_logic;

  signal p2l_dma_adr     : std_logic_vector(31 downto 0);
  signal p2l_dma_dat_s2m : std_logic_vector(31 downto 0);
  signal p2l_dma_dat_m2s : std_logic_vector(31 downto 0);
  signal p2l_dma_sel     : std_logic_vector(3 downto 0);
  signal p2l_dma_cyc     : std_logic;
  signal p2l_dma_stb     : std_logic;
  signal p2l_dma_we      : std_logic;
  signal p2l_dma_ack     : std_logic;
  signal p2l_dma_stall   : std_logic;


--==============================================================================
-- Architecture begin (gn4124_core)
--==============================================================================
begin

  -----------------------------------------------------------------------------
  -- Unused entity port (kept for compatibility)
  -----------------------------------------------------------------------------
  debug_o        <= (others => '0');
  p2l_pll_locked <= '0';

  -----------------------------------------------------------------------------
  -- The Internal Core Clock is Derived from the P2L_CLK
  -----------------------------------------------------------------------------
  gen_clk_s3 : if g_IS_SPARTAN6 = false generate
    CLK_ibuf : IBUFGDS
      port map(
        I  => p2l_clk_p_i,
        IB => p2l_clk_n_i,
        O  => clk_p_buf);

    CLK_bufg : BUFG
      port map(
        I => clk_p_buf,
        O => clk_p_io);

    CLKn_ibuf : IBUFGDS
      port map(
        I  => p2l_clk_n_i,
        IB => p2l_clk_p_i,
        O  => clk_n_buf);

    CLKn_bufg : BUFG
      port map(
        I => clk_n_buf,
        O => clk_n_io);

    clk_sys   <= clk_p_io;
    clk_sys_n <= clk_n_io;
  end generate gen_clk_s3;

  gen_clk_s6 : if g_IS_SPARTAN6 = true generate
    clk_p_ibuf : IBUFGDS
      port map (
        I  => p2l_clk_p_i,
        IB => p2l_clk_n_i,
        O  => clk_p_buf
        );

    clk_p_bufio2 : BUFIO2
      generic map (
        DIVIDE        => 2,
        DIVIDE_BYPASS => true,          -- DIVCLK output sourced from Divider (FALSE) or from I input (TRUE).
        I_INVERT      => false,
        USE_DOUBLER   => true
        )
      port map (
        DIVCLK       => clk_sys_buf,
        IOCLK        => clk_p_io,
        SERDESSTROBE => open,
        I            => clk_p_buf
        );

    clk_n_bufio2 : BUFIO2
      generic map (
        DIVIDE        => 2,
        DIVIDE_BYPASS => true,          -- DIVCLK output sourced from Divider (FALSE) or from I input (TRUE).
        I_INVERT      => true,
        USE_DOUBLER   => true
        )
      port map (
        DIVCLK       => clk_sys_n_buf,
        IOCLK        => clk_n_io,
        SERDESSTROBE => open,
        I            => clk_p_buf
        );

    clk_sys_buf : BUFG
      port map (
        O => clk_sys,
        I => clk_sys_buf
        );

    clk_sys_n_buf : BUFG
      port map (
        O => clk_sys_n,
        I => clk_sys_n_buf
        );
  end generate gen_clk_s6;


  ------------------------------------------------------------------------------
  -- Reset aligned to core clock
  ------------------------------------------------------------------------------
  p_core_rst : process (clk_sys, rst_n_a_i)
  begin
    if rst_n_a_i = c_RST_ACTIVE then
      rst_reg <= c_RST_ACTIVE;
    elsif rising_edge(clk_sys) then
      rst_reg <= not(c_RST_ACTIVE);
    end if;
  end process p_core_rst;

  gen_rst : if g_IS_SPARTAN6 = false generate
    cmp_rst_buf : BUFG
      port map (
        I => rst_reg,
        O => rst_n
        );
  end generate gen_rst;

  gen_rst_s6 : if g_IS_SPARTAN6 = true generate
    rst_n <= rst_reg;
  end generate gen_rst_s6;


  ------------------------------------------------------------------------------
  -- IRQ pulse forward to GN4124 GPIO
  ------------------------------------------------------------------------------
  irq_p_o <= irq_p_i;

  --============================================================================
  -- P2L DataPath
  --============================================================================

  -----------------------------------------------------------------------------
  -- p2l_des: Deserialize the P2L DDR inputs
  -----------------------------------------------------------------------------
  cmp_p2l_des : p2l_des
    generic map (
      g_IS_SPARTAN6 => g_IS_SPARTAN6
      )
    port map
    (
      ---------------------------------------------------------
      -- Raw unprocessed reset from the GN412x
      rst_n_i     => rst_n,
      clk_sys_i   => clk_sys,
      clk_sys_n_i => clk_sys_n,
      clk_p_i     => clk_p_io,
      clk_n_i     => clk_n_io,

      ---------------------------------------------------------
      -- P2L Clock Domain
      --
      -- P2L Inputs
      p2l_valid_i  => p2l_valid_i,
      p2l_dframe_i => p2l_dframe_i,
      p2l_data_i   => p2l_data_i,

      ---------------------------------------------------------
      -- Core Clock Domain
      --
      -- DeSerialized Output
      p2l_valid_o  => des_pd_valid,
      p2l_dframe_o => des_pd_dframe,
      p2l_data_o   => des_pd_data
      );

  ------------------------------------------------------------------------------
  -- P2L local bus control signals
  ------------------------------------------------------------------------------
  -- de-asserted to pause transfer from GN4124
  p2l_rdy_o <= p2l_rdy_wbm and p2l_rdy_pdm;

  -----------------------------------------------------------------------------
  -- p2l_decode32: Decode the output of the p2l_des
  -----------------------------------------------------------------------------
  cmp_p2l_decode32 : p2l_decode32
    port map
    (
      ---------------------------------------------------------
      -- Clock/Reset
      clk_i   => clk_sys,
      rst_n_i => rst_n,

      ---------------------------------------------------------
      -- Input from the Deserializer
      --
      des_p2l_valid_i  => des_pd_valid,
      des_p2l_dframe_i => des_pd_dframe,
      des_p2l_data_i   => des_pd_data,

      ---------------------------------------------------------
      -- Decoder Outputs
      --
      -- Header
      p2l_hdr_start_o   => p2l_hdr_start,
      p2l_hdr_length_o  => p2l_hdr_length,
      p2l_hdr_cid_o     => p2l_hdr_cid,
      p2l_hdr_last_o    => p2l_hdr_last,
      p2l_hdr_stat_o    => p2l_hdr_stat,
      p2l_target_mrd_o  => p2l_target_mrd,
      p2l_target_mwr_o  => p2l_target_mwr,
      p2l_master_cpld_o => p2l_master_cpld,
      p2l_master_cpln_o => p2l_master_cpln,
      --
      -- Address
      p2l_addr_start_o  => p2l_addr_start,
      p2l_addr_o        => p2l_addr,
      --
      -- Data
      p2l_d_valid_o     => p2l_d_valid,
      p2l_d_last_o      => p2l_d_last,
      p2l_d_o           => p2l_d,
      p2l_be_o          => p2l_be
      );


  --===========================================================================
  -- Core Logic Blocks
  --===========================================================================

  -----------------------------------------------------------------------------
  -- Wishbone master
  -----------------------------------------------------------------------------
  cmp_wbmaster32 : wbmaster32
    generic map
    (
      g_BAR0_APERTURE => g_BAR0_APERTURE,
      g_WB_SLAVES_NB  => (g_CSR_WB_SLAVES_NB + 1)  -- +1 for the DMA controller (wb slave always present)
      )
    port map
    (
      ---------------------------------------------------------
      -- Clock/Reset
      clk_i   => clk_sys,
      rst_n_i => rst_n,

      ---------------------------------------------------------
      -- From P2L Decoder
      --
      -- Header
      pd_wbm_hdr_start_i  => p2l_hdr_start,
      pd_wbm_hdr_length_i => p2l_hdr_length,
      pd_wbm_hdr_cid_i    => p2l_hdr_cid,
      pd_wbm_target_mrd_i => p2l_target_mrd,
      pd_wbm_target_mwr_i => p2l_target_mwr,
      --
      -- Address
      pd_wbm_addr_start_i => p2l_addr_start,
      pd_wbm_addr_i       => p2l_addr,
      --
      -- Data
      pd_wbm_data_valid_i => p2l_d_valid,
      pd_wbm_data_last_i  => p2l_d_last,
      pd_wbm_data_i       => p2l_d,
      pd_wbm_be_i         => p2l_be,

      ---------------------------------------------------------
      -- P2L Control
      p_wr_rdy_o   => p_wr_rdy_o,
      p2l_rdy_o    => p2l_rdy_wbm,
      p_rd_d_rdy_i => p_rd_d_rdy,

      ---------------------------------------------------------
      -- To the L2P Interface
      wbm_arb_valid_o  => wbm_arb_valid,
      wbm_arb_dframe_o => wbm_arb_dframe,
      wbm_arb_data_o   => wbm_arb_data,
      wbm_arb_req_o    => wbm_arb_req,
      arb_wbm_gnt_i    => arb_wbm_gnt,

      ---------------------------------------------------------
      -- Wishbone Interface
      wb_clk_i => wb_clk_i,
      wb_adr_o => wb_adr,
      wb_dat_i => wb_dat_s2m,
      wb_dat_o => wb_dat_m2s,
      wb_sel_o => wb_sel,
      wb_cyc_o => wb_cyc,
      wb_stb_o => wb_stb,
      wb_we_o  => wb_we,
      wb_ack_i => wb_ack
      );

  wb_adr_o   <= wb_adr;
  wb_dat_s2m <= wb_dat_i & wb_dat_s2m_dma_ctrl;
  wb_dat_o   <= wb_dat_m2s;
  wb_sel_o   <= wb_sel;
  wb_cyc_o   <= wb_cyc(g_CSR_WB_SLAVES_NB downto 1);  -- wb_cyc(0) is for DMA controller
  wb_stb_o   <= wb_stb;
  wb_we_o    <= wb_we;
  wb_ack     <= wb_ack_i & wb_ack_dma_ctrl;

  -----------------------------------------------------------------------------
  -- DMA controller
  -----------------------------------------------------------------------------
  cmp_dma_controller : dma_controller
    port map
    (
      clk_i   => clk_sys,
      rst_n_i => rst_n,

      dma_ctrl_irq_o => dma_irq_o,

      dma_ctrl_carrier_addr_o => dma_ctrl_carrier_addr,
      dma_ctrl_host_addr_h_o  => dma_ctrl_host_addr_h,
      dma_ctrl_host_addr_l_o  => dma_ctrl_host_addr_l,
      dma_ctrl_len_o          => dma_ctrl_len,
      dma_ctrl_start_l2p_o    => dma_ctrl_start_l2p,
      dma_ctrl_start_p2l_o    => dma_ctrl_start_p2l,
      dma_ctrl_start_next_o   => dma_ctrl_start_next,
      dma_ctrl_done_i         => dma_ctrl_done,
      dma_ctrl_error_i        => dma_ctrl_error,
      dma_ctrl_byte_swap_o    => dma_ctrl_byte_swap,
      dma_ctrl_abort_o        => dma_ctrl_abort,

      next_item_carrier_addr_i => next_item_carrier_addr,
      next_item_host_addr_h_i  => next_item_host_addr_h,
      next_item_host_addr_l_i  => next_item_host_addr_l,
      next_item_len_i          => next_item_len,
      next_item_next_l_i       => next_item_next_l,
      next_item_next_h_i       => next_item_next_h,
      next_item_attrib_i       => next_item_attrib,
      next_item_valid_i        => next_item_valid,

      wb_clk_i => wb_clk_i,
      wb_adr_i => wb_adr(3 downto 0),
      wb_dat_o => wb_dat_s2m_dma_ctrl,
      wb_dat_i => wb_dat_m2s,
      wb_sel_i => wb_sel,
      wb_cyc_i => wb_cyc(0),
      wb_stb_i => wb_stb,
      wb_we_i  => wb_we,
      wb_ack_o => wb_ack_dma_ctrl
      );

  -- Status signals from DMA masters
  dma_ctrl_done  <= dma_ctrl_l2p_done or dma_ctrl_p2l_done;
  dma_ctrl_error <= dma_ctrl_l2p_error or dma_ctrl_p2l_error;

  -----------------------------------------------------------------------------
  -- L2P DMA master
  -----------------------------------------------------------------------------
  cmp_l2p_dma_master : l2p_dma_master
    port map
    (
      clk_i   => clk_sys,
      rst_n_i => rst_n,

      dma_ctrl_target_addr_i => dma_ctrl_carrier_addr,
      dma_ctrl_host_addr_h_i => dma_ctrl_host_addr_h,
      dma_ctrl_host_addr_l_i => dma_ctrl_host_addr_l,
      dma_ctrl_len_i         => dma_ctrl_len,
      dma_ctrl_start_l2p_i   => dma_ctrl_start_l2p,
      dma_ctrl_done_o        => dma_ctrl_l2p_done,
      dma_ctrl_error_o       => dma_ctrl_l2p_error,
      dma_ctrl_byte_swap_i   => dma_ctrl_byte_swap,
      dma_ctrl_abort_i       => dma_ctrl_abort,

      ldm_arb_valid_o  => ldm_arb_valid,
      ldm_arb_dframe_o => ldm_arb_dframe,
      ldm_arb_data_o   => ldm_arb_data,
      ldm_arb_req_o    => ldm_arb_req,
      arb_ldm_gnt_i    => arb_ldm_gnt,

      l2p_edb_o  => l2p_edb,
      l_wr_rdy_i => l_wr_rdy,
      l2p_rdy_i  => l2p_rdy,

      l2p_dma_clk_i   => dma_clk_i,
      l2p_dma_adr_o   => l2p_dma_adr,
      l2p_dma_dat_i   => l2p_dma_dat_s2m,
      l2p_dma_dat_o   => l2p_dma_dat_m2s,
      l2p_dma_sel_o   => l2p_dma_sel,
      l2p_dma_cyc_o   => l2p_dma_cyc,
      l2p_dma_stb_o   => l2p_dma_stb,
      l2p_dma_we_o    => l2p_dma_we,
      l2p_dma_ack_i   => l2p_dma_ack,
      l2p_dma_stall_i => l2p_dma_stall,
      p2l_dma_cyc_i   => p2l_dma_cyc
      );

  -----------------------------------------------------------------------------
  -- P2L DMA  master
  -----------------------------------------------------------------------------
  cmp_p2l_dma_master : p2l_dma_master
    port map
    (
      clk_i   => clk_sys,
      rst_n_i => rst_n,

      dma_ctrl_carrier_addr_i => dma_ctrl_carrier_addr,
      dma_ctrl_host_addr_h_i  => dma_ctrl_host_addr_h,
      dma_ctrl_host_addr_l_i  => dma_ctrl_host_addr_l,
      dma_ctrl_len_i          => dma_ctrl_len,
      dma_ctrl_start_p2l_i    => dma_ctrl_start_p2l,
      dma_ctrl_start_next_i   => dma_ctrl_start_next,
      dma_ctrl_done_o         => dma_ctrl_p2l_done,
      dma_ctrl_error_o        => dma_ctrl_p2l_error,
      dma_ctrl_byte_swap_i    => dma_ctrl_byte_swap,
      dma_ctrl_abort_i        => dma_ctrl_abort,

      pd_pdm_hdr_start_i   => p2l_hdr_start,
      pd_pdm_hdr_length_i  => p2l_hdr_length,
      pd_pdm_hdr_cid_i     => p2l_hdr_cid,
      pd_pdm_master_cpld_i => p2l_master_cpld,
      pd_pdm_master_cpln_i => p2l_master_cpln,

      pd_pdm_data_valid_i => p2l_d_valid,
      pd_pdm_data_last_i  => p2l_d_last,
      pd_pdm_data_i       => p2l_d,
      pd_pdm_be_i         => p2l_be,

      p2l_rdy_o  => p2l_rdy_pdm,
      rx_error_o => rx_error_o,

      pdm_arb_valid_o  => pdm_arb_valid,
      pdm_arb_dframe_o => pdm_arb_dframe,
      pdm_arb_data_o   => pdm_arb_data,
      pdm_arb_req_o    => pdm_arb_req,
      arb_pdm_gnt_i    => arb_pdm_gnt,

      p2l_dma_clk_i   => dma_clk_i,
      p2l_dma_adr_o   => p2l_dma_adr,
      p2l_dma_dat_i   => p2l_dma_dat_s2m,
      p2l_dma_dat_o   => p2l_dma_dat_m2s,
      p2l_dma_sel_o   => p2l_dma_sel,
      p2l_dma_cyc_o   => p2l_dma_cyc,
      p2l_dma_stb_o   => p2l_dma_stb,
      p2l_dma_we_o    => p2l_dma_we,
      p2l_dma_ack_i   => p2l_dma_ack,
      p2l_dma_stall_i => p2l_dma_stall,
      l2p_dma_cyc_i   => l2p_dma_cyc,

      next_item_carrier_addr_o => next_item_carrier_addr,
      next_item_host_addr_h_o  => next_item_host_addr_h,
      next_item_host_addr_l_o  => next_item_host_addr_l,
      next_item_len_o          => next_item_len,
      next_item_next_l_o       => next_item_next_l,
      next_item_next_h_o       => next_item_next_h,
      next_item_attrib_o       => next_item_attrib,
      next_item_valid_o        => next_item_valid
      );

  p_dma_wb_mux : process (p2l_dma_cyc, l2p_dma_cyc, l2p_dma_we, p2l_dma_we,
                          l2p_dma_stb, p2l_dma_stb, l2p_dma_sel, p2l_dma_sel,
                          l2p_dma_dat_m2s, p2l_dma_dat_m2s, l2p_dma_adr, p2l_dma_adr)
  begin
    if (l2p_dma_cyc = '1') then
      dma_adr_o <= l2p_dma_adr;
      dma_dat_o <= l2p_dma_dat_m2s;
      dma_sel_o <= l2p_dma_sel;
      dma_cyc_o <= l2p_dma_cyc;
      dma_stb_o <= l2p_dma_stb;
      dma_we_o  <= l2p_dma_we;
    elsif (p2l_dma_cyc = '1') then
      dma_adr_o <= p2l_dma_adr;
      dma_dat_o <= p2l_dma_dat_m2s;
      dma_sel_o <= p2l_dma_sel;
      dma_cyc_o <= p2l_dma_cyc;
      dma_stb_o <= p2l_dma_stb;
      dma_we_o  <= p2l_dma_we;
    else
      dma_adr_o <= (others => '0');
      dma_dat_o <= (others => '0');
      dma_sel_o <= (others => '0');
      dma_cyc_o <= '0';
      dma_stb_o <= '0';
      dma_we_o  <= '0';
    end if;
  end process p_dma_wb_mux;

  l2p_dma_dat_s2m <= dma_dat_i;
  p2l_dma_dat_s2m <= dma_dat_i;
  l2p_dma_ack     <= dma_ack_i;
  p2l_dma_ack     <= dma_ack_i;
  l2p_dma_stall   <= dma_stall_i;
  p2l_dma_stall   <= dma_stall_i;


  --===========================================================================
  -- L2P DataPath
  --===========================================================================

  -----------------------------------------------------------------------------
  -- Resync GN412x L2P status signals
  -----------------------------------------------------------------------------
  p_l2p_status_sync : process (clk_sys, rst_n)
  begin
    if(rst_n = c_RST_ACTIVE) then
      l_wr_rdy_t    <= "00";
      l_wr_rdy_t2   <= "00";
      l_wr_rdy      <= "00";
      p_rd_d_rdy_t  <= "00";
      p_rd_d_rdy_t2 <= "00";
      p_rd_d_rdy    <= "00";
      l2p_rdy_t     <= '0';
      l2p_rdy_t2    <= '0';
      l2p_rdy       <= '0';
      l2p_edb_o     <= '0';
      l2p_edb_t     <= '0';
      l2p_edb_t2    <= '0';
    elsif rising_edge(clk_sys) then
      -- must be checked before l2p_dma_master issues a master write
      l_wr_rdy_t  <= l_wr_rdy_i;
      l_wr_rdy_t2 <= l_wr_rdy_t;
      l_wr_rdy    <= l_wr_rdy_t2;

      -- must be checked before wbmaster32 sends read completion with data
      p_rd_d_rdy_t  <= p_rd_d_rdy_i;
      p_rd_d_rdy_t2 <= p_rd_d_rdy_t;
      p_rd_d_rdy    <= p_rd_d_rdy_t2;

      -- when de-asserted, l2p_dma_master must stop sending data (de-assert l2p_valid) within 3 (or 7 ?) clock cycles
      l2p_rdy_t  <= l2p_rdy_i;
      l2p_rdy_t2 <= l2p_rdy_t;
      l2p_rdy    <= l2p_rdy_t2;

      --assert when packet badly ends (e.g. dma abort)
      l2p_edb_t  <= l2p_edb;
      l2p_edb_t2 <= l2p_edb_t;
      l2p_edb_o  <= l2p_edb_t2;
    end if;
  end process p_l2p_status_sync;


  -----------------------------------------------------------------------------
  -- L2P arbiter, arbitrates access to GN4124
  -----------------------------------------------------------------------------
  cmp_l2p_arbiter : l2p_arbiter
    port map
    (
      ---------------------------------------------------------
      -- Clock/Reset
      clk_i   => clk_sys,
      rst_n_i => rst_n,

      ---------------------------------------------------------
      -- From Wishbone master (wbm) to arbiter (arb)
      wbm_arb_valid_i  => wbm_arb_valid,
      wbm_arb_dframe_i => wbm_arb_dframe,
      wbm_arb_data_i   => wbm_arb_data,
      wbm_arb_req_i    => wbm_arb_req,
      arb_wbm_gnt_o    => arb_wbm_gnt,

      ---------------------------------------------------------
      -- From DMA controller (pdm) to arbiter (arb)
      pdm_arb_valid_i  => pdm_arb_valid,
      pdm_arb_dframe_i => pdm_arb_dframe,
      pdm_arb_data_i   => pdm_arb_data,
      pdm_arb_req_i    => pdm_arb_req,
      arb_pdm_gnt_o    => arb_pdm_gnt,

      ---------------------------------------------------------
      -- From P2L DMA master (pdm) to arbiter (arb)
      ldm_arb_valid_i  => ldm_arb_valid,
      ldm_arb_dframe_i => ldm_arb_dframe,
      ldm_arb_data_i   => ldm_arb_data,
      ldm_arb_req_i    => ldm_arb_req,
      arb_ldm_gnt_o    => arb_ldm_gnt,

      ---------------------------------------------------------
      -- From arbiter (arb) to serializer (ser)
      arb_ser_valid_o  => arb_ser_valid,
      arb_ser_dframe_o => arb_ser_dframe,
      arb_ser_data_o   => arb_ser_data
      );



  -----------------------------------------------------------------------------
  -- L2P_SER: Generate the L2P DDR Outputs
  -----------------------------------------------------------------------------
  cmp_l2p_ser : l2p_ser
    generic map (
      g_IS_SPARTAN6 => g_IS_SPARTAN6
      )
    port map
    (
      ---------------------------------------------------------
      -- clk_p Clock Domain Inputs
      clk_sys_i   => clk_sys,
      clk_sys_n_i => clk_sys_n,
      clk_p_i     => clk_p_io,
      clk_n_i     => clk_n_io,
      rst_n_i     => rst_n,

      ---------------------------------------------------------
      -- DeSerialized Output
      l2p_valid_i  => arb_ser_valid,
      l2p_dframe_i => arb_ser_dframe,
      l2p_data_i   => arb_ser_data,

      ---------------------------------------------------------
      -- SER Outputs
      --
      -- P2L Inputs
      l2p_clk_p_o  => l2p_clk_p_o,
      l2p_clk_n_o  => l2p_clk_n_o,
      l2p_valid_o  => l2p_valid_o,
      l2p_dframe_o => l2p_dframe_o,
      l2p_data_o   => l2p_data_o
      );


end rtl;
--==============================================================================
-- Architecture end (gn4124_core)
--==============================================================================

