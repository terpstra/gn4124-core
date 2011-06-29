--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: gw_wrapper (gullwing_wrapper.vhd)
--
-- author: Matthieu Cattin (matthieu.cattin@cern.ch)
--
-- date: 20-10-2010
--
-- version: 0.1
--
-- description: Wrapper for the GN4124 core to drop into the FPGA on the
--              Gullwing board
--
-- dependencies:
--
--------------------------------------------------------------------------------
-- last changes: 21-10-2010 (mcattin) Add a RAM block to perform  bi-directional
--                                    DMA tests.
--------------------------------------------------------------------------------
-- TODO: - 
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gn4124_core_pkg.all;

library UNISIM;
use UNISIM.vcomponents.all;


entity gw_wrapper is
  generic
    (
      TAR_ADDR_WDTH : integer := 13     -- not used for this project
      );
  port
    (
      -- From ASIC Local bus
      L_CLKp : in std_logic;            -- Running at 100 or 200 Mhz
      L_CLKn : in std_logic;            -- Running at 100 or 200 Mhz

      L_RST_N   : in std_logic;
      L_RST33_N : in std_logic;

      SYS_CLKB   : in std_logic;        -- Running at 161 Mhz (for the SDRAM)
      SYS_CLK    : in std_logic;        -- Running at 161 Mhz (for the SDRAM)
      RESET_IN_N : in std_logic;

      -- General Purpose Interface
      GPIO : inout std_logic_vector(15 downto 0);  -- General Purpose Input/Output

      -- PCIe to Local [Inbound Data] - RX
      P2L_RDY    : out std_logic;                      -- Rx Buffer Full Flag
      P2L_CLKn   : in  std_logic;                      -- Receiver Source Synchronous Clock-
      P2L_CLKp   : in  std_logic;                      -- Receiver Source Synchronous Clock+
      P2L_DATA   : in  std_logic_vector(15 downto 0);  -- Parallel receive data
      P2L_DFRAME : in  std_logic;                      -- Receive Frame
      P2L_VALID  : in  std_logic;                      -- Receive Data Valid

      -- Inbound Buffer Request/Status
      P_WR_REQ : in  std_logic_vector(1 downto 0);  -- PCIe Write Request
      P_WR_RDY : out std_logic_vector(1 downto 0);  -- PCIe Write Ready
      RX_ERROR : out std_logic;                     -- Receive Error

      -- Local to Parallel [Outbound Data] - TX
      L2P_DATA   : out std_logic_vector(15 downto 0);  -- Parallel transmit data
      L2P_DFRAME : out std_logic;                      -- Transmit Data Frame
      L2P_VALID  : out std_logic;                      -- Transmit Data Valid
      L2P_CLKn   : out std_logic;                      -- Transmitter Source Synchronous Clock-
      L2P_CLKp   : out std_logic;                      -- Transmitter Source Synchronous Clock+
      L2P_EDB    : out std_logic;                      -- Packet termination and discard

      -- Outbound Buffer Status
      L2P_RDY    : in std_logic;                     -- Tx Buffer Full Flag
      L_WR_RDY   : in std_logic_vector(1 downto 0);  -- Local-to-PCIe Write
      P_RD_D_RDY : in std_logic_vector(1 downto 0);  -- PCIe-to-Local Read Response Data Ready
      TX_ERROR   : in std_logic;                     -- Transmit Error
      VC_RDY     : in std_logic_vector(1 downto 0);  -- Channel ready

      -- DDR2 SDRAM Interface
      CNTRL0_DDR2_DQ         : inout std_logic_vector(31 downto 0);
      CNTRL0_DDR2_A          : out   std_logic_vector(12 downto 0);
      CNTRL0_DDR2_BA         : out   std_logic_vector(1 downto 0);
      CNTRL0_DDR2_CKE        : out   std_logic;
      CNTRL0_DDR2_CS_N       : out   std_logic;
      CNTRL0_DDR2_RAS_N      : out   std_logic;
      CNTRL0_DDR2_CAS_N      : out   std_logic;
      CNTRL0_DDR2_WE_N       : out   std_logic;
      CNTRL0_DDR2_ODT        : out   std_logic;
      CNTRL0_DDR2_DM         : out   std_logic_vector(3 downto 0);
      CNTRL0_RST_DQS_DIV_IN  : in    std_logic;
      CNTRL0_RST_DQS_DIV_OUT : out   std_logic;
      CNTRL0_DDR2_DQS        : inout std_logic_vector(3 downto 0);
      CNTRL0_DDR2_DQS_N      : inout std_logic_vector(3 downto 0);
      CNTRL0_DDR2_CK         : out   std_logic_vector(1 downto 0);
      CNTRL0_DDR2_CK_N       : out   std_logic_vector(1 downto 0);

      MIC_CLKA : out   std_logic;
      MIC_CLKB : out   std_logic;
      MIC_DATA : inout std_logic_vector(31 downto 0);

      -- GN1559 related
      SER              : out std_logic_vector(19 downto 0);
      SER_H            : out std_logic;
      SER_V            : out std_logic;
      SER_F            : out std_logic;
      SER_SMPTE_BYPASS : out std_logic;
      SER_DVB_ASI      : out std_logic;
      SER_SDHDN        : out std_logic;

      -- GN1531 de-serializer6
      DES              : in    std_logic_vector(19 downto 0);
      DES_PCLK         : in    std_logic;
      DES_H            : in    std_logic;
      DES_V            : in    std_logic;
      DES_F            : in    std_logic;
      DES_SMPTE_BYPASS : inout std_logic;
      DES_DVB_ASI      : inout std_logic;
      DES_SDHDN        : inout std_logic;

      -- GN4911 Timing Generator
      SYNCSEPERATOR_H_TIMING : in std_logic;
      SYNCSEPERATOR_V_TIMING : in std_logic;
      SYNCSEPERATOR_F_TIMING : in std_logic;

      -- I2C
      SDA : inout std_logic;
      SCL : in    std_logic;

      -- Debug Switches
      DEBUG : in  std_logic_vector(7 downto 0);
      LED   : out std_logic_vector(7 downto 0);

      -- SPI
      SPI_SCK  : in  std_logic;
      SPI_SS   : in  std_logic_vector(4 downto 0);
      SPI_MOSI : in  std_logic;
      SPI_MISO : out std_logic;

      PCLK_4911_1531   : in  std_logic;  -- requested by Jared
      GS4911_HOST_B    : out std_logic;
      GS4911_SCLK      : out std_logic;
      GS4911_SDIN      : out std_logic;
      GS4911_SDOUT     : in  std_logic;
      GS4911_CSB       : out std_logic;
      GS4911_LOCK_LOST : in  std_logic;  -- requested by Jared
      GS4911_REF_LOST  : in  std_logic   -- requested by Jared
      );
