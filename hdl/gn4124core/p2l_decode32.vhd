--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: P2L_DECODE32 (p2l_decode32.vhd)
--
-- author:
--
-- date:
--
-- version: 0.0
--
-- description: P2L Packet Decoder - For 32 Bit Data Path Design
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
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.gn4124_core_pkg.all;


entity p2l_decode32 is
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
end p2l_decode32;

architecture rtl of p2l_decode32 is

-----------------------------------------------------------------------------
-- to_mvl Function
-----------------------------------------------------------------------------
  function f_to_mvl (b : in boolean) return std_logic is
  begin
    if (b = true) then
      return('1');
    else
      return('0');
    end if;
  end f_to_mvl;

-----------------------------------------------------------------------------
-- Internal Signals
-----------------------------------------------------------------------------
  signal des_p2l_valid_d  : std_logic;
  signal des_p2l_dframe_d : std_logic;

  signal p2l_hdr_start  : std_logic;                     -- Indicates Header start cycle
  signal p2l_hdr_length : std_logic_vector(9 downto 0);  -- Latched LENGTH value from header
  signal p2l_hdr_cid    : std_logic_vector(1 downto 0);  -- Completion ID
  signal p2l_hdr_last   : std_logic;                     -- Indicates Last packet in a completion
  signal p2l_hdr_stat   : std_logic_vector(1 downto 0);  -- Completion Status

  signal p2l_addr_start : std_logic;
  signal p2l_addr       : unsigned(31 downto 0);  -- Registered and counting Address

  signal p2l_d_valid : std_logic;                      -- Indicates Address/Data is valid
  signal p2l_d_last  : std_logic;                      -- Indicates end of the packet
  signal p2l_d       : std_logic_vector(31 downto 0);  -- Address/Data
  signal p2l_be      : std_logic_vector(3 downto 0);   -- Byte Enable for data

  signal p2l_hdr_fbe : std_logic_vector(3 downto 0);  -- First Byte Enable
  signal p2l_hdr_lbe : std_logic_vector(3 downto 0);  -- Last Byte Enable

--  signal CYCLE             : STD_ULOGIC;    -- Indicates Address/Data Cycle
  signal dcycle : std_logic;            -- Indicates Data Cycle
  signal acycle : std_logic;            -- Indicates Address Cycle

  signal target_mrd  : std_logic;
  signal target_mwr  : std_logic;
  signal master_cpld : std_logic;
  signal master_cpln : std_logic;


begin

--=============================================================================================--
--=============================================================================================--
--== DECODER LOGIC
--=============================================================================================--
--=============================================================================================--

-----------------------------------------------------------------------------
-- 1 tick delay version of des_p2l_valid_i and des_p2l_dframe_i
-----------------------------------------------------------------------------
  process (clk_i, rst_n_i)
  begin
    if rst_n_i = c_RST_ACTIVE then
      des_p2l_dframe_d <= '0';
      des_p2l_valid_d  <= '0';
    elsif rising_edge(clk_i) then
      des_p2l_dframe_d <= des_p2l_dframe_i;
      des_p2l_valid_d  <= des_p2l_valid_i;
    end if;
  end process;


-----------------------------------------------------------------------------
-- Decode all cycle types
-----------------------------------------------------------------------------
  process (clk_i, rst_n_i)
  begin
    if rst_n_i = c_RST_ACTIVE then
      target_mrd  <= '0';
      target_mwr  <= '0';
      master_cpld <= '0';
      master_cpln <= '0';
    elsif rising_edge(clk_i) then
      if((des_p2l_dframe_i and not des_p2l_dframe_d and des_p2l_valid_i) = '1') then
        target_mrd  <= f_to_mvl(des_p2l_data_i(27 downto 24) = "0000");
        target_mwr  <= f_to_mvl(des_p2l_data_i(27 downto 24) = "0010");
        master_cpld <= f_to_mvl(des_p2l_data_i(27 downto 24) = "0101");
        master_cpln <= f_to_mvl(des_p2l_data_i(27 downto 24) = "0100");
      elsif((des_p2l_valid_d and not des_p2l_dframe_d) = '1') then
        target_mrd  <= '0';
        target_mwr  <= '0';
        master_cpld <= '0';
        master_cpln <= '0';
      end if;
    end if;
  end process;


