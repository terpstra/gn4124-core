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
-- date: 31-08-2010
--
-- version: 0.2
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
-- TODO: - error signal
--       -
--       -
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gn4124_core_pkg.all;


entity l2p_dma_master is
  port
    (
      ---------------------------------------------------------
      -- Clock/Reset
      sys_clk_i    : in std_logic;
      sys_rst_n_i  : in std_logic;
      gn4124_clk_i : in std_logic;

      ---------------------------------------------------------
      -- From the DMA controller
      dma_ctrl_carrier_addr_i : in  std_logic_vector(31 downto 0);
      dma_ctrl_host_addr_h_i  : in  std_logic_vector(31 downto 0);
      dma_ctrl_host_addr_l_i  : in  std_logic_vector(31 downto 0);
      dma_ctrl_len_i          : in  std_logic_vector(31 downto 0);
      dma_ctrl_start_l2p_i    : in  std_logic;
      dma_ctrl_done_o         : out std_logic;
      dma_ctrl_error_o        : out std_logic;
      dma_ctrl_byte_swap_i    : in  std_logic_vector(1 downto 0);

      ---------------------------------------------------------
      -- To the L2P Interface (send the DMA data)
      ldm_arb_valid_o  : out std_logic;  -- Read completion signals
      ldm_arb_dframe_o : out std_logic;  -- Toward the arbiter
      ldm_arb_data_o   : out std_logic_vector(31 downto 0);
      ldm_arb_req_o    : out std_logic;
      arb_ldm_gnt_i    : in  std_logic;

      ---------------------------------------------------------
      -- DMA Interface (Pipelined Wishbone)
      l2p_dma_adr_o   : out std_logic_vector(31 downto 0);  -- Adress
      l2p_dma_dat_i   : in  std_logic_vector(31 downto 0);  -- Data in
      l2p_dma_dat_o   : out std_logic_vector(31 downto 0);  -- Data out
      l2p_dma_sel_o   : out std_logic_vector(3 downto 0);   -- Byte select
      l2p_dma_cyc_o   : out std_logic;                      -- Read or write cycle
      l2p_dma_stb_o   : out std_logic;                      -- Read or write strobe
      l2p_dma_we_o    : out std_logic;                      -- Write
      l2p_dma_ack_i   : in  std_logic;                      -- Acknowledge
      l2p_dma_stall_i : in  std_logic                       -- for pipelined Wishbone
      );
end l2p_dma_master;


architecture behaviour of l2p_dma_master is


  component fifo
    port (
      rst         : in  std_logic;
      wr_clk      : in  std_logic;
      rd_clk      : in  std_logic;
      din         : in  std_logic_vector(31 downto 0);
      wr_en       : in  std_logic;
      rd_en       : in  std_logic;
      dout        : out std_logic_vector(31 downto 0);
      full        : out std_logic;
      almost_full : out std_logic;
      empty       : out std_logic);
  end component;


-----------------------------------------------------------------------------
-- Internal Signals
-----------------------------------------------------------------------------

  signal fifo_rst : std_logic;

-- L2P DMA Master State Machine

  constant l2p_max_payload : integer := 32;

  type   l2p_dma_state_type is (IDLE, WB_DATA_WAIT, L2P_HEADER, L2P_ADDR_H, L2P_ADDR_L, L2P_DATA, L2P_DATA_LAST);
  signal l2p_dma_current_state : l2p_dma_state_type;
  signal l2p_dma_next_state    : l2p_dma_state_type;

  type   wishbone_state_type is (IDLE, WB_WAIT_L2P_START, WB_FIFO_FULL, WB_REQUEST, WB_LAST_ACK, WB_WAIT_L2P_IDLE);
  signal wishbone_current_state : wishbone_state_type;
  signal wishbone_next_state    : wishbone_state_type;

  signal s_carrier_addr : unsigned(31 downto 0);
  signal s_host_addr_h  : std_logic_vector(31 downto 0);
  signal s_host_addr_l  : std_logic_vector(31 downto 0);
  signal s_start        : std_logic;

  signal s_l2p_header : std_logic_vector(31 downto 0);
  signal s_l2p_data   : std_logic_vector(31 downto 0);

  signal l2p_data_cpt  : unsigned(9 downto 0);
  signal l2p_len_cpt   : unsigned(9 downto 0);
  signal l2p_address_h : std_logic_vector(31 downto 0);
  signal l2p_address_l : unsigned(31 downto 0);
  signal l2p_len_dec   : std_logic;


  signal wb_data_cpt : unsigned(9 downto 0);
  signal wb_ack_cpt  : unsigned(9 downto 0);

  signal s_fifo_din         : std_logic_vector(31 downto 0);
  signal s_fifo_dout        : std_logic_vector(31 downto 0);
  signal s_fifo_wr_en       : std_logic;
  signal s_fifo_rd_en       : std_logic;
  signal s_fifo_empty       : std_logic;
  signal s_fifo_full        : std_logic;
  signal s_fifo_almost_full : std_logic;

  signal s_64b_address : std_logic;


