--==============================================================================
--! @file gn4124_core_pkg.vhd
--==============================================================================

--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Package for gn4124 core
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--! @brief
--! Package for components declaration and core wide constants
--------------------------------------------------------------------------------
--! @version
--! 0.1 | mc | 01.09.2010 | File creation and Doxygen comments
--!
--! @author
--! mc : Matthieu Cattin, CERN (BE-CO-HT)
--------------------------------------------------------------------------------


--==============================================================================
--! Package declaration
--==============================================================================
package gn4124_core_pkg is


--==============================================================================
--Components declaration
--==============================================================================
  constant c_RST_ACTIVE : std_logic := '0';  -- Active low reset


--==============================================================================
--Components declaration
--==============================================================================

-----------------------------------------------------------------------------
  component p2l_des
-----------------------------------------------------------------------------
    port
      (
        ---------------------------------------------------------
        -- Reset and clock
        rst_n_i : in std_logic;
        clk_p_i : in std_logic;
        clk_n_i : in std_logic;

        ---------------------------------------------------------
        -- P2L Clock Domain
        --
        -- P2L Inputs
        p2l_valid_i  : in std_logic;
        p2l_dframe_i : in std_logic;
        p2l_data_i   : in std_logic_vector(15 downto 0);

        ---------------------------------------------------------
        -- Core Clock Domain
        --
        -- DeSerialized Output
        p2l_valid_o  : out std_logic;
        p2l_dframe_o : out std_logic;
        p2l_data_o   : out std_logic_vector(31 downto 0)
        );
  end component;  -- p2l_des

-----------------------------------------------------------------------------
  component p2l_decode32
-----------------------------------------------------------------------------
    port
      (
        ---------------------------------------------------------
        -- Clock/Reset
        clk_i   : in std_logic;
        rst_n_i : in std_logic;

        ---------------------------------------------------------
        -- Input from the Deserializer
        des_p2l_valid_i  : in std_logic;
        des_p2l_dframe_i : in std_logic;
        des_p2l_data_i   : in std_logic_vector(31 downto 0);

        ---------------------------------------------------------
        -- Decoder Outputs
        --
        -- Header
        p2l_hdr_start_o   : out std_logic;                      -- Indicates Header start cycle
        p2l_hdr_length_o  : out std_logic_vector(9 downto 0);   -- Latched LENGTH value from header
        p2l_hdr_cid_o     : out std_logic_vector(1 downto 0);   -- Completion ID
        p2l_hdr_last_o    : out std_logic;                      -- Indicates Last packet in a completion
        p2l_hdr_stat_o    : out std_logic_vector(1 downto 0);   -- Completion Status
        p2l_target_mrd_o  : out std_logic;                      -- Target memory read
        p2l_target_mwr_o  : out std_logic;                      -- Target memory write
        p2l_master_cpld_o : out std_logic;                      -- Master completion with data
        p2l_master_cpln_o : out std_logic;                      -- Master completion without data
        --
        -- Address
        p2l_addr_start_o  : out std_logic;                      -- Indicates Address Start
        p2l_addr_o        : out std_logic_vector(31 downto 0);  -- Latched Address that will increment with data
        --
        -- Data
        p2l_d_valid_o     : out std_logic;                      -- Indicates Data is valid
        p2l_d_last_o      : out std_logic;                      -- Indicates end of the packet
        p2l_d_o           : out std_logic_vector(31 downto 0);  -- Data
        p2l_be_o          : out std_logic_vector(3 downto 0)    -- Byte Enable for data
        );
  end component;  -- p2l_decode32


-----------------------------------------------------------------------------
  component l2p_ser
-----------------------------------------------------------------------------
    port
      (
        ---------------------------------------------------------
        -- ICLK Clock Domain Inputs
        clk_p_i : in std_logic;
        clk_n_i : in std_logic;
        rst_n_i : in std_logic;

        l2p_valid_i  : in std_logic;
        l2p_dframe_i : in std_logic;
        l2p_data_i   : in std_logic_vector(31 downto 0);

        ---------------------------------------------------------
        -- SER Outputs
        l2p_clk_p_o  : out std_logic;
        l2p_clk_n_o  : out std_logic;
        l2p_valid_o  : out std_logic;
        l2p_dframe_o : out std_logic;
        l2p_data_o   : out std_logic_vector(15 downto 0)
        );
  end component;  -- l2p_ser


