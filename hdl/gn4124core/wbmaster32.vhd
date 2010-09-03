--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: 32 bit Wishbone master (wbmaster32.vhd)
--
-- author: Simon Deprez (simon.deprez@cern.ch)
--
-- date: 12-08-2010
--
-- version: 0.2
--
-- description: Provide a Wishbone interface for read and write control and
-- status registers
--
-- dependencies: DPRAM_SMALL (DPRAM_SMALL.vhd)
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


entity wbmaster32 is
  generic
    (
      WBM_TIMEOUT : integer := 5        -- Determines the timeout value of read and write cycle
      );
  port
    (
      DEBUG : out std_logic_vector(3 downto 0);

      ---------------------------------------------------------
      -- Clock/Reset
      sys_clk_i    : in std_logic;
      sys_rst_n_i  : in std_logic;
      gn4124_clk_i : in std_logic;

      ---------------------------------------------------------
      -- From P2L Decoder
      --
      -- Header
      pd_wbm_hdr_start_i  : in std_logic;                      -- Indicates Header start cycle
      pd_wbm_hdr_length_i : in std_logic_vector(9 downto 0);   -- Latched LENGTH value from header
      pd_wbm_hdr_cid_i    : in std_logic_vector(1 downto 0);   -- Completion ID
      pd_wbm_target_mrd_i : in std_logic;                      -- Target memory read
      pd_wbm_target_mwr_i : in std_logic;                      -- Target memory write
      --
      -- Address
      pd_wbm_addr_start_i : in std_logic;                      -- Indicates Address Start
      pd_wbm_addr_i       : in std_logic_vector(31 downto 0);  -- Latched Address that will increment with data
      pd_wbm_wbm_addr_i   : in std_logic;                      -- Indicates that current address is for the EPI interface
                                                               -- Can be connected to a decode of IP2L_ADDRi
                                                               -- or to IP2L_ADDRi(0) for BAR2
                                                               -- or to not IP2L_ADDRi(0) for BAR0
      --
      -- Data
      pd_wbm_data_valid_i : in std_logic;                      -- Indicates Data is valid
      pd_wbm_data_last_i  : in std_logic;                      -- Indicates end of the packet
      pd_wbm_data_i       : in std_logic_vector(31 downto 0);  -- Data
      pd_wbm_be_i         : in std_logic_vector(3 downto 0);   -- Byte Enable for data

      ---------------------------------------------------------
      -- P2L Control
      p_wr_rdy_o : out std_logic;       -- Write buffer not empty

      ---------------------------------------------------------
      -- To the L2P Interface
      wbm_arb_valid_o  : out std_logic;  -- Read completion signals
      wbm_arb_dframe_o : out std_logic;  -- Toward the arbiter
      wbm_arb_data_o   : out std_logic_vector(31 downto 0);
      wbm_arb_req_o    : out std_logic;
      arb_wbm_gnt_i    : in  std_logic;

      ---------------------------------------------------------
      -- Wishbone Interface
      wb_adr_o   : out std_logic_vector(32-1 downto 0);  -- Adress
      wb_dat_i   : in  std_logic_vector(31 downto 0);    -- Data in
      wb_dat_o   : out std_logic_vector(31 downto 0);    -- Data out
      wb_sel_o   : out std_logic_vector(3 downto 0);     -- Byte select
      wb_cyc_o   : out std_logic;                        -- Read or write cycle
      wb_stb_o   : out std_logic;                        -- Read or write strobe
      wb_we_o    : out std_logic;                        -- Write
      wb_ack_i   : in  std_logic;                        -- Acknowledge
      wb_stall_i : in  std_logic                         -- Pipelined mode
      );
end wbmaster32;

architecture behaviour of wbmaster32 is

  component fifo_write
    port (
      rst    : in  std_logic;
      wr_clk : in  std_logic;
      rd_clk : in  std_logic;
      din    : in  std_logic_vector(63 downto 0);
      wr_en  : in  std_logic;
      rd_en  : in  std_logic;
      dout   : out std_logic_vector(63 downto 0);
      full   : out std_logic;
      empty  : out std_logic);
  end component;