begin


  ------------------------------------------------------------------------------
  -- Active high reset for fifo
  ------------------------------------------------------------------------------
  gen_fifo_rst_n : if c_RST_ACTIVE = '0' generate
    fifo_rst <= not(sys_rst_n_i);
  end generate;

  gen_fifo_rst : if c_RST_ACTIVE = '1' generate
    fifo_rst <= sys_rst_n_i;
  end generate;


--=========================================================================--
-- PCIe write block
--=========================================================================--
  process (gn4124_clk_i, sys_rst_n_i)
  begin
    if (sys_rst_n_i = c_RST_ACTIVE) then
      l2p_len_cpt   <= (others => '0');
      l2p_data_cpt  <= (others => '0');
      l2p_address_h <= (others => '0');
      l2p_address_l <= (others => '0');
      s_64b_address <= '0';
      s_l2p_header  <= (others => '0');

    elsif rising_edge(gn4124_clk_i) then

      if (s_host_addr_h = X"00000000") then
        s_64b_address <= '0';
      else
        s_64b_address <= '1';
      end if;

      s_l2p_header <= "000"                                          -->  Traffic Class
                      & '0'                                          -->  Snoop
                      & "001"                                        -->  Memory write
                      & s_64b_address                                -->  Memory write
                      & "1111"                                       -->  LBE
                      & "1111"                                       -->  FBE
                      & "000"                                        -->  Reserved
                      & '0'                                          -->  VC
                      & "00"                                         -->  Reserved
                      & std_logic_vector(l2p_data_cpt(9 downto 0));  -->  Length

      if (wishbone_current_state = WB_WAIT_L2P_START and  -- First block of data
          l2p_dma_current_state = IDLE) then
        l2p_len_cpt   <= wb_data_cpt;
        l2p_address_h <= s_host_addr_h;
        l2p_address_l <= unsigned(s_host_addr_l);
        if (wb_data_cpt > l2p_max_payload) then
          l2p_data_cpt <= to_unsigned(l2p_max_payload, 10);
          l2p_len_dec  <= '1';
        else
          l2p_data_cpt <= wb_data_cpt;
          l2p_len_dec  <= '0';
        end if;
      end if;

      if (l2p_len_cpt > 0 and l2p_dma_current_state = L2P_DATA_LAST) then  -- Others blocks
        if (l2p_len_cpt > l2p_max_payload) then
          l2p_data_cpt <= to_unsigned(l2p_max_payload, 10);
          l2p_len_dec  <= '1';
        else
          l2p_data_cpt <= l2p_len_cpt;
          l2p_len_dec  <= '0';
        end if;
        l2p_address_l(31 downto 2) <= l2p_address_l(31 downto 2) + l2p_max_payload;
      end if;

      if (l2p_dma_current_state = L2P_ADDR_L) then  -- Others blocks
        if (l2p_len_dec = '1') then
          l2p_len_cpt <= l2p_len_cpt - l2p_max_payload;
        else
          l2p_len_cpt <= (others => '0');
        end if;
      end if;

      if l2p_dma_current_state = L2P_DATA then
        l2p_data_cpt <= l2p_data_cpt - 1;
      end if;

    end if;
  end process;

  --s_64b_address <= '0' when l2p_address_h = x"00000000" else
  --                 '1';

  --s_l2p_header <= "000"                                          -->  Traffic Class
  --                & '0'                                          -->  Snoop
  --                & "001"                                        -->  Memory write
  --                & s_64b_address                                -->  Memory write
  --                & "1111"                                       -->  LBE
  --                & "1111"                                       -->  FBE
  --                & "000"                                        -->  Reserved
  --                & '0'                                          -->  VC
  --                & "00"                                         -->  Reserved
  --                & std_logic_vector(l2p_data_cpt(9 downto 0));  -->  Length

