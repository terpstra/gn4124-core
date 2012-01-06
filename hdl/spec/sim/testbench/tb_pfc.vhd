library IEEE;
use IEEE.std_logic_1164.all;
use std.textio.all;

--library std_developerskit;
--use std_developerskit.std_iopak.all;

use work.util.all;
use work.textutil.all;

--############################################################################
--############################################################################
--==========================================================================--
--
-- *Module      : tb_pfc
--
-- *Description : Test Bench for the GN4124 BFM + PFC Design
--
-- *History
--
--==========================================================================--
--############################################################################
--############################################################################

entity TB_PFC is
  generic
    (
      T_LCLK : time := 30 ns            -- Default LCLK Clock Period 
      );
end TB_PFC;

architecture TEST of TB_PFC is

--###########################################################################
--###########################################################################
--##
--## Component Declairations
--##
--###########################################################################
--###########################################################################
-----------------------------------------------------------------------------
-- GN4124 Local Bus Model
-----------------------------------------------------------------------------
  component GN412X_BFM
    generic
      (
        STRING_MAX     : integer := 256;           -- Command string maximum length
        T_LCLK         : time    := 10 ns;         -- Local Bus Clock Period
        T_P2L_CLK_DLY  : time    := 2 ns;          -- Delay from LCLK to P2L_CLK
        INSTANCE_LABEL : string  := "GN412X_BFM";  -- Label string to be used as a prefix for messages from the model
        MODE_PRIMARY   : boolean := true           -- TRUE for BFM acting as GN412x, FALSE for BFM acting as the DUT
        );
    port
      (
        --=========================================================--
        -------------------------------------------------------------
        -- CMD_ROUTER Interface
        --
        CMD                : in    string(1 to STRING_MAX);
        CMD_REQ            : in    bit;
        CMD_ACK            : out   bit;
        CMD_CLOCK_EN       : in    boolean;
        --=========================================================--
        -------------------------------------------------------------
        -- GN412x Signal I/O
        -------------------------------------------------------------
        -- This is the reset input to the BFM
        --
        RSTINn             : in    std_logic;
        -------------------------------------------------------------
        -- Reset outputs to DUT
        --
        RSTOUT18n          : out   std_logic;
        RSTOUT33n          : out   std_logic;
        -------------------------------------------------------------
        ----------------- Local Bus Clock ---------------------------
        -------------------------------------------------------------  __ Direction for primary mode
        --                                                            / \
        LCLK, LCLKn        : inout std_logic;      -- Out
        -------------------------------------------------------------
        ----------------- Local-to-PCI Dataflow ---------------------
        -------------------------------------------------------------
        -- Transmitter Source Synchronous Clock.
        --
        L2P_CLKp, L2P_CLKn : inout std_logic;      -- In  
        -------------------------------------------------------------
        -- L2P DDR Link
        --
        L2P_DATA           : inout std_logic_vector(15 downto 0);  -- In  -- Parallel Transmit Data.
        L2P_DFRAME         : inout std_logic;  -- In  -- Transmit Data Frame.
        L2P_VALID          : inout std_logic;  -- In  -- Transmit Data Valid. 
        L2P_EDB            : inout std_logic;  -- In  -- End-of-Packet Bad Flag.
        -------------------------------------------------------------
        -- L2P SDR Controls
        --
        L_WR_RDY           : inout std_logic_vector(1 downto 0);  -- Out -- Local-to-PCIe Write.
        P_RD_D_RDY         : inout std_logic_vector(1 downto 0);  -- Out -- PCIe-to-Local Read Response Data Ready.
        L2P_RDY            : inout std_logic;  -- Out -- Tx Buffer Full Flag.
        TX_ERROR           : inout std_logic;  -- Out -- Transmit Error.
        -------------------------------------------------------------
        ----------------- PCIe-to-Local Dataflow ---------------------
        -------------------------------------------------------------
        -- Transmitter Source Synchronous Clock.
        --
        P2L_CLKp, P2L_CLKn : inout std_logic;  -- Out -- P2L Source Synchronous Clock.
        -------------------------------------------------------------
        -- P2L DDR Link
        --
        P2L_DATA           : inout std_logic_vector(15 downto 0);  -- Out -- Parallel Receive Data.
        P2L_DFRAME         : inout std_logic;  -- Out -- Receive Frame.
        P2L_VALID          : inout std_logic;  -- Out -- Receive Data Valid.
        -------------------------------------------------------------
        -- P2L SDR Controls
        --
        P2L_RDY            : inout std_logic;  -- In  -- Rx Buffer Full Flag.
        P_WR_REQ           : inout std_logic_vector(1 downto 0);  -- Out -- PCIe Write Request.
        P_WR_RDY           : inout std_logic_vector(1 downto 0);  -- In  -- PCIe Write Ready.
        RX_ERROR           : inout std_logic;  -- In  -- Receive Error.
        VC_RDY             : inout std_logic_vector(1 downto 0);  -- Out -- Virtual Channel Ready Status.
        -------------------------------------------------------------
        -- GPIO signals
        --
        GPIO               : inout std_logic_vector(15 downto 0)
        );
  end component;  --GN412X_BFM;

