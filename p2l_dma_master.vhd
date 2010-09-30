--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: 32 bit P2L DMA master (p2l_dma_master.vhd)
--
-- authors: Simon Deprez (simon.deprez@cern.ch)
--          Matthieu Cattin (matthieu.cattin@cern.ch)
--
-- date: 31-08-2010
--
-- version: 0.1
--
-- description: Provide a pipelined Wishbone interface to performs DMA
--              transfers from PCI express host to local application.
--              This entity is also used to catch the next item in chained DMA.
--
-- dependencies:
--
--------------------------------------------------------------------------------
-- last changes: 29-09-2010 (mcattin) Add a wishbone clock,
--                                    clean useless entity ports
--------------------------------------------------------------------------------
-- TODO: - byte swap
--       - byte enable support.
--       - abort feature => assert RX_ERROR to GN4124
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
      sys_clk_i   : in std_logic;
      sys_rst_n_i : in std_logic;

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
      dma_ctrl_abort_i        : in  std_logic;

      ---------------------------------------------------------
      -- From P2L Decoder (receive the read completion)
      --
      -- Header
      pd_pdm_hdr_start_i   : in std_logic;                      -- Header strobe
      pd_pdm_hdr_length_i  : in std_logic_vector(9 downto 0);   -- Packet length in 32-bit words multiples
      pd_pdm_hdr_cid_i     : in std_logic_vector(1 downto 0);   -- Completion ID
      pd_pdm_master_cpld_i : in std_logic;                      -- Master read completion with data
      pd_pdm_master_cpln_i : in std_logic;                      -- Master read completion without data
      --
      -- Data
      pd_pdm_data_valid_i  : in std_logic;                      -- Indicates Data is valid
      pd_pdm_data_last_i   : in std_logic;                      -- Indicates end of the packet
      pd_pdm_data_i        : in std_logic_vector(31 downto 0);  -- Data
      pd_pdm_be_i          : in std_logic_vector(3 downto 0);   -- Byte Enable for data

      ---------------------------------------------------------
      -- P2L control
      p2l_rdy_o : out std_logic;        -- Asserted to pause transfer already in progress

      ---------------------------------------------------------
      -- To the P2L Interface (send the DMA Master Read request)
      pdm_arb_valid_o  : out std_logic;  -- Read completion signals
      pdm_arb_dframe_o : out std_logic;  -- Toward the arbiter
      pdm_arb_data_o   : out std_logic_vector(31 downto 0);
      pdm_arb_req_o    : out std_logic;
      arb_pdm_gnt_i    : in  std_logic;

      ---------------------------------------------------------
      -- DMA Interface (Pipelined Wishbone)
      p2l_dma_clk_i   : in  std_logic;                      -- Bus clock
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

  -----------------------------------------------------------------------------
  -- Local constants
  -----------------------------------------------------------------------------
  constant c_P2L_MAX_PAYLOAD       : unsigned(10 downto 0)        := to_unsigned(1024, 11);  -- MUST BE 1024
  constant c_TO_WB_FIFO_FULL_THRES : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(500, 9));

  -----------------------------------------------------------------------------
  -- Internal Signals
  -----------------------------------------------------------------------------

  -- control signals
  signal is_next_item     : std_logic;
  signal completion_error : std_logic;
  signal dma_busy_error   : std_logic;

  -- L2P packet generator
  signal l2p_address_h   : std_logic_vector(31 downto 0);
  signal l2p_address_l   : std_logic_vector(31 downto 0);
  signal l2p_len_cnt     : unsigned(29 downto 0);
  signal l2p_len_header  : unsigned(9 downto 0);
  signal l2p_64b_address : std_logic;
  signal s_l2p_header    : std_logic_vector(31 downto 0);
  signal l2p_last_packet : std_logic;

  -- Next item retrieve
  signal next_item_data_cnt : unsigned(2 downto 0);

  -- Target address counter
  signal target_addr_cnt : unsigned(29 downto 0);

  -- sync fifo
  signal fifo_rst : std_logic;

  signal to_wb_fifo_empty : std_logic;
  signal to_wb_fifo_full  : std_logic;
  signal to_wb_fifo_rd    : std_logic;
  signal to_wb_fifo_wr    : std_logic;
  signal to_wb_fifo_din   : std_logic_vector(63 downto 0);
  signal to_wb_fifo_dout  : std_logic_vector(63 downto 0);
  signal to_wb_fifo_valid : std_logic;

  -- P2L DMA read request FSM
  type   p2l_dma_state_type is (P2L_IDLE, P2L_HEADER, P2L_ADDR_H, P2L_ADDR_L, P2L_WAIT_READ_COMPLETION);
  signal p2l_dma_current_state : p2l_dma_state_type;


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

  -- Errors to DMA controller
  dma_ctrl_error_o <= dma_busy_error or completion_error;

  ------------------------------------------------------------------------------
  -- PCIe read request
  ------------------------------------------------------------------------------
  -- Stores infofmation for read request packet
  -- Can be a P2L DMA transfer or catching the next item of a chained DMA
  p_read_req : process (sys_clk_i, sys_rst_n_i)
  begin
    if (sys_rst_n_i = c_RST_ACTIVE) then
      l2p_address_h   <= (others => '0');
      l2p_address_l   <= (others => '0');
      l2p_len_cnt     <= (others => '0');
      l2p_len_header  <= (others => '0');
      l2p_64b_address <= '0';
      is_next_item    <= '0';
      l2p_last_packet <= '0';
    elsif rising_edge(sys_clk_i) then
      if (p2l_dma_current_state = P2L_IDLE) then
        if (dma_ctrl_start_p2l_i = '1' or dma_ctrl_start_next_i = '1') then
          -- Stores DMA info locally
          l2p_address_h <= dma_ctrl_host_addr_h_i;
          l2p_address_l <= dma_ctrl_host_addr_l_i;
          l2p_len_cnt   <= unsigned(dma_ctrl_len_i(31 downto 2));  -- dma_ctrl_len_i is in byte
          if (dma_ctrl_start_next_i = '1') then
            -- Catching next DMA item
            is_next_item <= '1';                                   -- flag for data retrieve block
          else
            -- P2L DMA transfer
            is_next_item <= '0';
          end if;
          if (dma_ctrl_host_addr_h_i = X"00000000") then
            l2p_64b_address <= '0';
          else
            l2p_64b_address <= '1';
          end if;
        end if;
      elsif (p2l_dma_current_state = P2L_HEADER) then
        -- if DMA length is bigger than the max PCIe payload size,
        -- we have to generate several read request
        if (l2p_len_cnt > c_P2L_MAX_PAYLOAD) then
          -- when payload length is 1024, the header length field = 0
          l2p_len_header  <= (others => '0');
          l2p_last_packet <= '0';
        elsif (l2p_len_cnt = c_P2L_MAX_PAYLOAD) then
          l2p_len_header  <= (others => '0');
          l2p_last_packet <= '1';
        else
          l2p_len_header  <= l2p_len_cnt(9 downto 0);
          l2p_last_packet <= '1';
        end if;
      elsif (p2l_dma_current_state = P2L_ADDR_L) then
        -- Subtract the number of word requested to generate a new read request if needed
        if (l2p_last_packet = '0') then
          l2p_len_cnt <= l2p_len_cnt - c_P2L_MAX_PAYLOAD;
        else
          l2p_len_cnt <= (others => '0');
        end if;
      elsif (l2p_last_packet = '0' and p2l_dma_current_state = P2L_WAIT_READ_COMPLETION) then
        -- Load length of the next read request (if any)
        if (l2p_len_cnt > c_P2L_MAX_PAYLOAD) then
          -- when payload length is 1024, the header length field = 0
          l2p_len_header  <= (others => '0');
          l2p_last_packet <= '0';
        elsif (l2p_len_cnt = c_P2L_MAX_PAYLOAD) then
          l2p_len_header  <= (others => '0');
          l2p_last_packet <= '1';
        else
          l2p_len_header  <= l2p_len_cnt(9 downto 0);
          l2p_last_packet <= '1';
        end if;
      end if;
    end if;
  end process p_read_req;

  s_l2p_header <= "000"                                -->  Traffic Class
                  & '0'                                -->  Snoop
                  & "000" & l2p_64b_address            -->  Packet type = read request (32 or 64 bits)
                  & "1111"                             -->  LBE (Last Byte Enable)
                  & "1111"                             -->  FBE (First Byte Enable)
                  & "000"                              -->  Reserved
                  & '0'                                -->  VC (Virtual Channel)
                  & "01"                               -->  CID
                  & std_logic_vector(l2p_len_header);  -->  Length (in 32-bit words)
                                                       --   0x000 => 1024 words (4096 bytes)

  -----------------------------------------------------------------------------
  -- PCIe read request FSM
  -----------------------------------------------------------------------------
  p_read_req_fsm : process (sys_clk_i, sys_rst_n_i)
  begin
    if(sys_rst_n_i = c_RST_ACTIVE) then
      p2l_dma_current_state <= P2L_IDLE;
      pdm_arb_req_o         <= '0';
      pdm_arb_data_o        <= (others => '0');
      pdm_arb_valid_o       <= '0';
      pdm_arb_dframe_o      <= '0';
      dma_ctrl_done_o       <= '0';
      next_item_valid_o     <= '0';
      completion_error      <= '0';
    elsif rising_edge(sys_clk_i) then
      case p2l_dma_current_state is

        when P2L_IDLE =>
          -- Clear status bits
          dma_ctrl_done_o   <= '0';
          next_item_valid_o <= '0';
          completion_error  <= '0';
          -- Start a read request when a P2L DMA is initated or when the DMA
          -- controller asks for the next DMA info (in a chained DMA).
          if (dma_ctrl_start_p2l_i = '1' or dma_ctrl_start_next_i = '1') then
            -- request access to PCIe bus
            pdm_arb_req_o         <= '1';
            -- prepare a packet, first the header
            p2l_dma_current_state <= P2L_HEADER;
          end if;

        when P2L_HEADER =>
          if(arb_pdm_gnt_i = '1') then
            -- clear access request to the arbiter
            -- access is granted until dframe is cleared
            pdm_arb_req_o    <= '0';
            -- send header
            pdm_arb_data_o   <= s_l2p_header;
            pdm_arb_valid_o  <= '1';
            pdm_arb_dframe_o <= '1';
            if(l2p_64b_address = '1') then
              -- if host address is 64-bit, we have to send an additionnal
              -- 32-word containing highest bits of the host address
              p2l_dma_current_state <= P2L_ADDR_H;
            else
              -- for 32-bit host address, we only have to send lowest bits
              p2l_dma_current_state <= P2L_ADDR_L;
            end if;
          end if;

        when P2L_ADDR_H =>
          -- send host address 32 highest bits
          pdm_arb_data_o        <= l2p_address_h;
          p2l_dma_current_state <= P2L_ADDR_L;

        when P2L_ADDR_L =>
          -- send host address 32 lowest bits
          pdm_arb_data_o        <= l2p_address_l;
          -- clear dframe signal to indicate the end of packet
          pdm_arb_dframe_o      <= '0';
          p2l_dma_current_state <= P2L_WAIT_READ_COMPLETION;

        when P2L_WAIT_READ_COMPLETION =>
          -- End of the read request packet
          pdm_arb_valid_o <= '0';
          if (pd_pdm_master_cpld_i = '1' and pd_pdm_data_last_i = '1') then
            -- last word of read completion has been received
            if (l2p_last_packet = '0') then
              -- A new read request is needed, DMA size > max payload
              p2l_dma_current_state <= P2L_HEADER;
              -- As the end of packet is used to delimit arbitration phases
              -- we have to ask again for permission
              pdm_arb_req_o         <= '1';
            else
              -- indicate end of DMA transfer
              if (is_next_item = '1') then
                next_item_valid_o <= '1';
              else
                dma_ctrl_done_o <= '1';
              end if;
              p2l_dma_current_state <= P2L_IDLE;
            end if;
          elsif (pd_pdm_master_cpln_i = '1') then
            -- should not return a read completion without data
            completion_error      <= '1';
            p2l_dma_current_state <= P2L_IDLE;
          end if;


        when others =>
          p2l_dma_current_state <= P2L_IDLE;
          pdm_arb_req_o         <= '0';
          pdm_arb_data_o        <= (others => '0');
          pdm_arb_valid_o       <= '0';
          pdm_arb_dframe_o      <= '0';
          dma_ctrl_done_o       <= '0';
          next_item_valid_o     <= '0';

      end case;
    end if;
  end process p_read_req_fsm;

  ------------------------------------------------------------------------------
  -- Next DMA item retrieve
  ------------------------------------------------------------------------------
  p_next_item : process (sys_clk_i, sys_rst_n_i)
  begin
    if (sys_rst_n_i = c_RST_ACTIVE) then
      next_item_carrier_addr_o <= (others => '0');
      next_item_host_addr_h_o  <= (others => '0');
      next_item_host_addr_l_o  <= (others => '0');
      next_item_len_o          <= (others => '0');
      next_item_next_l_o       <= (others => '0');
      next_item_next_h_o       <= (others => '0');
      next_item_attrib_o       <= (others => '0');
      next_item_data_cnt       <= (others => '0');
    elsif rising_edge(sys_clk_i) then
      if (dma_ctrl_start_next_i = '1') then
        next_item_data_cnt <= (others => '0');
      elsif (p2l_dma_current_state = P2L_WAIT_READ_COMPLETION
             and is_next_item = '1' and pd_pdm_data_valid_i = '1') then
        next_item_data_cnt <= next_item_data_cnt + 1;
        -- next item data are supposed to be received in the rigth order !!
        case next_item_data_cnt is
          when "000" =>
            next_item_carrier_addr_o <= pd_pdm_data_i;
          when "001" =>
            next_item_host_addr_l_o <= pd_pdm_data_i;
          when "010" =>
            next_item_host_addr_h_o <= pd_pdm_data_i;
          when "011" =>
            next_item_len_o <= pd_pdm_data_i;
          when "100" =>
            next_item_next_l_o <= pd_pdm_data_i;
          when "101" =>
            next_item_next_h_o <= pd_pdm_data_i;
          when "110" =>
            next_item_attrib_o <= pd_pdm_data_i;
          when others =>
            null;
        end case;
      end if;
    end if;
  end process p_next_item;

  ------------------------------------------------------------------------------
  -- Target address counter
  ------------------------------------------------------------------------------
  p_addr_cnt : process (sys_clk_i, sys_rst_n_i)
  begin
    if (sys_rst_n_i = c_RST_ACTIVE) then
      target_addr_cnt <= (others => '0');
      dma_busy_error  <= '0';
      to_wb_fifo_din  <= (others => '0');
      to_wb_fifo_wr   <= '0';
    elsif rising_edge(sys_clk_i) then
      if (dma_ctrl_start_p2l_i = '1') then
        if (p2l_dma_current_state = P2L_IDLE) then
          -- dma_ctrl_target_addr_i is a byte address and target_addr_cnt is a
          -- 32-bit word address
          target_addr_cnt <= unsigned(dma_ctrl_carrier_addr_i(31 downto 2));
        else
          dma_busy_error <= '1';
        end if;
      elsif (p2l_dma_current_state = P2L_WAIT_READ_COMPLETION
             and is_next_item = '0' and pd_pdm_data_valid_i = '1') then
        -- increment target address counter
        target_addr_cnt              <= target_addr_cnt + 1;
        -- write target address and data to the sync fifo
        to_wb_fifo_wr                <= '1';
        to_wb_fifo_din(31 downto 0)  <= pd_pdm_data_i;
        to_wb_fifo_din(61 downto 32) <= std_logic_vector(target_addr_cnt);
      else
        dma_busy_error <= '0';
        to_wb_fifo_wr  <= '0';
      end if;
    end if;
  end process p_addr_cnt;

  ------------------------------------------------------------------------------
  -- FIFOs for transition between GN4124 core and wishbone clock domain
  ------------------------------------------------------------------------------
  cmp_to_wb_fifo : fifo_64x512
    port map (
      rst                     => fifo_rst,
      wr_clk                  => sys_clk_i,
      rd_clk                  => p2l_dma_clk_i,
      din                     => to_wb_fifo_din,
      wr_en                   => to_wb_fifo_wr,
      rd_en                   => to_wb_fifo_rd,
      prog_full_thresh_assert => c_TO_WB_FIFO_FULL_THRES,
      prog_full_thresh_negate => c_TO_WB_FIFO_FULL_THRES,
      dout                    => to_wb_fifo_dout,
      full                    => open,
      empty                   => to_wb_fifo_empty,
      valid                   => to_wb_fifo_valid,
      prog_full               => to_wb_fifo_full);

  -- pause transfer from GN4124 if fifo is (almost) full
  p2l_rdy_o <= not(to_wb_fifo_full);

  ------------------------------------------------------------------------------
  -- Wishbone master (write only)
  ------------------------------------------------------------------------------

  -- fifo read
  to_wb_fifo_rd <= not(to_wb_fifo_empty)
                   and not(p2l_dma_stall_i);

  -- write only
  p2l_dma_we_o <= '1';

  -- Wishbone master process
  p_wb_master : process (sys_rst_n_i, p2l_dma_clk_i)
  begin
    if (sys_rst_n_i = c_RST_ACTIVE) then
      p2l_dma_cyc_o <= '0';
      p2l_dma_stb_o <= '0';
      p2l_dma_sel_o <= "0000";
      p2l_dma_adr_o <= (others => '0');
      p2l_dma_dat_o <= (others => '0');
    elsif rising_edge(p2l_dma_clk_i) then
      -- data and address
      if (to_wb_fifo_valid = '1') then
        p2l_dma_adr_o <= "00" & to_wb_fifo_dout(61 downto 32);
        p2l_dma_dat_o <= to_wb_fifo_dout(31 downto 0);
      end if;
      -- stb and sel signals management
      if (to_wb_fifo_valid = '1' or p2l_dma_stall_i = '1') then
        p2l_dma_stb_o <= '1';
        p2l_dma_sel_o <= (others => '1');
      else
        p2l_dma_stb_o <= '0';
        p2l_dma_sel_o <= (others => '0');
      end if;
      -- cyc signal management
      if (to_wb_fifo_valid = '1') then
        p2l_dma_cyc_o <= '1';
      elsif (p2l_dma_ack_i = '1') then
        -- last ack received -> end of the transaction
        p2l_dma_cyc_o <= '0';
      end if;
    end if;
  end process p_wb_master;


end behaviour;

