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
--! Package for components declaration
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

-----------------------------------------------------------------------------
  component P2L_DES
-----------------------------------------------------------------------------
    port
      (
        ---------------------------------------------------------
        -- Raw unprocessed reset from the GN412x
        --
        L_RST       : in     std_ulogic;
        ---------------------------------------------------------
        -- P2L Clock Domain
        --
        -- P2L Inputs
        P2L_CLKp    : in     std_ulogic;
        P2L_CLKn    : in     std_ulogic;
        P2L_VALID   : in     std_ulogic;
        P2L_DFRAME  : in     std_ulogic;
        P2L_DATA    : in     std_ulogic_vector(15 downto 0);
        --
        ---------------------------------------------------------
        ---------------------------------------------------------
        -- ICLK Clock Domain
        --
        IRST        : out    std_ulogic;
        -- Core Logic Clock
        ICLK        : buffer std_ulogic;
        ICLKn       : buffer std_ulogic;
        -- DeSerialized Output
        ICLK_VALID  : out    std_ulogic;
        ICLK_DFRAME : out    std_ulogic;
        ICLK_DATA   : out    std_ulogic_vector(31 downto 0)
        --
        ---------------------------------------------------------
        );
  end component;  -- P2L_DES

-----------------------------------------------------------------------------
  component P2L_DECODE32
-----------------------------------------------------------------------------
    port
      (
        ---------------------------------------------------------
        ---------------------------------------------------------
        -- Clock/Reset
        --
        CLK               : in  std_ulogic;
        RST               : in  std_ulogic;
        ---------------------------------------------------------
        -- Input from the Deserializer
        --
        DES_P2L_VALIDi    : in  std_ulogic;
        DES_P2L_DFRAMEi   : in  std_ulogic;
        DES_P2L_DATAi     : in  std_ulogic_vector(31 downto 0);
        --
        ---------------------------------------------------------
        ---------------------------------------------------------
        -- Decoder Outputs
        --
        -- Header
        IP2L_HDR_STARTo   : out std_ulogic;                      -- Indicates Header start cycle
        IP2L_HDR_LENGTHo  : out std_ulogic_vector(9 downto 0);   -- Latched LENGTH value from header
        IP2L_HDR_CIDo     : out std_ulogic_vector(1 downto 0);   -- Completion ID
        IP2L_HDR_LASTo    : out std_ulogic;                      -- Indicates Last packet in a completion
        IP2L_HDR_STATo    : out std_ulogic_vector(1 downto 0);   -- Completion Status
        IP2L_TARGET_MRDo  : out std_ulogic;                      -- Target memory read
        IP2L_TARGET_MWRo  : out std_ulogic;                      -- Target memory write
        IP2L_MASTER_CPLDo : out std_ulogic;                      -- Master completion with data
        IP2L_MASTER_CPLNo : out std_ulogic;                      -- Master completion without data
        --
        -- Address
        IP2L_ADDR_STARTo  : out std_ulogic;                      -- Indicates Address Start
        IP2L_ADDRo        : out std_ulogic_vector(31 downto 0);  -- Latched Address that will increment with data
        --
        -- Data
        IP2L_D_VALIDo     : out std_ulogic;                      -- Indicates Data is valid
        IP2L_D_LASTo      : out std_ulogic;                      -- Indicates end of the packet
        IP2L_Do           : out std_ulogic_vector(31 downto 0);  -- Data
        IP2L_BEo          : out std_ulogic_vector(3 downto 0)    -- Byte Enable for data
        --
        ---------------------------------------------------------
        );
  end component;  -- P2L_DECODE32


-----------------------------------------------------------------------------
  component L2P_SER
-----------------------------------------------------------------------------
    port
      (
        ---------------------------------------------------------
        -- ICLK Clock Domain Inputs
        --
        ICLKp : in std_ulogic;
        ICLKn : in std_ulogic;
        IRST  : in std_ulogic;

        ICLK_VALID  : in  std_ulogic;
        ICLK_DFRAME : in  std_ulogic;
        ICLK_DATA   : in  std_ulogic_vector(31 downto 0);
        --
        ---------------------------------------------------------
        ---------------------------------------------------------
        -- SER Outputs
        --
        L2P_CLKp    : out std_ulogic;
        L2P_CLKn    : out std_ulogic;
        L2P_VALID   : out std_ulogic;
        L2P_DFRAME  : out std_ulogic;
        L2P_DATA    : out std_ulogic_vector(15 downto 0)
        --
        ---------------------------------------------------------
        );
  end component;  -- L2P_SER

-----------------------------------------------------------------------------
  component wbmaster32 is