-----------------------------------------------------------------------------
-- PCIe Write State Machine
-----------------------------------------------------------------------------

  process (gn4124_clk_i, sys_rst_n_i)
  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then
      l2p_dma_current_state <= IDLE;
      ldm_arb_req_o         <= '0';
      ldm_arb_data_o        <= (others => '0');
      ldm_arb_valid_o       <= '0';
      ldm_arb_dframe_o      <= '0';
      s_fifo_rd_en          <= '0';
    elsif rising_edge(gn4124_clk_i) then
      case l2p_dma_current_state is
        -----------------------------------------------------------------
        -- IDLE
        -----------------------------------------------------------------
        when IDLE =>
          if(wishbone_current_state = WB_WAIT_L2P_START) then
            l2p_dma_current_state <= L2P_HEADER;
            ldm_arb_req_o         <= '1';
            ldm_arb_data_o        <= s_l2p_header;
            ldm_arb_valid_o       <= '1';
            ldm_arb_dframe_o      <= '1';
            s_fifo_rd_en          <= '0';
          else
            l2p_dma_current_state <= IDLE;
            ldm_arb_data_o        <= (others => '0');
            ldm_arb_valid_o       <= '0';
            ldm_arb_dframe_o      <= '0';
            s_fifo_rd_en          <= '0';
          end if;

          -----------------------------------------------------------------
          -- L2P HEADER
          -----------------------------------------------------------------
        when L2P_HEADER =>
          if(arb_ldm_gnt_i = '1') then
            ldm_arb_req_o <= '0';
            if(s_64b_address = '1') then
              l2p_dma_current_state <= L2P_ADDR_H;
              ldm_arb_data_o        <= l2p_address_h;
              ldm_arb_valid_o       <= '1';
              ldm_arb_dframe_o      <= '1';
              s_fifo_rd_en          <= '0';
            else
              l2p_dma_current_state <= L2P_ADDR_L;
              ldm_arb_data_o        <= std_logic_vector(l2p_address_l);
              ldm_arb_valid_o       <= '1';
              ldm_arb_dframe_o      <= '1';
              s_fifo_rd_en          <= '1';
            end if;
          else
            l2p_dma_current_state <= L2P_HEADER;
            ldm_arb_req_o         <= '1';
            ldm_arb_data_o        <= s_l2p_header;
            ldm_arb_valid_o       <= '1';
            ldm_arb_dframe_o      <= '1';
            s_fifo_rd_en          <= '0';
          end if;

          -----------------------------------------------------------------
          -- L2P ADDRESS (63-32)
          -----------------------------------------------------------------
        when L2P_ADDR_H =>
          l2p_dma_current_state <= L2P_ADDR_L;
          ldm_arb_data_o        <= std_logic_vector(l2p_address_l);
          ldm_arb_valid_o       <= '1';
          ldm_arb_dframe_o      <= '1';
          s_fifo_rd_en          <= '1';

          -----------------------------------------------------------------
          -- L2P ADDRESS (31-00)
          -----------------------------------------------------------------
        when L2P_ADDR_L =>
          if(s_fifo_empty = '1') then
            l2p_dma_current_state <= WB_DATA_WAIT;
            ldm_arb_valid_o       <= '0';
            ldm_arb_dframe_o      <= '1';
            s_fifo_rd_en          <= '1';
          elsif(l2p_data_cpt = 1) then
            l2p_dma_current_state <= L2P_DATA_LAST;
            ldm_arb_data_o        <= s_l2p_data;
            ldm_arb_valid_o       <= '1';
            ldm_arb_dframe_o      <= '0';
            s_fifo_rd_en          <= '0';
          else
            l2p_dma_current_state <= L2P_DATA;
            --ldm_arb_data_o <= s_l2p_data;
            ldm_arb_valid_o       <= '0';
            ldm_arb_dframe_o      <= '1';
            if (s_fifo_empty = '0') then
              s_fifo_rd_en <= '1';
            end if;
          end if;

          -----------------------------------------------------------------
          -- Wait data from the Wishbone machine
          -----------------------------------------------------------------
        when WB_DATA_WAIT =>
          if(s_fifo_empty = '1') then
            l2p_dma_current_state <= WB_DATA_WAIT;
            ldm_arb_valid_o       <= '0';
            ldm_arb_dframe_o      <= '1';
            s_fifo_rd_en          <= '1';
          elsif(l2p_data_cpt = 1) then
            l2p_dma_current_state <= L2P_DATA_LAST;
            ldm_arb_data_o        <= s_l2p_data;
            ldm_arb_valid_o       <= '1';
            ldm_arb_dframe_o      <= '0';
            s_fifo_rd_en          <= '0';
          else
            l2p_dma_current_state <= L2P_DATA;
            --ldm_arb_data_o <= s_l2p_data;
            ldm_arb_valid_o       <= '0';
            ldm_arb_dframe_o      <= '1';
            if (s_fifo_empty = '0') then
              s_fifo_rd_en <= '1';
            end if;
          end if;

          -----------------------------------------------------------------
          -- L2P DATA
          -----------------------------------------------------------------
        when L2P_DATA =>
          if(s_fifo_empty = '1') then
            l2p_dma_current_state <= WB_DATA_WAIT;
            ldm_arb_valid_o       <= '0';
            ldm_arb_dframe_o      <= '1';
            s_fifo_rd_en          <= '1';
          elsif(l2p_data_cpt = 2) then
            l2p_dma_current_state <= L2P_DATA_LAST;
            ldm_arb_data_o        <= s_l2p_data;
            ldm_arb_valid_o       <= '1';
            ldm_arb_dframe_o      <= '0';
            s_fifo_rd_en          <= '0';
          else
            l2p_dma_current_state <= L2P_DATA;
            ldm_arb_data_o        <= s_l2p_data;
            ldm_arb_valid_o       <= '1';
            ldm_arb_dframe_o      <= '1';
            if (s_fifo_empty = '0') then
              s_fifo_rd_en <= '1';
            end if;
          end if;

          -----------------------------------------------------------------
          -- L2P DATA Last double word
          -----------------------------------------------------------------
        when L2P_DATA_LAST =>
          if(l2p_len_cpt > 0) then
            l2p_dma_current_state <= L2P_HEADER;
            ldm_arb_req_o         <= '1';
            ldm_arb_data_o        <= s_l2p_header;
            ldm_arb_valid_o       <= '1';
            ldm_arb_dframe_o      <= '1';
            s_fifo_rd_en          <= '0';
          else
            l2p_dma_current_state <= IDLE;
            ldm_arb_data_o        <= (others => '0');
            ldm_arb_valid_o       <= '0';
            ldm_arb_dframe_o      <= '0';
            s_fifo_rd_en          <= '0';
          end if;

          -----------------------------------------------------------------
          -- OTHERS
          -----------------------------------------------------------------
        when others =>
          l2p_dma_current_state <= IDLE;
          ldm_arb_req_o         <= '0';
          ldm_arb_data_o        <= (others => '0');
          ldm_arb_valid_o       <= '0';
          ldm_arb_dframe_o      <= '0';
          s_fifo_rd_en          <= '0';

      end case;
      --l2p_dma_current_state <= l2p_dma_next_state;
    end if;
  end process;


