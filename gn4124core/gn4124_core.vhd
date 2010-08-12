--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: Gn4124 core main block (gn4124-core.vhd)
--
-- author: Simon Deprez (simon.deprez@cern.ch)
--
-- date: 07-07-2010
--
-- version: 0.1
--
-- description: 
-- 
--
-- dependencies: 
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
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.lotus_pkg.all;
use work.lotus_util.all;

--==============================================================================
-- Entity declaration for GN4124 core (gn4124_core)
--==============================================================================
entity gn4124_core is
	port
	(
    LED                    : out    std_logic_vector(7 downto 0);
		---------------------------------------------------------
		-- Clock/Reset from GN412x
    --	    L_CLKp                 : in   std_logic;                     -- Running at 100 or 200 Mhz
    --	    L_CLKn                 : in   std_logic;                     -- Running at 100 or 200 Mhz

    sys_clk_i                : in   std_logic;
    sys_rst_i                : in   std_logic;

    --
    ---------------------------------------------------------
		---------------------------------------------------------
		-- P2L Direction
		--
    -- Source Sync DDR related signals
    p2l_clk_p_i            : in   std_logic;                     -- Receiver Source Synchronous Clock+
    p2l_clk_n_i            : in   std_logic;                     -- Receiver Source Synchronous Clock-
    p2l_data_i             : in   std_logic_vector(15 downto 0); -- Parallel receive data
    p2l_dframe_i           : in   std_logic;                     -- Receive Frame
    p2l_valid_i            : in   std_logic;                     -- Receive Data Valid
    -- P2L Control
    p2l_rdy_o              : out  std_logic;                     -- Rx Buffer Full Flag
    p_wr_req_o             : in   std_logic_vector(1 downto 0);  -- PCIe Write Request
    p_wr_rdy_o             : out  std_logic_vector(1 downto 0);  -- PCIe Write Ready
    rx_error_o             : out  std_logic;                     -- Receive Error
    --
    ---------------------------------------------------------
		---------------------------------------------------------
		-- L2P Direction
		--
    -- Source Sync DDR related signals
    l2p_clk_p_o            : out  std_logic;                     -- Transmitter Source Synchronous Clock+
    l2p_clk_n_o            : out  std_logic;                     -- Transmitter Source Synchronous Clock-
    l2p_data_o             : out  std_logic_vector(15 downto 0); -- Parallel transmit data 
    l2p_dframe_o           : out  std_logic;                     -- Transmit Data Frame
    l2p_valid_o            : out  std_logic;                     -- Transmit Data Valid
    l2p_edb_o              : out  std_logic;                     -- Packet termination and discard
    -- L2P Control
    l2p_rdy_i              : in   std_logic;                     -- Tx Buffer Full Flag
    l_wr_rdy_i             : in   std_logic_vector(1 downto 0);  -- Local-to-PCIe Write
    p_rd_d_rdy_i           : in   std_logic_vector(1 downto 0);  -- PCIe-to-Local Read Response Data Ready
    tx_error_i             : in   std_logic;                     -- Transmit Error
    vc_rdy_i               : in   std_logic_vector(1 downto 0);  -- Channel ready
    --
    ---------------------------------------------------------
		---------------------------------------------------------
		-- Target Interface (Wishbone master)
		--
    wb_adr_o         : out  STD_LOGIC_VECTOR(31 downto 0);
    wb_dat_i         : in   STD_LOGIC_VECTOR(31 downto 0);  -- Data in
    wb_dat_o         : out  STD_LOGIC_VECTOR(31 downto 0);  -- Data out
    wb_sel_o         : out  STD_LOGIC_VECTOR(3 downto 0);             -- Byte select
    wb_cyc_o         : out  STD_LOGIC; 
    wb_stb_o         : out  STD_LOGIC;
    wb_we_o          : out  STD_LOGIC;
    wb_ack_i         : in  STD_LOGIC;
    wb_stall_i         : in  STD_LOGIC;
    --
    ---------------------------------------------------------
		---------------------------------------------------------
		-- L2P DMA Interface (Pipelined Wishbone master)
		--
    dma_adr_o         : out  STD_LOGIC_VECTOR(31 downto 0);
    dma_dat_i         : in   STD_LOGIC_VECTOR(31 downto 0);  -- Data in
    dma_dat_o         : out  STD_LOGIC_VECTOR(31 downto 0);  -- Data out
    dma_sel_o         : out  STD_LOGIC_VECTOR(3 downto 0);   -- Byte select
    dma_cyc_o         : out  STD_LOGIC; 
    dma_stb_o         : out  STD_LOGIC;
    dma_we_o          : out  STD_LOGIC;
    dma_ack_i         : in   STD_LOGIC;
    dma_stall_i       : in   STD_LOGIC                        -- for pipelined Wishbone
    --
    ---------------------------------------------------------
	);
end gn4124_core;

--==============================================================================
-- Architecture declaration for GN4124 core (gn4124_core)
--==============================================================================
architecture BEHAVIOUR of gn4124_core is

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
		L_RST          : in     STD_ULOGIC;
		---------------------------------------------------------
		-- P2L Clock Domain
		--
		-- P2L Inputs
		P2L_CLKp       : in     STD_ULOGIC;
		P2L_CLKn       : in     STD_ULOGIC;
		P2L_VALID      : in     STD_ULOGIC;
		P2L_DFRAME     : in     STD_ULOGIC;
		P2L_DATA       : in     STD_ULOGIC_VECTOR(15 downto 0);
		--
		---------------------------------------------------------
		---------------------------------------------------------
		-- ICLK Clock Domain
		--
		IRST           : out    STD_ULOGIC;
		-- Core Logic Clock
		ICLK           : buffer STD_ULOGIC;
		ICLKn          : buffer STD_ULOGIC;
		-- DeSerialized Output
		ICLK_VALID     : out    STD_ULOGIC;
		ICLK_DFRAME    : out    STD_ULOGIC;
		ICLK_DATA      : out    STD_ULOGIC_VECTOR(31 downto 0)
		--
		---------------------------------------------------------
	);