-----------------------------------------------------------------------------
-- CMD_ROUTER component
-----------------------------------------------------------------------------
  component cmd_router
    generic(N_BFM      : integer := 8;
            N_FILES    : integer := 3;
            FIFO_DEPTH : integer := 8;
            STRING_MAX : integer := 256
            );
    port(CMD          : out string(1 to STRING_MAX);
         CMD_REQ      : out bit_vector(N_BFM-1 downto 0);
         CMD_ACK      : in  bit_vector(N_BFM-1 downto 0);
         CMD_ERR      : in  bit_vector(N_BFM-1 downto 0);
         CMD_CLOCK_EN : out boolean
         );
  end component;  --cmd_router;

-----------------------------------------------------------------------------
-- CMD_ROUTER component
-----------------------------------------------------------------------------
  component simple
    port(
      clk : in  std_logic;
      d   : in  std_logic_vector(15 downto 0);
      q   : out std_logic_vector(15 downto 0)
      );
  end component;

-----------------------------------------------------------------------------
-- Design top entity
-----------------------------------------------------------------------------
  component pfc_top
    generic(
      g_SIMULATION         : string  := "FALSE";
      g_CALIB_SOFT_IP      : string  := "TRUE"
      );
    port
      (

        -- Global ports
        SYS_CLK_P : in std_logic;       -- 25MHz system clock
        SYS_CLK_N : in std_logic;       -- 25MHz system clock

        -- From GN4124 Local bus
        L_CLKp : in std_logic;          -- Local bus clock (frequency set in GN4124 config registers)
        L_CLKn : in std_logic;          -- Local bus clock (frequency set in GN4124 config registers)

        L_RST_N : in std_logic;         -- Reset from GN4124 (RSTOUT18_N)

        -- General Purpose Interface
        GPIO : inout std_logic_vector(1 downto 0);  -- GPIO[0] -> GN4124 GPIO8
                                                    -- GPIO[1] -> GN4124 GPIO9

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

        -- Font panel LEDs
        LED_RED   : out std_logic;
        LED_GREEN : out std_logic;

        -- User IO (eSATA connector)
        USER_IO_0_P : out std_logic;
        USER_IO_0_N : out std_logic;
        USER_IO_1_P : out std_logic;
        USER_IO_1_N : out std_logic;

        -- FMC connector management signals
        PRSNT_M2C_L       : in    std_logic;
        PG_C2M            : out   std_logic;
        M2C_DIR           : in    std_logic;  -- HPC only
        FPGA_SDA          : inout std_logic;
        FPGA_SCL          : out   std_logic;
        TMS_TO_FMC_P1V8   : out   std_logic;
        TDO_FROM_FMC_P1V8 : in    std_logic;
        TDI_TO_FMC_P1V8   : out   std_logic;
        TCK_TO_FMC_P1V8   : out   std_logic;

        -- FMC connector clock inputs
        CLK1_M2C_P : in std_logic;
        CLK1_M2C_N : in std_logic;
        CLK0_M2C_P : in std_logic;
        CLK0_M2C_N : in std_logic;

        -- FMC connector user defined signals
        LA33_P : out std_logic;
        LA33_N : out std_logic;
        LA32_P : out std_logic;
        LA32_N : out std_logic;
        LA31_P : out std_logic;
        LA31_N : out std_logic;
        LA30_P : out std_logic;
        LA30_N : out std_logic;
        LA29_P : out std_logic;
        LA29_N : out std_logic;
        LA28_P : out std_logic;
        LA28_N : out std_logic;
        LA27_P : out std_logic;
        LA27_N : out std_logic;
        LA26_P : out std_logic;
        LA26_N : out std_logic;
        LA25_P : out std_logic;
        LA25_N : out std_logic;
        LA24_P : out std_logic;
        LA24_N : out std_logic;
        LA23_P : out std_logic;
        LA23_N : out std_logic;
        LA22_P : out std_logic;
        LA22_N : out std_logic;
        LA21_P : out std_logic;
        LA21_N : out std_logic;
        LA20_P : out std_logic;
        LA20_N : out std_logic;
        LA19_P : out std_logic;
        LA19_N : out std_logic;
        LA18_P : out std_logic;
        LA18_N : out std_logic;
        LA17_P : out std_logic;
        LA17_N : out std_logic;
        LA16_P : out std_logic;
        LA16_N : out std_logic;
        LA15_P : out std_logic;
        LA15_N : out std_logic;
        LA14_P : out std_logic;
        LA14_N : out std_logic;
        LA13_P : out std_logic;
        LA13_N : out std_logic;
        LA12_P : out std_logic;
        LA12_N : out std_logic;
        LA11_P : out std_logic;
        LA11_N : out std_logic;
        LA10_P : in  std_logic;
        LA10_N : out std_logic;
        LA09_P : out std_logic;
        LA09_N : out std_logic;
        LA08_P : out std_logic;
        LA08_N : out std_logic;
        LA07_P : out std_logic;
        LA07_N : out std_logic;
        LA06_P : out std_logic;
        LA06_N : out std_logic;
        LA05_P : out std_logic;
        LA05_N : out std_logic;
        LA04_P : out std_logic;
        LA04_N : out std_logic;
        LA03_P : out std_logic;
        LA03_N : out std_logic;
        LA02_P : out std_logic;
        LA02_N : out std_logic;
        LA01_P : in  std_logic;
        LA01_N : out std_logic;
        LA00_P : out std_logic;
        LA00_N : out std_logic;

        -- SPI interface
        SCLK_V_MON_P1V8 : out std_logic;
        DIN_V_MON       : out std_logic;
        CSVR_V_MON_P1V8 : out std_logic;  -- Digital potentiometer for VADJ

        -- Power supplies control
        ENABLE_VADJ : out std_logic;

        -- DDR3 interface
        ddr3_a_o      : out   std_logic_vector(13 downto 0);
        ddr3_ba_o     : out   std_logic_vector(2 downto 0);
        ddr3_cas_n_o  : out   std_logic;
        ddr3_clk_p_o  : out   std_logic;
        ddr3_clk_n_o  : out   std_logic;
        ddr3_cke_o    : out   std_logic;
        ddr3_dm_o     : out   std_logic;
        ddr3_dq_b     : inout std_logic_vector(15 downto 0);
        ddr3_dqs_p_b  : inout std_logic;
        ddr3_dqs_n_b  : inout std_logic;
        ddr3_odt_o    : out   std_logic;
        ddr3_ras_n_o  : out   std_logic;
        ddr3_rst_n_o  : out   std_logic;
        ddr3_udm_o    : out   std_logic;
        ddr3_udqs_p_b : inout std_logic;
        ddr3_udqs_n_b : inout std_logic;
        ddr3_we_n_o   : out   std_logic;
        ddr3_rzq_b    : inout std_logic;
        ddr3_zio_b    : inout std_logic
        );
  end component;  --pfc_top;

  ------------------------------------------------------------------------------
  -- DDR3 model
  ------------------------------------------------------------------------------
  component ddr3
    port (
      rst_n   : in    std_logic;
      ck      : in    std_logic;
      ck_n    : in    std_logic;
      cke     : in    std_logic;
      cs_n    : in    std_logic;
      ras_n   : in    std_logic;
      cas_n   : in    std_logic;
      we_n    : in    std_logic;
      dm_tdqs : inout std_logic_vector(1 downto 0);
      ba      : in    std_logic_vector(2 downto 0);
      addr    : in    std_logic_vector(13 downto 0);
      dq      : inout std_logic_vector(15 downto 0);
      dqs     : inout std_logic_vector(1 downto 0);
      dqs_n   : inout std_logic_vector(1 downto 0);
      tdqs_n  : out   std_logic_vector(1 downto 0);
      odt     : in    std_logic
      );
  end component;

