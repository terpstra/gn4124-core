--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: 32-bit Wishbone master (wbmaster32.vhd)
--
-- authors: Simon Deprez (simon.deprez@cern.ch)
--          Matthieu Cattin (matthieu.cattin@cern.ch)
--
-- date: 12-08-2010
--
-- version: 0.2
--
-- description: Provide a Wishbone interface for single read and write
--              control and status registers
--
-- dependencies: Xilinx FIFOs (fifo_32x512.xco, fifo_64x512.xco)
--
--------------------------------------------------------------------------------
-- last changes: 27-09-2010 (mcattin) Split wishbone and gn4124 clock domains
--               All signals crossing the clock domains are now going through fifos.
--               Dead times optimisation in packet generator.
--------------------------------------------------------------------------------
-- TODO: - byte enable support.
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
      -- GN4124 core clock and reset
      sys_clk_i   : in std_logic;
      sys_rst_n_i : in std_logic;

      ---------------------------------------------------------
      -- From P2L packet decoder
      --
      -- Header
      pd_wbm_hdr_start_i  : in std_logic;                      -- Header strobe
      pd_wbm_hdr_length_i : in std_logic_vector(9 downto 0);   -- Packet length in 32-bit words multiples
      pd_wbm_hdr_cid_i    : in std_logic_vector(1 downto 0);   -- Completion ID
      pd_wbm_target_mrd_i : in std_logic;                      -- Target memory read
      pd_wbm_target_mwr_i : in std_logic;                      -- Target memory write
      --
      -- Address
      pd_wbm_addr_start_i : in std_logic;                      -- Address strobe
      pd_wbm_addr_i       : in std_logic_vector(31 downto 0);  -- Target address (in byte) that will increment with data
                                                               -- increment = 4 bytes
      --
      -- Data
      pd_wbm_data_valid_i : in std_logic;                      -- Indicates Data is valid
      pd_wbm_data_last_i  : in std_logic;                      -- Indicates end of the packet
      pd_wbm_data_i       : in std_logic_vector(31 downto 0);  -- Data
      pd_wbm_be_i         : in std_logic_vector(3 downto 0);   -- Byte Enable for data

      ---------------------------------------------------------
      -- P2L channel control
      p_wr_rdy_o   : out std_logic_vector(1 downto 0);  -- Ready to accept target write
      p2l_rdy_o    : out std_logic;                     -- De-asserted to pause transfer already in progress
      p_rd_d_rdy_i : in  std_logic_vector(1 downto 0);  -- Asserted when GN4124 ready to accept read completion with data

      ---------------------------------------------------------
      -- To the arbiter (L2P data)
      wbm_arb_valid_o  : out std_logic;  -- Read completion signals
      wbm_arb_dframe_o : out std_logic;  -- Toward the arbiter
      wbm_arb_data_o   : out std_logic_vector(31 downto 0);
      wbm_arb_req_o    : out std_logic;
      arb_wbm_gnt_i    : in  std_logic;

      ---------------------------------------------------------
      -- CSR wishbone interface
      wb_clk_i   : in  std_logic;                        -- Wishbone bus clock
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


-----------------------------------------------------------------------------
-- Local constants
-----------------------------------------------------------------------------
  constant c_TO_WB_FIFO_FULL_THRES   : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(500, 9));
  constant c_FROM_WB_FIFO_FULL_THRES : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(500, 9));

