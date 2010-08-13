--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: 32 bit DMA master (l2p_dma_master.vhd)
--
-- author: Simon Deprez (simon.deprez@cern.ch)
--
-- date: 24-06-2010
--
-- version: 0.1
--
-- description: Provide a pipelined Wishbone interface to performs DMA 
-- transfers from local application to PCI express host.
--
-- dependencies: 
--
--------------------------------------------------------------------------------
-- last changes: <date> <initials> <log>
-- <extended description>
--------------------------------------------------------------------------------
-- TODO: - Pipelined Wishbone interface
--       - 
--       - 
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

entity l2p_dma_master is
  port
    (
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- Clock/Reset
      --
      clk_i : in std_ulogic;
      rst_i : in std_ulogic;
      ---------------------------------------------------------

      ---------------------------------------------------------
      -- From the DMA controller 
      --
      dma_ctrl_carrier_addr_i : in  std_logic_vector(31 downto 0);
      dma_ctrl_host_addr_h_i  : in  std_logic_vector(31 downto 0);
      dma_ctrl_host_addr_l_i  : in  std_logic_vector(31 downto 0);
      dma_ctrl_len_i          : in  std_logic_vector(31 downto 0);
      dma_ctrl_start_l2p_i    : in  std_logic;
      dma_ctrl_done_o         : out std_logic;
      dma_ctrl_error_o        : out std_logic;
      --
      ---------------------------------------------------------

      ---------------------------------------------------------
      -- To the L2P Interface (send the DMA data)
      --
      ldm_arb_valid_o  : out std_ulogic;  -- Read completion signals
      ldm_arb_dframe_o : out std_ulogic;  -- Toward the arbiter
      ldm_arb_data_o   : out std_ulogic_vector(31 downto 0);
      ldm_arb_req_o    : out std_ulogic;
      arb_ldm_gnt_i    : in  std_ulogic;
      --
      ---------------------------------------------------------

      ---------------------------------------------------------
      -- DMA Interface (Pipelined Wishbone)
      --
      l2p_dma_adr_o   : out std_logic_vector(31 downto 0);  -- Adress
      l2p_dma_dat_i   : in  std_logic_vector(31 downto 0);  -- Data in
      l2p_dma_dat_o   : out std_logic_vector(31 downto 0);  -- Data out
      l2p_dma_sel_o   : out std_logic_vector(3 downto 0);   -- Byte select
      l2p_dma_cyc_o   : out std_logic;  -- Read or write cycle
      l2p_dma_stb_o   : out std_logic;  -- Read or write strobe
      l2p_dma_we_o    : out std_logic;  -- Write
      l2p_dma_ack_i   : in  std_logic;  -- Acknowledge
      l2p_dma_stall_i : in  std_logic   -- for pipelined Wishbone
      --
      ---------------------------------------------------------
      );
end l2p_dma_master;

architecture behaviour of l2p_dma_master is

component fifo
  port (
  rst: IN std_logic;
  wr_clk: IN std_logic;
  rd_clk: IN std_logic;
  din: IN std_logic_VECTOR(31 downto 0);
  wr_en: IN std_logic;
  rd_en: IN std_logic;
  dout: OUT std_logic_VECTOR(31 downto 0);
  full: OUT std_logic;
  almost_full: OUT std_logic;
  empty: OUT std_logic);
end component;

-----------------------------------------------------------------------------
-- Internal Signals 
-----------------------------------------------------------------------------
-- L2P DMA Master State Machine
  type   l2p_dma_state_type is (IDLE, WB_DATA_WAIT, L2P_HEADER, L2P_ADDR_H, L2P_ADDR_L, L2P_DATA, L2P_DATA_LAST);
  signal l2p_dma_current_state : l2p_dma_state_type;

  type   wishbone_state_type is (IDLE, WB_REQUEST, WB_STALL, WB_LAST_ACK, WB_FIFO_FULL);
  signal wishbone_current_state : wishbone_state_type;

  signal s_carrier_addr : std_logic_vector(31 downto 0);
  signal s_host_addr_h  : std_logic_vector(31 downto 0);
  signal s_host_addr_l  : std_logic_vector(31 downto 0);
  signal s_len          : std_logic_vector(29 downto 0);
  signal s_start        : std_logic;
  signal s_l2p_header   : std_logic_vector(31 downto 0);
  signal s_l2p_data     : std_logic_vector(31 downto 0);
  signal l2p_data_cpt   : std_logic_vector(29 downto 0);
  signal wb_data_cpt    : std_logic_vector(29 downto 0);
  signal s_fifo_rd_en   : std_logic;
  signal s_fifo_empty   : std_logic;
  signal s_fifo_full    : std_logic;
  signal s_fifo_almost_full : std_logic;
  
  signal s_64b_address   : std_logic;