-----------------------------------------------------------------------------
    generic
      (
        WBM_TIMEOUT : integer := 5      -- Determines the timeout value of read and write
        );
    port
      (
        DEBUG     : out std_logic_vector(3 downto 0);
        ---------------------------------------------------------
        ---------------------------------------------------------
        -- Clock/Reset
        --
        sys_clk_i : in  std_ulogic;
        sys_rst_i : in  std_ulogic;

        gn4124_clk_i        : in  std_ulogic;
        ---------------------------------------------------------
        ---------------------------------------------------------
        -- From P2L Decoder
        --
        -- Header
        pd_wbm_hdr_start_i  : in  std_ulogic;                       -- Indicates Header start cycle
        pd_wbm_hdr_length_i : in  std_ulogic_vector(9 downto 0);    -- Latched LENGTH value from header
        pd_wbm_hdr_cid_i    : in  std_ulogic_vector(1 downto 0);    -- Completion ID
        pd_wbm_target_mrd_i : in  std_ulogic;                       -- Target memory read
        pd_wbm_target_mwr_i : in  std_ulogic;                       -- Target memory write
        --
        -- Address
        pd_wbm_addr_start_i : in  std_ulogic;                       -- Indicates Address Start
        pd_wbm_addr_i       : in  std_ulogic_vector(31 downto 0);   -- Latched Address that will increment with data
        pd_wbm_wbm_addr_i   : in  std_ulogic;                       -- Indicates that current address is for the EPI interface
                                                                    -- Can be connected to a decode of IP2L_ADDRi
                                                                    -- or to IP2L_ADDRi(0) for BAR2
                                                                    -- or to not IP2L_ADDRi(0) for BAR0
        --
        -- Data
        pd_wbm_data_valid_i : in  std_ulogic;                       -- Indicates Data is valid
        pd_wbm_data_last_i  : in  std_ulogic;                       -- Indicates end of the packet
        pd_wbm_data_i       : in  std_ulogic_vector(31 downto 0);   -- Data
        pd_wbm_be_i         : in  std_ulogic_vector(3 downto 0);    -- Byte Enable for data
        --
        ---------------------------------------------------------
        -- P2L Control
        --
        p_wr_rdy_o          : out std_ulogic;                       -- Write buffer not empty
        ---------------------------------------------------------
        ---------------------------------------------------------
        -- To the L2P Interface
        --
        wbm_arb_valid_o     : out std_ulogic;                       -- Read completion signals
        wbm_arb_dframe_o    : out std_ulogic;                       -- Toward the arbiter
        wbm_arb_data_o      : out std_ulogic_vector(31 downto 0);
        wbm_arb_req_o       : out std_ulogic;
        arb_wbm_gnt_i       : in  std_ulogic;
        --
        ---------------------------------------------------------
        ---------------------------------------------------------
        -- Wishbone Interface
        --
        wb_adr_o            : out std_logic_vector(32-1 downto 0);  -- Adress
        wb_dat_i            : in  std_logic_vector(31 downto 0);    -- Data in
        wb_dat_o            : out std_logic_vector(31 downto 0);    -- Data out
        wb_sel_o            : out std_logic_vector(3 downto 0);     -- Byte select
        wb_cyc_o            : out std_logic;                        -- Read or write cycle
        wb_stb_o            : out std_logic;                        -- Read or write strobe
        wb_we_o             : out std_logic;                        -- Write
        wb_ack_i            : in  std_logic;                        -- Acknowledge
        wb_stall_i          : in  std_logic                         -- Pipelined mode
        --
        ---------------------------------------------------------
        );
  end component;  -- wbmaster32

-----------------------------------------------------------------------------
  component dma_controller is