-----------------------------------------------------------------------------
-- Bus toward arbiter
-----------------------------------------------------------------------------

  --ldm_arb_req_o <= '1' when (l2p_dma_current_state = L2P_HEADER)
  --                 else '0';

  --ldm_arb_data_o <= s_l2p_header when (l2p_dma_current_state = L2P_HEADER)
  --                  else l2p_address_h when (l2p_dma_current_state = L2P_ADDR_H)

  --                  else std_logic_vector(l2p_address_l) when (l2p_dma_current_state = L2P_ADDR_L)
  --                  else s_l2p_data when (l2p_dma_current_state = L2P_DATA
  --                                        or l2p_dma_current_state = L2P_DATA_LAST)
  --                  else (others => '0');

  --ldm_arb_valid_o <= '1' when (l2p_dma_current_state = L2P_HEADER
  --                             or l2p_dma_current_state = L2P_ADDR_H
  --                             or l2p_dma_current_state = L2P_ADDR_L
  --                             or l2p_dma_current_state = L2P_DATA
  --                             or l2p_dma_current_state = L2P_DATA_LAST)
  --                   else '0';


  --ldm_arb_dframe_o <= '1' when (l2p_dma_current_state = L2P_HEADER
  --                              or l2p_dma_current_state = L2P_ADDR_H
  --                              or l2p_dma_current_state = L2P_ADDR_L
  --                              or l2p_dma_current_state = WB_DATA_WAIT
  --                              or l2p_dma_current_state = L2P_DATA)
  --                    else '0';

  --s_fifo_rd_en <= '1' when ((l2p_dma_current_state = L2P_ADDR_L
  --                           or l2p_dma_current_state = WB_DATA_WAIT
  --                           or l2p_dma_current_state = L2P_DATA) and not s_fifo_empty='1')
  --                else '0';


