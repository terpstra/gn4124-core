--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: L2P serializer (l2p_ser.vhd)
--
-- authors: Simon Deprez (simon.deprez@cern.ch)
--          Matthieu Cattin (matthieu.cattin@cern.ch)
--
-- date: 31-08-2010
--
-- version: 1.0
--
-- description: Generates the DDR L2P bus from SDR that is synchronous to the
--              core clock.
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
-- last changes: 23-09-2010 (mcattin) Always active high reset for FFs.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gn4124_core_pkg.all;

library UNISIM;
use UNISIM.vcomponents.all;


entity l2p_ser is
  generic (
    g_IS_SPARTAN6 : boolean := false
    );
  port
    (
      ---------------------------------------------------------
      -- Reset and clock
      clk_sys_i   : in std_logic;
      clk_sys_n_i : in std_logic;
      clk_p_i     : in std_logic;
      clk_n_i     : in std_logic;
      rst_n_i     : in std_logic;

      ---------------------------------------------------------
      -- Serializer inputs
      l2p_valid_i  : in std_logic;
      l2p_dframe_i : in std_logic;
      l2p_data_i   : in std_logic_vector(31 downto 0);

      ---------------------------------------------------------
      -- L2P DDR outputs
      l2p_clk_p_o  : out std_logic;
      l2p_clk_n_o  : out std_logic;
      l2p_valid_o  : out std_logic;
      l2p_dframe_o : out std_logic;
      l2p_data_o   : out std_logic_vector(15 downto 0)
      );
end l2p_ser;


architecture rtl of l2p_ser is


  -----------------------------------------------------------------------------
  -- Signals declaration
  -----------------------------------------------------------------------------

  -- DDR FF reset
  signal ff_rst : std_logic;

  -- SDR to DDR signals
  signal dframe_d       : std_logic;
  signal valid_d        : std_logic;
  signal data_d         : std_logic_vector(l2p_data_i'range);
  signal l2p_dframe_buf : std_logic;
  signal l2p_valid_buf  : std_logic;
  signal l2p_data_buf   : std_logic_vector(l2p_data_i'range);
  signal l2p_clk_sdr    : std_logic;


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
  -- Re-allign data tightly for the positive clock edge
  -----------------------------------------------------------------------------
  process (clk_sys_i, rst_n_i)
  begin
    if(rst_n_i = c_RST_ACTIVE) then
      dframe_d <= '0';
      valid_d  <= '0';
      data_d   <= (others => '0');
    elsif rising_edge(clk_sys_i) then
      dframe_d <= l2p_dframe_i;
      valid_d  <= l2p_valid_i;
      data_d   <= l2p_data_i;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Align control signals to the negative clock edge
  ------------------------------------------------------------------------------
  -- Spartan3 control signal generation
  gen_ctl_s3 : if g_IS_SPARTAN6 = false generate
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
  end generate gen_ctl_s3;

  -- Spartan6 control signal generation
  gen_ctl_s6 : if g_IS_SPARTAN6 = true generate
    cmp_ddr_ff_valid : ODDR2
      port map
      (
        Q  => l2p_valid_buf,
        C0 => clk_p_i,
        C1 => clk_n_i,
        CE => '1',
        D0 => valid_d,
        D1 => valid_d,
        R  => ff_rst,
        S  => '0'
        );
    cmp_buf_valid : OBUF
      port map (
        O => l2p_valid_o,
        I => l2p_valid_buf
        );

    cmp_ddr_ff_dframe : ODDR2
      port map
      (
        Q  => l2p_dframe_buf,
        C0 => clk_p_i,
        C1 => clk_n_i,
        CE => '1',
        D0 => dframe_d,
        D1 => dframe_d,
        R  => ff_rst,
        S  => '0'
        );
    cmp_buf_dframe : OBUF
      port map (
        O => l2p_dframe_o,
        I => l2p_dframe_buf
        );

  end generate gen_ctl_s6;

  ------------------------------------------------------------------------------
  -- DDR FF instanciation for data
  ------------------------------------------------------------------------------

  -- Spartan3 primitives instanciation
  gen_data_s3 : if g_IS_SPARTAN6 = false generate
    -- Data
    gen_bits : for i in 0 to 15 generate
      cmp_ddr_ff : OFDDRRSE
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
    end generate gen_bits;
  end generate gen_data_s3;

  -- Spartan6 primitives instanciation
  gen_data_s6 : if g_IS_SPARTAN6 = true generate
    -- Data
    gen_bits : for i in 0 to 15 generate
      cmp_ddr_ff : ODDR2
        port map
        (
          Q  => l2p_data_buf(i),
          C0 => clk_p_i,
          C1 => clk_n_i,
          CE => '1',
          D0 => data_d(i),
          D1 => data_d(i+16),
          R  => ff_rst,
          S  => '0'
          );
      cmp_buf : OBUF
        port map (
          O => l2p_data_o(i),
          I => l2p_data_buf(i)
          );
    end generate gen_bits;
  end generate gen_data_s6;

  ------------------------------------------------------------------------------
  -- DDR source synchronous clock generation
  ------------------------------------------------------------------------------
  L2P_CLK_BUF : OBUFDS
    port map(
      O  => l2p_clk_p_o,
      OB => l2p_clk_n_o,
      I  => l2p_clk_sdr);

  -- Spartan3 primitives instanciation
  gen_clk_s3 : if g_IS_SPARTAN6 = false generate
    -- L2P clock
    cmp_ddr_ff : FDDRRSE
      port map(
        Q  => l2p_clk_sdr,
        C0 => clk_n_i,
        C1 => clk_p_i,
        CE => '1',
        D0 => '1',
        D1 => '0',
        R  => '0',
        S  => '0');
  end generate gen_clk_s3;

  -- Spartan6 primitives instanciation
  gen_clk_s6 : if g_IS_SPARTAN6 = true generate
    -- L2P clock
    cmp_ddr_ff : ODDR2
      port map(
        Q  => l2p_clk_sdr,
        C0 => clk_sys_i,
        C1 => clk_sys_n_i,
        CE => '1',
        D0 => '1',
        D1 => '0',
        R  => '0',
        S  => '0');
  end generate gen_clk_s6;

end rtl;