-----------------------------------------------------------------------------
    port
      (
        DEBUG                   : out std_logic_vector(3 downto 0);
        ---------------------------------------------------------
        ---------------------------------------------------------
        -- Clock/Reset
        --
        sys_clk_i               : in  std_ulogic;
        sys_rst_i               : in  std_ulogic;
        ---------------------------------------------------------
        ---------------------------------------------------------
        -- To the L2P DMA master and P2L DMA master
        --
        dma_ctrl_carrier_addr_o : out std_logic_vector(31 downto 0);
        dma_ctrl_host_addr_h_o  : out std_logic_vector(31 downto 0);
        dma_ctrl_host_addr_l_o  : out std_logic_vector(31 downto 0);
        dma_ctrl_len_o          : out std_logic_vector(31 downto 0);
        dma_ctrl_start_l2p_o    : out std_logic;  -- To the L2P DMA master
        dma_ctrl_start_p2l_o    : out std_logic;  -- To the P2L DMA master
        dma_ctrl_start_next_o   : out std_logic;  -- To the P2L DMA master
        dma_ctrl_done_i         : in  std_logic;
        dma_ctrl_error_i        : in  std_logic;

        dma_ctrl_byte_swap_o : out std_logic_vector(1 downto 0);
        --
        ---------------------------------------------------------

        ---------------------------------------------------------
        -- From P2L DMA MASTER
        --
        next_item_carrier_addr_i : in std_logic_vector(31 downto 0);
        next_item_host_addr_h_i  : in std_logic_vector(31 downto 0);
        next_item_host_addr_l_i  : in std_logic_vector(31 downto 0);
        next_item_len_i          : in std_logic_vector(31 downto 0);
        next_item_next_l_i       : in std_logic_vector(31 downto 0);
        next_item_next_h_i       : in std_logic_vector(31 downto 0);
        next_item_attrib_i       : in std_logic_vector(31 downto 0);
        next_item_valid_i        : in std_logic;
        --
        ---------------------------------------------------------

        ---------------------------------------------------------
        -- Wishbone Slave Interface
        --
        wb_adr_i : in  std_logic_vector(3 downto 0);   -- Adress
        wb_dat_o : out std_logic_vector(31 downto 0);  -- Data in
        wb_dat_i : in  std_logic_vector(31 downto 0);  -- Data out
        wb_sel_i : in  std_logic_vector(3 downto 0);   -- Byte select
        wb_cyc_i : in  std_logic;                      -- Read or write cycle
        wb_stb_i : in  std_logic;                      -- Read or write strobe
        wb_we_i  : in  std_logic;                      -- Write
        wb_ack_o : out std_logic                       -- Acknowledge
        --
        ---------------------------------------------------------
        );
  end component;  -- dma_controller

-----------------------------------------------------------------------------
  component l2p_dma_master is
-----------------------------------------------------------------------------
    port
      (
        ---------------------------------------------------------
        ---------------------------------------------------------
        -- Clock/Reset
        --
        sys_clk_i : in std_ulogic;
        sys_rst_i : in std_ulogic;

        gn4124_clk_i : in std_ulogic;
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

        dma_ctrl_byte_swap_i : in std_logic_vector(1 downto 0);
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
        l2p_dma_cyc_o   : out std_logic;                      -- Read or write cycle
        l2p_dma_stb_o   : out std_logic;                      -- Read or write strobe
        l2p_dma_we_o    : out std_logic;                      -- Write
        l2p_dma_ack_i   : in  std_logic;                      -- Acknowledge
        l2p_dma_stall_i : in  std_logic                       -- for pipelined Wishbone
        --
        ---------------------------------------------------------
        );
  end component;  -- l2p_dma_master

-----------------------------------------------------------------------------
  component p2l_dma_master is
