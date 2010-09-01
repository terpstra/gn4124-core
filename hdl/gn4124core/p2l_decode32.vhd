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


entity P2L_DECODE32 is
  port
    (
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- Clock/Reset
      --
      CLK               : in  std_logic;
      RST               : in  std_logic;
      ---------------------------------------------------------
      -- Input from the Deserializer
      --
      DES_P2L_VALIDi    : in  std_logic;
      DES_P2L_DFRAMEi   : in  std_logic;
      DES_P2L_DATAi     : in  std_logic_vector(31 downto 0);
      --
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- Decoder Outputs
      --
      -- Header
      IP2L_HDR_STARTo   : out std_logic;                      -- Indicates Header start cycle
      IP2L_HDR_LENGTHo  : out std_logic_vector(9 downto 0);   -- Latched LENGTH value from header
      IP2L_HDR_CIDo     : out std_logic_vector(1 downto 0);   -- Completion ID
      IP2L_HDR_LASTo    : out std_logic;                      -- Indicates Last packet in a completion
      IP2L_HDR_STATo    : out std_logic_vector(1 downto 0);   -- Completion Status
      IP2L_TARGET_MRDo  : out std_logic;                      -- Target memory read
      IP2L_TARGET_MWRo  : out std_logic;                      -- Target memory write
      IP2L_MASTER_CPLDo : out std_logic;                      -- Master completion with data
      IP2L_MASTER_CPLNo : out std_logic;                      -- Master completion without data
      --
      -- Address
      IP2L_ADDR_STARTo  : out std_logic;                      -- Indicates Address Start
      IP2L_ADDRo        : out std_logic_vector(31 downto 0);  -- Latched Address that will increment with data
      --
      -- Data
      IP2L_D_VALIDo     : out std_logic;                      -- Indicates Data is valid
      IP2L_D_LASTo      : out std_logic;                      -- Indicates end of the packet
      IP2L_Do           : out std_logic_vector(31 downto 0);  -- Data
      IP2L_BEo          : out std_logic_vector(3 downto 0)    -- Byte Enable for data
      --
      ---------------------------------------------------------
      );
end P2L_DECODE32;

architecture BEHAVIOUR of P2L_DECODE32 is

-----------------------------------------------------------------------------
-- to_mvl Function
-----------------------------------------------------------------------------
  function to_mvl (b : in boolean) return std_logic is
  begin
    if (b = true) then
      return('1');
    else
      return('0');
    end if;
  end to_mvl;

-----------------------------------------------------------------------------
-- Internal Signals
-----------------------------------------------------------------------------
  signal Q_DES_P2L_VALIDi  : std_logic;
  signal Q_DES_P2L_DFRAMEi : std_logic;

  signal IP2L_HDR_START  : std_logic;                     -- Indicates Header start cycle
  signal IP2L_HDR_LENGTH : std_logic_vector(9 downto 0);  -- Latched LENGTH value from header
  signal IP2L_HDR_CID    : std_logic_vector(1 downto 0);  -- Completion ID
  signal IP2L_HDR_LAST   : std_logic;                     -- Indicates Last packet in a completion
  signal IP2L_HDR_STAT   : std_logic_vector(1 downto 0);  -- Completion Status

  signal IP2L_ADDR_START : std_logic;
  signal IP2L_ADDR       : unsigned(31 downto 0);  -- Registered and counting Address

  signal IP2L_D_VALID : std_logic;                      -- Indicates Address/Data is valid
  signal IP2L_D_LAST  : std_logic;                      -- Indicates end of the packet
  signal IP2L_D       : std_logic_vector(31 downto 0);  -- Address/Data
  signal IP2L_BE      : std_logic_vector(3 downto 0);   -- Byte Enable for data

  signal IP2L_HDR_FBE : std_logic_vector(3 downto 0);  -- First Byte Enable
  signal IP2L_HDR_LBE : std_logic_vector(3 downto 0);  -- Last Byte Enable