--=========================================================================--
-- Wishbone L2P DMA master block (pipelined)
--=========================================================================--

-----------------------------------------------------------------------------
-- Wishbone master state machine
-----------------------------------------------------------------------------
  process (sys_clk_i, sys_rst_n_i)
  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then
      wishbone_current_state <= IDLE;
    elsif rising_edge(sys_clk_i) then
      case wishbone_current_state is
        -----------------------------------------------------------------
        -- Wait for a Wishbone cycle
        -----------------------------------------------------------------
        when IDLE =>
          if(dma_ctrl_start_l2p_i = '1' and not (dma_ctrl_len_i(31 downto 2) = "000000000000000000000000000000")) then
            wishbone_current_state <= WB_WAIT_L2P_START;
          else
            wishbone_current_state <= IDLE;
          end if;

          -----------------------------------------------------------------
          -- Wait L2P Write machine is ready
          -----------------------------------------------------------------
        when WB_WAIT_L2P_START =>
          if not (l2p_dma_current_state = IDLE) then
            wishbone_current_state <= WB_REQUEST;
          else
            wishbone_current_state <= WB_WAIT_L2P_START;
          end if;

          -----------------------------------------------------------------
          -- Request on the Wishbone bus
          -----------------------------------------------------------------
        when WB_REQUEST =>
          if(wb_data_cpt = 1) then
            if (l2p_dma_ack_i = '0') then
              wishbone_current_state <= WB_LAST_ACK;
            elsif (wb_ack_cpt = 2) then
              wishbone_current_state <= WB_LAST_ACK;
            else
              wishbone_current_state <= WB_WAIT_L2P_IDLE;
            end if;
          elsif (s_fifo_almost_full = '1') then
            wishbone_current_state <= WB_FIFO_FULL;
          else
            wishbone_current_state <= WB_REQUEST;
          end if;

          -----------------------------------------------------------------
          -- Wait the fifo is not full
          -----------------------------------------------------------------
        when WB_FIFO_FULL =>
          if(s_fifo_almost_full = '0') then
            if(wb_data_cpt > 0) then
              wishbone_current_state <= WB_REQUEST;
            else
              wishbone_current_state <= WB_WAIT_L2P_IDLE;
            end if;
          else
            wishbone_current_state <= WB_FIFO_FULL;
          end if;

          -----------------------------------------------------------------
          -- Wait for the last acknowledge
          -----------------------------------------------------------------
        when WB_LAST_ACK =>
          if(l2p_dma_ack_i = '1') then
            wishbone_current_state <= WB_WAIT_L2P_IDLE;
          else
            wishbone_current_state <= WB_LAST_ACK;
          end if;

          -----------------------------------------------------------------
          -- Wait the L2P machine is idle
          -----------------------------------------------------------------
        when WB_WAIT_L2P_IDLE =>
          if (l2p_dma_current_state = IDLE) then
            wishbone_current_state <= IDLE;
          else
            wishbone_current_state <= WB_WAIT_L2P_IDLE;
          end if;
          -----------------------------------------------------------------
          -- OTHERS
          -----------------------------------------------------------------
        when others =>
          wishbone_current_state <= IDLE;
      end case;
      --öwishbone_current_state <= wishbone_next_state;
    end if;
  end process;

  process (sys_clk_i, sys_rst_n_i)
  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then

      wb_data_cpt    <= (others => '0');
      wb_ack_cpt     <= (others => '0');
      s_carrier_addr <= (others => '0');
      s_host_addr_h  <= (others => '0');
      s_host_addr_l  <= (others => '0');
    elsif rising_edge(sys_clk_i) then
      if (dma_ctrl_start_l2p_i = '1' and l2p_dma_current_state = IDLE) then
        s_carrier_addr <= unsigned(dma_ctrl_carrier_addr_i);
        s_host_addr_h  <= dma_ctrl_host_addr_h_i;
        s_host_addr_l  <= dma_ctrl_host_addr_l_i;
        wb_data_cpt    <= unsigned(dma_ctrl_len_i(11 downto 2));
        wb_ack_cpt     <= unsigned(dma_ctrl_len_i(11 downto 2));
      end if;
      if (wishbone_current_state = WB_REQUEST and l2p_dma_stall_i = '0') then
        wb_data_cpt    <= wb_data_cpt - 1;
        s_carrier_addr <= s_carrier_addr + 1;
      end if;
      if (l2p_dma_ack_i = '1') then
        wb_ack_cpt <= wb_ack_cpt - 1;
      end if;

    end if;
  end process;

  l2p_dma_cyc_o <= '1' when (wishbone_current_state = WB_REQUEST
                             or wishbone_current_state = WB_LAST_ACK
                             or wishbone_current_state = WB_FIFO_FULL)
                   else '0';

  l2p_dma_stb_o <= '1' when wishbone_current_state = WB_REQUEST
                   else '0';

  l2p_dma_sel_o <= "1111" when wishbone_current_state = WB_REQUEST
                   else "0000";

  l2p_dma_adr_o <= std_logic_vector(s_carrier_addr) when wishbone_current_state = WB_REQUEST
                   else (others => '0');

  l2p_dma_we_o <= '0';

  l2p_dma_dat_o <= (others => '0');


  dma_ctrl_done_o <= '1' when wishbone_current_state = WB_WAIT_L2P_IDLE
                     else '0';

  dma_ctrl_error_o <= '0';