-----------------------------------------------------------------------------
-- Internal Signals
-----------------------------------------------------------------------------

  signal fifo_rst : std_logic;

  -- P2L Bus Tracker State Machine
  type wishbone_state_type is (WB_IDLE, WB_READ_REQUEST, WB_READ_WAIT_ACK, WB_READ_SEND_PCIE,
                               WB_WRITE_FIFO, WB_WRITE_REQUEST, WB_WRITE_WAIT_ACK);
  signal wishbone_current_state : wishbone_state_type;

  type   l2p_read_cpl_state_type is (IDLE, L2P_SEM, L2P_HEADER, L2P_DATA);
  signal l2p_read_cpl_current_state : l2p_read_cpl_state_type;

  signal s_read_request  : std_logic;   -- signal a waiting read request to the Wishbone master state machine
  signal s_write_request : std_logic;   -- signal a waiting write request to the Wishbone master state machine

  signal s_p2l_addr_reg   : std_logic_vector(31 downto 0);
  signal s_p2l_cid_reg    : std_logic_vector(1 downto 0);
  signal s_p2l_len_reg    : std_logic_vector(9 downto 0);
  signal s_p2l_header_d1  : std_logic;
  signal s_p2l_rd_req_reg : std_logic;

  signal s_read_request_reg : std_logic;
  signal s_read_addr_reg    : unsigned(31 downto 0);
  signal s_read_cid_reg     : std_logic_vector(1 downto 0);
  signal s_read_len_reg     : unsigned(9 downto 0);
  signal s_read_data_reg    : std_logic_vector(31 downto 0);

  signal s_l2p_header_reg : std_logic_vector(31 downto 0);
  signal s_l2p_last       : std_logic;

  signal s_fifo_push  : std_logic;
  signal s_fifo_pop   : std_logic;
  signal s_fifo_empty : std_logic;
  signal s_fifo_full  : std_logic;
  signal s_fifo_in    : std_logic_vector(63 downto 0);
  signal s_fifo_out   : std_logic_vector(63 downto 0);

  signal s_write_data_reg : std_logic_vector(31 downto 0);
  signal s_write_addr_reg : std_logic_vector(31 downto 0);

  signal s_wb_timeout_cnt : unsigned(3 downto 0);
  signal s_wb_timeout     : std_logic;

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
-- Read completion block
--=========================================================================--

  s_read_request <= s_read_request_reg and not s_write_request;

  s_write_request <= not s_fifo_empty;

  s_l2p_last <= '1' when (s_read_len_reg(9 downto 0) = "0000000000")
                else '0';

  process (sys_clk_i, sys_rst_n_i)
  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then
      s_read_addr_reg    <= (others => '0');
      s_read_cid_reg     <= (others => '0');
      s_read_len_reg     <= (others => '0');
      s_read_data_reg    <= (others => '0');
      s_read_request_reg <= '0';
      DEBUG(1 downto 0)  <= "00";
    else
      if rising_edge(sys_clk_i) then

        if (wishbone_current_state = WB_READ_REQUEST or wishbone_current_state = WB_READ_WAIT_ACK) then
          if (wb_ack_i = '1') then
            s_read_data_reg              <= wb_dat_i;
            DEBUG(0)                     <= '1';
            s_read_addr_reg(31 downto 2) <= s_read_addr_reg(31 downto 2) + 1;
            s_read_len_reg               <= s_read_len_reg - 1;
          elsif (s_wb_timeout = '1') then
            s_read_data_reg              <= x"12345678";
            s_read_addr_reg(31 downto 2) <= s_read_addr_reg(31 downto 2) + 1;
            s_read_len_reg               <= s_read_len_reg - 1;
          end if;

        end if;

        if (s_l2p_last = '1') then
          s_read_request_reg <= '0';
        end if;

        if (s_p2l_rd_req_reg = '1' and not (s_p2l_len_reg = "0000000000")) then
          s_read_addr_reg    <= unsigned(s_p2l_addr_reg);
          s_read_cid_reg     <= s_p2l_cid_reg;
          s_read_len_reg     <= unsigned(s_p2l_len_reg);
          s_read_request_reg <= '1';
          DEBUG(1)           <= '1';
        end if;

      end if;
    end if;
  end process;

  process (gn4124_clk_i, sys_rst_n_i)
  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then
      s_p2l_addr_reg   <= (others => '0');
      s_p2l_cid_reg    <= (others => '0');
      s_p2l_len_reg    <= (others => '0');
      s_p2l_header_d1  <= '0';
      s_p2l_rd_req_reg <= '0';
    else
      if rising_edge(gn4124_clk_i) then
        s_p2l_header_d1 <= pd_wbm_hdr_start_i;

        if (s_p2l_header_d1 = '1' and pd_wbm_addr_start_i = '1' and
            pd_wbm_target_mrd_i = '1' and pd_wbm_wbm_addr_i = '1' and
            s_p2l_rd_req_reg = '0') then
          s_p2l_addr_reg   <= pd_wbm_addr_i;
          s_p2l_cid_reg    <= pd_wbm_hdr_cid_i;
          s_p2l_len_reg    <= pd_wbm_hdr_length_i;
          s_p2l_rd_req_reg <= '1';
        elsif (s_read_request = '1') then
          s_p2l_rd_req_reg <= '0';
        end if;
      end if;
    end if;
  end process;

  --read completion header
  s_l2p_header_reg <= "000"             -->  Traffic Class
                      & '0'             -->  Reserved
                      & "0101"          -->  Read completion
                      & "000000"        -->  Reserved
                      & "00"            -->  Completion Status
                      & s_l2p_last      -->  Last completion packet
                      & "00"            -->  Reserved
                      & '0'             -->  VC
                      & s_read_cid_reg  -->  CID
                      & "0000000001";   -->  Length

