--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: DMA controller (dma_controller.vhd)
--
-- author: Simon Deprez (simon.deprez@cern.ch)
--
-- date: 24-06-2010
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

entity dma_controller is
  port
  ( 
    DEBUG                : out    std_logic_vector(3 downto 0);
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
end dma_controller;

architecture behaviour of dma_controller is

component dma_controller_wb_slave is
  port (
    rst_n_i                                  : in     std_logic;
    wb_clk_i                                 : in     std_logic;
    wb_addr_i                                : in     std_logic_vector(3 downto 0);
    wb_data_i                                : in     std_logic_vector(31 downto 0);
    wb_data_o                                : out    std_logic_vector(31 downto 0);
    wb_cyc_i                                 : in     std_logic;
    wb_sel_i                                 : in     std_logic_vector(3 downto 0);
    wb_stb_i                                 : in     std_logic;
    wb_we_i                                  : in     std_logic;
    wb_ack_o                                 : out    std_logic;
-- Port for std_logic_vector field: 'DMA engine control' in reg: 'DMACTRLR'
    dma_ctrl_o                               : out    std_logic_vector(31 downto 0);
    dma_ctrl_i                               : in     std_logic_vector(31 downto 0);
    dma_ctrl_load_o                          : out    std_logic;
-- Port for std_logic_vector field: 'DMA engine status' in reg: 'DMASTATR'
    dma_stat_o                               : out    std_logic_vector(31 downto 0);
    dma_stat_i                               : in     std_logic_vector(31 downto 0);
    dma_stat_load_o                          : out    std_logic;
-- Port for std_logic_vector field: 'DMA start address in the carrier' in reg: 'DMACSTARTR'
    dma_cstart_o                             : out    std_logic_vector(31 downto 0);
    dma_cstart_i                             : in     std_logic_vector(31 downto 0);
    dma_cstart_load_o                        : out    std_logic;
-- Port for std_logic_vector field: 'DMA start address (low) in the host' in reg: 'DMAHSTARTLR'
    dma_hstartl_o                            : out    std_logic_vector(31 downto 0);
    dma_hstartl_i                            : in     std_logic_vector(31 downto 0);
    dma_hstartl_load_o                       : out    std_logic;
-- Port for std_logic_vector field: 'DMA start address (high) in the host' in reg: 'DMAHSTARTHR'
    dma_hstarth_o                            : out    std_logic_vector(31 downto 0);
    dma_hstarth_i                            : in     std_logic_vector(31 downto 0);
    dma_hstarth_load_o                       : out    std_logic;
-- Port for std_logic_vector field: 'DMA read length in bytes' in reg: 'DMALENR'
    dma_len_o                                : out    std_logic_vector(31 downto 0);
    dma_len_i                                : in     std_logic_vector(31 downto 0);
    dma_len_load_o                           : out    std_logic;
-- Port for std_logic_vector field: 'Pointer (low) to next item in list' in reg: 'DMANEXTLR'
    dma_nextl_o                              : out    std_logic_vector(31 downto 0);
    dma_nextl_i                              : in     std_logic_vector(31 downto 0);
    dma_nextl_load_o                         : out    std_logic;
-- Port for std_logic_vector field: 'Pointer (high) to next item in list' in reg: 'DMANEXTHR'
    dma_nexth_o                              : out    std_logic_vector(31 downto 0);
    dma_nexth_i                              : in     std_logic_vector(31 downto 0);
    dma_nexth_load_o                         : out    std_logic;
-- Port for std_logic_vector field: 'DMA chain control' in reg: 'DMAATTRIBR'
    dma_attrib_o                             : out    std_logic_vector(31 downto 0);
    dma_attrib_i                             : in     std_logic_vector(31 downto 0);
    dma_attrib_load_o                        : out    std_logic
  );
end component dma_controller_wb_slave;

  signal   dma_reset              : std_logic;
  signal   dma_reset_n            : std_logic;

  signal   dma_ctrl               : std_logic_vector(31 downto 0);
  signal   dma_stat               : std_logic_vector(31 downto 0);
  signal   dma_cstart             : std_logic_vector(31 downto 0);
  signal   dma_hstartl            : std_logic_vector(31 downto 0);
  signal   dma_hstarth            : std_logic_vector(31 downto 0);
  signal   dma_len                : std_logic_vector(31 downto 0);
  signal   dma_nextl              : std_logic_vector(31 downto 0);
  signal   dma_nexth              : std_logic_vector(31 downto 0);
  signal   dma_attrib             : std_logic_vector(31 downto 0);

  signal   dma_ctrl_load          : std_logic;
  signal   dma_stat_load          : std_logic;
  signal   dma_cstart_load        : std_logic;
  signal   dma_hstartl_load       : std_logic;
  signal   dma_hstarth_load       : std_logic;
  signal   dma_len_load           : std_logic;
  signal   dma_nextl_load         : std_logic;
  signal   dma_nexth_load         : std_logic;
  signal   dma_attrib_load        : std_logic;

  signal   dma_ctrl_reg           : std_logic_vector(31 downto 0);
  signal   dma_stat_reg           : std_logic_vector(31 downto 0);
  signal   dma_cstart_reg         : std_logic_vector(31 downto 0);
  signal   dma_hstartl_reg        : std_logic_vector(31 downto 0);
  signal   dma_hstarth_reg        : std_logic_vector(31 downto 0);
  signal   dma_len_reg            : std_logic_vector(31 downto 0);
  signal   dma_nextl_reg          : std_logic_vector(31 downto 0);
  signal   dma_nexth_reg          : std_logic_vector(31 downto 0);
  signal   dma_attrib_reg         : std_logic_vector(31 downto 0);


    
begin
  DEBUG(1 downto 0) <= dma_ctrl_reg(1 downto 0);
  DEBUG(3 downto 2) <= dma_stat_reg(1 downto 0);
  dma_reset <= rst_i;
  dma_reset_n <= not dma_reset;

  dma_controller_wb_slave_0 : dma_controller_wb_slave  port map (
    rst_n_i            => dma_reset_n,
    wb_clk_i           => clk_i,
    wb_addr_i          => wb_adr_i,
    wb_data_i          => wb_dat_i,
    wb_data_o          => wb_dat_o,
    wb_cyc_i           => wb_cyc_i,
    wb_sel_i           => wb_sel_i,
    wb_stb_i           => wb_stb_i,
    wb_we_i            => wb_we_i,
    wb_ack_o           => wb_ack_o,
    dma_ctrl_o         => dma_ctrl,
    dma_ctrl_i         => dma_ctrl_reg,
    dma_ctrl_load_o    => dma_ctrl_load,
    dma_stat_o         => dma_stat,
    dma_stat_i         => dma_stat_reg,
    dma_stat_load_o    => dma_stat_load,
    dma_cstart_o       => dma_cstart,
    dma_cstart_i       => dma_cstart_reg,
    dma_cstart_load_o  => dma_cstart_load,
    dma_hstartl_o      => dma_hstartl,
    dma_hstartl_i      => dma_hstartl_reg,
    dma_hstartl_load_o => dma_hstartl_load,
    dma_hstarth_o      => dma_hstarth,
    dma_hstarth_i      => dma_hstarth_reg,
    dma_hstarth_load_o => dma_hstarth_load,
    dma_len_o          => dma_len,
    dma_len_i          => dma_len_reg,
    dma_len_load_o     => dma_len_load,
    dma_nextl_o        => dma_nextl,
    dma_nextl_i        => dma_nextl_reg,
    dma_nextl_load_o   => dma_nextl_load,
    dma_nexth_o        => dma_nexth,
    dma_nexth_i        => dma_nexth_reg,
    dma_nexth_load_o   => dma_nexth_load,
    dma_attrib_o       => dma_attrib,
    dma_attrib_i       => dma_attrib_reg,
    dma_attrib_load_o  => dma_attrib_load
  );

  process (clk_i, rst_i)
  begin
    if (rst_i = '1') then                        
      dma_ctrl_reg     <= x"00000000";
      dma_stat_reg     <= x"00000000";
      dma_cstart_reg   <= x"00000000";
      dma_hstartl_reg  <= x"00000000";
      dma_hstarth_reg  <= x"00000000";
      dma_len_reg      <= x"00000000";
      dma_nextl_reg    <= x"00000000";
      dma_nexth_reg    <= x"00000000";
      dma_attrib_reg   <= x"00000000";
    elsif rising_edge(clk_i) then                
      if (dma_ctrl_load = '1') then 
        dma_ctrl_reg <= dma_ctrl;
      end if;
      if (dma_stat_load = '1') then          
        dma_stat_reg <= dma_stat;
      end if;
      if (dma_cstart_load = '1') then 
        dma_cstart_reg <= dma_cstart;
      end if;
      if (dma_hstartl_load = '1') then 
        dma_hstartl_reg <= dma_hstartl;
      end if;
      if (dma_hstarth_load = '1') then 
        dma_hstarth_reg <= dma_hstarth;
      end if;
      if (dma_len_load = '1') then 
        dma_len_reg <= dma_len;
      end if;
      if (dma_nextl_load = '1') then 
        dma_nextl_reg <= dma_nextl;
      end if;
      if (dma_nexth_load = '1') then 
        dma_nexth_reg <= dma_nexth;
      end if;
      if (dma_attrib_load = '1') then 
        dma_attrib_reg <= dma_attrib;
      end if;
      if (next_item_valid_i = '1') then 
        dma_ctrl_reg(0) <= '1';                  -- Start a new transfer
        dma_cstart_reg <= next_item_carrier_addr_i;
        dma_hstartl_reg <= next_item_host_addr_l_i;
        dma_hstarth_reg <= next_item_host_addr_h_i;
        dma_len_reg <= next_item_len_i;
        dma_nextl_reg <= next_item_next_l_i;
        dma_nexth_reg <= next_item_next_h_i;
        dma_attrib_reg <= next_item_attrib_i;
      end if;
      if (dma_ctrl_reg(0) = '1') then 
        dma_ctrl_reg(0) <= '0';                  -- Only one transfer
      end if;
    end if;
  end process;

  dma_ctrl_carrier_addr_o  <= dma_cstart_reg;
  dma_ctrl_host_addr_h_o   <= dma_hstarth_reg;
  dma_ctrl_host_addr_l_o   <= dma_hstartl_reg;
  dma_ctrl_len_o           <= dma_len_reg;
  dma_ctrl_start_l2p_o     <= dma_ctrl_reg(0); 
  dma_ctrl_start_p2l_o     <= '0';
  dma_ctrl_start_next_o    <= '0';

end behaviour;