end gw_wrapper;

architecture rtl of gw_wrapper is

  ------------------------------------------------------------------------------
  -- Components declaration
  ------------------------------------------------------------------------------

  component gn4124_core
    generic(
      g_BAR0_APERTURE     : integer := 20;  -- BAR0 aperture, defined in GN4124 PCI_BAR_CONFIG register (0x80C)
                                            -- => number of bits to address periph on the board
      g_CSR_WB_SLAVES_NB  : integer := 1;   -- Number of CSR wishbone slaves
      g_DMA_WB_SLAVES_NB  : integer := 1;   -- Number of DMA wishbone slaves
      g_DMA_WB_ADDR_WIDTH : integer := 26   -- DMA wishbone address bus width
      );
    port
      (
        ---------------------------------------------------------
        -- Asynchronous reset from GN4124
        rst_n_a_i : in std_logic;

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
        vc_rdy_i     : in  std_logic_vector(1 downto 0);   -- Channel ready

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
  end component;  --  gn4124_core

  component dummy_stat_regs_wb_slave
    port (
      rst_n_i                 : in  std_logic;
      wb_clk_i                : in  std_logic;
      wb_addr_i               : in  std_logic_vector(1 downto 0);
      wb_data_i               : in  std_logic_vector(31 downto 0);
      wb_data_o               : out std_logic_vector(31 downto 0);
      wb_cyc_i                : in  std_logic;
      wb_sel_i                : in  std_logic_vector(3 downto 0);
      wb_stb_i                : in  std_logic;
      wb_we_i                 : in  std_logic;
      wb_ack_o                : out std_logic;
      dummy_stat_reg_1_i      : in  std_logic_vector(31 downto 0);
      dummy_stat_reg_2_i      : in  std_logic_vector(31 downto 0);
      dummy_stat_reg_3_i      : in  std_logic_vector(31 downto 0);
      dummy_stat_reg_switch_i : in  std_logic_vector(31 downto 0)
      );
  end component;

  component dummy_ctrl_regs_wb_slave
    port (
      rst_n_i         : in  std_logic;
      wb_clk_i        : in  std_logic;
      wb_addr_i       : in  std_logic_vector(1 downto 0);
      wb_data_i       : in  std_logic_vector(31 downto 0);
      wb_data_o       : out std_logic_vector(31 downto 0);
      wb_cyc_i        : in  std_logic;
      wb_sel_i        : in  std_logic_vector(3 downto 0);
      wb_stb_i        : in  std_logic;
      wb_we_i         : in  std_logic;
      wb_ack_o        : out std_logic;
      dummy_reg_1_o   : out std_logic_vector(31 downto 0);
      dummy_reg_2_o   : out std_logic_vector(31 downto 0);
      dummy_reg_3_o   : out std_logic_vector(31 downto 0);
      dummy_reg_led_o : out std_logic_vector(31 downto 0)
      );
  end component;

  component ram_2048x32
    port (
      clka  : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(10 downto 0);
      dina  : in  std_logic_vector(31 downto 0);
      douta : out std_logic_vector(31 downto 0)
      );
  end component;

  ------------------------------------------------------------------------------
  -- Constants declaration
  ------------------------------------------------------------------------------
  constant c_BAR0_APERTURE     : integer := 20;
  constant c_CSR_WB_SLAVES_NB  : integer := 2;
  constant c_DMA_WB_SLAVES_NB  : integer := 1;
  constant c_DMA_WB_ADDR_WIDTH : integer := 26;

  ------------------------------------------------------------------------------
  -- Signals declaration
  ------------------------------------------------------------------------------

  -- LCLK from GN4124 used as system clock
  signal l_clk : std_logic;

  -- CSR wishbone bus
  signal wb_adr   : std_logic_vector(c_BAR0_APERTURE-log2_ceil(c_CSR_WB_SLAVES_NB+1)-1 downto 0);
  signal wb_dat_i : std_logic_vector((32*c_CSR_WB_SLAVES_NB)-1 downto 0);
  signal wb_dat_o : std_logic_vector(31 downto 0);
  signal wb_sel   : std_logic_vector(3 downto 0);
  signal wb_cyc   : std_logic_vector(c_CSR_WB_SLAVES_NB-1 downto 0);
  signal wb_stb   : std_logic;
  signal wb_we    : std_logic;
  signal wb_ack   : std_logic_vector(c_CSR_WB_SLAVES_NB-1 downto 0);

  -- DMA wishbone bus
  signal dma_adr_o   : std_logic_vector(31 downto 0);
  signal dma_dat_i   : std_logic_vector((32*c_DMA_WB_SLAVES_NB)-1 downto 0);
  signal dma_dat_o   : std_logic_vector(31 downto 0);
  signal dma_sel_o   : std_logic_vector(3 downto 0);
  signal dma_cyc_o   : std_logic;       --_vector(c_DMA_WB_SLAVES_NB-1 downto 0);
  signal dma_stb_o   : std_logic;
  signal dma_we_o    : std_logic;
  signal dma_ack_i   : std_logic;       --_vector(c_DMA_WB_SLAVES_NB-1 downto 0);
  signal dma_stall_i : std_logic;       --_vector(c_DMA_WB_SLAVES_NB-1 downto 0);
  signal ram_we      : std_logic_vector(0 downto 0);

  -- Interrupts stuff
  signal irq_sources   : std_logic_vector(1 downto 0);
  signal irq_to_gn4124 : std_logic;

  -- CSR whisbone slaves for test
  signal dummy_stat_reg_1      : std_logic_vector(31 downto 0);
  signal dummy_stat_reg_2      : std_logic_vector(31 downto 0);
  signal dummy_stat_reg_3      : std_logic_vector(31 downto 0);
  signal dummy_stat_reg_switch : std_logic_vector(31 downto 0);

  signal dummy_ctrl_reg_1   : std_logic_vector(31 downto 0);
  signal dummy_ctrl_reg_2   : std_logic_vector(31 downto 0);
  signal dummy_ctrl_reg_3   : std_logic_vector(31 downto 0);
  signal dummy_ctrl_reg_led : std_logic_vector(31 downto 0);

begin

  ------------------------------------------------------------------------------
  -- System clock from gennum LCLK
  ------------------------------------------------------------------------------
  cmp_sysclk_buf : IBUFDS
    generic map (
      DIFF_TERM    => false,            -- Differential Termination
      IBUF_LOW_PWR => true,             -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
      IOSTANDARD   => "DEFAULT")
    port map (
      O  => l_clk,                      -- Buffer output
      I  => L_CLKp,                     -- Diff_p buffer input (connect directly to top-level port)
      IB => L_CLKn                      -- Diff_n buffer input (connect directly to top-level port)
      );


  ------------------------------------------------------------------------------
  -- Assign static (unused) outputs
  ------------------------------------------------------------------------------
  GS4911_CSB       <= '1';
  SER_SDHDN        <= '0';
  SER_H            <= '0';
  SER_V            <= '0';
  SER_F            <= '0';
  SPI_MISO         <= '0';
  GS4911_SCLK      <= '0';
  GS4911_SDIN      <= '0';
  SER_DVB_ASI      <= '0';
  GS4911_HOST_B    <= '0';
  SER_SMPTE_BYPASS <= '0';

  ------------------------------------------------------------------------------
  -- GN4124 interface
  ------------------------------------------------------------------------------
  cmp_gn4124_core : gn4124_core
    generic map (
      g_BAR0_APERTURE     => c_BAR0_APERTURE,
      g_CSR_WB_SLAVES_NB  => c_CSR_WB_SLAVES_NB,
      g_DMA_WB_SLAVES_NB  => c_DMA_WB_SLAVES_NB,
      g_DMA_WB_ADDR_WIDTH => c_DMA_WB_ADDR_WIDTH
      )
    port map
    (
      ---------------------------------------------------------
      -- Reset from GN4124
      rst_n_a_i => L_RST_N,

      ---------------------------------------------------------
      -- P2L Direction
      --
      -- Source Sync DDR related signals
      p2l_clk_p_i  => P2L_CLKp,
      p2l_clk_n_i  => P2L_CLKn,
      p2l_data_i   => P2L_DATA,
      p2l_dframe_i => P2L_DFRAME,
      p2l_valid_i  => P2L_VALID,

      -- P2L Control
      p2l_rdy_o  => P2L_RDY,
      p_wr_req_i => P_WR_REQ,
      p_wr_rdy_o => P_WR_RDY,
      rx_error_o => RX_ERROR,

      ---------------------------------------------------------
      -- L2P Direction
      --
      -- Source Sync DDR related signals
      l2p_clk_p_o  => L2P_CLKp,
      l2p_clk_n_o  => L2P_CLKn,
      l2p_data_o   => L2P_DATA,
      l2p_dframe_o => L2P_DFRAME,
      l2p_valid_o  => L2P_VALID,
      l2p_edb_o    => L2P_EDB,

      -- L2P Control
      l2p_rdy_i    => L2P_RDY,
      l_wr_rdy_i   => L_WR_RDY,
      p_rd_d_rdy_i => P_RD_D_RDY,
      tx_error_i   => TX_ERROR,
      vc_rdy_i     => VC_RDY,

      ---------------------------------------------------------
      -- Interrupt interface
      dma_irq_o => irq_sources,
      irq_p_i   => irq_to_gn4124,
      irq_p_o   => GPIO(8),

      ---------------------------------------------------------
      -- Target Interface (Wishbone master)
      wb_clk_i => l_clk,
      wb_adr_o => wb_adr,
      wb_dat_o => wb_dat_o,
      wb_sel_o => wb_sel,
      wb_stb_o => wb_stb,
      wb_we_o  => wb_we,
      wb_cyc_o => wb_cyc,
      wb_dat_i => wb_dat_i,
      wb_ack_i => wb_ack,

      ---------------------------------------------------------
      -- L2P DMA Interface (Pipelined Wishbone master)
      dma_clk_i   => l_clk,
      dma_adr_o   => dma_adr_o,
      dma_dat_o   => dma_dat_o,
      dma_sel_o   => dma_sel_o,
      dma_stb_o   => dma_stb_o,
      dma_we_o    => dma_we_o,
      dma_cyc_o   => dma_cyc_o,
      dma_dat_i   => dma_dat_i,
      dma_ack_i   => dma_ack_i,
      dma_stall_i => dma_stall_i
      );


  ------------------------------------------------------------------------------
  -- CSR wishbone bus slaves
  ------------------------------------------------------------------------------
  cmp_dummy_stat_regs : dummy_stat_regs_wb_slave
    port map(
      rst_n_i                 => L_RST_N,
      wb_clk_i                => l_clk,
      wb_addr_i               => wb_adr(1 downto 0),
      wb_data_i               => wb_dat_o,
      wb_data_o               => wb_dat_i(31 downto 0),
      wb_cyc_i                => wb_cyc(0),
      wb_sel_i                => wb_sel,
      wb_stb_i                => wb_stb,
      wb_we_i                 => wb_we,
      wb_ack_o                => wb_ack(0),
      dummy_stat_reg_1_i      => dummy_stat_reg_1,
      dummy_stat_reg_2_i      => dummy_stat_reg_2,
      dummy_stat_reg_3_i      => dummy_stat_reg_3,
      dummy_stat_reg_switch_i => dummy_stat_reg_switch
      );

  dummy_stat_reg_1      <= X"DEADBABE";
  dummy_stat_reg_2      <= X"BEEFFACE";
  dummy_stat_reg_3      <= X"12345678";
  dummy_stat_reg_switch <= X"000000" & DEBUG;

  cmp_dummy_ctrl_regs : dummy_ctrl_regs_wb_slave
    port map(
      rst_n_i         => L_RST_N,
      wb_clk_i        => l_clk,
      wb_addr_i       => wb_adr(1 downto 0),
      wb_data_i       => wb_dat_o,
      wb_data_o       => wb_dat_i(63 downto 32),
      wb_cyc_i        => wb_cyc(1),
      wb_sel_i        => wb_sel,
      wb_stb_i        => wb_stb,
      wb_we_i         => wb_we,
      wb_ack_o        => wb_ack(1),
      dummy_reg_1_o   => dummy_ctrl_reg_1,
      dummy_reg_2_o   => dummy_ctrl_reg_2,
      dummy_reg_3_o   => dummy_ctrl_reg_3,
      dummy_reg_led_o => dummy_ctrl_reg_led
      );

  LED <= dummy_ctrl_reg_led(7 downto 0);

  ------------------------------------------------------------------------------
  -- DMA wishbone bus connected to a DPRAM
  ------------------------------------------------------------------------------
  process (l_clk, L_RST_N)
  begin
    if (L_RST_N = '0') then
      dma_ack_i <= '0';
    elsif rising_edge(l_clk) then
      if (dma_cyc_o = '1' and dma_stb_o = '1') then
        dma_ack_i <= '1';
      else
        dma_ack_i <= '0';
      end if;
    end if;
  end process;

  dma_stall_i <= '0';

  ram_we(0) <= dma_we_o and dma_cyc_o and dma_stb_o;

  cmp_test_ram : ram_2048x32
    port map (
      clka  => l_clk,
      wea   => ram_we,
      addra => dma_adr_o(10 downto 0),
      dina  => dma_dat_o,
      douta => dma_dat_i
      );


  ------------------------------------------------------------------------------
  -- Interrupt stuff
  ------------------------------------------------------------------------------
  -- just forward irq pulses for test
  irq_to_gn4124 <= irq_sources(1) or irq_sources(0) or dummy_ctrl_reg_1(0);


end rtl;


