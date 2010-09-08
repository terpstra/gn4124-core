--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: 32 bit P2L DMA master (p2l_dma_master.vhd)
--
-- author: Simon Deprez (simon.deprez@cern.ch)
--
-- date: 31-08-2010
--
-- version: 0.1
--
-- description: Provide a pipelined Wishbone interface to performs DMA
-- transfers from PCI express host to local application.
--
-- dependencies:
--
--------------------------------------------------------------------------------
-- last changes: <date> <initials> <log>
-- <extended description>
--------------------------------------------------------------------------------
-- TODO: - P2L transfer
--       - error signal
--       -
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gn4124_core_pkg.all;


entity p2l_dma_master is
  port
    (

      DEBUG : out std_logic_vector(3 downto 0);

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
      dma_ctrl_start_p2l_i    : in  std_logic;
      dma_ctrl_start_next_i   : in  std_logic;
      dma_ctrl_done_o         : out std_logic;
      dma_ctrl_error_o        : out std_logic;
      dma_ctrl_byte_swap_i    : in  std_logic_vector(1 downto 0);

      ---------------------------------------------------------
      -- From P2L Decoder (receive the read completion)
      --
      -- Header
      pd_pdm_hdr_start_i   : in std_logic;                      -- Indicates Header start cycle
      pd_pdm_hdr_length_i  : in std_logic_vector(9 downto 0);   -- Latched LENGTH value from header
      pd_pdm_hdr_cid_i     : in std_logic_vector(1 downto 0);   -- Completion ID
      pd_pdm_target_mrd_i  : in std_logic;                      -- Target memory read
      pd_pdm_target_mwr_i  : in std_logic;                      -- Target memory write
      pd_pdm_target_cpld_i : in std_logic;                      -- Target memory write
      --
      -- Address
      pd_pdm_addr_start_i  : in std_logic;                      -- Indicates Address Start
      pd_pdm_addr_i        : in std_logic_vector(31 downto 0);  -- Latched Address that will increment with data
      pd_pdm_wbm_addr_i    : in std_logic;                      -- Indicates that current address is for the EPI interface
                                                                -- Can be connected to a decode of IP2L_ADDRi
                                                                -- or to IP2L_ADDRi(0) for BAR2
                                                                -- or to not IP2L_ADDRi(0) for BAR0
      --
      -- Data
      pd_pdm_data_valid_i  : in std_logic;                      -- Indicates Data is valid
      pd_pdm_data_last_i   : in std_logic;                      -- Indicates end of the packet
      pd_pdm_data_i        : in std_logic_vector(31 downto 0);  -- Data
      pd_pdm_be_i          : in std_logic_vector(3 downto 0);   -- Byte Enable for data

      ---------------------------------------------------------
      -- To the P2L Interface (send the DMA Master Read request)
      pdm_arb_valid_o  : out std_logic;  -- Read completion signals
      pdm_arb_dframe_o : out std_logic;  -- Toward the arbiter
      pdm_arb_data_o   : out std_logic_vector(31 downto 0);
      pdm_arb_req_o    : out std_logic;
      arb_pdm_gnt_i    : in  std_logic;

      ---------------------------------------------------------
      -- DMA Interface (Pipelined Wishbone)
      p2l_dma_adr_o   : out std_logic_vector(31 downto 0);  -- Adress
      p2l_dma_dat_i   : in  std_logic_vector(31 downto 0);  -- Data in
      p2l_dma_dat_o   : out std_logic_vector(31 downto 0);  -- Data out
      p2l_dma_sel_o   : out std_logic_vector(3 downto 0);   -- Byte select
      p2l_dma_cyc_o   : out std_logic;                      -- Read or write cycle
      p2l_dma_stb_o   : out std_logic;                      -- Read or write strobe
      p2l_dma_we_o    : out std_logic;                      -- Write
      p2l_dma_ack_i   : in  std_logic;                      -- Acknowledge
      p2l_dma_stall_i : in  std_logic;                      -- for pipelined Wishbone

      ---------------------------------------------------------
      -- From P2L DMA MASTER
      next_item_carrier_addr_o : out std_logic_vector(31 downto 0);
      next_item_host_addr_h_o  : out std_logic_vector(31 downto 0);
      next_item_host_addr_l_o  : out std_logic_vector(31 downto 0);
      next_item_len_o          : out std_logic_vector(31 downto 0);
      next_item_next_l_o       : out std_logic_vector(31 downto 0);
      next_item_next_h_o       : out std_logic_vector(31 downto 0);
      next_item_attrib_o       : out std_logic_vector(31 downto 0);
      next_item_valid_o        : out std_logic
      );
