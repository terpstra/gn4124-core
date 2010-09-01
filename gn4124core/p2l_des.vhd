--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: P2L_DES (p2l_des.vhd)
--
-- author:
--
-- date:
--
-- version: 0.0
--
-- description: Takes the DDR P2L bus and converts to SDR that is synchronous
--              to ICLK
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
--use IEEE.STD_LOGIC_ARITH.all;
--use IEEE.STD_LOGIC_UNSIGNED.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity P2L_DES is
  port
    (
      ---------------------------------------------------------
      -- Raw unprocessed reset from the GN412x
      --
      L_RST       : in     std_logic;
      ---------------------------------------------------------
      -- P2L Clock Domain
      --
      -- P2L Inputs
      P2L_CLKp    : in     std_logic;
      P2L_CLKn    : in     std_logic;
      P2L_VALID   : in     std_logic;
      P2L_DFRAME  : in     std_logic;
      P2L_DATA    : in     std_logic_vector(15 downto 0);
      --
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- ICLK Clock Domain
      --
      IRST        : out    std_logic;
      -- Core Logic Clock
      ICLK        : buffer std_logic;
      ICLKn       : buffer std_logic;
      -- DeSerialized Output
      ICLK_VALID  : out    std_logic;
      ICLK_DFRAME : out    std_logic;
      ICLK_DATA   : out    std_logic_vector(31 downto 0)
      --
      ---------------------------------------------------------
      );
end P2L_DES;

architecture BEHAVIOUR of P2L_DES is


-----------------------------------------------------------------------------
--  component IDDR2
-------------------------------------------------------------------------------
--    generic
--      (
--        DDR_ALIGNMENT : string := "NONE";
--        INIT_Q0       : bit    := '0';
--        INIT_Q1       : bit    := '0';
--        SRTYPE        : string := "SYNC"
--        );
--    port
--      (
--        Q0 : out std_ulogic;
--        Q1 : out std_ulogic;
--        C0 : in  std_ulogic;
--        C1 : in  std_ulogic;
--        CE : in  std_ulogic;
--        D  : in  std_ulogic;
--        R  : in  std_ulogic;
--        S  : in  std_ulogic
--        );
--  end component;

-----------------------------------------------------------------------------
--  component IFDDRRSE
-------------------------------------------------------------------------------
--    port
--      (
--        Q0 : out std_ulogic;
--        Q1 : out std_ulogic;
--        C0 : in  std_ulogic;
--        C1 : in  std_ulogic;
--        CE : in  std_ulogic;
--        D  : in  std_ulogic;
--        R  : in  std_ulogic;
--        S  : in  std_ulogic
--        );
--  end component;

