library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;
use std.textio.all;

--library std_developerskit;
--use std_developerskit.std_iopak.all;

use work.util.all;
use work.textutil.all;

--############################################################################
--############################################################################
--==========================================================================--
--
-- *Module      : tb_spec
--
-- *Description : Test Bench for the GN4124 BFM + SPEC Design
--
-- *History
--
--==========================================================================--
--############################################################################
--############################################################################

entity TB_SPEC is
  generic
    (
      T_LCLK : time := 30 ns            -- Default LCLK Clock Period 
      );
end TB_SPEC;

architecture TEST of TB_SPEC is

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
  component spec_gn4124_test
    port
      (
        -- Local oscillator
        clk20_vcxo_i : in std_logic;  -- 20MHz VCXO clock

        -- Carrier font panel LEDs
        LED_RED_O   : out std_logic;
        LED_GREEN_O : out std_logic;

        -- Auxiliary pins
        AUX_LEDS_O    : out std_logic_vector(3 downto 0);
        AUX_BUTTONS_I : in  std_logic_vector(1 downto 0);

        -- GN4124 interface
        L_CLKp       : in    std_logic;                      -- Local bus clock (frequency set in GN4124 config registers)
        L_CLKn       : in    std_logic;                      -- Local bus clock (frequency set in GN4124 config registers)
        L_RST_N      : in    std_logic;                      -- Reset from GN4124 (RSTOUT18_N)
        P2L_RDY      : out   std_logic;                      -- Rx Buffer Full Flag
        P2L_CLKn     : in    std_logic;                      -- Receiver Source Synchronous Clock-
        P2L_CLKp     : in    std_logic;                      -- Receiver Source Synchronous Clock+
        P2L_DATA     : in    std_logic_vector(15 downto 0);  -- Parallel receive data
        P2L_DFRAME   : in    std_logic;                      -- Receive Frame
        P2L_VALID    : in    std_logic;                      -- Receive Data Valid
        P_WR_REQ     : in    std_logic_vector(1 downto 0);   -- PCIe Write Request
        P_WR_RDY     : out   std_logic_vector(1 downto 0);   -- PCIe Write Ready
        RX_ERROR     : out   std_logic;                      -- Receive Error
        L2P_DATA     : out   std_logic_vector(15 downto 0);  -- Parallel transmit data
        L2P_DFRAME   : out   std_logic;                      -- Transmit Data Frame
        L2P_VALID    : out   std_logic;                      -- Transmit Data Valid
        L2P_CLKn     : out   std_logic;                      -- Transmitter Source Synchronous Clock-
        L2P_CLKp     : out   std_logic;                      -- Transmitter Source Synchronous Clock+
        L2P_EDB      : out   std_logic;                      -- Packet termination and discard
        L2P_RDY      : in    std_logic;                      -- Tx Buffer Full Flag
        L_WR_RDY     : in    std_logic_vector(1 downto 0);   -- Local-to-PCIe Write
        P_RD_D_RDY   : in    std_logic_vector(1 downto 0);   -- PCIe-to-Local Read Response Data Ready
        TX_ERROR     : in    std_logic;                      -- Transmit Error
        VC_RDY       : in    std_logic_vector(1 downto 0);   -- Channel ready
        GPIO         : inout std_logic_vector(1 downto 0);   -- GPIO[0] -> GN4124 GPIO8
                                                             -- GPIO[1] -> GN4124 GPIO9
        -- PCB version
        pcb_ver_i : in std_logic_vector(3 downto 0)
        );
  end component spec_gn4124_test;


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

  -- System signals
  signal clk20_vcxo_i : std_logic := '0';  -- 20MHz VCXO clock

  -- GN4124 interface
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
  signal GPIO               : std_logic_vector(15 downto 0);

  -- Aux signals
  signal LED_RED     : std_logic;
  signal LED_GREEN   : std_logic;
  signal AUX_BUTTONS : std_logic_vector(1 downto 0);
  signal AUX_LEDS    : std_logic_vector(3 downto 0);
  signal PCB_VER : std_logic_vector(3 downto 0) := "0011";


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
      T_LCLK         => 6.25 ns,
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

  U1 : spec_gn4124_test
    port map (
      clk20_vcxo_i => clk20_vcxo_i,
      LED_RED_O      => LED_RED,
      LED_GREEN_O    => LED_GREEN,
      AUX_LEDS_O     => AUX_LEDS,
      AUX_BUTTONS_I  => AUX_BUTTONS,

      -- GN4124 interface
      l_clkp     => LCLK,               -- Running at 200 Mhz
      l_clkn     => LCLKn,              -- Running at 200 Mhz
      l_rst_n    => RSTOUT18n,
      p2l_rdy    => P2L_RDY,            -- Rx Buffer Full Flag
      p2l_clkn   => P2L_CLKn,           -- Receiver Source Synchronous Clock-
      p2l_clkp   => P2L_CLKp,           -- Receiver Source Synchronous Clock+
      p2l_data   => P2L_DATA,           -- Parallel receive data
      p2l_dframe => P2L_DFRAME,         -- Receive Frame
      p2l_valid  => P2L_VALID,          -- Receive Data Valid
      p_wr_req   => P_WR_REQ,           -- PCIe Write Request
      p_wr_rdy   => P_WR_RDY,           -- PCIe Write Ready
      rx_error   => RX_ERROR,           -- Receive Error
      l2p_data   => L2P_DATA,           -- Parallel transmit data 
      l2p_dframe => L2P_DFRAME,         -- Transmit Data Frame
      l2p_valid  => L2P_VALID,          -- Transmit Data Valid
      l2p_clkn   => L2P_CLKn,           -- Transmitter Source Synchronous Clock-
      l2p_clkp   => L2P_CLKp,           -- Transmitter Source Synchronous Clock+
      l2p_edb    => L2P_EDB,            -- Packet termination and discard
      l2p_rdy    => L2P_RDY,            -- Tx Buffer Full Flag
      l_wr_rdy   => L_WR_RDY,           -- Local-to-PCIe Write
      p_rd_d_rdy => P_RD_D_RDY,         -- PCIe-to-Local Read Response Data Ready
      tx_error   => TX_ERROR,           -- Transmit Error
      vc_rdy     => VC_RDY,             -- Channel ready
      gpio       => GPIO(9 downto 8),   -- General Purpose Input/Output

      pcb_ver_i => PCB_VER
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
    clk20_vcxo_i <= '1';
    wait for 25 ns;
    clk20_vcxo_i <= '0';
    wait for 25 ns;
  end process sys_clk;


end TEST;