end p2l_dma_master;

architecture behaviour of p2l_dma_master is
--
--component fifo
--  port (
--  rst: IN std_logic;
--  wr_clk: IN std_logic;
--  rd_clk: IN std_logic;
--  din: IN std_logic_VECTOR(31 downto 0);
--  wr_en: IN std_logic;
--  rd_en: IN std_logic;
--  dout: OUT std_logic_VECTOR(31 downto 0);
--  full: OUT std_logic;
--  almost_full: OUT std_logic;
--  empty: OUT std_logic);
--end component;

-----------------------------------------------------------------------------
-- Internal Signals
-----------------------------------------------------------------------------
-- >P2L DMA Master State Machine
  type p2l_dma_state_type is (IDLE, WB_DATA_WAIT, P2L_HEADER, P2L_ADDR_H,
                                P2L_ADDR_L, P2L_DATA, P2L_DATA_WAIT, P2L_WAIT_WB_IDLE);
  signal p2l_dma_current_state : p2l_dma_state_type;
  signal p2l_dma_next_state    : p2l_dma_state_type;

  type   wishbone_state_type is (IDLE, WB_WAIT_P2L_START, WB_GET_CHAIN, WB_SEND_NEXT_ITEM_VALID);
  signal wishbone_current_state : wishbone_state_type;
  signal wishbone_next_state    : wishbone_state_type;

  signal s_carrier_addr : std_logic_vector(31 downto 0);
  signal s_host_addr_h  : std_logic_vector(31 downto 0);
  signal s_host_addr_l  : std_logic_vector(31 downto 0);
  signal s_start        : std_logic;
  signal s_chain        : std_logic;

  signal p2l_address_h : std_logic_vector(31 downto 0);
  signal p2l_address_l : std_logic_vector(31 downto 0);

  signal s_p2l_header : std_logic_vector(31 downto 0);
  signal s_p2l_data   : std_logic_vector(31 downto 0);

  signal p2l_data_cpt : unsigned(9 downto 0);

  signal wb_data_cpt : unsigned(9 downto 0);
  signal wb_ack_cpt  : unsigned(9 downto 0);

  signal s_chain_cpt : unsigned(2 downto 0);

--  signal s_fifo_din     : std_logic_vector(31 downto 0);
--  signal s_fifo_dout    : std_logic_vector(31 downto 0);
--  signal s_fifo_wr_en   : std_logic;
--  signal s_fifo_rd_en   : std_logic;
--  signal s_fifo_empty   : std_logic;
--  signal s_fifo_full    : std_logic;
--  signal s_fifo_almost_full : std_logic;

  signal s_64b_address : std_logic;

begin


--=========================================================================--
-- PCIe write block
--=========================================================================--
  process (gn4124_clk_i, sys_rst_n_i)
  begin
    if (sys_rst_n_i = c_RST_ACTIVE) then
      p2l_data_cpt  <= (others => '0');
      s_chain_cpt   <= "000";
      p2l_address_h <= (others => '0');
      p2l_address_l <= (others => '0');

      next_item_carrier_addr_o <= (others => '0');
      next_item_host_addr_h_o  <= (others => '0');
      next_item_host_addr_l_o  <= (others => '0');
      next_item_len_o          <= (others => '0');
      next_item_next_l_o       <= (others => '0');
      next_item_next_h_o       <= (others => '0');
      next_item_attrib_o       <= (others => '0');
    elsif rising_edge(gn4124_clk_i) then
      if (wishbone_current_state = WB_WAIT_P2L_START and
          p2l_dma_current_state = IDLE) then
        p2l_address_h <= s_host_addr_h;
        p2l_address_l <= s_host_addr_l;
        p2l_data_cpt  <= wb_data_cpt;
        s_chain_cpt   <= "111";
      end if;

      if (p2l_dma_current_state = P2L_DATA_WAIT and s_chain = '1'
          and pd_pdm_target_cpld_i = '1' and pd_pdm_hdr_start_i = '0') then
        if (s_chain_cpt = "111") then
          next_item_carrier_addr_o <= pd_pdm_data_i;
          s_chain_cpt              <= "110";
        end if;
        if (s_chain_cpt = "110") then
          next_item_host_addr_l_o <= pd_pdm_data_i;
          s_chain_cpt             <= "101";
        end if;
        if (s_chain_cpt = "101") then
          next_item_host_addr_h_o <= pd_pdm_data_i;
          s_chain_cpt             <= "100";
        end if;
        if (s_chain_cpt = "100") then
          next_item_len_o <= pd_pdm_data_i;
          s_chain_cpt     <= "011";
        end if;
        if (s_chain_cpt = "011") then
          next_item_next_l_o <= pd_pdm_data_i;
          s_chain_cpt        <= "010";
        end if;
        if (s_chain_cpt = "010") then
          next_item_next_h_o <= pd_pdm_data_i;
          s_chain_cpt        <= "001";
        end if;
        if (s_chain_cpt = "001") then
          next_item_attrib_o <= pd_pdm_data_i;
        end if;
      end if;

    end if;
  end process;

  s_64b_address <= '0' when p2l_address_h = x"00000000" else
                   '1';

  s_p2l_header <= "000"                                          -->  Traffic Class
                  & '0'                                          -->  Snoop
                  & "000"                                        -->  Memory read
                  & s_64b_address                                -->  Memory read
                  & "1111"                                       -->  LBE
                  & "1111"                                       -->  FBE
                  & "000"                                        -->  Reserved
                  & '0'                                          -->  VC
                  & "01"                                         -->  CID
                  & std_logic_vector(p2l_data_cpt(9 downto 0));  -->  Length