--  signal CYCLE             : STD_ULOGIC;    -- Indicates Address/Data Cycle
  signal DCYCLE : std_logic;            -- Indicates Data Cycle
  signal ACYCLE : std_logic;            -- Indicates Address Cycle

  signal TARGET_MRD  : std_logic;
  signal TARGET_MWR  : std_logic;
  signal MASTER_CPLD : std_logic;
  signal MASTER_CPLN : std_logic;


begin

--=============================================================================================--
--=============================================================================================--
--== DECODER LOGIC
--=============================================================================================--
--=============================================================================================--

-----------------------------------------------------------------------------
-- Q_DES_P2L_VALIDi: Clocked version of DES_P2L_DFRAMEi
-----------------------------------------------------------------------------
  process (CLK, RST)
  begin
    if RST = c_RST_ACTIVE then
      Q_DES_P2L_DFRAMEi <= '0';
      Q_DES_P2L_VALIDi  <= '0';
    elsif rising_edge(CLK) then
      Q_DES_P2L_DFRAMEi <= DES_P2L_DFRAMEi;
      Q_DES_P2L_VALIDi  <= DES_P2L_VALIDi;
    end if;
  end process;


-----------------------------------------------------------------------------
-- Decode all cycle types
-----------------------------------------------------------------------------
  process (CLK, RST)
  begin
    if RST = c_RST_ACTIVE then
      TARGET_MRD  <= '0';
      TARGET_MWR  <= '0';
      MASTER_CPLD <= '0';
      MASTER_CPLN <= '0';
    elsif rising_edge(CLK) then
      if((DES_P2L_DFRAMEi and not Q_DES_P2L_DFRAMEi and DES_P2L_VALIDi) = '1') then
        TARGET_MRD  <= To_MVL(DES_P2L_DATAi(27 downto 24) = "0000");
        TARGET_MWR  <= To_MVL(DES_P2L_DATAi(27 downto 24) = "0010");
        MASTER_CPLD <= To_MVL(DES_P2L_DATAi(27 downto 24) = "0101");
        MASTER_CPLN <= To_MVL(DES_P2L_DATAi(27 downto 24) = "0100");
      elsif((Q_DES_P2L_VALIDi and not Q_DES_P2L_DFRAMEi) = '1') then
        TARGET_MRD  <= '0';
        TARGET_MWR  <= '0';
        MASTER_CPLD <= '0';
        MASTER_CPLN <= '0';
      end if;
    end if;
  end process;


-----------------------------------------------------------------------------
-- IP2L_HDR_START: Indicates Header start cycle
-----------------------------------------------------------------------------
  process (CLK, RST)
  begin
    if RST = c_RST_ACTIVE then
      IP2L_HDR_START  <= '0';
      IP2L_HDR_LENGTH <= (others => '0');
      IP2L_HDR_CID    <= (others => '0');
      IP2L_HDR_LAST   <= '0';
      IP2L_HDR_STAT   <= (others => '0');
      IP2L_HDR_FBE    <= (others => '0');
      IP2L_HDR_LBE    <= (others => '0');
    elsif rising_edge(CLK) then
      if((DES_P2L_VALIDi and DES_P2L_DFRAMEi and not Q_DES_P2L_DFRAMEi) = '1') then
        IP2L_HDR_START  <= '1';
        IP2L_HDR_LENGTH <= DES_P2L_DATAi(9 downto 0);
        IP2L_HDR_CID    <= DES_P2L_DATAi(11 downto 10);
        IP2L_HDR_LAST   <= DES_P2L_DATAi(15);
        IP2L_HDR_STAT   <= DES_P2L_DATAi(17 downto 16);
        IP2L_HDR_FBE    <= DES_P2L_DATAi(19 downto 16);  -- First Byte Enable
        IP2L_HDR_LBE    <= DES_P2L_DATAi(23 downto 20);  -- Last Byte Enable
      else
        IP2L_HDR_START <= '0';
      end if;
    end if;
  end process;

-----------------------------------------------------------------------------
-- CYCLE: indicates a cycle is in progress
-----------------------------------------------------------------------------
  process (CLK, RST)
  begin
    if RST = c_RST_ACTIVE then