-----------------------------------------------------------------------------
-- PCIe write State Machine (Read completion)
-----------------------------------------------------------------------------

  process (gn4124_clk_i, sys_rst_n_i)
    variable l2p_read_cpl_next_state : l2p_read_cpl_state_type;
  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then
      l2p_read_cpl_current_state <= IDLE;
      wbm_arb_req_o <= '0';
      wbm_arb_data_o <= (others => '0');
      wbm_arb_valid_o <= '0';
      wbm_arb_dframe_o <= '0';
    elsif rising_edge(gn4124_clk_i) then
      case l2p_read_cpl_current_state is
        -----------------------------------------------------------------
        -- IDLE
        -----------------------------------------------------------------
        when IDLE =>
          if(wishbone_current_state = WB_READ_SEND_PCIE) then
            l2p_read_cpl_next_state := L2P_SEM;
          else
            l2p_read_cpl_next_state := IDLE;
          end if;
          wbm_arb_req_o <= '0';
          wbm_arb_data_o <= (others => '0');
          wbm_arb_valid_o <= '0';
          wbm_arb_dframe_o <= '0';

          -----------------------------------------------------------------
          -- L2P_SEM
          -----------------------------------------------------------------
        when L2P_SEM =>
          if not (wishbone_current_state = WB_READ_SEND_PCIE) then
            l2p_read_cpl_next_state := L2P_HEADER;
          else
            l2p_read_cpl_next_state := L2P_SEM;
          end if;
          wbm_arb_req_o <= '0';
          wbm_arb_data_o <= (others => '0');
          wbm_arb_valid_o <= '0';
          wbm_arb_dframe_o <= '0';

          -----------------------------------------------------------------
          -- L2P HEADER
          -----------------------------------------------------------------
        when L2P_HEADER =>
          if(arb_wbm_gnt_i = '1') then
            l2p_read_cpl_next_state := L2P_DATA;
          else
            l2p_read_cpl_next_state := L2P_HEADER;
          end if;
          wbm_arb_req_o <= '1';
          wbm_arb_data_o <= s_l2p_header_reg;
          wbm_arb_valid_o <= '1';
          wbm_arb_dframe_o <= '1';

          -----------------------------------------------------------------
          -- L2P DATA
          -----------------------------------------------------------------
        when L2P_DATA =>
          l2p_read_cpl_next_state := IDLE;
          wbm_arb_req_o <= '0';
          wbm_arb_data_o <= s_read_data_reg;
          wbm_arb_valid_o <= '1';
          wbm_arb_dframe_o <= '0';

          -----------------------------------------------------------------
          -- OTHERS
          -----------------------------------------------------------------
        when others =>
          l2p_read_cpl_next_state := IDLE;
          wbm_arb_req_o <= '0';
          wbm_arb_data_o <= (others => '0');
          wbm_arb_valid_o <= '0';
          wbm_arb_dframe_o <= '0';

      end case;
      l2p_read_cpl_current_state <= l2p_read_cpl_next_state;
    end if;
  end process;


-----------------------------------------------------------------------------
-- Bus toward arbiter
-----------------------------------------------------------------------------

  --wbm_arb_req_o <= '1' when (l2p_read_cpl_current_state = L2P_HEADER)
  --                 else '0';

  --wbm_arb_data_o <= s_l2p_header_reg when l2p_read_cpl_current_state = L2P_HEADER
  --                  else s_read_data_reg when l2p_read_cpl_current_state = L2P_DATA
  --                  else (others => '0');

  --wbm_arb_valid_o <= '1' when (l2p_read_cpl_current_state = L2P_HEADER
  --                             or l2p_read_cpl_current_state = L2P_DATA)
  --                   else '0';

  --wbm_arb_dframe_o <= '1' when l2p_read_cpl_current_state = L2P_HEADER
  --                    else '0';