-----------------------------------------------------------------------------
-- PCIe read request State Machine
-----------------------------------------------------------------------------

  process (gn4124_clk_i, sys_rst_n_i)
  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then
      p2l_dma_current_state <= IDLE;
      DEBUG                 <= "1111";
    elsif rising_edge(gn4124_clk_i) then
      case p2l_dma_current_state is
        -----------------------------------------------------------------
        -- IDLE
        -----------------------------------------------------------------
        when IDLE =>
          if(wishbone_current_state = WB_WAIT_P2L_START) then
            p2l_dma_current_state <= P2L_HEADER;
          else
            p2l_dma_current_state <= IDLE;
          end if;
          DEBUG <= "1110";

          -----------------------------------------------------------------
          -- P2L HEADER
          -----------------------------------------------------------------
        when P2L_HEADER =>
          if(arb_pdm_gnt_i = '1') then
            if(s_64b_address = '1') then
              p2l_dma_current_state <= P2L_ADDR_H;
            else
              p2l_dma_current_state <= P2L_ADDR_L;
            end if;
          else
            p2l_dma_current_state <= P2L_HEADER;
          end if;
          DEBUG <= "1101";
          -----------------------------------------------------------------
          -- P2L ADDRESS (63-32)
          -----------------------------------------------------------------
        when P2L_ADDR_H =>
          p2l_dma_current_state <= P2L_ADDR_L;
          DEBUG              <= "1100";
          -----------------------------------------------------------------
          -- P2L ADDRESS (31-00)
          -----------------------------------------------------------------
        when P2L_ADDR_L =>
          p2l_dma_current_state <= P2L_DATA_WAIT;
          DEBUG              <= "1011";
          -----------------------------------------------------------------
          -- Wait for all the data
          -----------------------------------------------------------------
        when P2L_DATA_WAIT =>
          if(s_chain_cpt = "001") then
            p2l_dma_current_state <= P2L_WAIT_WB_IDLE;
          else
            p2l_dma_current_state <= P2L_DATA_WAIT;
          end if;
          DEBUG <= "1010";
          -----------------------------------------------------------------
          -- Wait for the end of the Wishbone cycles
          -----------------------------------------------------------------
        when P2L_WAIT_WB_IDLE =>
          if (wishbone_current_state = IDLE) then
            p2l_dma_current_state <= IDLE;
          else
            p2l_dma_current_state <= P2L_WAIT_WB_IDLE;
          end if;
          DEBUG <= "1001";
          -----------------------------------------------------------------
          -- OTHERS
          -----------------------------------------------------------------
        when others =>
          p2l_dma_current_state <= IDLE;
      end case;
      --p2l_dma_current_state <= p2l_dma_next_state;
    end if;
  end process;


-----------------------------------------------------------------------------
-- Bus toward arbiter
-----------------------------------------------------------------------------

  pdm_arb_req_o <= '1' when (p2l_dma_current_state = P2L_HEADER)
                   else '0';

  pdm_arb_data_o <= s_p2l_header when (p2l_dma_current_state = P2L_HEADER)
                    else p2l_address_h when (p2l_dma_current_state = P2L_ADDR_H)
                    else p2l_address_l when (p2l_dma_current_state = P2L_ADDR_L)
                    else x"00000000";

  pdm_arb_valid_o <= '1' when (p2l_dma_current_state = P2L_HEADER
                               or p2l_dma_current_state = P2L_ADDR_H
                               or p2l_dma_current_state = P2L_ADDR_L)
                     else '0';


  pdm_arb_dframe_o <= '1' when (p2l_dma_current_state = P2L_HEADER
                                or p2l_dma_current_state = P2L_ADDR_H)
                      else '0';