-----------------------------------------------------------------------------
  component wbmaster32
-----------------------------------------------------------------------------
    generic
      (
        WBM_TIMEOUT : integer := 5      -- Determines the timeout value of read and write
        );
    port
      (
        DEBUG : out std_logic_vector(3 downto 0);

        ---------------------------------------------------------
        -- Clock/Reset
        sys_clk_i   : in std_logic;
        sys_rst_n_i : in std_logic;

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
        p_wr_rdy_o : out std_logic;     -- Write buffer not empty

        ---------------------------------------------------------
        -- To the L2P Interface
        wbm_arb_valid_o  : out std_logic;  -- Read completion signals
        wbm_arb_dframe_o : out std_logic;  -- Toward the arbiter
        wbm_arb_data_o   : out std_logic_vector(31 downto 0);
        wbm_arb_req_o    : out std_logic;
        arb_wbm_gnt_i    : in  std_logic;

        ---------------------------------------------------------
        -- Wishbone Interface
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
  end component;  -- wbmaster32

-----------------------------------------------------------------------------
  component dma_controller
-----------------------------------------------------------------------------
    port
      (
        DEBUG : out std_logic_vector(3 downto 0);

        ---------------------------------------------------------
        -- Clock/Reset
        sys_clk_i   : in std_logic;
        sys_rst_n_i : in std_logic;

        ---------------------------------------------------------
        -- To the L2P DMA master and P2L DMA master
        dma_ctrl_carrier_addr_o : out std_logic_vector(31 downto 0);
        dma_ctrl_host_addr_h_o  : out std_logic_vector(31 downto 0);
        dma_ctrl_host_addr_l_o  : out std_logic_vector(31 downto 0);
        dma_ctrl_len_o          : out std_logic_vector(31 downto 0);
        dma_ctrl_start_l2p_o    : out std_logic;  -- To the L2P DMA master
        dma_ctrl_start_p2l_o    : out std_logic;  -- To the P2L DMA master
        dma_ctrl_start_next_o   : out std_logic;  -- To the P2L DMA master
        dma_ctrl_done_i         : in  std_logic;
        dma_ctrl_error_i        : in  std_logic;
        dma_ctrl_byte_swap_o    : out std_logic_vector(1 downto 0);

        ---------------------------------------------------------
        -- From P2L DMA MASTER
        next_item_carrier_addr_i : in std_logic_vector(31 downto 0);
        next_item_host_addr_h_i  : in std_logic_vector(31 downto 0);
        next_item_host_addr_l_i  : in std_logic_vector(31 downto 0);
        next_item_len_i          : in std_logic_vector(31 downto 0);
        next_item_next_l_i       : in std_logic_vector(31 downto 0);
        next_item_next_h_i       : in std_logic_vector(31 downto 0);
        next_item_attrib_i       : in std_logic_vector(31 downto 0);
        next_item_valid_i        : in std_logic;

        ---------------------------------------------------------
        -- Wishbone Slave Interface
        wb_adr_i : in  std_logic_vector(3 downto 0);   -- Adress
        wb_dat_o : out std_logic_vector(31 downto 0);  -- Data in
        wb_dat_i : in  std_logic_vector(31 downto 0);  -- Data out
        wb_sel_i : in  std_logic_vector(3 downto 0);   -- Byte select
        wb_cyc_i : in  std_logic;                      -- Read or write cycle
        wb_stb_i : in  std_logic;                      -- Read or write strobe
        wb_we_i  : in  std_logic;                      -- Write
        wb_ack_o : out std_logic                       -- Acknowledge
        );
  end component;  -- dma_controller

-----------------------------------------------------------------------------
  component l2p_dma_master
-----------------------------------------------------------------------------
    generic (
      -- Enable byte swap module (if false, no swap)
      g_BYTE_SWAP : boolean := true
      );
    port
      (
        ---------------------------------------------------------
        -- GN4124 core clock and reset
        sys_clk_i   : in std_logic;
        sys_rst_n_i : in std_logic;

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

        ---------------------------------------------------------
        -- To the L2P Interface (send the DMA data)
        ldm_arb_valid_o  : out std_logic;  -- Read completion signals
        ldm_arb_dframe_o : out std_logic;  -- Toward the arbiter
        ldm_arb_data_o   : out std_logic_vector(31 downto 0);
        ldm_arb_req_o    : out std_logic;
        arb_ldm_gnt_i    : in  std_logic;

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
  end component;  -- l2p_dma_master

-----------------------------------------------------------------------------
  component p2l_dma_master
-----------------------------------------------------------------------------
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
        -- To the L2P Interface (send the DMA Master Read request)
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
  end component;  -- p2l_dma_master

-----------------------------------------------------------------------------
  component arbiter
-----------------------------------------------------------------------------
    port (
      ---------------------------------------------------------
      -- Clock/Reset
      clk_i   : in std_logic;
      rst_n_i : in std_logic;

      ---------------------------------------------------------
      -- From Wishbone master (wbm) to arbiter (arb)
      wbm_arb_valid_i  : in  std_logic;
      wbm_arb_dframe_i : in  std_logic;
      wbm_arb_data_i   : in  std_logic_vector(31 downto 0);
      wbm_arb_req_i    : in  std_logic;
      arb_wbm_gnt_o    : out std_logic;

      ---------------------------------------------------------
      -- From DMA controller (pdm) to arbiter (arb)
      pdm_arb_valid_i  : in  std_logic;
      pdm_arb_dframe_i : in  std_logic;
      pdm_arb_data_i   : in  std_logic_vector(31 downto 0);
      pdm_arb_req_i    : in  std_logic;
      arb_pdm_gnt_o    : out std_logic;

      ---------------------------------------------------------
      -- From P2L DMA master (ldm) to arbiter (arb)
      ldm_arb_valid_i  : in  std_logic;
      ldm_arb_dframe_i : in  std_logic;
      ldm_arb_data_i   : in  std_logic_vector(31 downto 0);
      ldm_arb_req_i    : in  std_logic;
      arb_ldm_gnt_o    : out std_logic;

      ---------------------------------------------------------
      -- From arbiter (arb) to serializer (ser)
      arb_ser_valid_o  : out std_logic;
      arb_ser_dframe_o : out std_logic;
      arb_ser_data_o   : out std_logic_vector(31 downto 0)
      );
  end component;  -- arbiter

-----------------------------------------------------------------------------
  component fifo_32x512
-----------------------------------------------------------------------------
    port (
      rst                     : in  std_logic;
      wr_clk                  : in  std_logic;
      rd_clk                  : in  std_logic;
      din                     : in  std_logic_vector(31 downto 0);
      wr_en                   : in  std_logic;
      rd_en                   : in  std_logic;
      prog_full_thresh_assert : in  std_logic_vector(8 downto 0);
      prog_full_thresh_negate : in  std_logic_vector(8 downto 0);
      dout                    : out std_logic_vector(31 downto 0);
      full                    : out std_logic;
      empty                   : out std_logic;
      valid                   : out std_logic;
      prog_full               : out std_logic);
  end component;

-----------------------------------------------------------------------------
  component fifo_64x512
-----------------------------------------------------------------------------
    port (
      rst                     : in  std_logic;
      wr_clk                  : in  std_logic;
      rd_clk                  : in  std_logic;
      din                     : in  std_logic_vector(63 downto 0);
      wr_en                   : in  std_logic;
      rd_en                   : in  std_logic;
      prog_full_thresh_assert : in  std_logic_vector(8 downto 0);
      prog_full_thresh_negate : in  std_logic_vector(8 downto 0);
      dout                    : out std_logic_vector(63 downto 0);
      full                    : out std_logic;
      empty                   : out std_logic;
      valid                   : out std_logic;
      prog_full               : out std_logic);
  end component;


end gn4124_core_pkg;
