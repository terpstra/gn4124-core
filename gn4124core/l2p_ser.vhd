--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: l2p_ser (l2p_ser.vhd)
--
-- author:
--
-- date:
--
-- version: 0.0
--
-- description: Generates the DDR L2P bus from SDR that is synchronous to ICLK
--
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
use work.gn4124_core_pkg.all;


library UNISIM;
use UNISIM.vcomponents.all;

entity l2p_ser is
  port
    (
      ---------------------------------------------------------
      -- ICLK Clock Domain Inputs
      clk_p_i : in std_logic;
      clk_n_i : in std_logic;
      rst_n_i : in std_logic;

      l2p_valid_i  : in std_logic;
      l2p_dframe_i : in std_logic;
      l2p_data_i   : in std_logic_vector(31 downto 0);

      ---------------------------------------------------------
      -- SER Outputs
      l2p_clk_p_o  : out std_logic;
      l2p_clk_n_o  : out std_logic;
      l2p_valid_o  : out std_logic;
      l2p_dframe_o : out std_logic;
      l2p_data_o   : out std_logic_vector(15 downto 0)
      );
end l2p_ser;

architecture rtl of l2p_ser is

-----------------------------------------------------------------------------
-- Internal Signals
-----------------------------------------------------------------------------
  signal ff_rst      : std_logic;
  signal dframe_d    : std_logic;
  signal valid_d     : std_logic;
  signal data_d      : std_logic_vector(l2p_data_i'range);
  signal l2p_clk_sdr : std_logic;


begin

  ------------------------------------------------------------------------------
  -- Active high reset for DDR FF
  ------------------------------------------------------------------------------
  gen_fifo_rst_n : if c_RST_ACTIVE = '0' generate
    ff_rst <= not(rst_n_i);
  end generate;

  gen_fifo_rst : if c_RST_ACTIVE = '1' generate
    ff_rst <= rst_n_i;
  end generate;


-----------------------------------------------------------------------------
-- Re-allign Data tightly for the +'ve clock edge
-----------------------------------------------------------------------------
  process (clk_p_i, rst_n_i)
  begin
    if(rst_n_i = c_RST_ACTIVE) then
      dframe_d <= '0';
      valid_d  <= '0';
      data_d   <= (others => '0');
    elsif rising_edge(clk_p_i) then
      dframe_d <= l2p_dframe_i;
      valid_d  <= l2p_valid_i;
      data_d   <= l2p_data_i;
    end if;
  end process;

  process (clk_n_i, rst_n_i)
  begin
    if(rst_n_i = c_RST_ACTIVE) then
      l2p_valid_o  <= '0';
      l2p_dframe_o <= '0';
    elsif rising_edge(clk_n_i) then
      l2p_valid_o  <= valid_d;
      l2p_dframe_o <= dframe_d;
    end if;
  end process;


  DDROUT : for i in 0 to 15 generate
    U : OFDDRRSE
      port map
      (
        Q  => l2p_data_o(i),
        C0 => clk_n_i,
        C1 => clk_p_i,
        CE => '1',
        D0 => data_d(i),
        D1 => data_d(i+16),
        R  => ff_rst,
        S  => '0'
        );
  end generate;

  L2P_CLK_BUF : OBUFDS
    port map(
      O  => l2p_clk_p_o,
      OB => l2p_clk_n_o,
      I  => l2p_clk_sdr);

  L2P_CLK_int : FDDRRSE
    port map(
      Q  => l2p_clk_sdr,
      C0 => clk_n_i,
      C1 => clk_p_i,
      CE => '1',
      D0 => '1',
      D1 => '0',
      R  => '0',
      S  => '0');

end rtl;