end component; -- P2L_DES

-----------------------------------------------------------------------------
component P2L_DECODE32
-----------------------------------------------------------------------------
	port
	( 
		---------------------------------------------------------
		---------------------------------------------------------
		-- Clock/Reset
		--
		CLK              : in   STD_ULOGIC;
		RST              : in   STD_ULOGIC;
		---------------------------------------------------------
		-- Input from the Deserializer
		--
		DES_P2L_VALIDi   : in   STD_ULOGIC;
		DES_P2L_DFRAMEi  : in   STD_ULOGIC;
		DES_P2L_DATAi    : in   STD_ULOGIC_VECTOR(31 downto 0);
		--
		---------------------------------------------------------
		---------------------------------------------------------
		-- Decoder Outputs
		--
		-- Header
		IP2L_HDR_STARTo  : out  STD_ULOGIC;                     -- Indicates Header start cycle 
		IP2L_HDR_LENGTHo : out  STD_ULOGIC_VECTOR(9 downto 0);  -- Latched LENGTH value from header
		IP2L_HDR_CIDo    : out  STD_ULOGIC_VECTOR(1 downto 0);  -- Completion ID
		IP2L_HDR_LASTo   : out  STD_ULOGIC;                     -- Indicates Last packet in a completion
		IP2L_HDR_STATo   : out  STD_ULOGIC_VECTOR(1 downto 0);  -- Completion Status
		IP2L_TARGET_MRDo : out  STD_ULOGIC;                     -- Target memory read
		IP2L_TARGET_MWRo : out  STD_ULOGIC;                     -- Target memory write
		IP2L_MASTER_CPLDo: out  STD_ULOGIC;                     -- Master completion with data
		IP2L_MASTER_CPLNo: out  STD_ULOGIC;                     -- Master completion without data
		--
		-- Address
		IP2L_ADDR_STARTo : out  STD_ULOGIC;                     -- Indicates Address Start 
		IP2L_ADDRo       : out  STD_ULOGIC_VECTOR(31 downto 0); -- Latched Address that will increment with data
		--
		-- Data
		IP2L_D_VALIDo    : out  STD_ULOGIC;                     -- Indicates Data is valid
		IP2L_D_LASTo     : out  STD_ULOGIC;                     -- Indicates end of the packet
		IP2L_Do          : out  STD_ULOGIC_VECTOR(31 downto 0); -- Data
		IP2L_BEo         : out  STD_ULOGIC_VECTOR( 3 downto 0)  -- Byte Enable for data
		--
		---------------------------------------------------------
	);
end component; -- P2L_DECODE32


-----------------------------------------------------------------------------
component L2P_SER
-----------------------------------------------------------------------------
	port
	( 
		---------------------------------------------------------
		-- ICLK Clock Domain Inputs
		--
		ICLKp          : in   STD_ULOGIC;
		ICLKn          : in   STD_ULOGIC;
		IRST           : in   STD_ULOGIC;

		ICLK_VALID     : in   STD_ULOGIC;
		ICLK_DFRAME    : in   STD_ULOGIC;
		ICLK_DATA      : in   STD_ULOGIC_VECTOR(31 downto 0);
		--
		---------------------------------------------------------
		---------------------------------------------------------
		-- SER Outputs
		--
		L2P_CLKp       : out  STD_ULOGIC;
		L2P_CLKn       : out  STD_ULOGIC;
		L2P_VALID      : out  STD_ULOGIC;
		L2P_DFRAME     : out  STD_ULOGIC;
		L2P_DATA       : out  STD_ULOGIC_VECTOR(15 downto 0)
		--
		---------------------------------------------------------
	);
end component; -- L2P_SER

