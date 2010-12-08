--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: pfc_wrapper_clk_test (pfc_wrapper_clk_test.vhd)
--
-- author: Matthieu Cattin (matthieu.cattin@cern.ch)
--
-- date: 20-10-2010
--
-- version: 0.1
--
-- description: Wrapper for the GN4124 core to drop into the FPGA on the
--              PFC (PCIe FMC Carrier) board
--
-- dependencies:
--
--------------------------------------------------------------------------------
-- last changes: see svn log.
--------------------------------------------------------------------------------
-- TODO: - 
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.vcomponents.all;


entity pfc_wrapper_clk_test is
  generic
    (
      TAR_ADDR_WDTH : integer := 13     -- not used for this project
      );
  port
    (

      -- Global ports
      SYS_CLK_P : in std_logic;         -- 25MHz system clock
      SYS_CLK_N : in std_logic;         -- 25MHz system clock

      -- From GN4124 Local bus
      L_CLKp : in std_logic;            -- Local bus clock (frequency set in GN4124 config registers)
      L_CLKn : in std_logic;            -- Local bus clock (frequency set in GN4124 config registers)

      L_RST_N : in std_logic;           -- Reset from GN4124 (RSTOUT18_N)

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
      USER_IO_1_N : out std_logic
      );
end pfc_wrapper_clk_test;

architecture rtl of pfc_wrapper_clk_test is


  ------------------------------------------------------------------------------
  -- Signals declaration
  ------------------------------------------------------------------------------

  -- System clock
  signal sys_clk : std_logic;

  -- LCLK from GN4124 used as system clock
  signal l_clk : std_logic;

  -- FOR TEST
  signal p2l_clk         : std_logic;
  signal p2l_clk_div_cnt : unsigned(3 downto 0);
  signal p2l_clk_div     : std_logic;
  signal l_clk_div_cnt   : unsigned(3 downto 0);
  signal l_clk_div       : std_logic;


begin


  ------------------------------------------------------------------------------
  -- System clock from 25MHz TCXO
  ------------------------------------------------------------------------------
  cmp_sysclk_buf : IBUFDS
    generic map (
      DIFF_TERM    => false,            -- Differential Termination
      IBUF_LOW_PWR => true,             -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
      IOSTANDARD   => "DEFAULT")
    port map (
      O  => sys_clk,                    -- Buffer output
      I  => sys_clk_p,                  -- Diff_p buffer input (connect directly to top-level port)
      IB => sys_clk_n                   -- Diff_n buffer input (connect directly to top-level port)
      );

  ------------------------------------------------------------------------------
  -- Local clock from gennum LCLK
  ------------------------------------------------------------------------------
  cmp_l_clk_buf : IBUFDS
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
  -- FOR TEST
  ------------------------------------------------------------------------------
  cmp_p2lclk_buf : IBUFDS
    generic map (
      DIFF_TERM    => false,            -- Differential Termination
      IBUF_LOW_PWR => true,             -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
      IOSTANDARD   => "DEFAULT")
    port map (
      O  => p2l_clk,                    -- Buffer output
      I  => P2L_CLKp,                   -- Diff_p buffer input (connect directly to top-level port)
      IB => P2L_CLKn                    -- Diff_n buffer input (connect directly to top-level port)
      );

  p_div_p2l_clk : process (p2l_clk, L_RST_N)
  begin
    if L_RST_N = '0' then
      p2l_clk_div     <= '0';
      p2l_clk_div_cnt <= (others => '0');
    elsif rising_edge(p2l_clk) then
      if p2l_clk_div_cnt = 4 then
        p2l_clk_div     <= not (p2l_clk_div);
        p2l_clk_div_cnt <= (others => '0');
      else
        p2l_clk_div_cnt <= p2l_clk_div_cnt + 1;
      end if;
    end if;
  end process p_div_p2l_clk;

  p_div_l_clk : process (l_clk, L_RST_N)
  begin
    if L_RST_N = '0' then
      l_clk_div     <= '0';
      l_clk_div_cnt <= (others => '0');
    elsif rising_edge(l_clk) then
      if l_clk_div_cnt = 4 then
        l_clk_div     <= not (l_clk_div);
        l_clk_div_cnt <= (others => '0');
      else
        l_clk_div_cnt <= l_clk_div_cnt + 1;
      end if;
    end if;
  end process p_div_l_clk;

  USER_IO_0_P <= p2l_clk_div;
  USER_IO_0_N <= l_clk_div;
  USER_IO_1_P <= sys_clk;
  USER_IO_1_N <= '0';

  cmp_l2pclk_buf : OBUFDS
    port map (
      O  => L2P_CLKp,
      OB => L2P_CLKn,
      I  => p2l_clk
      );

  GPIO       <= "00";
  P2L_RDY    <= '0';
  P_WR_RDY   <= "00";
  RX_ERROR   <= '0';
  L2P_DATA   <= X"0000";
  L2P_DFRAME <= '0';
  L2P_VALID  <= '0';
  L2P_EDB    <= '0';
  LED_RED    <= '0';
  LED_GREEN  <= '1';

end rtl;