begin


--=========================================================================--
-- PCIe write block
--=========================================================================-- 
  process (clk_i, rst_i)
    variable l2p_dma_next_state : l2p_dma_state_type;
  begin
    if (rst_i = '1') then
      s_host_addr_h  <= x"00000000";
      s_host_addr_l  <= x"00000000";
      s_len          <= "000000000000000000000000000000";
      l2p_data_cpt   <= "000000000000000000000000000000";
    elsif (clk_i'event and clk_i = '1') then
      if (dma_ctrl_start_l2p_i = '1' and l2p_dma_current_state = IDLE) then
        s_host_addr_h  <= dma_ctrl_host_addr_h_i;
        s_host_addr_l  <= dma_ctrl_host_addr_l_i;
        s_len          <= dma_ctrl_len_i(31 downto 2);
        l2p_data_cpt   <= dma_ctrl_len_i(31 downto 2);
      end if;
      if l2p_dma_current_state = L2P_DATA then
        l2p_data_cpt <= l2p_data_cpt - 1;
      end if;
    end if;
  end process;
  s_64b_address <= '0' when s_host_addr_h = x"00000000" else 
                   '1';

  s_l2p_header <= "000"                  -->  Traffic Class
                  & '0'                  -->  Snoop
                  & "001"                -->  Memory write
                  & s_64b_address         -->  Memory write
                  & "1111"               -->  LBE
                  & "1111"               -->  FBE
                  & "000"                -->  Reserved
                  & '0'                  -->  VC
                  & "00"                 -->  Reserved
                  & s_len(9 downto 0);   -->  Length

-----------------------------------------------------------------------------
-- PCIe write State Machine
-----------------------------------------------------------------------------

  process (clk_i, rst_i)
    variable l2p_dma_next_state : l2p_dma_state_type;
  begin
    if(rst_i = '1') then
      l2p_dma_current_state <= IDLE;
    elsif(clk_i'event and clk_i = '1') then
      case l2p_dma_current_state is
        -----------------------------------------------------------------
        -- IDLE
        -----------------------------------------------------------------
        when IDLE =>
          if(dma_ctrl_start_l2p_i = '1') then
            l2p_dma_next_state := L2P_HEADER;
          else
            l2p_dma_next_state := IDLE;
          end if;

        -----------------------------------------------------------------
        -- L2P HEADER
        -----------------------------------------------------------------
        when L2P_HEADER =>
          if(arb_ldm_gnt_i = '1') then
            if(s_64b_address = '1') then
              l2p_dma_next_state := L2P_ADDR_H;
            else
              l2p_dma_next_state := L2P_ADDR_L;
            end if;
          else
            l2p_dma_next_state := L2P_HEADER;
          end if;

        -----------------------------------------------------------------
        -- L2P ADDRESS (63-32)
        -----------------------------------------------------------------
        when L2P_ADDR_H =>
          l2p_dma_next_state := L2P_ADDR_L;

        -----------------------------------------------------------------
        -- L2P ADDRESS (31-00)
        -----------------------------------------------------------------
        when L2P_ADDR_L =>
          if(s_fifo_empty = '0') then
            l2p_dma_next_state := L2P_DATA;
          else
            l2p_dma_next_state := WB_DATA_WAIT;
          end if;

        -----------------------------------------------------------------
        -- Wait for Wishbone acknowledge 
        -----------------------------------------------------------------
        when WB_DATA_WAIT =>
          if(s_fifo_empty = '0') then
            l2p_dma_next_state := L2P_DATA;
          else
            l2p_dma_next_state := WB_DATA_WAIT;
          end if;

        -----------------------------------------------------------------
        -- L2P DATA
        -----------------------------------------------------------------
        when L2P_DATA =>
          if(l2p_data_cpt = 2) then
            l2p_dma_next_state := L2P_DATA_LAST;
          elsif(s_fifo_empty = '0') then
            l2p_dma_next_state := L2P_DATA;
          else
            l2p_dma_next_state := WB_DATA_WAIT;
          end if;

        -----------------------------------------------------------------
        -- L2P DATA Last double word
        -----------------------------------------------------------------
        when L2P_DATA_LAST =>
          l2p_dma_next_state := IDLE;

        -----------------------------------------------------------------
        -- OTHERS
        -----------------------------------------------------------------
        when others =>
          l2p_dma_next_state := IDLE;
      end case;
      l2p_dma_current_state <= l2p_dma_next_state;
    end if;
  end process;
  
  
-----------------------------------------------------------------------------
-- Bus toward arbiter
-----------------------------------------------------------------------------

  ldm_arb_req_o <= '1' when (l2p_dma_current_state = L2P_HEADER)
                       else '0';

  ldm_arb_data_o <= To_StdULogicVector(s_l2p_header) when (l2p_dma_current_state = L2P_HEADER)
                       else To_StdULogicVector(s_host_addr_h) when (l2p_dma_current_state = L2P_ADDR_H)

                       else To_StdULogicVector(s_host_addr_l) when (l2p_dma_current_state = L2P_ADDR_L)
                       --else To_StdULogicVector(s_l2p_data)    when (l2p_dma_current_state = L2P_DATA
                       else To_StdULogicVector(s_l2p_data)    when (l2p_dma_current_state = L2P_DATA
                                            or l2p_dma_current_state = L2P_DATA_LAST)
                       else x"00000000";

  ldm_arb_valid_o <= '1' when (l2p_dma_current_state = L2P_HEADER
                                             or l2p_dma_current_state = L2P_ADDR_H
                                             or l2p_dma_current_state = L2P_ADDR_L
                                             or l2p_dma_current_state = L2P_DATA
                                             or l2p_dma_current_state = L2P_DATA_LAST)
                       else '0';


  ldm_arb_dframe_o <= '1' when (l2p_dma_current_state = L2P_HEADER
                                             or l2p_dma_current_state = L2P_ADDR_H
                                             or l2p_dma_current_state = L2P_ADDR_L
                                             or l2p_dma_current_state = WB_DATA_WAIT
                                             or l2p_dma_current_state = L2P_DATA)
                       else '0';

  s_fifo_rd_en <= '1' when ((l2p_dma_current_state = L2P_ADDR_L
                                             or l2p_dma_current_state = WB_DATA_WAIT
                                             or l2p_dma_current_state = L2P_DATA) and not s_fifo_empty='1') 
                      else '0';


--=========================================================================--
-- Wishbone L2P DMA master block (pipelined)
--=========================================================================--

-----------------------------------------------------------------------------
-- Wishbone master state machine
-----------------------------------------------------------------------------
  process (clk_i, rst_i)
    variable wishbone_next_state : wishbone_state_type;
  begin
    if(rst_i = '1') then
      wishbone_current_state <= IDLE;
    elsif(clk_i'event and clk_i = '1') then
      case wishbone_current_state is
        -----------------------------------------------------------------
        -- Wait for a Wishbone cycle
        -----------------------------------------------------------------
        when IDLE =>
          if(dma_ctrl_start_l2p_i = '1') then
            wishbone_next_state := WB_REQUEST;
          else
            wishbone_next_state := IDLE;
          end if;

        -----------------------------------------------------------------
        -- Request on the Wishbone bus
        -----------------------------------------------------------------
        when WB_REQUEST =>
          if (l2p_dma_stall_i = '1') then
            wishbone_next_state := WB_STALL;
          elsif(wb_data_cpt = 1 and l2p_dma_ack_i = '0') then
            wishbone_next_state := WB_LAST_ACK;
          elsif(wb_data_cpt = 1) then
            wishbone_next_state := IDLE;
          elsif (s_fifo_almost_full = '1') then
            wishbone_next_state := WB_FIFO_FULL;
          else
            wishbone_next_state := WB_REQUEST;
          end if;
          
        -----------------------------------------------------------------
        -- Request on the Wishbone bus
        -----------------------------------------------------------------
        when WB_STALL =>
          if (l2p_dma_stall_i = '1') then
            wishbone_next_state := WB_STALL;
          elsif(wb_data_cpt = 1 and l2p_dma_ack_i = '0') then
            wishbone_next_state := WB_LAST_ACK;
          elsif(wb_data_cpt = 1) then
            wishbone_next_state := IDLE;
          elsif (s_fifo_almost_full = '1') then
            wishbone_next_state := WB_FIFO_FULL;
          else
            wishbone_next_state := WB_REQUEST;
          end if;
          
        -----------------------------------------------------------------
        -- Request on the Wishbone bus
        -----------------------------------------------------------------
        when WB_FIFO_FULL =>
          if(s_fifo_almost_full = '0' and s_fifo_almost_full = '0') then
            if(wb_data_cpt > 0) then
              wishbone_next_state := WB_REQUEST;
            else
              wishbone_next_state := IDLE;
            end if;
          else
            wishbone_next_state := WB_FIFO_FULL;
          end if;

        -----------------------------------------------------------------
        -- Wait for the last acknowledge
        -----------------------------------------------------------------
        when WB_LAST_ACK =>
          if(l2p_dma_ack_i = '1') then
            wishbone_next_state := IDLE;
          else
            wishbone_next_state := WB_LAST_ACK;
          end if;

        -----------------------------------------------------------------
        -- OTHERS
        -----------------------------------------------------------------
        when others =>
          wishbone_next_state := IDLE;
      end case;
      wishbone_current_state <= wishbone_next_state;
    end if;
  end process;

  process (clk_i, rst_i)
  begin
    if(rst_i = '1') then
      wb_data_cpt    <= "000000000000000000000000000000";
      s_carrier_addr <= x"00000000";
    elsif (clk_i'event and clk_i = '1') then
      if (dma_ctrl_start_l2p_i = '1' and l2p_dma_current_state = IDLE) then
        s_carrier_addr <= dma_ctrl_carrier_addr_i;
        wb_data_cpt    <= dma_ctrl_len_i(31 downto 2);
      end if;
      if ((wishbone_current_state = WB_REQUEST or wishbone_current_state = WB_STALL) and l2p_dma_stall_i = '0') then
        wb_data_cpt <= wb_data_cpt - 1;
        s_carrier_addr <= s_carrier_addr+1;
      end if;
    end if;
  end process;
  
  l2p_dma_cyc_o <= '1' when (wishbone_current_state = WB_REQUEST
                          or wishbone_current_state = WB_STALL
                          or wishbone_current_state = WB_LAST_ACK
                          or wishbone_current_state = WB_FIFO_FULL)
              else '0';

  l2p_dma_stb_o <= '1' when (wishbone_current_state = WB_REQUEST
                          or wishbone_current_state = WB_STALL)
              else '0';

  l2p_dma_we_o  <= '0' when (wishbone_current_state = WB_REQUEST
                          or wishbone_current_state = WB_STALL)
              else '0';
              
  l2p_dma_sel_o <= "1111" when (wishbone_current_state = WB_REQUEST
                          or wishbone_current_state = WB_STALL)
              else "0000";
 
  l2p_dma_dat_o <= x"00000000";
  l2p_dma_adr_o <= s_carrier_addr when (wishbone_current_state = WB_REQUEST
                                     or wishbone_current_state = WB_STALL)
              else x"00000000";
  
--=========================================================================--
-- FIFO block
--=========================================================================-- 

  u_fifo : fifo port map
  (
    rst    => rst_i,
    wr_clk => clk_i,
    rd_clk => clk_i,
    din    => l2p_dma_dat_i,
    wr_en  => l2p_dma_ack_i,
    rd_en  => s_fifo_rd_en,
    dout   => s_l2p_data,
    full   => s_fifo_full,
    almost_full   => s_fifo_almost_full,
    empty  => s_fifo_empty
  );

end behaviour;