-----------------------------------------------------------------------------
component wbmaster32 is
-----------------------------------------------------------------------------
	generic
	(
		WBM_TIMEOUT    : integer := 5                            -- Determines the timeout value of read and write
	);
		port
	( 
		---------------------------------------------------------
		---------------------------------------------------------
		-- Clock/Reset
		--
		sys_clk_i           : in   STD_ULOGIC;
		sys_rst_i           : in   STD_ULOGIC;

    gn4124_clk_i        : in   STD_ULOGIC;
		---------------------------------------------------------
		---------------------------------------------------------
		-- From P2L Decoder
		--
		-- Header
		pd_wbm_hdr_start_i  : in   STD_ULOGIC;                      -- Indicates Header start cycle 
		pd_wbm_hdr_length_i : in   STD_ULOGIC_VECTOR(9 downto 0);   -- Latched LENGTH value from header
		pd_wbm_hdr_cid_i    : in   STD_ULOGIC_VECTOR(1 downto 0);   -- Completion ID
		pd_wbm_target_mrd_i : in   STD_ULOGIC;                      -- Target memory read
		pd_wbm_target_mwr_i : in   STD_ULOGIC;                      -- Target memory write
		--
		-- Address
		pd_wbm_addr_start_i : in   STD_ULOGIC;                      -- Indicates Address Start 
		pd_wbm_addr_i       : in   STD_ULOGIC_VECTOR(31 downto 0);  -- Latched Address that will increment with data
		pd_wbm_wbm_addr_i   : in   STD_ULOGIC;                      -- Indicates that current address is for the EPI interface
		                                                            -- Can be connected to a decode of IP2L_ADDRi 
		                                                            -- or to IP2L_ADDRi(0) for BAR2
		                                                            -- or to not IP2L_ADDRi(0) for BAR0
		--
		-- Data
		pd_wbm_data_valid_i    : in   STD_ULOGIC;                       -- Indicates Data is valid
		pd_wbm_data_last_i     : in   STD_ULOGIC;                       -- Indicates end of the packet
		pd_wbm_data_i          : in   STD_ULOGIC_VECTOR(31 downto 0);   -- Data
		pd_wbm_be_i            : in   STD_ULOGIC_VECTOR( 3 downto 0);   -- Byte Enable for data
		--
		---------------------------------------------------------
		-- P2L Control
		--
		p_wr_rdy_o        : out  STD_ULOGIC;                        -- Write buffer not empty
		---------------------------------------------------------
		---------------------------------------------------------
		-- To the L2P Interface
		--
		wbm_arb_valid_o      : out  STD_ULOGIC;                     -- Read completion signals
		wbm_arb_dframe_o     : out  STD_ULOGIC;                     -- Toward the arbiter
		wbm_arb_data_o       : out  STD_ULOGIC_VECTOR(31 downto 0);
		wbm_arb_req_o        : out  STD_ULOGIC;
		arb_wbm_gnt_i        : in   STD_ULOGIC;
		--
		---------------------------------------------------------
		---------------------------------------------------------
		-- Wishbone Interface
		--
    wb_adr_o         : out  STD_LOGIC_VECTOR(32-1 downto 0);    -- Adress
    wb_dat_i         : in   STD_LOGIC_VECTOR(31 downto 0);      -- Data in
    wb_dat_o         : out  STD_LOGIC_VECTOR(31 downto 0);      -- Data out
    wb_sel_o         : out  STD_LOGIC_VECTOR(3 downto 0);       -- Byte select
    wb_cyc_o         : out  STD_LOGIC;                          -- Read or write cycle
    wb_stb_o         : out  STD_LOGIC;                          -- Read or write strobe
    wb_we_o          : out  STD_LOGIC;                          -- Write
    wb_ack_i         : in   STD_LOGIC;                          -- Acknowledge
    wb_stall_i       : in   STD_LOGIC                           -- Pipelined mode
		--
		---------------------------------------------------------
	);
end component; -- wbmaster32

-----------------------------------------------------------------------------
component dma_controller is
-----------------------------------------------------------------------------
port
	( 
    LED                    : out    std_logic_vector(7 downto 0);
		---------------------------------------------------------
		---------------------------------------------------------
		-- Clock/Reset
		--
		clk_i             : in   STD_ULOGIC;
		rst_i             : in   STD_ULOGIC;
		---------------------------------------------------------
		---------------------------------------------------------
		-- To the L2P DMA master and P2L DMA master
		--
		dma_ctrl_carrier_addr_o  : out  STD_LOGIC_VECTOR(31 downto 0);
    dma_ctrl_host_addr_h_o   : out  STD_LOGIC_VECTOR(31 downto 0);
    dma_ctrl_host_addr_l_o   : out  STD_LOGIC_VECTOR(31 downto 0);
    dma_ctrl_len_o           : out  STD_LOGIC_VECTOR(31 downto 0);
    dma_ctrl_start_l2p_o     : out  STD_LOGIC;                       -- To the L2P DMA master
    dma_ctrl_start_p2l_o     : out  STD_LOGIC;                       -- To the P2L DMA master
    dma_ctrl_start_next_o    : out  STD_LOGIC;                       -- To the P2L DMA master
    dma_ctrl_done_i          : in  STD_LOGIC;   
    dma_ctrl_error_i         : in  STD_LOGIC;      
		--
		---------------------------------------------------------

	  ---------------------------------------------------------
		-- From P2L DMA MASTER
		--
		next_item_carrier_addr_i  : in  STD_LOGIC_VECTOR(31 downto 0);
		next_item_host_addr_h_i   : in  STD_LOGIC_VECTOR(31 downto 0);
		next_item_host_addr_l_i   : in  STD_LOGIC_VECTOR(31 downto 0);
		next_item_len_i           : in  STD_LOGIC_VECTOR(31 downto 0);
		next_item_next_l_i        : in  STD_LOGIC_VECTOR(31 downto 0);
		next_item_next_h_i        : in  STD_LOGIC_VECTOR(31 downto 0);   
		next_item_attrib_i        : in  STD_LOGIC_VECTOR(31 downto 0);
		next_item_valid_i         : in  STD_LOGIC;      
		--
		---------------------------------------------------------

		---------------------------------------------------------
		-- Wishbone Slave Interface
		--
    wb_adr_i         : in   STD_LOGIC_VECTOR(3 downto 0);             -- Adress
    wb_dat_o         : out  STD_LOGIC_VECTOR(31 downto 0);            -- Data in
    wb_dat_i         : in   STD_LOGIC_VECTOR(31 downto 0);            -- Data out
    wb_sel_i         : in   STD_LOGIC_VECTOR(3 downto 0);             -- Byte select
    wb_cyc_i         : in   STD_LOGIC;                                -- Read or write cycle
    wb_stb_i         : in   STD_LOGIC;                                -- Read or write strobe
    wb_we_i          : in   STD_LOGIC;                                -- Write
    wb_ack_o         : out  STD_LOGIC                                 -- Acknowledge
		--
		---------------------------------------------------------
	);
end component; -- dma_controller