-----------------------------------------------------------------------------
    port
      (
        DEBUG     : out std_logic_vector(3 downto 0);
        ---------------------------------------------------------
        ---------------------------------------------------------
        -- Clock/Reset
        --
        sys_clk_i : in  std_ulogic;
        sys_rst_i : in  std_ulogic;

        gn4124_clk_i : in std_ulogic;
        ---------------------------------------------------------

        ---------------------------------------------------------
        -- From the DMA controller
        --
        dma_ctrl_carrier_addr_i : in  std_logic_vector(31 downto 0);
        dma_ctrl_host_addr_h_i  : in  std_logic_vector(31 downto 0);
        dma_ctrl_host_addr_l_i  : in  std_logic_vector(31 downto 0);
        dma_ctrl_len_i          : in  std_logic_vector(31 downto 0);
        dma_ctrl_start_p2l_i    : in  std_logic;
        dma_ctrl_start_next_i   : in  std_logic;
        dma_ctrl_done_o         : out std_logic;
        dma_ctrl_error_o        : out std_logic;

        dma_ctrl_byte_swap_i : in std_logic_vector(1 downto 0);
        --
        ---------------------------------------------------------

        ---------------------------------------------------------
        -- From P2L Decoder (receive the read completion)
        --
        -- Header
        pd_pdm_hdr_start_i   : in std_ulogic;                      -- Indicates Header start cycle
        pd_pdm_hdr_length_i  : in std_ulogic_vector(9 downto 0);   -- Latched LENGTH value from header
        pd_pdm_hdr_cid_i     : in std_ulogic_vector(1 downto 0);   -- Completion ID
        pd_pdm_target_mrd_i  : in std_ulogic;                      -- Target memory read
        pd_pdm_target_mwr_i  : in std_ulogic;                      -- Target memory write
        pd_pdm_target_cpld_i : in std_ulogic;                      -- Target memory write
        --
        -- Address
        pd_pdm_addr_start_i  : in std_ulogic;                      -- Indicates Address Start
        pd_pdm_addr_i        : in std_ulogic_vector(31 downto 0);  -- Latched Address that will increment with data
        pd_pdm_wbm_addr_i    : in std_ulogic;                      -- Indicates that current address is for the EPI interface
                                                                   -- Can be connected to a decode of IP2L_ADDRi
                                                                   -- or to IP2L_ADDRi(0) for BAR2
                                                                   -- or to not IP2L_ADDRi(0) for BAR0
        --
        -- Data
        pd_pdm_data_valid_i  : in std_ulogic;                      -- Indicates Data is valid
        pd_pdm_data_last_i   : in std_ulogic;                      -- Indicates end of the packet
        pd_pdm_data_i        : in std_ulogic_vector(31 downto 0);  -- Data
        pd_pdm_be_i          : in std_ulogic_vector(3 downto 0);   -- Byte Enable for data
        --
        ---------------------------------------------------------

        ---------------------------------------------------------
        -- To the L2P Interface (send the DMA Master Read request)
        --
        pdm_arb_valid_o  : out std_ulogic;  -- Read completion signals
        pdm_arb_dframe_o : out std_ulogic;  -- Toward the arbiter
        pdm_arb_data_o   : out std_ulogic_vector(31 downto 0);
        pdm_arb_req_o    : out std_ulogic;
        arb_pdm_gnt_i    : in  std_ulogic;
        --
        ---------------------------------------------------------

        ---------------------------------------------------------
        -- DMA Interface (Pipelined Wishbone)
        --
        p2l_dma_adr_o   : out std_logic_vector(31 downto 0);  -- Adress
        p2l_dma_dat_i   : in  std_logic_vector(31 downto 0);  -- Data in
        p2l_dma_dat_o   : out std_logic_vector(31 downto 0);  -- Data out
        p2l_dma_sel_o   : out std_logic_vector(3 downto 0);   -- Byte select
        p2l_dma_cyc_o   : out std_logic;                      -- Read or write cycle
        p2l_dma_stb_o   : out std_logic;                      -- Read or write strobe
        p2l_dma_we_o    : out std_logic;                      -- Write
        p2l_dma_ack_i   : in  std_logic;                      -- Acknowledge
        p2l_dma_stall_i : in  std_logic;                      -- for pipelined Wishbone
        --
        ---------------------------------------------------------

        ---------------------------------------------------------
        -- From P2L DMA MASTER
        --
        next_item_carrier_addr_o : out std_logic_vector(31 downto 0);
        next_item_host_addr_h_o  : out std_logic_vector(31 downto 0);
        next_item_host_addr_l_o  : out std_logic_vector(31 downto 0);
        next_item_len_o          : out std_logic_vector(31 downto 0);
        next_item_next_l_o       : out std_logic_vector(31 downto 0);
        next_item_next_h_o       : out std_logic_vector(31 downto 0);
        next_item_attrib_o       : out std_logic_vector(31 downto 0);
        next_item_valid_o        : out std_logic
        --
        ---------------------------------------------------------
        );
  end component;  -- p2l_dma_master

-----------------------------------------------------------------------------
  component arbiter is
-----------------------------------------------------------------------------
    port (
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- Clock/Reset
      --
      clk_i            : in  std_ulogic;
      rst_i            : in  std_ulogic;
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- From Wishbone master (wbm) to arbiter (arb)
      --
      wbm_arb_valid_i  : in  std_ulogic;
      wbm_arb_dframe_i : in  std_ulogic;
      wbm_arb_data_i   : in  std_ulogic_vector(31 downto 0);
      wbm_arb_req_i    : in  std_ulogic;
      arb_wbm_gnt_o    : out std_ulogic;
      --
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- From DMA controller (pdm) to arbiter (arb)
      --
      pdm_arb_valid_i  : in  std_ulogic;
      pdm_arb_dframe_i : in  std_ulogic;
      pdm_arb_data_i   : in  std_ulogic_vector(31 downto 0);
      pdm_arb_req_i    : in  std_ulogic;
      arb_pdm_gnt_o    : out std_ulogic;
      --
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- From P2L DMA master (ldm) to arbiter (arb)
      --
      ldm_arb_valid_i  : in  std_ulogic;
      ldm_arb_dframe_i : in  std_ulogic;
      ldm_arb_data_i   : in  std_ulogic_vector(31 downto 0);
      ldm_arb_req_i    : in  std_ulogic;
      arb_ldm_gnt_o    : out std_ulogic;
      --
      ---------------------------------------------------------

      ---------------------------------------------------------
      -- From arbiter (arb) to serializer (ser)
      --
      arb_ser_valid_o  : out std_ulogic;
      arb_ser_dframe_o : out std_ulogic;
      arb_ser_data_o   : out std_ulogic_vector(31 downto 0)
      --
      ---------------------------------------------------------
      );
  end component;        -- arbiter

end gn4124_core_pkg;