--=========================================================================--
-- Wishbone master block (pipelined)
--=========================================================================--

----------------------------------------------------------------------------
-- Timeout counter
-----------------------------------------------------------------------------
  process (sys_clk_i, sys_rst_n_i)
    variable wishbone_next_state : wishbone_state_type;

  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then
      s_wb_timeout_cnt <= (others => '0');
      s_wb_timeout     <= '0';
    elsif rising_edge(sys_clk_i) then
      if wishbone_current_state = WB_IDLE then
        s_wb_timeout_cnt <= (others => '0');
        s_wb_timeout     <= '0';
      elsif (s_wb_timeout_cnt = WBM_TIMEOUT) then
        s_wb_timeout <= '1';
      elsif (wishbone_current_state = WB_READ_REQUEST or wishbone_current_state = WB_WRITE_REQUEST or
             wishbone_current_state = WB_READ_WAIT_ACK or wishbone_current_state = WB_WRITE_WAIT_ACK) then
        s_wb_timeout_cnt <= s_wb_timeout_cnt + 1;
      end if;
    end if;
  end process;
----------------------------------------------------------------------------
-- Wishbone master state machine
-----------------------------------------------------------------------------
  process (sys_clk_i, sys_rst_n_i)
    variable wishbone_next_state : wishbone_state_type;

  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then
      wishbone_current_state <= WB_IDLE;
      wb_cyc_o <= '0';
      wb_stb_o <= '0';
      wb_we_o <= '0';
      wb_sel_o <= "0000";
      wb_dat_o <= (others => '0');
      wb_adr_o <= (others => '0');
    elsif rising_edge(sys_clk_i) then
      case wishbone_current_state is
        -----------------------------------------------------------------
        -- Wait for a Wishbone cycle
        -----------------------------------------------------------------
        when WB_IDLE =>
          if(s_read_request = '1' and l2p_read_cpl_current_state = IDLE) then
            wishbone_next_state := WB_READ_REQUEST;
          elsif(s_write_request = '1') then
            wishbone_next_state := WB_WRITE_FIFO;
          else
            wishbone_next_state := WB_IDLE;
          end if;
          wb_cyc_o <= '0';
          wb_stb_o <= '0';
          wb_we_o <= '0';
          wb_sel_o <= "0000";
          wb_dat_o <= (others => '0');
          wb_adr_o <= (others => '0');

          -----------------------------------------------------------------
          -- Write wait fifo
          -----------------------------------------------------------------
        when WB_WRITE_FIFO =>
          wishbone_next_state := WB_WRITE_REQUEST;
          wb_cyc_o <= '0';
          wb_stb_o <= '0';
          wb_we_o <= '0';
          wb_sel_o <= "0000";
          wb_dat_o <= (others => '0');
          wb_adr_o <= (others => '0');

          -----------------------------------------------------------------
          -- Write request on the Wishbone bus
          -----------------------------------------------------------------
        when WB_WRITE_REQUEST =>
          if (wb_stall_i = '1' and s_wb_timeout = '0') then
            wishbone_next_state := WB_WRITE_REQUEST;
          elsif(wb_ack_i = '1' or s_wb_timeout = '1') then
            wishbone_next_state := WB_IDLE;
          else
            wishbone_next_state := WB_WRITE_WAIT_ACK;
          end if;
          wb_cyc_o <= '1';
          wb_stb_o <= '1';
          wb_we_o <= '1';
          wb_sel_o <= "1111";
          wb_dat_o <= s_write_data_reg;
          wb_adr_o <= s_write_addr_reg;

          -----------------------------------------------------------------
          -- Wait for acknowledge (write request)
          -----------------------------------------------------------------
        when WB_WRITE_WAIT_ACK =>
          if(wb_ack_i = '1' or s_wb_timeout = '1') then
            wishbone_next_state := WB_IDLE;
          else
            wishbone_next_state := WB_WRITE_WAIT_ACK;
          end if;

          -----------------------------------------------------------------
          -- Read request on the Wishbone bus
          -----------------------------------------------------------------
        when WB_READ_REQUEST =>
          if (wb_stall_i = '1' and s_wb_timeout = '0') then
            wishbone_next_state := WB_READ_REQUEST;
          elsif(wb_ack_i = '1' or s_wb_timeout = '1') then
            wishbone_next_state := WB_READ_SEND_PCIE;
          else
            wishbone_next_state := WB_READ_WAIT_ACK;
          end if;
          wb_cyc_o <= '1';
          wb_stb_o <= '1';
          wb_we_o <= '0';
          wb_sel_o <= "1111";
          wb_dat_o <= (others => '0');
          wb_adr_o <= std_logic_vector(s_read_addr_reg);

          -----------------------------------------------------------------
          -- Wait for acknowledge (read request)
          -----------------------------------------------------------------
        when WB_READ_WAIT_ACK =>
          if(wb_ack_i = '1' or s_wb_timeout = '1') then
            wishbone_next_state := WB_READ_SEND_PCIE;
          else
            wishbone_next_state := WB_READ_WAIT_ACK;
          end if;

          -----------------------------------------------------------------
          -- Wait for the read completion machine start
          -----------------------------------------------------------------
        when WB_READ_SEND_PCIE =>
          if (l2p_read_cpl_current_state = L2P_SEM) then
            wishbone_next_state := WB_IDLE;
          else
            wishbone_next_state := WB_READ_SEND_PCIE;
          end if;
          wb_cyc_o <= '0';
          wb_stb_o <= '0';
          wb_we_o <= '0';
          wb_sel_o <= "0000";
          wb_dat_o <= (others => '0');
          wb_adr_o <= (others => '0');

          -----------------------------------------------------------------
          -- OTHERS
          -----------------------------------------------------------------
        when others =>
          wishbone_next_state := WB_IDLE;
          wb_cyc_o <= '0';
          wb_stb_o <= '0';
          wb_we_o <= '0';
          wb_sel_o <= "0000";
          wb_dat_o <= (others => '0');
          wb_adr_o <= (others => '0');

      end case;
      wishbone_current_state <= wishbone_next_state;
    end if;
  end process;

  --wb_cyc_o <= '1' when (wishbone_current_state = WB_WRITE_REQUEST
  --                      or wishbone_current_state = WB_READ_REQUEST
  --                      or wishbone_current_state = WB_WRITE_WAIT_ACK
  --                      or wishbone_current_state = WB_READ_WAIT_ACK)
  --            else '0';

  --wb_stb_o <= '1' when (wishbone_current_state = WB_WRITE_REQUEST
  --                      or wishbone_current_state = WB_READ_REQUEST)
  --            else '0';

  --wb_we_o <= '1' when wishbone_current_state = WB_WRITE_REQUEST
  --           else '0';

  --wb_sel_o <= "1111" when (wishbone_current_state = WB_WRITE_REQUEST
  --                         or wishbone_current_state = WB_READ_REQUEST)
  --            else "0000";

  --wb_dat_o <= s_write_data_reg when (wishbone_current_state = WB_WRITE_REQUEST)
  --            else (others => '0');

  --wb_adr_o <= std_logic_vector(s_read_addr_reg) when (wishbone_current_state = WB_READ_REQUEST)
  --            else s_write_addr_reg when (wishbone_current_state = WB_WRITE_REQUEST)
  --            else (others => '0');