--###########################################################################
--###########################################################################
--##
--## Constants
--##
--###########################################################################
--###########################################################################
  --
  -- Number of Models receiving commands
  constant N_BFM      : integer := 2;   -- 0 : GN412X_BFM in Model Mode
  --                                  -- 1 : GN412X_BFM in DUT mode
  -- Number of files to feed BFMs
  constant N_FILES    : integer := 2;
  --
  -- Depth of the command FIFO for each model
  constant FIFO_DEPTH : integer := 16;
  --
  -- Maximum width of a command string
  constant STRING_MAX : integer := 256;
  --

--###########################################################################
--###########################################################################
--##
--## Signals
--##
--###########################################################################
--###########################################################################
-----------------------------------------------------------------------------
-- Command Router Signals
-----------------------------------------------------------------------------
  signal CMD          : string(1 to STRING_MAX);
  signal CMD_REQ      : bit_vector(N_BFM-1 downto 0);
  signal CMD_ACK      : bit_vector(N_BFM-1 downto 0);
  signal CMD_ERR      : bit_vector(N_BFM-1 downto 0);
  signal CMD_CLOCK_EN : boolean;

-----------------------------------------------------------------------------
-- GN412x BFM Signals
-----------------------------------------------------------------------------
  signal RSTINn             : std_logic;
  signal RSTOUT18n          : std_logic;
  signal RSTOUT33n          : std_logic;
  signal LCLK, LCLKn        : std_logic;
  signal L2P_CLKp, L2P_CLKn : std_logic;
  signal L2P_DATA           : std_logic_vector(15 downto 0);
  signal L2P_DATA_32        : std_logic_vector(31 downto 0);  -- For monitoring use
  signal L2P_DFRAME         : std_logic;
  signal L2P_VALID          : std_logic;
  signal L2P_EDB            : std_logic;
  signal L_WR_RDY           : std_logic_vector(1 downto 0);
  signal P_RD_D_RDY         : std_logic_vector(1 downto 0);
  signal L2P_RDY            : std_logic;
  signal TX_ERROR           : std_logic;
  signal P2L_CLKp, P2L_CLKn : std_logic;
  signal P2L_DATA           : std_logic_vector(15 downto 0);
  signal P2L_DATA_32        : std_logic_vector(31 downto 0);  -- For monitoring use
  signal P2L_DFRAME         : std_logic;
  signal P2L_VALID          : std_logic;
  signal P2L_RDY            : std_logic;
  signal P_WR_REQ           : std_logic_vector(1 downto 0);
  signal P_WR_RDY           : std_logic_vector(1 downto 0);
  signal RX_ERROR           : std_logic;
  signal VC_RDY             : std_logic_vector(1 downto 0);

  signal GPIO : std_logic_vector(15 downto 0);

  -- Font panel LEDs
  signal LED_RED   : std_logic;
  signal LED_GREEN : std_logic;

  -- User IO (eSATA connector)
  signal USER_IO_0_P : std_logic;
  signal USER_IO_0_N : std_logic;
  signal USER_IO_1_P : std_logic;
  signal USER_IO_1_N : std_logic;

  -- FMC connector management signals
  signal PRSNT_M2C_L       : std_logic := '0';
  signal PG_C2M            : std_logic;
  signal M2C_DIR           : std_logic := '0';
  signal FPGA_SDA          : std_logic := 'Z';
  signal FPGA_SCL          : std_logic;
  signal TMS_TO_FMC_P1V8   : std_logic;
  signal TDO_FROM_FMC_P1V8 : std_logic := '0';
  signal TDI_TO_FMC_P1V8   : std_logic;
  signal TCK_TO_FMC_P1V8   : std_logic;

  -- FMC connector clock inputs
  signal CLK1_M2C_P : std_logic := '0';
  signal CLK1_M2C_N : std_logic := '0';
  signal CLK0_M2C_P : std_logic := '0';
  signal CLK0_M2C_N : std_logic := '0';

  -- FMC connector user defined signals
  signal LA33_P : std_logic;
  signal LA33_N : std_logic;
  signal LA32_P : std_logic;
  signal LA32_N : std_logic;
  signal LA31_P : std_logic;
  signal LA31_N : std_logic;
  signal LA30_P : std_logic;
  signal LA30_N : std_logic;
  signal LA29_P : std_logic;
  signal LA29_N : std_logic;
  signal LA28_P : std_logic;
  signal LA28_N : std_logic;
  signal LA27_P : std_logic;
  signal LA27_N : std_logic;
  signal LA26_P : std_logic;
  signal LA26_N : std_logic;
  signal LA25_P : std_logic;
  signal LA25_N : std_logic;
  signal LA24_P : std_logic;
  signal LA24_N : std_logic;
  signal LA23_P : std_logic;
  signal LA23_N : std_logic;
  signal LA22_P : std_logic;
  signal LA22_N : std_logic;
  signal LA21_P : std_logic;
  signal LA21_N : std_logic;
  signal LA20_P : std_logic;
  signal LA20_N : std_logic;
  signal LA19_P : std_logic;
  signal LA19_N : std_logic;
  signal LA18_P : std_logic;
  signal LA18_N : std_logic;
  signal LA17_P : std_logic;
  signal LA17_N : std_logic;
  signal LA16_P : std_logic;
  signal LA16_N : std_logic;
  signal LA15_P : std_logic;
  signal LA15_N : std_logic;
  signal LA14_P : std_logic;
  signal LA14_N : std_logic;
  signal LA13_P : std_logic;
  signal LA13_N : std_logic;
  signal LA12_P : std_logic;
  signal LA12_N : std_logic;
  signal LA11_P : std_logic;
  signal LA11_N : std_logic;
  signal LA10_P : std_logic := '0';
  signal LA10_N : std_logic;
  signal LA09_P : std_logic;
  signal LA09_N : std_logic;
  signal LA08_P : std_logic;
  signal LA08_N : std_logic;
  signal LA07_P : std_logic;
  signal LA07_N : std_logic;
  signal LA06_P : std_logic;
  signal LA06_N : std_logic;
  signal LA05_P : std_logic;
  signal LA05_N : std_logic;
  signal LA04_P : std_logic;
  signal LA04_N : std_logic;
  signal LA03_P : std_logic;
  signal LA03_N : std_logic;
  signal LA02_P : std_logic;
  signal LA02_N : std_logic;
  signal LA01_P : std_logic := '0';
  signal LA01_N : std_logic;
  signal LA00_P : std_logic;
  signal LA00_N : std_logic;

  -- SPI interface
  signal SCLK_V_MON_P1V8 : std_logic;
  signal DIN_V_MON       : std_logic;
  signal CSVR_V_MON_P1V8 : std_logic;

  -- Power supplies control
  signal ENABLE_VADJ : std_logic;

  -- DDR3 interface
  signal ddr3_a_o     : std_logic_vector(13 downto 0);
  signal ddr3_ba_o    : std_logic_vector(2 downto 0);
  signal ddr3_cas_n_o : std_logic;
  signal ddr3_clk_p_o : std_logic;
  signal ddr3_clk_n_o : std_logic;
  signal ddr3_cke_o   : std_logic;
  signal ddr3_dm_b    : std_logic_vector(1 downto 0)  := (others => 'Z');
  signal ddr3_dq_b    : std_logic_vector(15 downto 0) := (others => 'Z');
  signal ddr3_dqs_p_b : std_logic_vector(1 downto 0)  := (others => 'Z');
  signal ddr3_dqs_n_b : std_logic_vector(1 downto 0)  := (others => 'Z');
  signal ddr3_odt_o   : std_logic;
  signal ddr3_ras_n_o : std_logic;
  signal ddr3_rst_n_o : std_logic;
  signal ddr3_dm_o    : std_logic;
  signal ddr3_udm_o   : std_logic;
  --signal ddr3_udqs_p_b : std_logic                     := 'Z';
  --signal ddr3_udqs_n_b : std_logic                     := 'Z';
  signal ddr3_we_n_o  : std_logic;
  signal ddr3_rzq_b   : std_logic;
  signal ddr3_zio_b   : std_logic                     := 'Z';

  -- 25MHz system clock
  signal SYS_CLK_P : std_logic;
  signal SYS_CLK_N : std_logic;

