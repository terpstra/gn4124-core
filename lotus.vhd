--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: LOTUS (lotus.vhd)
--
-- author:
--
-- date:
--
-- version: 0.1
--
-- description: Wrapper for the Lotus Project to drop into the FPGA on the
--              Gullwing board
--
-- dependencies:
--
--------------------------------------------------------------------------------
-- last changes: <date> <initials> <log>
-- <extended description>
--------------------------------------------------------------------------------
-- TODO: -
--       -
--       -
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.lotus_util.all;

library UNISIM;
use UNISIM.vcomponents.all;


entity LOTUS is
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
end LOTUS;

architecture BEHAVIOUR of LOTUS is

-----------------------------------------------------------------------------
  component gn4124_core
-----------------------------------------------------------------------------
    port
      (
        LED         : out std_logic_vector(7 downto 0);
        ---------------------------------------------------------
        -- Clock/Reset from GN412x
        --      L_CLKp                 : in   std_logic;                     -- Running at 100 or 200 Mhz
        --      L_CLKn                 : in   std_logic;                     -- Running at 100 or 200 Mhz
        sys_clk_i   : in  std_logic;
        sys_rst_n_i : in  std_logic;

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
        p_wr_req_o   : in  std_logic_vector(1 downto 0);   -- PCIe Write Request
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
        -- Target Interface (Wishbone master)
        wb_adr_o   : out std_logic_vector(31 downto 0);
        wb_dat_i   : in  std_logic_vector(31 downto 0);  -- Data in
        wb_dat_o   : out std_logic_vector(31 downto 0);  -- Data out
        wb_sel_o   : out std_logic_vector(3 downto 0);   -- Byte select
        wb_cyc_o   : out std_logic;
        wb_stb_o   : out std_logic;
        wb_we_o    : out std_logic;
        wb_ack_i   : in  std_logic;
        wb_stall_i : in  std_logic;

        ---------------------------------------------------------
        -- L2P DMA Interface (Pipelined Wishbone master)
        dma_adr_o   : out std_logic_vector(31 downto 0);
        dma_dat_i   : in  std_logic_vector(31 downto 0);  -- Data in
        dma_dat_o   : out std_logic_vector(31 downto 0);  -- Data out
        dma_sel_o   : out std_logic_vector(3 downto 0);   -- Byte select
        dma_cyc_o   : out std_logic;
        dma_stb_o   : out std_logic;
        dma_we_o    : out std_logic;
        dma_ack_i   : in  std_logic;
        dma_stall_i : in  std_logic                       -- for pipelined Wishbone
        );
  end component;  --  gn4124_core

--=============================================================================================--
-- Internal Signals
--=============================================================================================--

  -- Internal 1X clock operating at the same rate as LCLK
  signal ICLK  : std_logic;
  signal ICLKn : std_logic;
  -- RESET for all ICLK logic
  signal IRST  : std_logic;
  signal L_RST : std_logic;

  signal wb_adr_o   : std_logic_vector(31 downto 0);
  signal wb_dat_i   : std_logic_vector(31 downto 0);
  signal wb_dat_o   : std_logic_vector(31 downto 0);
  signal wb_sel_o   : std_logic_vector(3 downto 0);
  signal wb_cyc_o   : std_logic;
  signal wb_stb_o   : std_logic;
  signal wb_we_o    : std_logic;
  signal wb_ack_i   : std_logic;
  signal wb_stall_i : std_logic;

  signal dma_adr_o   : std_logic_vector(31 downto 0);
  signal dma_dat_i   : std_logic_vector(31 downto 0);
  signal dma_dat_o   : std_logic_vector(31 downto 0);
  signal dma_sel_o   : std_logic_vector(3 downto 0);
  signal dma_cyc_o   : std_logic;
  signal dma_stb_o   : std_logic;
  signal dma_we_o    : std_logic;
  signal dma_ack_i   : std_logic;
  signal dma_stall_i : std_logic;