--=========================================================================--
-- FIFO blocks for writes requests
--=========================================================================--

  s_fifo_push <= pd_wbm_data_valid_i and pd_wbm_target_mwr_i and pd_wbm_wbm_addr_i and not s_fifo_full;

  s_fifo_pop <= '1' when (wishbone_current_state = WB_IDLE
                          and s_write_request = '1'
                          and s_read_request = '0')
                else '0';

  u_fifo_write : fifo_write port map
    (
      rst    => fifo_rst,
      wr_clk => gn4124_clk_i,
      rd_clk => sys_clk_i,
      din    => s_fifo_in,
      wr_en  => s_fifo_push,
      rd_en  => s_fifo_pop,
      dout   => s_fifo_out,
      full   => s_fifo_full,
      empty  => s_fifo_empty
      );

  s_fifo_in(63 downto 32) <= pd_wbm_addr_i;
  s_fifo_in(31 downto 0)  <= pd_wbm_data_i;

  process (sys_clk_i, sys_rst_n_i)
  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then
      s_write_data_reg <= (others => '0');
      s_write_addr_reg <= (others => '0');
    elsif rising_edge(sys_clk_i) then
      if (wishbone_current_state = WB_WRITE_FIFO) then
        s_write_data_reg <= s_fifo_out(31 downto 0);
        s_write_addr_reg <= s_fifo_out(63 downto 32);
      end if;
    end if;
  end process;

  p_wr_rdy_o <= s_fifo_empty;

end behaviour;