--      CYCLE  <= '0';
      ACYCLE <= '0';
      DCYCLE <= '0';
    elsif rising_edge(CLK) then

      if(ACYCLE = '0') then
        ACYCLE <= DES_P2L_VALIDi and DES_P2L_DFRAMEi and not Q_DES_P2L_DFRAMEi;
      else
        ACYCLE <= not DES_P2L_VALIDi;
      end if;

--      if(CYCLE = '0') then
--        CYCLE <= IP2L_HDR_START;
--      else
--        CYCLE <= not(Q_DES_P2L_VALIDi and not Q_DES_P2L_DFRAMEi);
--      end if;

      if(DCYCLE = '0') then
        DCYCLE <= ACYCLE and TARGET_MWR and DES_P2L_VALIDi;
      else
        DCYCLE <= not(DES_P2L_VALIDi and not DES_P2L_DFRAMEi);
      end if;
    end if;
  end process;

-----------------------------------------------------------------------------
-- Address/Data/Byte Enable
-----------------------------------------------------------------------------
  process (CLK, RST)
  begin
    if RST = c_RST_ACTIVE then
      IP2L_D_VALID    <= '0';
      IP2L_D_LAST     <= '0';
      IP2L_D          <= (others => '0');
      IP2L_BE         <= (others => '0');
      IP2L_ADDR       <= (others => '0');
      IP2L_ADDR_START <= '0';
    elsif rising_edge(CLK) then

      IP2L_D_VALID <= DCYCLE and DES_P2L_VALIDi;
      IP2L_D_LAST  <= (ACYCLE or DCYCLE) and DES_P2L_VALIDi and not DES_P2L_DFRAMEi;

      IP2L_ADDR_START <= ACYCLE and DES_P2L_VALIDi;

      if((ACYCLE and DES_P2L_VALIDi) = '1') then
        IP2L_ADDR <= unsigned(DES_P2L_DATAi);
      elsif(IP2L_D_VALID = '1') then
        IP2L_ADDR(31 downto 2) <= IP2L_ADDR(31 downto 2) + 1;
      end if;

      if(DES_P2L_VALIDi = '1') then
        IP2L_D <= DES_P2L_DATAi;
      end if;

      if(((ACYCLE or IP2L_ADDR_START) = '1') or (IP2L_HDR_LENGTH = "0000000001")) then
        IP2L_BE <= IP2L_HDR_FBE;        -- First Byte Enable
      elsif((DCYCLE and DES_P2L_VALIDi and not DES_P2L_DFRAMEi) = '1') then
        IP2L_BE <= IP2L_HDR_LBE;        -- Last Byte Enable
      elsif(IP2L_D_VALID = '1') then
        IP2L_BE <= (others => '1');     -- Intermediate Byte Enables
      end if;
    end if;
  end process;


-----------------------------------------------------------------------------
-- Generate the Final Output Data
-----------------------------------------------------------------------------

  IP2L_HDR_STARTo  <= IP2L_HDR_START;
  IP2L_HDR_LENGTHo <= IP2L_HDR_LENGTH;
  IP2L_HDR_CIDo    <= IP2L_HDR_CID;
  IP2L_HDR_LASTo   <= IP2L_HDR_LAST;
  IP2L_HDR_STATo   <= IP2L_HDR_STAT;

  IP2L_ADDR_STARTo <= IP2L_ADDR_START;
  IP2L_ADDRo       <= std_logic_vector(IP2L_ADDR);
  IP2L_D_VALIDo    <= IP2L_D_VALID;
  IP2L_D_LASTo     <= IP2L_D_LAST;
  IP2L_Do          <= IP2L_D;
  IP2L_BEo         <= IP2L_BE;


  IP2L_TARGET_MRDo  <= TARGET_MRD;
  IP2L_TARGET_MWRo  <= TARGET_MWR;
  IP2L_MASTER_CPLDo <= MASTER_CPLD;
  IP2L_MASTER_CPLNo <= MASTER_CPLN;


end BEHAVIOUR;