-----------------------------------------------------------------------------
component l2p_dma_master is
-----------------------------------------------------------------------------
  port
  ( 
		---------------------------------------------------------
		---------------------------------------------------------
		-- Clock/Reset
		--
		clk_i                   : in   STD_ULOGIC;
		rst_i                   : in   STD_ULOGIC;
		---------------------------------------------------------

	  ---------------------------------------------------------
		-- From the DMA controller 
		--
    dma_ctrl_carrier_addr_i : in  STD_LOGIC_VECTOR(31 downto 0);
    dma_ctrl_host_addr_h_i  : in  STD_LOGIC_VECTOR(31 downto 0);
    dma_ctrl_host_addr_l_i  : in  STD_LOGIC_VECTOR(31 downto 0);
    dma_ctrl_len_i          : in  STD_LOGIC_VECTOR(31 downto 0);
    dma_ctrl_start_l2p_i    : in  STD_LOGIC;       
    dma_ctrl_done_o         : out STD_LOGIC;   
    dma_ctrl_error_o        : out STD_LOGIC;        
		--
		---------------------------------------------------------

		---------------------------------------------------------
		-- To the L2P Interface (send the DMA data)
		--
		ldm_arb_valid_o         : out  STD_ULOGIC;                      -- Read completion signals
		ldm_arb_dframe_o        : out  STD_ULOGIC;                      -- Toward the arbiter
		ldm_arb_data_o          : out  STD_ULOGIC_VECTOR(31 downto 0);
		ldm_arb_req_o           : out  STD_ULOGIC;
		arb_ldm_gnt_i           : in   STD_ULOGIC;
		--
		---------------------------------------------------------

		---------------------------------------------------------
		-- DMA Interface (Pipelined Wishbone)
		--
    l2p_dma_adr_o           : out  STD_LOGIC_VECTOR(31 downto 0);   -- Adress
    l2p_dma_dat_i           : in   STD_LOGIC_VECTOR(31 downto 0);   -- Data in
    l2p_dma_dat_o           : out  STD_LOGIC_VECTOR(31 downto 0);   -- Data out
    l2p_dma_sel_o           : out  STD_LOGIC_VECTOR(3 downto 0);    -- Byte select
    l2p_dma_cyc_o           : out  STD_LOGIC;                       -- Read or write cycle
    l2p_dma_stb_o           : out  STD_LOGIC;                       -- Read or write strobe
    l2p_dma_we_o            : out  STD_LOGIC;                       -- Write
    l2p_dma_ack_i           : in   STD_LOGIC;                       -- Acknowledge
    l2p_dma_stall_i         : in   STD_LOGIC                        -- for pipelined Wishbone
		--
		---------------------------------------------------------
	);
end component; -- l2p_dma_master


-----------------------------------------------------------------------------
component arbiter is
-----------------------------------------------------------------------------
  port ( 
		---------------------------------------------------------
		---------------------------------------------------------
		-- Clock/Reset
		--
		clk_i             : in   STD_ULOGIC;
		rst_i             : in   STD_ULOGIC;
		---------------------------------------------------------
		---------------------------------------------------------
		-- From Wishbone master (wbm) to arbiter (arb)
		--
		wbm_arb_valid_i  : in  STD_ULOGIC;
		wbm_arb_dframe_i : in  STD_ULOGIC;
		wbm_arb_data_i   : in  STD_ULOGIC_VECTOR(31 downto 0);
		wbm_arb_req_i    : in  STD_ULOGIC;
		arb_wbm_gnt_o    : out STD_ULOGIC;
		--
		---------------------------------------------------------
		---------------------------------------------------------
		-- From DMA controller (pdm) to arbiter (arb)
		--
		pdm_arb_valid_i  : in  STD_ULOGIC;
		pdm_arb_dframe_i : in  STD_ULOGIC;
		pdm_arb_data_i   : in  STD_ULOGIC_VECTOR(31 downto 0);
		pdm_arb_req_i    : in  STD_ULOGIC;
		arb_pdm_gnt_o    : out STD_ULOGIC;
		--
		---------------------------------------------------------
		---------------------------------------------------------
		-- From P2L DMA master (ldm) to arbiter (arb)
		--
		ldm_arb_valid_i  : in  STD_ULOGIC;
		ldm_arb_dframe_i : in  STD_ULOGIC;
		ldm_arb_data_i   : in  STD_ULOGIC_VECTOR(31 downto 0);
		ldm_arb_req_i    : in  STD_ULOGIC;
		arb_ldm_gnt_o    : out STD_ULOGIC;
		--
		---------------------------------------------------------

		---------------------------------------------------------
		-- From arbiter (arb) to serializer (ser)
		--
		arb_ser_valid_o  : out STD_ULOGIC;
		arb_ser_dframe_o : out STD_ULOGIC;
		arb_ser_data_o   : out STD_ULOGIC_VECTOR(31 downto 0)
		--
		---------------------------------------------------------
	);
end component; -- arbiter

--==============================================================================
-- Internal signals
--==============================================================================

-------------------------------------------------------------
-- Clock/Reset
-------------------------------------------------------------
	-- Internal 1X clock operating at the same rate as LCLK
	signal clk_i                  : STD_ULOGIC;
	signal clk_n_i                : STD_ULOGIC;
	-- RESET for all clk_i logic
	signal rst_i                  : STD_ULOGIC;
	signal L_RST                  : STD_ULOGIC;



-------------------------------------------------------------
-- P2L DataPath (from deserializer to packet decoder)
-------------------------------------------------------------
	signal des_pd_valid           : STD_ULOGIC;
	signal des_pd_dframe          : STD_ULOGIC;
	signal des_pd_data            : STD_ULOGIC_VECTOR(31 downto 0);