-----------------------------------------------------------------------------
-- Internal Signals
-----------------------------------------------------------------------------

  -- Sync fifos
  signal fifo_rst : std_logic;

  signal to_wb_fifo_empty : std_logic;
  signal to_wb_fifo_full  : std_logic;
  signal to_wb_fifo_rd    : std_logic;
  signal to_wb_fifo_wr    : std_logic;
  signal to_wb_fifo_din   : std_logic_vector(63 downto 0);
  signal to_wb_fifo_dout  : std_logic_vector(63 downto 0);
  signal to_wb_fifo_rw    : std_logic;
  signal to_wb_fifo_data  : std_logic_vector(31 downto 0);
  signal to_wb_fifo_addr  : std_logic_vector(29 downto 0);

  signal from_wb_fifo_empty : std_logic;
  signal from_wb_fifo_full  : std_logic;
  signal from_wb_fifo_rd    : std_logic;
  signal from_wb_fifo_wr    : std_logic;
  signal from_wb_fifo_din   : std_logic_vector(31 downto 0);
  signal from_wb_fifo_dout  : std_logic_vector(31 downto 0);

  -- Wishbone FSM
  type   wishbone_state_type is (WB_IDLE, WB_READ_FIFO, WB_CYCLE, WB_WAIT_ACK);
  signal wishbone_current_state : wishbone_state_type;

  signal s_wb_we : std_logic;

  -- L2P packet generator
  type   l2p_read_cpl_state_type is (L2P_IDLE, L2P_HEADER, L2P_DATA);
  signal l2p_read_cpl_current_state : l2p_read_cpl_state_type;

  signal p2l_cid      : std_logic_vector(1 downto 0);
  signal s_l2p_header : std_logic_vector(31 downto 0);


