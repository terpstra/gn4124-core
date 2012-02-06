--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: P2L deserializer (p2l_des.vhd)
--
-- authors: Simon Deprez (simon.deprez@cern.ch)
--          Matthieu Cattin (matthieu.cattin@cern.ch)
--
-- date: 31-08-2010
--
-- version: 1.0
--
-- description: Takes the DDR P2L bus and converts to SDR that is synchronous
--              to the core clock.
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


entity p2l_des is
  generic (
    g_IS_SPARTAN6 : boolean := false
    );
  port
    (
      ---------------------------------------------------------
      -- Reset and clock
      rst_n_i     : in std_logic;
      clk_sys_i   : in std_logic;
      clk_sys_n_i : in std_logic;
      clk_p_i     : in std_logic;
      clk_n_i     : in std_logic;

      ---------------------------------------------------------
      -- P2L clock domain (DDR)
      --
      -- P2L inputs
      p2l_valid_i  : in std_logic;
      p2l_dframe_i : in std_logic;
      p2l_data_i   : in std_logic_vector(15 downto 0);

      ---------------------------------------------------------
      -- Core clock domain (SDR)
      --
      -- Deserialized output
      p2l_valid_o  : out std_logic;
      p2l_dframe_o : out std_logic;
      p2l_data_o   : out std_logic_vector(31 downto 0)
      );
end p2l_des;


architecture rtl of p2l_des is


  -----------------------------------------------------------------------------
  -- Signals declaration
  -----------------------------------------------------------------------------

  -- DDR FF reset
  signal ff_rst     : std_logic;
  signal p2l_data_d : std_logic_vector(p2l_data_i'range);

  -- SDR signals
  signal p2l_valid_p    : std_logic;
  signal p2l_valid_n    : std_logic;
  signal p2l_valid_buf  : std_logic;
  signal p2l_dframe_p   : std_logic;
  signal p2l_dframe_n   : std_logic;
  signal p2l_dframe_buf : std_logic;
  signal p2l_data_p     : std_logic_vector(p2l_data_i'range);
  signal p2l_data_n     : std_logic_vector(p2l_data_i'range);
  signal p2l_data_buf   : std_logic_vector(p2l_data_i'range);
  signal p2l_data_sdr_l : std_logic_vector(p2l_data_i'range);
  signal p2l_data_sdr   : std_logic_vector(p2l_data_i'length*2-1 downto 0);


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


  ------------------------------------------------------------------------------
  -- DDR FF instanciation
  ------------------------------------------------------------------------------

  -- Spartan3 primitives instanciation
  gen_in_s3 : if g_IS_SPARTAN6 = false generate
    -- Data
    DDRFF_D : for i in p2l_data_i'range generate
      U : IFDDRRSE
        port map
        (
          Q0 => p2l_data_n(i),
          Q1 => p2l_data_p(i),
          C0 => clk_n_i,
          C1 => clk_p_i,
          CE => '1',
          D  => p2l_data_i(i),
          R  => ff_rst,
          S  => '0'
          );
    end generate;

    -- dframe
    DDRFF_F : IFDDRRSE
      port map
      (
        Q0 => p2l_dframe_n,
        Q1 => p2l_dframe_p,
        C0 => clk_n_i,
        C1 => clk_p_i,
        CE => '1',
        D  => p2l_dframe_i,
        R  => ff_rst,
        S  => '0'
        );

    -- valid
    DDRFF_V : IFDDRRSE
      port map
      (
        Q0 => p2l_valid_n,
        Q1 => p2l_valid_p,
        C0 => clk_n_i,
        C1 => clk_p_i,
        CE => '1',
        D  => p2l_valid_i,
        R  => ff_rst,
        S  => '0'
        );
  end generate gen_in_s3;

  -- Spartan6 primitives instanciation
  gen_in_s6 : if g_IS_SPARTAN6 = true generate
    -- Data
    gen_data : for i in p2l_data_i'range generate
      cmp_buf : IBUF
        port map (
          O => p2l_data_buf(i),
          I => p2l_data_i(i)
          );

      cmp_ddr_ff : IDDR2
        port map
        (
          Q0 => p2l_data_n(i),
          Q1 => p2l_data_p(i),
          C0 => clk_n_i,
          C1 => clk_p_i,
          CE => '1',
          D  => p2l_data_buf(i),
          R  => ff_rst,
          S  => '0'
          );
    end generate gen_data;

    -- dframe
    cmp_buf_dframe : IBUF
      port map (
        O => p2l_dframe_buf,
        I => p2l_dframe_i
        );

    cmp_ddr_ff_dframe : IDDR2
      port map
      (
        Q0 => p2l_dframe_n,
        Q1 => p2l_dframe_p,
        C0 => clk_n_i,
        C1 => clk_p_i,
        CE => '1',
        D  => p2l_dframe_buf,
        R  => ff_rst,
        S  => '0'
        );

    -- valid
    cmp_buf_valid : IBUF
      port map (
        O => p2l_valid_buf,
        I => p2l_valid_i
        );

    cmp_ddr_ff_valid : IDDR2
      port map
      (
        Q0 => p2l_valid_n,
        Q1 => p2l_valid_p,
        C0 => clk_n_i,
        C1 => clk_p_i,
        CE => '1',
        D  => p2l_valid_buf,
        R  => ff_rst,
        S  => '0'
        );
  end generate gen_in_s6;


  -----------------------------------------------------------------------------
  -- Align positive edge data to negative edge clock
  -----------------------------------------------------------------------------
  process (clk_sys_n_i, rst_n_i)
  begin
    if(rst_n_i = c_RST_ACTIVE) then
      p2l_data_sdr_l <= (others => '0');
    elsif rising_edge(clk_sys_n_i) then
      p2l_data_sdr_l <= p2l_data_p;
    end if;
  end process;

  -- Combine 16-bit DDR data into 32-bit word
  p2l_data_sdr <= p2l_data_n & p2l_data_sdr_l;


  -----------------------------------------------------------------------------
  -- Final positive edge clock alignment
  -----------------------------------------------------------------------------
  process (clk_sys_i, rst_n_i)
  begin
    if(rst_n_i = c_RST_ACTIVE) then
      p2l_valid_o  <= '0';
      p2l_dframe_o <= '0';
      p2l_data_o   <= (others => '0');
    elsif rising_edge(clk_sys_i) then
      p2l_valid_o  <= p2l_valid_p;
      p2l_dframe_o <= p2l_dframe_p;
      p2l_data_o   <= p2l_data_sdr;
    end if;
  end process;


end rtl;