--  s_fifo_rd_en <= '1' when ((p2l_dma_current_state = p2l_addr_l
--                          or p2l_dma_current_state = wb_data_wait
--                          or p2l_dma_current_state = p2l_data) and not s_fifo_empty='1')
--                      else '0';


--=========================================================================--
-- Wishbone P2L DMA master block (pipelined)
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
          if(dma_ctrl_start_next_i = '1') then
            wishbone_current_state <= WB_WAIT_P2L_START;
          else
            wishbone_current_state <= IDLE;
          end if;

          -----------------------------------------------------------------
          -- Wait the P2L machine start
          -----------------------------------------------------------------
        when WB_WAIT_P2L_START =>
          if not (p2l_dma_current_state = IDLE) then
            if (s_chain = '1') then
              wishbone_current_state <= WB_GET_CHAIN;
            end if;
          else
            wishbone_current_state <= WB_WAIT_P2L_START;
          end if;

          -----------------------------------------------------------------
          -- Request on the Wishbone bus
          -----------------------------------------------------------------
        when WB_GET_CHAIN =>
          if(p2l_dma_current_state = P2L_WAIT_WB_IDLE) then
            wishbone_current_state <= WB_SEND_NEXT_ITEM_VALID;
          else
            wishbone_current_state <= WB_GET_CHAIN;
          end if;

          -----------------------------------------------------------------
          -- Request on the Wishbone bus
          -----------------------------------------------------------------
        when WB_SEND_NEXT_ITEM_VALID =>
          wishbone_current_state <= IDLE;

          -----------------------------------------------------------------
          -- OTHERS
          -----------------------------------------------------------------
        when others =>
          wishbone_current_state <= IDLE;
      end case;
      --wishbone_current_state <= wishbone_next_state;
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
      s_chain        <= '0';
    elsif rising_edge(sys_clk_i) then
      if (dma_ctrl_start_p2l_i = '1' or dma_ctrl_start_next_i = '1') then
        s_carrier_addr <= dma_ctrl_carrier_addr_i;
        s_host_addr_h  <= dma_ctrl_host_addr_h_i;
        s_host_addr_l  <= dma_ctrl_host_addr_l_i;
        wb_data_cpt    <= unsigned(dma_ctrl_len_i(11 downto 2));
        wb_ack_cpt     <= unsigned(dma_ctrl_len_i(11 downto 2));
      end if;
      if (dma_ctrl_start_next_i = '1') then
        s_chain <= '1';
      end if;

    end if;
  end process;

  p2l_dma_cyc_o <=                      --'1' when (wishbone_current_state = WB_REQUEST
                                        --  or wishbone_current_state = WB_LAST_ACK
                                        --  or wishbone_current_state = WB_FIFO_FULL) else
                                        '0';

  p2l_dma_stb_o <=                      --'1' when wishbone_current_state = WB_REQUEST else
                                        '0';

  p2l_dma_sel_o <=                      --"1111" when wishbone_current_state = WB_REQUEST else
                                        "0000";

  p2l_dma_adr_o <=                      --s_carrier_addr when wishbone_current_state = WB_REQUEST else
                                        (others => '0');

  p2l_dma_we_o <= '0';

  p2l_dma_dat_o <= (others => '0');


  next_item_valid_o <= '1' when wishbone_current_state = WB_SEND_NEXT_ITEM_VALID
                       else '0';

  dma_ctrl_done_o <= '0';

  dma_ctrl_error_o <= '0';
--=========================================================================--
-- FIFO block
--=========================================================================--
--  s_fifo_din   <= p2l_dma_dat_i;
--  s_fifo_wr_en <= p2l_dma_ack_i when wb_ack_cpt > 0
--             else '0';
--  s_p2l_data   <= s_fifo_dout;
--
--  u_fifo : fifo port map
--  (
--    rst    => sys_rst_i,
--    wr_clk => sys_clk_i,
--    rd_clk => gn4124_clk_i,
--    din    => s_fifo_din,
--    wr_en  => s_fifo_wr_en,
--    rd_en  => s_fifo_rd_en,
--    dout   => s_fifo_dout,
--    full   => s_fifo_full,
--    almost_full   => s_fifo_almost_full,
--    empty  => s_fifo_empty
--  );

end behaviour;