-----------------------------------------------------------------------------
-- Bus Monitor Signals
-----------------------------------------------------------------------------
  signal Q_P2L_DFRAME : std_logic;

  signal SIMPLE_TEST : std_logic_vector(15 downto 0);

--###########################################################################
--###########################################################################
--##
--## Start of Code
--##
--###########################################################################
--###########################################################################

begin

-----------------------------------------------------------------------------
-- MODEL Component
-----------------------------------------------------------------------------

  CMD_ERR <= (others => '0');

  UC : cmd_router
    generic map
    (N_BFM      => N_BFM,
     N_FILES    => N_FILES,
     FIFO_DEPTH => FIFO_DEPTH,
     STRING_MAX => STRING_MAX
     )
    port map
    (CMD          => CMD,
     CMD_REQ      => CMD_REQ,
     CMD_ACK      => CMD_ACK,
     CMD_ERR      => CMD_ERR,
     CMD_CLOCK_EN => CMD_CLOCK_EN
     );

-----------------------------------------------------------------------------
-- GN412x BFM - PRIMARY
-----------------------------------------------------------------------------

  U0 : gn412x_bfm
    generic map
    (
      STRING_MAX     => STRING_MAX,
      T_LCLK         => 10 ns,
      T_P2L_CLK_DLY  => 2 ns,
      INSTANCE_LABEL => "U0(Primary GN412x): ",
      MODE_PRIMARY   => true
      )
    port map
    (
      --=========================================================--
      -------------------------------------------------------------
      -- CMD_ROUTER Interface
      --
      CMD          => CMD,
      CMD_REQ      => CMD_REQ(0),
      CMD_ACK      => CMD_ACK(0),
      CMD_CLOCK_EN => CMD_CLOCK_EN,
      --=========================================================--
      -------------------------------------------------------------
      -- GN412x Signal I/O
      -------------------------------------------------------------
      -- This is the reset input to the BFM
      --
      RSTINn       => RSTINn,
      -------------------------------------------------------------
      -- Reset outputs to DUT
      --
      RSTOUT18n    => RSTOUT18n,
      RSTOUT33n    => RSTOUT33n,
      -------------------------------------------------------------
      ----------------- Local Bus Clock ---------------------------
      ------------------------------------------------------------- 
      --
      LCLK         => LCLK,
      LCLKn        => LCLKn,
      -------------------------------------------------------------
      ----------------- Local-to-PCI Dataflow ---------------------
      -------------------------------------------------------------
      -- Transmitter Source Synchronous Clock.
      --
      L2P_CLKp     => L2P_CLKp,
      L2P_CLKn     => L2P_CLKn,
      -------------------------------------------------------------
      -- L2P DDR Link
      --
      L2P_DATA     => L2P_DATA,
      L2P_DFRAME   => L2P_DFRAME,
      L2P_VALID    => L2P_VALID,
      L2P_EDB      => L2P_EDB,
      -------------------------------------------------------------
      -- L2P SDR Controls
      --
      L_WR_RDY     => L_WR_RDY,
      P_RD_D_RDY   => P_RD_D_RDY,
      L2P_RDY      => L2P_RDY,
      TX_ERROR     => TX_ERROR,
      -------------------------------------------------------------
      ----------------- PCIe-to-Local Dataflow ---------------------
      -------------------------------------------------------------
      -- Transmitter Source Synchronous Clock.
      --
      P2L_CLKp     => P2L_CLKp,
      P2L_CLKn     => P2L_CLKn,
      -------------------------------------------------------------
      -- P2L DDR Link
      --
      P2L_DATA     => P2L_DATA,
      P2L_DFRAME   => P2L_DFRAME,
      P2L_VALID    => P2L_VALID,
      -------------------------------------------------------------
      -- P2L SDR Controls
      --
      P2L_RDY      => P2L_RDY,
      P_WR_REQ     => P_WR_REQ,
      P_WR_RDY     => P_WR_RDY,
      RX_ERROR     => RX_ERROR,
      VC_RDY       => VC_RDY,
      GPIO         => gpio
      );                                -- GN412X_BFM;