-------------------------------------------------------------
-- P2L DataPath (from packet decoder to Wishbone master and P2L DMA master)
-------------------------------------------------------------

	signal IP2L_HDR_START  : STD_ULOGIC;                     -- Indicates Header start cycle 
	signal IP2L_HDR_LENGTH : STD_ULOGIC_VECTOR(9 downto 0);  -- Latched LENGTH value from header
	signal IP2L_HDR_CID    : STD_ULOGIC_VECTOR(1 downto 0);  -- Completion ID
	signal IP2L_HDR_LAST   : STD_ULOGIC;                     -- Indicates Last packet in a completion
	signal IP2L_HDR_STAT   : STD_ULOGIC_VECTOR(1 downto 0);  -- Completion Status
	signal IP2L_TARGET_MRD : STD_ULOGIC;
	signal IP2L_TARGET_MWR : STD_ULOGIC;
	signal IP2L_MASTER_CPLD : STD_ULOGIC;
	signal IP2L_MASTER_CPLN : STD_ULOGIC;

	signal IP2L_D_VALID    : STD_ULOGIC;                     -- Indicates Address/Data is valid
	signal IP2L_D_LAST     : STD_ULOGIC;                     -- Indicates end of the packet
	signal IP2L_D          : STD_ULOGIC_VECTOR(31 downto 0); -- Address/Data
	signal IP2L_BE         : STD_ULOGIC_VECTOR( 3 downto 0); -- Byte Enable for data
	signal IP2L_ADDR       : STD_ULOGIC_VECTOR(31 downto 0); -- Registered and counting Address
	signal IP2L_ADDR_START : STD_ULOGIC;
	signal IP2L_EPI_SELECT : STD_ULOGIC;

	signal P_WR_RDYo       : STD_ULOGIC;

