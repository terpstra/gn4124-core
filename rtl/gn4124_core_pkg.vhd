library ieee;

use ieee.std_logic_1164.all;

package gn4124_core_pkg is

  function priv_log2_ceil(N : natural) return positive is
  begin
    if N <= 2 then
      return 1;
    elsif N mod 2 = 0 then
      return 1 + priv_log2_ceil(N/2);
    else
      return 1 + priv_log2_ceil((N+1)/2);
    end if;
  end;

  component gn4124_core
    generic (
      g_BAR0_APERTURE     : integer := 20;
      g_CSR_WB_SLAVES_NB  : integer := 1;
      g_CSR_WB_MODE       : string := "pipelined";
      g_DMA_WB_SLAVES_NB  : integer := 1;
      g_DMA_WB_ADDR_WIDTH : integer := 26);
    port (
      rst_n_a_i      : in  std_logic;
      p2l_pll_locked : out std_logic;
      debug_o        : out std_logic_vector(7 downto 0);
      p2l_clk_p_i    : in  std_logic;
      p2l_clk_n_i    : in  std_logic;
      p2l_data_i     : in  std_logic_vector(15 downto 0);
      p2l_dframe_i   : in  std_logic;
      p2l_valid_i    : in  std_logic;
      p2l_rdy_o      : out std_logic;
      p_wr_req_i     : in  std_logic_vector(1 downto 0);
      p_wr_rdy_o     : out std_logic_vector(1 downto 0);
      rx_error_o     : out std_logic;
      vc_rdy_i       : in  std_logic_vector(1 downto 0);
      l2p_clk_p_o    : out std_logic;
      l2p_clk_n_o    : out std_logic;
      l2p_data_o     : out std_logic_vector(15 downto 0);
      l2p_dframe_o   : out std_logic;
      l2p_valid_o    : out std_logic;
      l2p_edb_o      : out std_logic;
      l2p_rdy_i      : in  std_logic;
      l_wr_rdy_i     : in  std_logic_vector(1 downto 0);
      p_rd_d_rdy_i   : in  std_logic_vector(1 downto 0);
      tx_error_i     : in  std_logic;
      dma_irq_o      : out std_logic_vector(1 downto 0);
      irq_p_i        : in  std_logic;
      irq_p_o        : out std_logic;
      wb_clk_i       : in  std_logic;
      wb_adr_o       : out std_logic_vector(g_BAR0_APERTURE-priv_log2_ceil(g_CSR_WB_SLAVES_NB+1)-1 downto 0);
      wb_dat_o       : out std_logic_vector(31 downto 0);
      wb_sel_o       : out std_logic_vector(3 downto 0);
      wb_stb_o       : out std_logic;
      wb_we_o        : out std_logic;
      wb_cyc_o       : out std_logic_vector(g_CSR_WB_SLAVES_NB-1 downto 0);
      wb_dat_i       : in  std_logic_vector((32*g_CSR_WB_SLAVES_NB)-1 downto 0);
      wb_ack_i       : in  std_logic_vector(g_CSR_WB_SLAVES_NB-1 downto 0);
      dma_clk_i      : in  std_logic;
      dma_adr_o      : out std_logic_vector(31 downto 0);
      dma_dat_o      : out std_logic_vector(31 downto 0);
      dma_sel_o      : out std_logic_vector(3 downto 0);
      dma_stb_o      : out std_logic;
      dma_we_o       : out std_logic;
      dma_cyc_o      : out std_logic;
      dma_dat_i      : in  std_logic_vector((32*g_DMA_WB_SLAVES_NB)-1 downto 0);
      dma_ack_i      : in  std_logic;
      dma_stall_i    : in  std_logic);
  end component;

end gn4124_core_pkg;