begin


  ------------------------------------------------------------------------------
  -- Active high reset for fifo
  ------------------------------------------------------------------------------
  -- Creates an active high reset for fifos regardless of c_RST_ACTIVE value
  gen_fifo_rst_n : if c_RST_ACTIVE = '0' generate
    fifo_rst <= not(sys_rst_n_i);
  end generate;

  gen_fifo_rst : if c_RST_ACTIVE = '1' generate
    fifo_rst <= sys_rst_n_i;
  end generate;

  ------------------------------------------------------------------------------
  -- Write frame from P2L decoder to fifo
  ------------------------------------------------------------------------------

  -- ready to receive new target write if fifo not full
  p_wr_rdy_o <= "00" when to_wb_fifo_full = '1' else "11";

  -- pause transfer from GN4124 when fifo is full
  p2l_rdy_o <= not(to_wb_fifo_full);

  p_from_decoder : process (sys_clk_i, sys_rst_n_i)
  begin
    if (sys_rst_n_i = c_RST_ACTIVE) then
      to_wb_fifo_din <= (others => '0');
      to_wb_fifo_wr  <= '0';
    elsif rising_edge(sys_clk_i) then
      if (pd_wbm_target_mwr_i = '1' and pd_wbm_data_valid_i = '1') then
        -- Target write
        -- wishbone address is in 32-bit words and address from PCIe in byte
        to_wb_fifo_din(61 downto 32) <= pd_wbm_addr_i(31 downto 2);
        to_wb_fifo_din(31 downto 0)  <= pd_wbm_data_i;
        to_wb_fifo_din(62)           <= '1';
        to_wb_fifo_wr                <= '1';
      elsif (pd_wbm_target_mrd_i = '1' and pd_wbm_addr_start_i = '1') then
        -- Target read request
        -- wishbone address is in 32-bit words and address from PCIe in byte
        to_wb_fifo_din(61 downto 32) <= pd_wbm_addr_i(31 downto 2);
        to_wb_fifo_din(62)           <= '0';
        to_wb_fifo_wr                <= '1';
      else
        to_wb_fifo_wr <= '0';
      end if;
    end if;
  end process p_from_decoder;

  ------------------------------------------------------------------------------
  -- Packet generator
  ------------------------------------------------------------------------------
  -- Generates read completion with requested data
  -- Single 32-bit word read only

  -- Store CID for read completion packet
  p_pkt_gen : process (sys_clk_i, sys_rst_n_i)
  begin
    if (sys_rst_n_i = c_RST_ACTIVE) then
      p2l_cid <= (others => '0');
    elsif rising_edge(sys_clk_i) then
      if (pd_wbm_hdr_start_i = '1') then
        p2l_cid <= pd_wbm_hdr_cid_i;
      end if;
    end if;
  end process p_pkt_gen;

  --read completion header
  s_l2p_header <= "000"                 -->  Traffic Class
                  & '0'                 -->  Reserved
                  & "0101"              -->  Read completion (Master read competition with data)
                  & "000000"            -->  Reserved
                  & "00"                -->  Completion Status
                  & '1'                 -->  Last completion packet
                  & "00"                -->  Reserved
                  & '0'                 -->  VC (Vitrual Channel)
                  & p2l_cid             -->  CID (Completion Identifer)
                  & "0000000001";       -->  Length (Single 32-bit word read only)

  ------------------------------------------------------------------------------
  -- L2P packet write FSM
  ------------------------------------------------------------------------------
  process (sys_clk_i, sys_rst_n_i)
  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then
      l2p_read_cpl_current_state <= L2P_IDLE;
      wbm_arb_req_o              <= '0';
      wbm_arb_data_o             <= (others => '0');
      wbm_arb_valid_o            <= '0';
      wbm_arb_dframe_o           <= '0';
      from_wb_fifo_rd            <= '0';
    elsif rising_edge(sys_clk_i) then
      case l2p_read_cpl_current_state is

        when L2P_IDLE =>
          wbm_arb_req_o    <= '0';
          wbm_arb_data_o   <= (others => '0');
          wbm_arb_valid_o  <= '0';
          wbm_arb_dframe_o <= '0';
          if(from_wb_fifo_empty = '0' and p_rd_d_rdy_i = "11") then
            -- generate a packet when read data in fifo and GN4124 ready to receive the packet
            wbm_arb_req_o              <= '1';
            from_wb_fifo_rd            <= '1';
            l2p_read_cpl_current_state <= L2P_HEADER;
          end if;

        when L2P_HEADER =>
          from_wb_fifo_rd <= '0';
          if(arb_wbm_gnt_i = '1') then
            wbm_arb_req_o              <= '0';
            wbm_arb_data_o             <= s_l2p_header;
            wbm_arb_valid_o            <= '1';
            wbm_arb_dframe_o           <= '1';
            l2p_read_cpl_current_state <= L2P_DATA;
          end if;

        when L2P_DATA =>
          l2p_read_cpl_current_state <= L2P_IDLE;
          wbm_arb_data_o             <= from_wb_fifo_dout;
          wbm_arb_dframe_o           <= '0';

        when others =>
          l2p_read_cpl_current_state <= L2P_IDLE;
          wbm_arb_req_o              <= '0';
          wbm_arb_data_o             <= (others => '0');
          wbm_arb_valid_o            <= '0';
          wbm_arb_dframe_o           <= '0';
          from_wb_fifo_rd            <= '0';

      end case;
    end if;
  end process;