-----------------------------------------------------------------------------
-- p2l_hdr_start: Indicates Header start cycle
-----------------------------------------------------------------------------
  process (clk_i, rst_n_i)
  begin
    if rst_n_i = c_RST_ACTIVE then
      p2l_hdr_start  <= '0';
      p2l_hdr_length <= (others => '0');
      p2l_hdr_cid    <= (others => '0');
      p2l_hdr_last   <= '0';
      p2l_hdr_stat   <= (others => '0');
      p2l_hdr_fbe    <= (others => '0');
      p2l_hdr_lbe    <= (others => '0');
    elsif rising_edge(clk_i) then
      if((des_p2l_valid_i and des_p2l_dframe_i and not des_p2l_dframe_d) = '1') then
        p2l_hdr_start  <= '1';
        p2l_hdr_length <= des_p2l_data_i(9 downto 0);
        p2l_hdr_cid    <= des_p2l_data_i(11 downto 10);
        p2l_hdr_last   <= des_p2l_data_i(15);
        p2l_hdr_stat   <= des_p2l_data_i(17 downto 16);
        p2l_hdr_fbe    <= des_p2l_data_i(19 downto 16);  -- First Byte Enable
        p2l_hdr_lbe    <= des_p2l_data_i(23 downto 20);  -- Last Byte Enable
      else
        p2l_hdr_start <= '0';
      end if;
    end if;
  end process;


-----------------------------------------------------------------------------
-- CYCLE: indicates a cycle is in progress
-----------------------------------------------------------------------------
  process (clk_i, rst_n_i)
  begin
    if rst_n_i = c_RST_ACTIVE then
--      CYCLE  <= '0';
      acycle <= '0';
      dcycle <= '0';
    elsif rising_edge(clk_i) then

      if(acycle = '0') then
        acycle <= des_p2l_valid_i and des_p2l_dframe_i and not des_p2l_dframe_d;
      else
        acycle <= not des_p2l_valid_i;
      end if;

--      if(CYCLE = '0') then
--        CYCLE <= p2l_hdr_start;
--      else
--        CYCLE <= not(des_p2l_valid_d and not des_p2l_dframe_d);
--      end if;

      if(dcycle = '0') then
        dcycle <= acycle and target_mwr and des_p2l_valid_i;
      else
        dcycle <= not(des_p2l_valid_i and not des_p2l_dframe_i);
      end if;
    end if;
  end process;

-----------------------------------------------------------------------------
-- Address/Data/Byte Enable
-----------------------------------------------------------------------------
  process (clk_i, rst_n_i)
  begin
    if rst_n_i = c_RST_ACTIVE then
      p2l_d_valid    <= '0';
      p2l_d_last     <= '0';
      p2l_d          <= (others => '0');
      p2l_be         <= (others => '0');
      p2l_addr       <= (others => '0');
      p2l_addr_start <= '0';
    elsif rising_edge(clk_i) then

      p2l_d_valid <= dcycle and des_p2l_valid_i;
      p2l_d_last  <= (acycle or dcycle) and des_p2l_valid_i and not des_p2l_dframe_i;

      p2l_addr_start <= acycle and des_p2l_valid_i;

      if((acycle and des_p2l_valid_i) = '1') then
        p2l_addr <= unsigned(des_p2l_data_i);
      elsif(p2l_d_valid = '1') then
        p2l_addr(31 downto 2) <= p2l_addr(31 downto 2) + 1;
      end if;

      if(des_p2l_valid_i = '1') then
        p2l_d <= des_p2l_data_i;
      end if;

      if(((acycle or p2l_addr_start) = '1') or (p2l_hdr_length = "0000000001")) then
        p2l_be <= p2l_hdr_fbe;          -- First Byte Enable
      elsif((dcycle and des_p2l_valid_i and not des_p2l_dframe_i) = '1') then
        p2l_be <= p2l_hdr_lbe;          -- Last Byte Enable
      elsif(p2l_d_valid = '1') then
        p2l_be <= (others => '1');      -- Intermediate Byte Enables
      end if;
    end if;
  end process;


-----------------------------------------------------------------------------
-- Generate the Final Output Data
-----------------------------------------------------------------------------
  p2l_hdr_start_o  <= p2l_hdr_start;
  p2l_hdr_length_o <= p2l_hdr_length;
  p2l_hdr_cid_o    <= p2l_hdr_cid;
  p2l_hdr_last_o   <= p2l_hdr_last;
  p2l_hdr_stat_o   <= p2l_hdr_stat;

  p2l_addr_start_o <= p2l_addr_start;
  p2l_addr_o       <= std_logic_vector(p2l_addr);
  p2l_d_valid_o    <= p2l_d_valid;
  p2l_d_last_o     <= p2l_d_last;
  p2l_d_o          <= p2l_d;
  p2l_be_o         <= p2l_be;

  p2l_target_mrd_o  <= target_mrd;
  p2l_target_mwr_o  <= target_mwr;
  p2l_master_cpld_o <= master_cpld;
  p2l_master_cpln_o <= master_cpln;


end rtl;
