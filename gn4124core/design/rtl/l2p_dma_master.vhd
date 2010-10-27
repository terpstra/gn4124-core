--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: 32-bit DMA master (l2p_dma_master.vhd)
--
-- authors: Simon Deprez (simon.deprez@cern.ch)
--          Matthieu Cattin (matthieu.cattin@cern.ch)
--
-- date: 31-08-2010
--
-- version: 1.0
--
-- description: Provides a pipelined Wishbone interface to performs DMA
--              transfers from local application to PCI express host.
--
-- dependencies: Xilinx FIFOs (fifo_32x512.xco)
--
--------------------------------------------------------------------------------
-- last changes: 23-09-2010 (mcattin) Split wishbone and gn4124 clock domains
--               All signals crossing the clock domains are now going through fifos.
--               Dead times optimisation in packet generator.
--------------------------------------------------------------------------------
-- TODO: - issue an error if ask DMA transfert of length = 0
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gn4124_core_pkg.all;


entity l2p_dma_master is
  generic (
    -- Enable byte swap module (if false, no swap)
    g_BYTE_SWAP : boolean := false
    );
  port
    (
      ---------------------------------------------------------
      -- GN4124 core clock and reset
      clk_i   : in std_logic;
      rst_n_i : in std_logic;

      ---------------------------------------------------------
      -- From the DMA controller
      dma_ctrl_target_addr_i : in  std_logic_vector(31 downto 0);
      dma_ctrl_host_addr_h_i : in  std_logic_vector(31 downto 0);
      dma_ctrl_host_addr_l_i : in  std_logic_vector(31 downto 0);
      dma_ctrl_len_i         : in  std_logic_vector(31 downto 0);
      dma_ctrl_start_l2p_i   : in  std_logic;
      dma_ctrl_done_o        : out std_logic;
      dma_ctrl_error_o       : out std_logic;
      dma_ctrl_byte_swap_i   : in  std_logic_vector(1 downto 0);
      dma_ctrl_abort_i       : in  std_logic;

      ---------------------------------------------------------
      -- To the arbiter (L2P data)
      ldm_arb_valid_o  : out std_logic;  -- Read completion signals
      ldm_arb_dframe_o : out std_logic;  -- Toward the arbiter
      ldm_arb_data_o   : out std_logic_vector(31 downto 0);
      ldm_arb_req_o    : out std_logic;
      arb_ldm_gnt_i    : in  std_logic;

      ---------------------------------------------------------
      -- L2P channel control
      l2p_edb_o  : out std_logic;                     -- Asserted when transfer is aborted
      l_wr_rdy_i : in  std_logic_vector(1 downto 0);  -- Asserted when GN4124 is ready to receive master write
      l2p_rdy_i  : in  std_logic;                     -- De-asserted to pause transfer already in progress

      ---------------------------------------------------------
      -- DMA Interface (Pipelined Wishbone)
      l2p_dma_clk_i   : in  std_logic;                      -- Bus clock
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


  -----------------------------------------------------------------------------
  -- Byte swap function
  -----------------------------------------------------------------------------
  function f_byte_swap (
    constant enable    : boolean;
    signal   din       : std_logic_vector(31 downto 0);
    signal   byte_swap : std_logic_vector(1 downto 0))
    return std_logic_vector is
    variable dout : std_logic_vector(31 downto 0) := din;
  begin
    if (enable = true) then
      case byte_swap is
        when "00" =>
          dout := din;
        when "01" =>
          dout := din(23 downto 16)
                  & din(31 downto 24)
                  & din(7 downto 0)
                  & din(15 downto 8);
        when "10" =>
          dout := din(15 downto 0)
                  & din(31 downto 16);
        when "11" =>
          dout := din(7 downto 0)
                  & din(15 downto 8)
                  & din(23 downto 16)
                  & din(31 downto 24);
        when others =>
          dout := din;
      end case;
    else
      dout := din;
    end if;
    return dout;
  end function f_byte_swap;

  -----------------------------------------------------------------------------
  -- Constants declaration
  -----------------------------------------------------------------------------
  constant c_L2P_MAX_PAYLOAD      : unsigned(10 downto 0)        := to_unsigned(1024, 11);  -- MUST be 1024
  constant c_ADDR_FIFO_FULL_THRES : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(500, 9));
  constant c_DATA_FIFO_FULL_THRES : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(500, 9));

  -----------------------------------------------------------------------------
  -- Signals declaration
  -----------------------------------------------------------------------------

  -- Target address counter
  signal target_addr_cnt : unsigned(29 downto 0);
  signal dma_length_cnt  : unsigned(29 downto 0);

  -- Sync FIFOs
  signal fifo_rst        : std_logic;
  signal addr_fifo_rd    : std_logic;
  signal addr_fifo_valid : std_logic;
  signal addr_fifo_empty : std_logic;
  signal addr_fifo_dout  : std_logic_vector(31 downto 0);
  signal addr_fifo_din   : std_logic_vector(31 downto 0);
  signal addr_fifo_wr    : std_logic;
  signal addr_fifo_full  : std_logic;

  signal data_fifo_rd    : std_logic;
  signal data_fifo_valid : std_logic;
  signal data_fifo_empty : std_logic;
  signal data_fifo_dout  : std_logic_vector(31 downto 0);
  signal data_fifo_din   : std_logic_vector(31 downto 0);
  signal data_fifo_wr    : std_logic;
  signal data_fifo_full  : std_logic;

  -- Wishbone
  signal wb_read_cnt   : unsigned(6 downto 0);
  signal wb_ack_cnt    : unsigned(6 downto 0);
  signal l2p_dma_cyc_t : std_logic;

  -- L2P DMA Master FSM
  type l2p_dma_state_type is (L2P_IDLE, L2P_WAIT_DATA, L2P_HEADER, L2P_ADDR_H,
                                L2P_ADDR_L, L2P_DATA, L2P_LAST_DATA, L2P_WAIT_RDY);
  signal l2p_dma_current_state : l2p_dma_state_type;

  -- L2P packet generator
  signal s_l2p_header : std_logic_vector(31 downto 0);

  signal l2p_len_cnt     : unsigned(29 downto 0);
  signal l2p_address_h   : unsigned(31 downto 0);
  signal l2p_address_l   : unsigned(31 downto 0);
  signal l2p_data_cnt    : unsigned(10 downto 0);
  signal l2p_64b_address : std_logic;
  signal l2p_len_header  : std_logic_vector(9 downto 0);
  signal l2p_byte_swap   : std_logic_vector(1 downto 0);
  signal l2p_last_packet : std_logic;