-----------------------------------------------------------------------------
-- Internal Signals
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-- Signals for the P2L_CLK domain
-----------------------------------------------------------------------------
--  signal P2L_RST            : STD_ULOGIC;
  signal VALIDp, VALIDn   : std_logic;
  signal DFRAMEp, DFRAMEn : std_logic;
  signal DATAp, DATAn     : std_logic_vector(P2L_DATA'range);
  signal P2L_DATA_SDR_L   : std_logic_vector(P2L_DATA'range);
  signal P2L_DATA_SDR     : std_logic_vector(P2L_DATA'length*2-1 downto 0);
  signal ICLK_i, ICLKn_i  : std_logic;
  signal IRST_FF          : std_logic;
  signal IRSTo            : std_logic;


begin
-----------------------------------------------------------------------------
-- IRST: ICLK alligned reset
-----------------------------------------------------------------------------
  process (ICLK, L_RST)
  begin
    if L_RST = '1' then
      IRST_FF <= '1';
    elsif rising_edge(ICLK) then
      IRST_FF <= '0';
    end if;
  end process;


  U_IRST : BUFG
    port map (I => IRST_FF,
              O => IRSTo);



  IRST <= IRSTo;

--=============================================================================================--
--=============================================================================================--
--== ALL P2L_CLOCK DOMAIN LOGIC
--=============================================================================================--
--=============================================================================================--
--  U_DDR_IN: DDR_IN
--  generic map
--  (
--    WIDTH => 18
--  )
--  port map
--  (
--    -- Reset
--    RESET   => IRST,
--    -- Clock
--    CLKp    => ICLK,
--    CLKn    => ICLKn,
--    -- Clock Enable
--    CE      => '1',
--    -- Input Data
--    D(17)           => P2L_VALID,
--    D(16)           => P2L_DFRAME,
--    D(15 downto 0)  => P2L_DATA,
--    -- Output Data
--    Qp(17)          => VALIDp,
--    Qp(16)          => DFRAMEp,
--    Qp(15 downto 0) => DATAp,
--    Qn(17)          => VALIDn,
--    Qn(16)          => DFRAMEn,
--    Qn(15 downto 0) => DATAn
--  );



  DDRFF_D : for i in P2L_DATA'range generate
    U : IFDDRRSE
--    generic map
--    (
--        DDR_ALIGNMENT => "NONE",
----        INIT_Q0 => '0',
----        INIT_Q1 => '0',
--        SRTYPE  => "SYNC"
--    )
      port map
      (
        Q0 => DATAn(i),
        Q1 => DATAp(i),
        C0 => ICLKn,
        C1 => ICLK,
        CE => '1',
        D  => P2L_DATA(i),
        R  => IRSTo,
        S  => '0'
        );                              -- IFDDRRSE (U)
  end generate;

  DDRFF_F : IFDDRRSE
--    generic map
--    (
--        DDR_ALIGNMENT => "NONE",
----        INIT_Q0 => '0',
----        INIT_Q1 => '0',
--        SRTYPE  => "SYNC"
--    )
    port map
    (
      Q0 => DFRAMEn,
      Q1 => DFRAMEp,
      C0 => ICLKn,
      C1 => ICLK,
      CE => '1',
      D  => P2L_DFRAME,
      R  => IRSTo,
      S  => '0'
      );                                -- IFDDRRSE (U)

  DDRFF_V : IFDDRRSE
--    generic map
--    (
--        DDR_ALIGNMENT => "NONE",
----        INIT_Q0 => '0',
----        INIT_Q1 => '0',
--        SRTYPE  => "SYNC"
--    )
    port map
    (
      Q0 => VALIDn,
      Q1 => VALIDp,
      C0 => ICLKn,
      C1 => ICLK,
      CE => '1',
      D  => P2L_VALID,
      R  => IRSTo,
      S  => '0'
      );                                -- IFDDRRSE (U)




-----------------------------------------------------------------------------
-- Align positive edge data to negative edge clock
-----------------------------------------------------------------------------
  process (ICLKn, IRSTo)
  begin
    if(IRSTo = '1') then
      P2L_DATA_SDR_L <= (others => '0');
    elsif rising_edge(ICLKn) then
      P2L_DATA_SDR_L <= DATAp;
    end if;
  end process;

  P2L_DATA_SDR <= DATAn & P2L_DATA_SDR_L;

-----------------------------------------------------------------------------
-- Final Positive Edge Clock Allignment
-----------------------------------------------------------------------------
  process (ICLK, IRSTo)
  begin
    if(IRSTo = '1') then
      ICLK_VALID  <= '0';
      ICLK_DFRAME <= '0';
      ICLK_DATA   <= (others => '0');
    elsif rising_edge(ICLK) then
      ICLK_VALID  <= VALIDp;
      ICLK_DFRAME <= DFRAMEp;
      ICLK_DATA   <= P2L_DATA_SDR;
    end if;
  end process;


-----------------------------------------------------------------------------
-- The Internal Core Clock is Derived from the P2L_CLK
-----------------------------------------------------------------------------
--  ICLK  <= P2L_CLKp;
--  ICLKn <= P2L_CLKn;

  ICLK_ibuf : IBUFGDS
    port map(
      I  => P2L_CLKp,
      IB => P2L_CLKn,
      O  => ICLK_i);
  ICLK_bufg : BUFG
    port map(
      I => ICLK_i,
      O => ICLK);

  ICLKn_ibuf : IBUFGDS
    port map(
      I  => P2L_CLKn,
      IB => P2L_CLKp,
      O  => ICLKn_i);
  ICLKn_bufg : BUFG
    port map(
      I => ICLKn_i,
      O => ICLKn);


end BEHAVIOUR;