-- TEST: L2P DMA interface
  type   wb_state_type is (IDLE, ACK, ST1);
  signal wb_current_state : wb_state_type;
  signal wb_data_cnt      : unsigned(31 downto 0);

  signal l_clk : std_logic;

  signal led0 : std_logic_vector(7 downto 0);

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
  -- Assign static outputs
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
  u_gn4124_core : gn4124_core
    port map
    (
      LED         => led,
      ---------------------------------------------------------
      -- Clock/Reset from GN412x
--      L_CLKp                 => L_CLKp,
--      L_CLKn                 => L_CLKn,
      sys_clk_i   => l_clk,
      sys_rst_n_i => L_RST_N,

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
      p_wr_req_o => P_WR_REQ,
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
      -- Target Interface (Wishbone master)
      wb_adr_o   => wb_adr_o,
      wb_dat_i   => wb_dat_i,
      wb_dat_o   => wb_dat_o,
      wb_sel_o   => wb_sel_o,
      wb_cyc_o   => wb_cyc_o,
      wb_stb_o   => wb_stb_o,
      wb_we_o    => wb_we_o,
      wb_ack_i   => wb_ack_i,
      wb_stall_i => wb_stall_i,

      ---------------------------------------------------------
      -- L2P DMA Interface (Pipelined Wishbone master)
      dma_adr_o   => dma_adr_o,
      dma_dat_i   => dma_dat_i,
      dma_dat_o   => dma_dat_o,
      dma_sel_o   => dma_sel_o,
      dma_cyc_o   => dma_cyc_o,
      dma_stb_o   => dma_stb_o,
      dma_we_o    => dma_we_o,
      dma_ack_i   => dma_ack_i,
      dma_stall_i => dma_stall_i
      );

  ------------------------------------------------------------------------------
  -- UNUSED local wishbone bus
  ------------------------------------------------------------------------------
  wb_ack_i   <= '0';
  wb_stall_i <= '0';
  wb_dat_i   <= "00000000000000000000000000000000";



  -----------------------------------------------------------------------------
  -- Simulation DMA Wisbbone
  -----------------------------------------------------------------------------

  -- TEST: L2P DMA interface
  -- process (L_CLKp, L_RST_N)
  --  variable wb_next_state : wb_state_type;
  --begin
  --  if(L_RST_N = '0') then
  --  elsif rising_edge(L_CLKp) then
  --    if (L2P_RDY = '0') then
  --    end if;
  --    if (L_WR_RDY(0) = '0') then
  --    end if;
  --    if (L_WR_RDY(1) = '0') then
  --    end if;
  --  end if;
  --end process;

  process (l_clk, L_RST_N)
    variable wb_next_state : wb_state_type;
  begin
    if(L_RST_N = '0') then
      wb_current_state <= IDLE;
      wb_data_cnt      <= x"AB340000";
    elsif rising_edge(l_clk) then
      case wb_current_state is
        -----------------------------------------------------------------
        -- IDLE
        -----------------------------------------------------------------
        when IDLE =>
          if (dma_stb_o = '1' and wb_data_cnt(0) = '0') then
            wb_next_state := ACK;
          elsif (dma_stb_o = '1' and wb_data_cnt(0) = '1') then
            wb_next_state := ST1;
          else
            wb_next_state := IDLE;
          end if;

          -----------------------------------------------------------------
          -- Send ACK signal
          -----------------------------------------------------------------
        when ACK =>
          wb_data_cnt <= wb_data_cnt + 1;
          if (dma_stb_o = '0') then
            wb_next_state := IDLE;
          elsif (wb_data_cnt(0) = '0') then
            wb_next_state := ST1;
          else
            wb_next_state := ACK;
          end if;

          -----------------------------------------------------------------
          -- One cycle delay
          -----------------------------------------------------------------
        when ST1 =>
          wb_next_state := ACK;

          -----------------------------------------------------------------
          -- OTHERS
          -----------------------------------------------------------------
        when others =>
          wb_next_state := IDLE;
      end case;
      wb_current_state <= wb_next_state;
    end if;
  end process;

  dma_stall_i <= '1' when ((wb_current_state = ACK and wb_data_cnt(0) = '0' and dma_stb_o = '1')
                           or (wb_current_state = IDLE and wb_data_cnt(0) = '1' and dma_stb_o = '1'))
                 else '0';

  dma_dat_i <= std_logic_vector(wb_data_cnt) when wb_current_state = ACK
               else x"00000000";

  dma_ack_i <= '1' when wb_current_state = ACK
               else '0';



end BEHAVIOUR;