begin


  ------------------------------------------------------------------------------
  -- Active high reset for fifo
  ------------------------------------------------------------------------------
  -- Creates an active high reset for fifos regardless of c_RST_ACTIVE value
  gen_fifo_rst_n : if c_RST_ACTIVE = '0' generate
    fifo_rst <= not(rst_n_i);
  end generate;

  gen_fifo_rst : if c_RST_ACTIVE = '1' generate
    fifo_rst <= rst_n_i;
  end generate;

  ------------------------------------------------------------------------------
  -- Target address counter
  ------------------------------------------------------------------------------
  p_target_cnt : process (clk_i, rst_n_i)
  begin
    if(rst_n_i = c_RST_ACTIVE) then
      target_addr_cnt  <= (others => '0');
      dma_length_cnt   <= (others => '0');
      dma_ctrl_error_o <= '0';
      addr_fifo_wr     <= '0';
    elsif rising_edge(clk_i) then
      if (dma_ctrl_start_l2p_i = '1') then
        if (l2p_dma_current_state = L2P_IDLE) then
          -- dma_ctrl_target_addr_i is a byte address and target_addr_cnt is a
          -- 32-bit word address
          target_addr_cnt  <= unsigned(dma_ctrl_target_addr_i(31 downto 2));
          -- dma_ctrl_len_i is in byte and dma_length_cnt is in 32-bit word
          dma_length_cnt   <= unsigned(dma_ctrl_len_i(31 downto 2));
          dma_ctrl_error_o <= '0';
        else
          -- trying to start a DMA transfert when another is still in progress
          -- will gives an error
          target_addr_cnt  <= (others => '0');
          dma_length_cnt   <= (others => '0');
          dma_ctrl_error_o <= '1';
        end if;
      elsif (dma_length_cnt /= 0 and addr_fifo_full = '0') then
        -- increment the target address and write it to address fifo
        addr_fifo_wr    <= '1';
        target_addr_cnt <= target_addr_cnt + 1;
        dma_length_cnt  <= dma_length_cnt - 1;
        -- Adust data width, fifo width is 32 bits
        addr_fifo_din <= "00" & std_logic_vector(target_addr_cnt);
      else
        addr_fifo_wr <= '0';
      end if;
    end if;
  end process p_target_cnt;

  ------------------------------------------------------------------------------
  -- Packet generator
  ------------------------------------------------------------------------------
  -- Sends data to the host.
  -- Split in several packets if amont of data exceeds max payload size.

  p_pkt_gen : process (clk_i, rst_n_i)
  begin
    if (rst_n_i = c_RST_ACTIVE) then
      l2p_len_cnt     <= (others => '0');
      l2p_data_cnt    <= (others => '0');
      l2p_address_h   <= (others => '0');
      l2p_address_l   <= (others => '0');
      l2p_64b_address <= '0';
      l2p_len_header  <= (others => '0');
      l2p_byte_swap   <= (others => '0');
      l2p_last_packet <= '0';
    elsif rising_edge(clk_i) then
      -- First packet
      if (l2p_dma_current_state = L2P_IDLE) then
        if (dma_ctrl_start_l2p_i = '1') then
          -- store DMA info locally
          l2p_len_cnt   <= unsigned(dma_ctrl_len_i(31 downto 2));
          l2p_address_h <= unsigned(dma_ctrl_host_addr_h_i);
          l2p_address_l <= unsigned(dma_ctrl_host_addr_l_i);
          l2p_byte_swap <= dma_ctrl_byte_swap_i;
        end if;
      elsif (l2p_dma_current_state = L2P_HEADER) then
        -- if DMA length is bigger than the max PCIe payload size,
        -- the data is split in several packets
        if (l2p_len_cnt > c_L2P_MAX_PAYLOAD) then
          l2p_data_cnt    <= c_L2P_MAX_PAYLOAD;
          -- when payload length is 1024, the header length field = 0
          l2p_len_header  <= (others => '0');
          l2p_last_packet <= '0';
        elsif (l2p_len_cnt = c_L2P_MAX_PAYLOAD) then
          l2p_data_cnt    <= c_L2P_MAX_PAYLOAD;
          -- if payload length is 1024, the header length field = 0
          l2p_len_header  <= (others => '0');
          l2p_last_packet <= '1';
        else
          l2p_data_cnt    <= l2p_len_cnt(10 downto 0);
          l2p_len_header  <= std_logic_vector(l2p_len_cnt(9 downto 0));
          l2p_last_packet <= '1';
        end if;
        -- if host address is 64-bit, generates a 64-bit address memory write
        if (l2p_address_h = 0) then
          l2p_64b_address <= '0';
        else
          l2p_64b_address <= '1';
        end if;
        -- Next packet (if any)
      elsif (l2p_dma_current_state = L2P_ADDR_L) then
        if (l2p_last_packet = '0') then
          l2p_len_cnt <= l2p_len_cnt - c_L2P_MAX_PAYLOAD;
        else
          l2p_len_cnt <= (others => '0');
        end if;
      elsif (l2p_dma_current_state = L2P_DATA) then
        l2p_data_cnt <= l2p_data_cnt - 1;
      elsif (l2p_last_packet = '0' and l2p_dma_current_state = L2P_LAST_DATA) then
        -- load the size of the next packet
        if (l2p_len_cnt > c_L2P_MAX_PAYLOAD) then
          l2p_data_cnt    <= c_L2P_MAX_PAYLOAD;
          -- when payload length is 1024, the header length field = 0
          l2p_len_header  <= (others => '0');
          l2p_last_packet <= '0';
        elsif (l2p_len_cnt = c_L2P_MAX_PAYLOAD) then
          l2p_data_cnt    <= c_L2P_MAX_PAYLOAD;
          -- if payload length is 1024, the header length field = 0
          l2p_len_header  <= (others => '0');
          l2p_last_packet <= '1';
        else
          l2p_data_cnt    <= l2p_len_cnt(10 downto 0);
          l2p_len_header  <= std_logic_vector(l2p_len_cnt(9 downto 0));
          l2p_last_packet <= '1';
        end if;
      end if;
    end if;
  end process p_pkt_gen;

  -- Packet header
  s_l2p_header <= "000"                      -->  Traffic Class
                  & '0'                      -->  Snoop
                  & "001" & l2p_64b_address  -->  Header type,
                                             --   memory write 32-bit or
                                             --   memory write 64-bit
                  & "1111"                   -->  LBE (Last Byte Enable)
                  & "1111"                   -->  FBE (First Byte Enable)
                  & "000"                    -->  Reserved
                  & '0'                      -->  VC (Virtual Channel)
                  & "00"                     -->  Reserved
                  & l2p_len_header;          -->  Length (in 32-bit words)
                                             --   0x000 => 1024 words (4096 bytes)

  -----------------------------------------------------------------------------
  -- L2P packet write FSM
  -----------------------------------------------------------------------------
  process(clk_i, rst_n_i)
  begin
    if (rst_n_i = c_RST_ACTIVE) then
      l2p_dma_current_state <= L2P_IDLE;
      ldm_arb_req_o         <= '0';
      ldm_arb_data_o        <= (others => '0');
      ldm_arb_valid_o       <= '0';
      ldm_arb_dframe_o      <= '0';
      data_fifo_rd          <= '0';
      dma_ctrl_done_o       <= '0';
      l2p_edb_o             <= '0';
    elsif rising_edge(clk_i) then
      case l2p_dma_current_state is

        when L2P_IDLE =>
          -- do nothing !
          data_fifo_rd     <= '0';
          dma_ctrl_done_o  <= '0';
          ldm_arb_data_o   <= (others => '0');
          ldm_arb_valid_o  <= '0';
          ldm_arb_dframe_o <= '0';
          l2p_edb_o        <= '0';

          if (data_fifo_empty = '0' and l_wr_rdy_i = "11") then
            -- We have data to send -> prepare a packet, first the header
            l2p_dma_current_state <= L2P_HEADER;
            -- request access to PCIe bus
            ldm_arb_req_o         <= '1';
          end if;

        when L2P_HEADER =>
          if(arb_ldm_gnt_i = '1') then
            -- clear access request to the arbiter
            -- access is granted until dframe is cleared
            ldm_arb_req_o    <= '0';
            -- send header
            ldm_arb_data_o   <= s_l2p_header;
            ldm_arb_valid_o  <= '1';
            ldm_arb_dframe_o <= '1';
            if(l2p_64b_address = '1') then
              -- if host address is 64-bit, we have to send an additionnal
              -- 32-word containing highest bits of the host address
              l2p_dma_current_state <= L2P_ADDR_H;
            else
              -- for 32-bit host address, we only have to send lowest bits
              l2p_dma_current_state <= L2P_ADDR_L;
              -- Starts reading data in the fifo now, because there is
              -- 1 cycle delay until data are available
              data_fifo_rd          <= '1';
            end if;
          end if;

        when L2P_ADDR_H =>
          -- send host address 32 highest bits
          ldm_arb_data_o        <= std_logic_vector(l2p_address_h);
          -- Now we still have to send lowest bits of the host address
          l2p_dma_current_state <= L2P_ADDR_L;
          -- Starts reading data in the fifo now, because there is
          -- 1 cycle delay until data are available
          data_fifo_rd          <= '1';

        when L2P_ADDR_L =>
          -- send host address 32 lowest bits
          ldm_arb_data_o  <= std_logic_vector(l2p_address_l);
          if(l2p_data_cnt <= 1) then
            -- Only one 32-bit data word to send
            l2p_dma_current_state <= L2P_LAST_DATA;
            -- Stop reading from fifo
            data_fifo_rd          <= '0';
          else
            -- More than one data word to send
            l2p_dma_current_state <= L2P_DATA;
          end if;

        when L2P_DATA =>
          -- send data with byte swap if requested
          ldm_arb_data_o  <= f_byte_swap(g_BYTE_SWAP, data_fifo_dout, l2p_byte_swap);
          ldm_arb_valid_o <= '1';
          if (dma_ctrl_abort_i = '1') then
            l2p_edb_o             <= '1';
            l2p_dma_current_state <= L2P_IDLE;
          elsif(data_fifo_empty = '1') then
            -- data not ready yet, wait for it
            l2p_dma_current_state <= L2P_WAIT_DATA;
          elsif(l2p_data_cnt <= 2) then
            -- Only one 32-bit data word to send
            l2p_dma_current_state <= L2P_LAST_DATA;
            -- Stop reading from fifo
            data_fifo_rd          <= '0';
          elsif (l2p_rdy_i = '0') then
            -- GN4124 not able to receive more data, have to wait
            l2p_dma_current_state <= L2P_WAIT_RDY;
            -- Stop reading from fifo
            data_fifo_rd          <= '0';
          end if;

        when L2P_WAIT_RDY =>
          ldm_arb_valid_o <= '0';
          if (l2p_rdy_i = '1') then
            -- GN4124 is ready to receive more data
            l2p_dma_current_state <= L2P_DATA;
            -- Re-start fifo reading
            data_fifo_rd          <= '1';
          end if;

        when L2P_WAIT_DATA =>
          ldm_arb_valid_o <= '0';
          if(data_fifo_empty = '0') then
            -- data ready to be send again
            l2p_dma_current_state <= L2P_DATA;
          elsif(l2p_data_cnt <= 2) then
            -- Only one 32-bit data word to send
            l2p_dma_current_state <= L2P_LAST_DATA;
            -- Stop reading from fifo
            data_fifo_rd          <= '0';
          end if;

        when L2P_LAST_DATA =>
          -- send last data word with byte swap if requested
          ldm_arb_data_o   <= f_byte_swap(g_BYTE_SWAP, data_fifo_dout, l2p_byte_swap);
          ldm_arb_valid_o  <= '1';
          -- clear dframe signal to indicate the end of packet
          ldm_arb_dframe_o <= '0';
          if(l2p_len_cnt > 0) then
            -- There is still data to be send -> start a new packet
            l2p_dma_current_state <= L2P_HEADER;
            -- As the end of packet is used to delimit arbitration phases
            -- we have to ask again for permission
            ldm_arb_req_o         <= '1';
          else
            -- Nomore data to send, go back to sleep
            l2p_dma_current_state <= L2P_IDLE;
            -- Indicate that the DMA transfer is finished
            dma_ctrl_done_o       <= '1';
          end if;

        when others =>
          -- should no arrive here, but just in case...
          l2p_dma_current_state <= L2P_IDLE;
          ldm_arb_req_o         <= '0';
          ldm_arb_data_o        <= (others => '0');
          ldm_arb_valid_o       <= '0';
          ldm_arb_dframe_o      <= '0';
          data_fifo_rd          <= '0';
          dma_ctrl_done_o       <= '0';

      end case;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- FIFOs for transition between GN4124 core and wishbone clock domain
  ------------------------------------------------------------------------------
  cmp_addr_fifo : fifo_32x512
    port map (
      rst                     => fifo_rst,
      wr_clk                  => clk_i,
      rd_clk                  => l2p_dma_clk_i,
      din                     => addr_fifo_din,
      wr_en                   => addr_fifo_wr,
      rd_en                   => addr_fifo_rd,
      prog_full_thresh_assert => c_ADDR_FIFO_FULL_THRES,
      prog_full_thresh_negate => c_ADDR_FIFO_FULL_THRES,
      dout                    => addr_fifo_dout,
      full                    => open,
      empty                   => addr_fifo_empty,
      valid                   => addr_fifo_valid,
      prog_full               => addr_fifo_full);

  cmp_data_fifo : fifo_32x512
    port map (
      rst                     => fifo_rst,
      wr_clk                  => l2p_dma_clk_i,
      rd_clk                  => clk_i,
      din                     => data_fifo_din,
      wr_en                   => data_fifo_wr,
      rd_en                   => data_fifo_rd,
      prog_full_thresh_assert => c_DATA_FIFO_FULL_THRES,
      prog_full_thresh_negate => c_DATA_FIFO_FULL_THRES,
      dout                    => data_fifo_dout,
      full                    => open,
      empty                   => data_fifo_empty,
      valid                   => data_fifo_valid,
      prog_full               => data_fifo_full);

  data_fifo_din <= l2p_dma_dat_i;
  -- latch data when receiving ack and the cycle has been initiated by this master
  data_fifo_wr  <= l2p_dma_ack_i and l2p_dma_cyc_t;

  ------------------------------------------------------------------------------
  -- Pipelined wishbone master
  ------------------------------------------------------------------------------
  -- Initatiates read transactions as long there is an address present
  -- in the address fifo. Then fills the data fifo with the read data.

  -- Wishbone master only make reads
  l2p_dma_we_o  <= '0';
  l2p_dma_dat_o <= (others => '0');

  -- Read address FIFO
  addr_fifo_rd <= not(addr_fifo_empty)
                  and not(l2p_dma_stall_i)
                  and not(data_fifo_full);

  -- Wishbone master process
  p_wb_master : process (l2p_dma_clk_i, rst_n_i)
  begin
    if (rst_n_i = c_RST_ACTIVE) then
      l2p_dma_adr_o <= (others => '0');
      l2p_dma_stb_o <= '0';
      l2p_dma_cyc_t <= '0';
      l2p_dma_sel_o <= (others => '0');
    elsif rising_edge(l2p_dma_clk_i) then
      -- adr signal management
      if (addr_fifo_valid = '1') then
        l2p_dma_adr_o <= addr_fifo_dout;
      end if;
      -- stb and sel signals management
      if (addr_fifo_valid = '1' or l2p_dma_stall_i = '1') then
        l2p_dma_stb_o <= '1';
        l2p_dma_sel_o <= (others => '1');
      else
        l2p_dma_stb_o <= '0';
        l2p_dma_sel_o <= (others => '0');
      end if;
      -- cyc signal management
      if (addr_fifo_valid = '1') then
        l2p_dma_cyc_t <= '1';
      elsif (wb_ack_cnt = wb_read_cnt-1 and l2p_dma_ack_i = '1') then
        -- last ack received -> end of the transaction
        l2p_dma_cyc_t <= '0';
      end if;
    end if;
  end process p_wb_master;

  -- for read back
  l2p_dma_cyc_o <= l2p_dma_cyc_t;

  -- Wishbone read cycle counter
  p_wb_read_cnt : process (l2p_dma_clk_i, rst_n_i)
  begin
    if (rst_n_i = c_RST_ACTIVE) then
      wb_read_cnt <= (others => '0');
    elsif rising_edge(l2p_dma_clk_i) then
      if (addr_fifo_valid = '1') then
        wb_read_cnt <= wb_read_cnt + 1;
      end if;
    end if;
  end process p_wb_read_cnt;

-- Wishbone ack counter
  p_wb_ack_cnt : process (l2p_dma_clk_i, rst_n_i)
  begin
    if (rst_n_i = c_RST_ACTIVE) then
      wb_ack_cnt <= (others => '0');
    elsif rising_edge(l2p_dma_clk_i) then
      if (l2p_dma_ack_i = '1' and l2p_dma_cyc_t = '1') then
        wb_ack_cnt <= wb_ack_cnt + 1;
      end if;
    end if;
  end process p_wb_ack_cnt;


end behaviour;

