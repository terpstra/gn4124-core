--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: p2l_des (p2l_des.vhd)
--
-- author:
--
-- date:
--
-- version: 0.0
--
-- description: Takes the DDR P2L bus and converts to SDR that is synchronous
--              to the core clock.
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


entity p2l_des is
  port
    (
      ---------------------------------------------------------
      -- Raw unprocessed reset from the GN412x
      l_rst_i : in std_logic;

      ---------------------------------------------------------
      -- P2L Clock Domain
      --
      -- P2L Inputs
      p2l_clk_p_i  : in std_logic;
      p2l_clk_n_i  : in std_logic;
      p2l_valid_i  : in std_logic;
      p2l_dframe_i : in std_logic;
      p2l_data_i   : in std_logic_vector(15 downto 0);

      ---------------------------------------------------------
      -- Core Clock Domain
      --
      rst_o        : out    std_logic;
      -- Core Logic Clock
      clk_p_o      : buffer std_logic;
      clk_n_o      : buffer std_logic;
      -- DeSerialized Output
      p2l_valid_o  : out    std_logic;
      p2l_dframe_o : out    std_logic;
      p2l_data_o   : out    std_logic_vector(31 downto 0)
      );
end p2l_des;


architecture rtl of p2l_des is


  -----------------------------------------------------------------------------
  -- Signals for the P2L_CLK domain
  -----------------------------------------------------------------------------
  signal ff_rst         : std_logic;
  signal p2l_valid_p    : std_logic;
  signal p2l_valid_n    : std_logic;
  signal p2l_dframe_p   : std_logic;
  signal p2l_dframe_n   : std_logic;
  signal p2l_data_p     : std_logic_vector(p2l_data_i'range);
  signal p2l_data_n     : std_logic_vector(p2l_data_i'range);
  signal p2l_data_sdr_l : std_logic_vector(p2l_data_i'range);
  signal p2l_data_sdr   : std_logic_vector(p2l_data_i'length*2-1 downto 0);
  signal clk_p          : std_logic;
  signal clk_n          : std_logic;
  signal rst_reg        : std_logic;
  signal rst_buf        : std_logic;


begin


  -----------------------------------------------------------------------------
  -- rst_o: clk_p_o alligned reset
  -----------------------------------------------------------------------------
  process (clk_p_o, l_rst_i)
  begin
    if l_rst_i = c_RST_ACTIVE then
      rst_reg <= c_RST_ACTIVE;
    elsif rising_edge(clk_p_o) then
      rst_reg <= not(c_RST_ACTIVE);
    end if;
  end process;


  cmp_rst_buf : BUFG
    port map (
      I => rst_reg,
      O => rst_buf);

  rst_o <= rst_buf;


------------------------------------------------------------------------------
  -- Active high reset for DDR FF
  ------------------------------------------------------------------------------
  gen_fifo_rst_n : if c_RST_ACTIVE = '0' generate
    ff_rst <= not(rst_buf);
  end generate;

  gen_fifo_rst : if c_RST_ACTIVE = '1' generate
    ff_rst <= rst_buf;
  end generate;


  ------------------------------------------------------------------------------
  -- DDR FF instanciation
  ------------------------------------------------------------------------------
  DDRFF_D : for i in p2l_data_i'range generate
    U : IFDDRRSE
      port map
      (
        Q0 => p2l_data_n(i),
        Q1 => p2l_data_p(i),
        C0 => clk_n_o,
        C1 => clk_p_o,
        CE => '1',
        D  => p2l_data_i(i),
        R  => ff_rst,
        S  => '0'
        );
  end generate;

  DDRFF_F : IFDDRRSE
    port map
    (
      Q0 => p2l_dframe_n,
      Q1 => p2l_dframe_p,
      C0 => clk_n_o,
      C1 => clk_p_o,
      CE => '1',
      D  => p2l_dframe_i,
      R  => ff_rst,
      S  => '0'
      );

  DDRFF_V : IFDDRRSE
    port map
    (
      Q0 => p2l_valid_n,
      Q1 => p2l_valid_p,
      C0 => clk_n_o,
      C1 => clk_p_o,
      CE => '1',
      D  => p2l_valid_i,
      R  => ff_rst,
      S  => '0'
      );


  -----------------------------------------------------------------------------
  -- Align positive edge data to negative edge clock
  -----------------------------------------------------------------------------
  process (clk_n_o, rst_buf)
  begin
    if(rst_buf = c_RST_ACTIVE) then
      p2l_data_sdr_l <= (others => '0');
    elsif rising_edge(clk_n_o) then
      p2l_data_sdr_l <= p2l_data_p;
    end if;
  end process;

  p2l_data_sdr <= p2l_data_n & p2l_data_sdr_l;


  -----------------------------------------------------------------------------
  -- Final Positive Edge Clock Allignment
  -----------------------------------------------------------------------------
  process (clk_p_o, rst_buf)
  begin
    if(rst_buf = c_RST_ACTIVE) then
      p2l_valid_o  <= '0';
      p2l_dframe_o <= '0';
      p2l_data_o   <= (others => '0');
    elsif rising_edge(clk_p_o) then
      p2l_valid_o  <= p2l_valid_p;
      p2l_dframe_o <= p2l_dframe_p;
      p2l_data_o   <= p2l_data_sdr;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- The Internal Core Clock is Derived from the P2L_CLK
  -----------------------------------------------------------------------------
  clk_p_ibuf : IBUFGDS
    port map(
      I  => p2l_clk_p_i,
      IB => p2l_clk_n_i,
      O  => clk_p);

  clk_p_bufg : BUFG
    port map(
      I => clk_p,
      O => clk_p_o);

  clk_n_ibuf : IBUFGDS
    port map(
      I  => p2l_clk_n_i,
      IB => p2l_clk_p_i,
      O  => clk_n);

  clk_n_bufg : BUFG
    port map(
      I => clk_n,
      O => clk_n_o);


end rtl;