----------------------------------------------------------------------------
-- FIFOs for transition between GN4124 core and wishbone clock domain
-----------------------------------------------------------------------------

  -- fifo for PCIe to WB transfer
  cmp_fifo_to_wb : fifo_64x512
    port map (
      rst                     => fifo_rst,
      wr_clk                  => sys_clk_i,
      rd_clk                  => wb_clk_i,
      din                     => to_wb_fifo_din,
      wr_en                   => to_wb_fifo_wr,
      rd_en                   => to_wb_fifo_rd,
      prog_full_thresh_assert => c_TO_WB_FIFO_FULL_THRES,
      prog_full_thresh_negate => c_TO_WB_FIFO_FULL_THRES,
      dout                    => to_wb_fifo_dout,
      full                    => open,
      empty                   => to_wb_fifo_empty,
      valid                   => open,
      prog_full               => to_wb_fifo_full);

  to_wb_fifo_rw   <= to_wb_fifo_dout(62);
  to_wb_fifo_addr <= to_wb_fifo_dout(61 downto 32);  -- 30-bit
  to_wb_fifo_data <= to_wb_fifo_dout(31 downto 0);   -- 32-bit

  -- fifo for WB to PCIe transfer
  cmp_from_wb_fifo : fifo_32x512
    port map (
      rst                     => fifo_rst,
      wr_clk                  => wb_clk_i,
      rd_clk                  => sys_clk_i,
      din                     => from_wb_fifo_din,
      wr_en                   => from_wb_fifo_wr,
      rd_en                   => from_wb_fifo_rd,
      prog_full_thresh_assert => c_FROM_WB_FIFO_FULL_THRES,
      prog_full_thresh_negate => c_FROM_WB_FIFO_FULL_THRES,
      dout                    => from_wb_fifo_dout,
      full                    => open,
      empty                   => from_wb_fifo_empty,
      valid                   => open,
      prog_full               => from_wb_fifo_full);

  ----------------------------------------------------------------------------
  -- Wishbone master state machine
  -----------------------------------------------------------------------------
  p_wb_fsm : process (wb_clk_i, sys_rst_n_i)
  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then
      wishbone_current_state <= WB_IDLE;
      to_wb_fifo_rd          <= '0';
      wb_cyc_o               <= '0';
      wb_stb_o               <= '0';
      s_wb_we                <= '0';
      wb_sel_o               <= "0000";
      wb_dat_o               <= (others => '0');
      wb_adr_o               <= (others => '0');
      from_wb_fifo_din       <= (others => '0');
      from_wb_fifo_wr        <= '0';
    elsif rising_edge(wb_clk_i) then
      case wishbone_current_state is

        when WB_IDLE =>
          -- stop writing to fifo
          from_wb_fifo_wr <= '0';
          -- clear bus
          wb_cyc_o        <= '0';
          wb_stb_o        <= '0';
          wb_sel_o        <= "0000";
          -- Wait for a Wishbone cycle
          if (to_wb_fifo_empty = '0') then
            -- read requset in fifo (address, data and transfer type)
            to_wb_fifo_rd          <= '1';
            wishbone_current_state <= WB_READ_FIFO;
          end if;

        when WB_READ_FIFO =>
          -- read only one request in fifo (no block transfer)
          to_wb_fifo_rd          <= '0';
          wishbone_current_state <= WB_CYCLE;

        when WB_CYCLE =>
          -- initate a bus cycle
          wb_cyc_o               <= '1';
          wb_stb_o               <= '1';
          s_wb_we                <= to_wb_fifo_rw;
          wb_sel_o               <= "1111";
          wb_adr_o               <= "00" & to_wb_fifo_addr;
          --if (to_wb_fifo_rw = '1') then
          wb_dat_o               <= to_wb_fifo_data;
          --end if;
          -- wait for slave to ack
          wishbone_current_state <= WB_WAIT_ACK;

        when WB_WAIT_ACK =>
          if (wb_ack_i = '1') then
            -- for read cycles write read data to fifo
            if (s_wb_we = '0') then
              from_wb_fifo_din <= wb_dat_i;
              from_wb_fifo_wr  <= '1';
            end if;
            -- end of the bus cycle
            wb_stb_o               <= '0';
            wb_cyc_o               <= '0';
            wishbone_current_state <= WB_IDLE;
          end if;

        when others =>
          -- should not get here!
          wishbone_current_state <= WB_IDLE;
          wb_cyc_o               <= '0';
          wb_stb_o               <= '0';
          s_wb_we                <= '0';
          wb_sel_o               <= "0000";
          wb_dat_o               <= (others => '0');
          wb_adr_o               <= (others => '0');
          to_wb_fifo_rd          <= '0';
          from_wb_fifo_din       <= (others => '0');
          from_wb_fifo_wr        <= '0';

      end case;
    end if;
  end process p_wb_fsm;

  -- for read back
  wb_we_o <= s_wb_we;

end behaviour;