-------------------------------------------------------------
-- L2P DataPath (from arbiter to serializer)
-------------------------------------------------------------
	signal arb_ser_valid   : STD_ULOGIC;
	signal arb_ser_dframe  : STD_ULOGIC;
	signal arb_ser_data    : STD_ULOGIC_VECTOR(31 downto 0);

	signal l2p_data_o_o    : STD_ULOGIC_VECTOR(l2p_data_o'range);

	-- Resync bridge controls
	signal Il_wr_rdy_i     : STD_ULOGIC; -- Clocked version of L_WR_RDY from GN412x
	signal Ip_rd_d_rdy_i   : STD_ULOGIC; -- Clocked version of p_rd_d_rdy_i from GN412x
	signal Il2p_rdy_i      : STD_ULOGIC; -- Clocked version of l2p_rdy_i from GN412x

-------------------------------------------------------------
-- Target Controller (Wishbone master)
-------------------------------------------------------------
	signal wbm_arb_valid  : STD_ULOGIC;
	signal wbm_arb_dframe : STD_ULOGIC;
	signal wbm_arb_data   : STD_ULOGIC_VECTOR(31 downto 0);
	signal wbm_arb_req    : STD_ULOGIC;
	signal arb_wbm_gnt    : STD_ULOGIC;

-------------------------------------------------------------
-- DMA controller 
-------------------------------------------------------------

	signal dma_ctrl_carrier_addr   : STD_LOGIC_VECTOR(31 downto 0);
	signal dma_ctrl_host_addr_h    : STD_LOGIC_VECTOR(31 downto 0);
	signal dma_ctrl_host_addr_l    : STD_LOGIC_VECTOR(31 downto 0);
	signal dma_ctrl_len            : STD_LOGIC_VECTOR(31 downto 0);
	signal dma_ctrl_start_l2p      : STD_LOGIC;                       -- To the L2P DMA master
	signal dma_ctrl_start_p2l      : STD_LOGIC;                       -- To the P2L DMA master
	signal dma_ctrl_start_next     : STD_LOGIC;                       -- To the P2L DMA master

	signal dma_ctrl_done           : STD_LOGIC;   
	signal dma_ctrl_error          : STD_LOGIC;    
  signal dma_ctrl_l2p_done       : STD_LOGIC;   
	signal dma_ctrl_l2p_error      : STD_LOGIC;     
  signal dma_ctrl_p2l_done       : STD_LOGIC;   
	signal dma_ctrl_p2l_error      : STD_LOGIC;       

	signal next_item_carrier_addr  : STD_LOGIC_VECTOR(31 downto 0);
	signal next_item_host_addr_h   : STD_LOGIC_VECTOR(31 downto 0);
	signal next_item_host_addr_l   : STD_LOGIC_VECTOR(31 downto 0);
	signal next_item_len           : STD_LOGIC_VECTOR(31 downto 0);
	signal next_item_next_l        : STD_LOGIC_VECTOR(31 downto 0);
	signal next_item_next_h        : STD_LOGIC_VECTOR(31 downto 0);   
	signal next_item_attrib        : STD_LOGIC_VECTOR(31 downto 0);
	signal next_item_valid         : STD_LOGIC;      

	signal wb_adr                  : STD_LOGIC_VECTOR(31 downto 0);             -- Adress
	signal wb_dat_s2m              : STD_LOGIC_VECTOR(31 downto 0);            -- Data in
	signal wb_dat_m2s              : STD_LOGIC_VECTOR(31 downto 0);            -- Data out
	signal wb_sel                  : STD_LOGIC_VECTOR(3 downto 0);             -- Byte select
	signal wb_cyc                  : STD_LOGIC;                                -- Read or write cycle
	signal wb_stb                  : STD_LOGIC;                                -- Read or write strobe
	signal wb_we                   : STD_LOGIC;                                -- Write
	signal wb_ack                  : STD_LOGIC;                                -- Acknowledge
  signal wb_stall                : STD_LOGIC;                                -- Pipelined mode
	signal wb_ack_dma_ctrl         : STD_LOGIC;                                --
  signal wb_stall_dma_ctrl       : STD_LOGIC;                                --
	signal wb_dat_s2m_dma_ctrl     : STD_LOGIC_VECTOR(31 downto 0);            --

	signal dma_adr                  : STD_LOGIC_VECTOR(31 downto 0);             -- Adress
	signal dma_dat_s2m              : STD_LOGIC_VECTOR(31 downto 0);            -- Data in
	signal dma_dat_m2s              : STD_LOGIC_VECTOR(31 downto 0);            -- Data out
	signal dma_sel                  : STD_LOGIC_VECTOR(3 downto 0);             -- Byte select
	signal dma_cyc                  : STD_LOGIC;                                -- Read or write cycle
	signal dma_stb                  : STD_LOGIC;                                -- Read or write strobe
	signal dma_we                   : STD_LOGIC;                                -- Write
	signal dma_ack                  : STD_LOGIC;                                -- Acknowledge
	signal dma_stall                : STD_LOGIC;                                -- Acknowledge
		--
		---------------------------------------------------------

-------------------------------------------------------------
-- L2P DMA master
-------------------------------------------------------------

	signal ldm_arb_req          : STD_ULOGIC; -- Request use of the L2P bus
	signal arb_ldm_gnt          : STD_ULOGIC; -- L2P bus emits data on behalf of the L2P DMA
	signal ldm_arb_valid        : STD_ULOGIC;
	signal ldm_arb_dframe       : STD_ULOGIC;
	signal ldm_arb_data         : STD_ULOGIC_VECTOR(31 downto 0);

--	signal IL2P_DMA_RDY          : STD_ULOGIC; -- Clocked version of l2p_rdy_i from GN412x

-------------------------------------------------------------
-- P2L DMA master
-------------------------------------------------------------
	signal pdm_arb_valid  : STD_ULOGIC;
	signal pdm_arb_dframe : STD_ULOGIC;
	signal pdm_arb_data   : STD_ULOGIC_VECTOR(31 downto 0);
	signal pdm_arb_req    : STD_ULOGIC;
	signal arb_pdm_gnt    : STD_ULOGIC;

--==============================================================================
-- Architecture begin (gn4124_core)
--==============================================================================
begin

--=============================================================================================--
--=============================================================================================--
--== CLOCKING/RESET
--=============================================================================================--
--=============================================================================================--

	L_RST <= not sys_rst_i;


--=============================================================================================--
--=============================================================================================--
--== P2L DataPath
--=============================================================================================--
--=============================================================================================--

-----------------------------------------------------------------------------
-- P2L_DES: Deserialize the P2L DDR Inputs
-----------------------------------------------------------------------------
U_P2L_DES: P2L_DES
	port map
	( 
		---------------------------------------------------------
		-- Raw unprocessed reset from the GN412x
		--
		L_RST           => L_RST,
		---------------------------------------------------------
		-- P2L Clock Domain
		--
		-- P2L Inputs
		P2L_CLKp        => p2l_clk_p_i,
		P2L_CLKn        => p2l_clk_n_i,
    P2L_VALID       => p2l_valid_i,
		P2L_DFRAME      => p2l_dframe_i,
		P2L_DATA        => To_StdULogicVector(p2l_data_i),
		--
		---------------------------------------------------------
		---------------------------------------------------------
		-- clk_i Clock Domain
		--
		IRST            => rst_i,
		-- Core Logic Clock
		ICLK            => clk_i,
		ICLKn           => clk_n_i,
		-- DeSerialized Output
		ICLK_VALID      => des_pd_valid,
		ICLK_DFRAME     => des_pd_dframe,
		ICLK_DATA       => des_pd_data
		--
		---------------------------------------------------------
	);

-----------------------------------------------------------------------------
-- P2L_DECODE32: Decode the output of the P2L_DES
-----------------------------------------------------------------------------
U_P2L_DECODE32: P2L_DECODE32
	port map
	( 
		---------------------------------------------------------
		---------------------------------------------------------
		-- Clock/Reset
		--
		CLK              => clk_i,
		RST              => rst_i,
		---------------------------------------------------------
		-- Input from the Deserializer
		--
		DES_P2L_VALIDi   => des_pd_valid,
		DES_P2L_DFRAMEi  => des_pd_dframe,
		DES_P2L_DATAi    => des_pd_data,
		--
		---------------------------------------------------------
		---------------------------------------------------------
		-- Decoder Outputs
		--
		-- Header
		IP2L_HDR_STARTo  => IP2L_HDR_START,
		IP2L_HDR_LENGTHo => IP2L_HDR_LENGTH,
		IP2L_HDR_CIDo    => IP2L_HDR_CID,
		IP2L_HDR_LASTo   => IP2L_HDR_LAST,
		IP2L_HDR_STATo   => IP2L_HDR_STAT,
		IP2L_TARGET_MRDo  => IP2L_TARGET_MRD,
		IP2L_TARGET_MWRo  => IP2L_TARGET_MWR,
		IP2L_MASTER_CPLDo => IP2L_MASTER_CPLD,
		IP2L_MASTER_CPLNo => IP2L_MASTER_CPLN,
		--
		-- Address
		IP2L_ADDR_STARTo => IP2L_ADDR_START,
		IP2L_ADDRo       => IP2L_ADDR,
		--
		-- Data
		IP2L_D_VALIDo    => IP2L_D_VALID,
		IP2L_D_LASTo     => IP2L_D_LAST,
		IP2L_Do          => IP2L_D,
		IP2L_BEo         => IP2L_BE
		--
		---------------------------------------------------------
	);


-----------------------------------------------------------------------------
-- Resync some GN412x Signals
-----------------------------------------------------------------------------
	process (clk_i, rst_i)
	begin  
		if(rst_i = '1') then
			Il_wr_rdy_i     <= '0';
			Ip_rd_d_rdy_i      <= '0';
			Il2p_rdy_i         <= '0';
		elsif(clk_i'event and clk_i = '1') then
			Il_wr_rdy_i     <= l_wr_rdy_i(0);
			Ip_rd_d_rdy_i      <= p_rd_d_rdy_i(0);
			Il2p_rdy_i         <= l2p_rdy_i;
		end if;
	end process;


--=============================================================================================--
--=============================================================================================--
--== Core Logic Blocks
--=============================================================================================--
--=============================================================================================--

-----------------------------------------------------------------------------
-- Wishbone master
-----------------------------------------------------------------------------
u_wbmaster32: wbmaster32
	generic map
	(
		WBM_TIMEOUT    => 5
	)
	port map
	( 
		---------------------------------------------------------
		---------------------------------------------------------
		-- Clock/Reset
		--
		sys_clk_i             => clk_i,
		sys_rst_i             => rst_i,
		
    gn4124_clk_i             => clk_i,
		---------------------------------------------------------
		---------------------------------------------------------
		-- From P2L Decoder
		--
		-- Header
		pd_wbm_hdr_start_i  => IP2L_HDR_START,
		pd_wbm_hdr_length_i => IP2L_HDR_LENGTH,
		pd_wbm_hdr_cid_i    => IP2L_HDR_CID,
		pd_wbm_target_mrd_i => IP2L_TARGET_MRD,
		pd_wbm_target_mwr_i => IP2L_TARGET_MWR,
		--
		-- Address
		pd_wbm_addr_start_i => IP2L_ADDR_START,
		pd_wbm_addr_i       => IP2L_ADDR,
		pd_wbm_wbm_addr_i   => IP2L_EPI_SELECT,
		--
		-- Data
		pd_wbm_data_valid_i    => IP2L_D_VALID,
		pd_wbm_data_last_i     => IP2L_D_LAST,
		pd_wbm_data_i          => IP2L_D,
		pd_wbm_be_i         => IP2L_BE,
		--
		---------------------------------------------------------
		-- P2L Control
		--
		p_wr_rdy_o        => P_WR_RDYo,
		---------------------------------------------------------
		---------------------------------------------------------
		-- To the L2P Interface
		--
		wbm_arb_valid_o  => wbm_arb_valid,
		wbm_arb_dframe_o => wbm_arb_dframe,
		wbm_arb_data_o   => wbm_arb_data,
		wbm_arb_req_o    => wbm_arb_req,
		arb_wbm_gnt_i    => arb_wbm_gnt,
		--
		---------------------------------------------------------
		---------------------------------------------------------
		-- Wishbone Interface
		--
    wb_adr_o         => wb_adr,
    wb_dat_i         => wb_dat_s2m,
    wb_dat_o         => wb_dat_m2s,
    wb_sel_o         => wb_sel,
    wb_cyc_o         => wb_cyc,
    wb_stb_o         => wb_stb,
    wb_we_o          => wb_we,
    wb_ack_i         => wb_ack,
    wb_stall_i       => wb_stall
		--
		---------------------------------------------------------
	);

    wb_adr_o         <= wb_adr;
    wb_dat_s2m       <= wb_dat_i or wb_dat_s2m_dma_ctrl;
    wb_dat_o         <= wb_dat_m2s;
    wb_sel_o         <= wb_sel;
    wb_cyc_o         <= wb_cyc;
    wb_stb_o         <= wb_stb;
    wb_we_o          <= wb_we;
    wb_ack           <= wb_ack_i or wb_ack_dma_ctrl;
    wb_stall         <= wb_stall_i or wb_stall_dma_ctrl;
    

    wb_stall_dma_ctrl <= wb_stb and not wb_ack;

	IP2L_EPI_SELECT <= not IP2L_ADDR(0);

-----------------------------------------------------------------------------
u_dma_controller: dma_controller
-----------------------------------------------------------------------------
  port map
	( 
    LED => LED,
		clk_i                     => clk_i,
		rst_i                     => rst_i, 

		dma_ctrl_carrier_addr_o   => dma_ctrl_carrier_addr,
    dma_ctrl_host_addr_h_o    => dma_ctrl_host_addr_h,
    dma_ctrl_host_addr_l_o    => dma_ctrl_host_addr_l,
    dma_ctrl_len_o            => dma_ctrl_len,
    dma_ctrl_start_l2p_o      => dma_ctrl_start_l2p,
    dma_ctrl_start_p2l_o      => dma_ctrl_start_p2l,
    dma_ctrl_start_next_o     => dma_ctrl_start_next,
    dma_ctrl_done_i           => dma_ctrl_done,
    dma_ctrl_error_i          => dma_ctrl_error,

		next_item_carrier_addr_i  => next_item_carrier_addr,
		next_item_host_addr_h_i   => next_item_host_addr_h,
		next_item_host_addr_l_i   => next_item_host_addr_l,
		next_item_len_i           => next_item_len,
		next_item_next_l_i        => next_item_next_l,
		next_item_next_h_i        => next_item_next_h,
		next_item_attrib_i        => next_item_attrib,
		next_item_valid_i         => next_item_valid,

    wb_adr_i                  => wb_adr(5 downto 2),
    wb_dat_o                  => wb_dat_s2m_dma_ctrl,
    wb_dat_i                  => wb_dat_m2s,
    wb_sel_i                  => wb_sel,
    wb_cyc_i                  => wb_cyc,
    wb_stb_i                  => wb_stb,
    wb_we_i                   => wb_we,
    wb_ack_o                  => wb_ack_dma_ctrl
		--
		---------------------------------------------------------
	);



dma_ctrl_done <= dma_ctrl_l2p_done or dma_ctrl_p2l_done;
dma_ctrl_error <= dma_ctrl_l2p_error or dma_ctrl_p2l_error;
-----------------------------------------------------------------------------
u_l2p_dma_master: l2p_dma_master
-----------------------------------------------------------------------------
  port map
  ( 
		clk_i                     => clk_i,
		rst_i                     => rst_i,

    dma_ctrl_carrier_addr_i   => dma_ctrl_carrier_addr,
    dma_ctrl_host_addr_h_i    => dma_ctrl_host_addr_h,
    dma_ctrl_host_addr_l_i    => dma_ctrl_host_addr_l,
    dma_ctrl_len_i            => dma_ctrl_len,
    dma_ctrl_start_l2p_i      => dma_ctrl_start_l2p,
    dma_ctrl_done_o           => dma_ctrl_l2p_done,
    dma_ctrl_error_o          => dma_ctrl_l2p_error,

		ldm_arb_valid_o           => ldm_arb_valid,
		ldm_arb_dframe_o          => ldm_arb_dframe,
		ldm_arb_data_o            => ldm_arb_data,
		ldm_arb_req_o             => ldm_arb_req,
		arb_ldm_gnt_i             => arb_ldm_gnt,

    l2p_dma_adr_o             => dma_adr,
    l2p_dma_dat_i             => dma_dat_s2m,
    l2p_dma_dat_o             => dma_dat_m2s,
    l2p_dma_sel_o             => dma_sel,
    l2p_dma_cyc_o             => dma_cyc,
    l2p_dma_stb_o             => dma_stb,
    l2p_dma_we_o              => dma_we,
    l2p_dma_ack_i             => dma_ack,
    l2p_dma_stall_i           => dma_stall
		--
		---------------------------------------------------------
	);

    dma_adr_o         <= dma_adr;
    dma_dat_s2m       <= dma_dat_i;
    dma_dat_o         <= dma_dat_m2s;
    dma_sel_o         <= dma_sel;
    dma_cyc_o         <= dma_cyc;
    dma_stb_o         <= dma_stb;
    dma_we_o          <= dma_we;
    dma_ack           <= dma_ack_i;
    dma_stall         <= dma_stall_i;

dma_ctrl_p2l_done <= '0';
dma_ctrl_p2l_error <= '0';


-----------------------------------------------------------------------------
-- Top Level LB Controls
-----------------------------------------------------------------------------

	p_wr_rdy_o <= P_WR_RDYo & P_WR_RDYo;
	rx_error_o <= '0';
	l2p_edb_o  <= '0';
	p2l_rdy_o  <= not rst_i;


--	ldm_arb_valid  <= '0';
--	ldm_arb_dframe <= '0';
--	ldm_arb_data   <= (others => '0');
--	ldm_arb_req    <= '0';


-----------------------------------------------------------------------------
-- P2L DMA
-----------------------------------------------------------------------------
	pdm_arb_valid  <= '0';
	pdm_arb_dframe <= '0';
	pdm_arb_data   <= (others => '0');
	pdm_arb_req    <= '0';



--=============================================================================================--
--=============================================================================================--
--== L2P DataPath
--=============================================================================================--
--=============================================================================================--

--	arb_wbm_gnt <= '1';

--	arb_ser_valid   <= wbm_arb_valid;

--	arb_ser_dframe  <= wbm_arb_dframe;

--	arb_ser_data    <= wbm_arb_data;

-----------------------------------------------------------------------------
-- ARBITER: Arbitrate between Wishbone master, DMA master and DMA pdmuencer
-----------------------------------------------------------------------------
u_arbiter: arbiter
	port map
	( 
		---------------------------------------------------------
		---------------------------------------------------------
		-- Clock/Reset
		--
		clk_i             => clk_i,
		rst_i             => rst_i,
		---------------------------------------------------------
		---------------------------------------------------------
		-- From Wishbone master (wbm) to arbiter (arb)
		--
		wbm_arb_valid_i  => wbm_arb_valid,
		wbm_arb_dframe_i => wbm_arb_dframe,
		wbm_arb_data_i   => wbm_arb_data,
		wbm_arb_req_i    => wbm_arb_req,
		arb_wbm_gnt_o    => arb_wbm_gnt,
		--
		---------------------------------------------------------
		---------------------------------------------------------
		-- From DMA controller (pdm) to arbiter (arb)
		--
		pdm_arb_valid_i  => pdm_arb_valid,
		pdm_arb_dframe_i => pdm_arb_dframe,
		pdm_arb_data_i   => pdm_arb_data,
		pdm_arb_req_i    => pdm_arb_req,
		arb_pdm_gnt_o    => arb_pdm_gnt,
		--
		---------------------------------------------------------
		---------------------------------------------------------
		-- From P2L DMA master (pdm) to arbiter (arb)
		--
		ldm_arb_valid_i  => ldm_arb_valid,
		ldm_arb_dframe_i => ldm_arb_dframe,
		ldm_arb_data_i   => ldm_arb_data,
		ldm_arb_req_i    => ldm_arb_req,
		arb_ldm_gnt_o    => arb_ldm_gnt,
		--
		---------------------------------------------------------

		---------------------------------------------------------
		-- From arbiter (arb) to serializer (ser)
		--
		arb_ser_valid_o  => arb_ser_valid,
		arb_ser_dframe_o => arb_ser_dframe,
		arb_ser_data_o   => arb_ser_data
		--
		---------------------------------------------------------
	);



-----------------------------------------------------------------------------
-- L2P_SER: Generate the L2P DDR Outputs
-----------------------------------------------------------------------------
U_L2P_SER: L2P_SER
	port map
	( 
		---------------------------------------------------------
		---------------------------------------------------------
		-- clk_i Clock Domain Inputs
		--
		ICLKp          => clk_i,
		ICLKn          => clk_n_i,
		IRST           => rst_i,
		-- DeSerialized Output
		ICLK_VALID     => arb_ser_valid,
		ICLK_DFRAME    => arb_ser_dframe,
		ICLK_DATA      => arb_ser_data,
		--
		---------------------------------------------------------
		-- SER Outputs
		--
		-- P2L Inputs
		L2P_CLKp       => l2p_clk_p_o,
		L2P_CLKn       => l2p_clk_n_o,
		L2P_VALID      => l2p_valid_o,
		L2P_DFRAME     => l2p_dframe_o,
		L2P_DATA       => l2p_data_o_o
		--
		---------------------------------------------------------
	);

	l2p_data_o <= To_StdLogicVector(l2p_data_o_o);




end BEHAVIOUR;
--==============================================================================
-- Architecture end (gn4124_core)
--==============================================================================