-----------------------------------------------------------------------------
-- UUT
-----------------------------------------------------------------------------

  U1 : pfc_top
    generic map (
      g_SIMULATION => "TRUE",
      g_CALIB_SOFT_IP => "FALSE")
    port map (
      -- Global ports
      SYS_CLK_P => SYS_CLK_P,
      SYS_CLK_N => SYS_CLK_N,

      -- From GN4124 Local bus
      l_clkp => LCLK,                   -- Running at 200 Mhz
      l_clkn => LCLKn,                  -- Running at 200 Mhz

      l_rst_n => RSTOUT18n,

      -- General Purpose Interface
      gpio => GPIO(9 downto 8),         -- General Purpose Input/Output

      -- PCIe to Local [Inbound Data] - RX
      p2l_rdy    => P2L_RDY,            -- Rx Buffer Full Flag
      p2l_clkn   => P2L_CLKn,           -- Receiver Source Synchronous Clock-
      p2l_clkp   => P2L_CLKp,           -- Receiver Source Synchronous Clock+
      p2l_data   => P2L_DATA,           -- Parallel receive data
      p2l_dframe => P2L_DFRAME,         -- Receive Frame
      p2l_valid  => P2L_VALID,          -- Receive Data Valid

      -- Inbound Buffer Request/Status
      p_wr_req => P_WR_REQ,             -- PCIe Write Request
      p_wr_rdy => P_WR_RDY,             -- PCIe Write Ready
      rx_error => RX_ERROR,             -- Receive Error

      -- Local to Parallel [Outbound Data] - TX
      l2p_data   => L2P_DATA,           -- Parallel transmit data 
      l2p_dframe => L2P_DFRAME,         -- Transmit Data Frame
      l2p_valid  => L2P_VALID,          -- Transmit Data Valid
      l2p_clkn   => L2P_CLKn,           -- Transmitter Source Synchronous Clock-
      l2p_clkp   => L2P_CLKp,           -- Transmitter Source Synchronous Clock+
      l2p_edb    => L2P_EDB,            -- Packet termination and discard

      -- Outbound Buffer Status
      l2p_rdy    => L2P_RDY,            -- Tx Buffer Full Flag
      l_wr_rdy   => L_WR_RDY,           -- Local-to-PCIe Write
      p_rd_d_rdy => P_RD_D_RDY,         -- PCIe-to-Local Read Response Data Ready
      tx_error   => TX_ERROR,           -- Transmit Error
      vc_rdy     => VC_RDY,             -- Channel ready

      -- Font panel LEDs
      LED_RED   => LED_RED,
      LED_GREEN => LED_GREEN,

      -- User IO (eSATA connector)
      USER_IO_0_P => USER_IO_0_P,
      USER_IO_0_N => USER_IO_0_N,
      USER_IO_1_P => USER_IO_1_P,
      USER_IO_1_N => USER_IO_1_N,

      -- FMC connector management signals
      PRSNT_M2C_L       => PRSNT_M2C_L,
      PG_C2M            => PG_C2M,
      M2C_DIR           => M2C_DIR,
      FPGA_SDA          => FPGA_SDA,
      FPGA_SCL          => FPGA_SCL,
      TMS_TO_FMC_P1V8   => TMS_TO_FMC_P1V8,
      TDO_FROM_FMC_P1V8 => TDO_FROM_FMC_P1V8,
      TDI_TO_FMC_P1V8   => TDI_TO_FMC_P1V8,
      TCK_TO_FMC_P1V8   => TCK_TO_FMC_P1V8,

      -- FMC connector clock inputs
      CLK1_M2C_P => CLK1_M2C_P,
      CLK1_M2C_N => CLK1_M2C_N,
      CLK0_M2C_P => CLK0_M2C_P,
      CLK0_M2C_N => CLK0_M2C_N,

      -- FMC connector user defined signals
      LA33_P => LA33_P,
      LA33_N => LA33_N,
      LA32_P => LA32_P,
      LA32_N => LA32_N,
      LA31_P => LA31_P,
      LA31_N => LA31_N,
      LA30_P => LA30_P,
      LA30_N => LA30_N,
      LA29_P => LA29_P,
      LA29_N => LA29_N,
      LA28_P => LA28_P,
      LA28_N => LA28_N,
      LA27_P => LA27_P,
      LA27_N => LA27_N,
      LA26_P => LA26_P,
      LA26_N => LA26_N,
      LA25_P => LA25_P,
      LA25_N => LA25_N,
      LA24_P => LA24_P,
      LA24_N => LA24_N,
      LA23_P => LA23_P,
      LA23_N => LA23_N,
      LA22_P => LA22_P,
      LA22_N => LA22_N,
      LA21_P => LA21_P,
      LA21_N => LA21_N,
      LA20_P => LA20_P,
      LA20_N => LA20_N,
      LA19_P => LA19_P,
      LA19_N => LA19_N,
      LA18_P => LA18_P,
      LA18_N => LA18_N,
      LA17_P => LA17_P,
      LA17_N => LA17_N,
      LA16_P => LA16_P,
      LA16_N => LA16_N,
      LA15_P => LA15_P,
      LA15_N => LA15_N,
      LA14_P => LA14_P,
      LA14_N => LA14_N,
      LA13_P => LA13_P,
      LA13_N => LA13_N,
      LA12_P => LA12_P,
      LA12_N => LA12_N,
      LA11_P => LA11_P,
      LA11_N => LA11_N,
      LA10_P => LA10_P,
      LA10_N => LA10_N,
      LA09_P => LA09_P,
      LA09_N => LA09_N,
      LA08_P => LA08_P,
      LA08_N => LA08_N,
      LA07_P => LA07_P,
      LA07_N => LA07_N,
      LA06_P => LA06_P,
      LA06_N => LA06_N,
      LA05_P => LA05_P,
      LA05_N => LA05_N,
      LA04_P => LA04_P,
      LA04_N => LA04_N,
      LA03_P => LA03_P,
      LA03_N => LA03_N,
      LA02_P => LA02_P,
      LA02_N => LA02_N,
      LA01_P => LA01_P,
      LA01_N => LA01_N,
      LA00_P => LA00_P,
      LA00_N => LA00_N,

      -- SPI interface
      SCLK_V_MON_P1V8 => SCLK_V_MON_P1V8,
      DIN_V_MON       => DIN_V_MON,
      CSVR_V_MON_P1V8 => CSVR_V_MON_P1V8,

      -- Power supplies control
      ENABLE_VADJ => ENABLE_VADJ,

      -- DDR3 interface
      ddr3_a_o      => ddr3_a_o,
      ddr3_ba_o     => ddr3_ba_o,
      ddr3_cas_n_o  => ddr3_cas_n_o,
      ddr3_clk_p_o  => ddr3_clk_p_o,
      ddr3_clk_n_o  => ddr3_clk_n_o,
      ddr3_cke_o    => ddr3_cke_o,
      ddr3_dm_o     => ddr3_dm_b(0),
      ddr3_dq_b     => ddr3_dq_b,
      ddr3_dqs_p_b  => ddr3_dqs_p_b(0),
      ddr3_dqs_n_b  => ddr3_dqs_n_b(0),
      ddr3_odt_o    => ddr3_odt_o,
      ddr3_ras_n_o  => ddr3_ras_n_o,
      ddr3_rst_n_o  => ddr3_rst_n_o,
      ddr3_udm_o    => ddr3_dm_b(1),
      ddr3_udqs_p_b => ddr3_dqs_p_b(1),
      ddr3_udqs_n_b => ddr3_dqs_n_b(1),
      ddr3_we_n_o   => ddr3_we_n_o,
      ddr3_rzq_b    => ddr3_rzq_b,
      ddr3_zio_b    => ddr3_zio_b
      );


  cmp_ddr3_model : ddr3
    port map(
      rst_n   => ddr3_rst_n_o,
      ck      => ddr3_clk_p_o,
      ck_n    => ddr3_clk_n_o,
      cke     => ddr3_cke_o,
      cs_n    => '0',                   -- Pulled down on PCB
      ras_n   => ddr3_ras_n_o,
      cas_n   => ddr3_cas_n_o,
      we_n    => ddr3_we_n_o,
      dm_tdqs => ddr3_dm_b,
      ba      => ddr3_ba_o,
      addr    => ddr3_a_o,
      dq      => ddr3_dq_b,
      dqs     => ddr3_dqs_p_b,
      dqs_n   => ddr3_dqs_n_b,
      tdqs_n  => open,                  -- dqs outputs for chaining
      odt     => ddr3_odt_o
      );


  process
    variable vP2L_DATA_LOW : std_logic_vector(P2L_DATA'range);
  begin
    wait until(P2L_CLKp'event and (P2L_CLKp = '1'));
    vP2L_DATA_LOW := P2L_DATA;
    loop
      wait on P2L_DATA, P2L_CLKp;
      P2L_DATA_32 <= P2L_DATA & vP2L_DATA_LOW;
      if(P2L_CLKp = '0') then
        exit;
      end if;
    end loop;
  end process;

  sys_clk : process
  begin
    SYS_CLK_P <= '1';
    SYS_CLK_N <= '0';
    wait for 20 ns;
    SYS_CLK_P <= '0';
    SYS_CLK_N <= '1';
    wait for 20 ns;
  end process sys_clk;

end TEST;