--=========================================================================--
-- FIFO block
--=========================================================================--
  s_fifo_din       <= l2p_dma_dat_i when dma_ctrl_byte_swap_i = "00" else
                      l2p_dma_dat_i(15 downto 0)&
                      l2p_dma_dat_i(31 downto 16) when dma_ctrl_byte_swap_i = "10" else
                      l2p_dma_dat_i(7 downto 0)&
                      l2p_dma_dat_i(15 downto 8)&
                      l2p_dma_dat_i(23 downto 16)&
                      l2p_dma_dat_i(31 downto 24) when dma_ctrl_byte_swap_i = "11" else
                      l2p_dma_dat_i(23 downto 16)&
                      l2p_dma_dat_i(31 downto 24)&
                      l2p_dma_dat_i(7 downto 0)&
                      l2p_dma_dat_i(15 downto 8);
  s_fifo_wr_en <= l2p_dma_ack_i when wb_ack_cpt > 0
                  else '0';
  s_l2p_data <= s_fifo_dout;

  u_fifo : fifo port map
    (
      rst         => fifo_rst,
      wr_clk      => sys_clk_i,
      rd_clk      => gn4124_clk_i,
      din         => s_fifo_din,
      wr_en       => s_fifo_wr_en,
      rd_en       => s_fifo_rd_en,
      dout        => s_fifo_dout,
      full        => s_fifo_full,
      almost_full => s_fifo_almost_full,
      empty       => s_fifo_empty
      );

end behaviour;

