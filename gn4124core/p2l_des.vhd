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
-- version: 0.1
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
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

entity P2L_DES is
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
end P2L_DES;

architecture BEHAVIOUR of P2L_DES is

-----------------------------------------------------------------------------
component DDR_IN
-----------------------------------------------------------------------------
  generic
  (
    WIDTH   : INTEGER := 18
  );
  port
  ( 
    -- Reset
    RESET   : in   STD_ULOGIC;
    -- Clockp
    CLKp    : in   STD_ULOGIC;
    CLKn    : in   STD_ULOGIC;
    -- Clock Enable
    CE      : in   STD_ULOGIC;
    -- Input Data
    D       : in   STD_ULOGIC_VECTOR(WIDTH-1 downto 0);
    -- Output Data
    Qp      : out  STD_ULOGIC_VECTOR(WIDTH-1 downto 0);
    Qn      : out  STD_ULOGIC_VECTOR(WIDTH-1 downto 0)
  );
end component;

-----------------------------------------------------------------------------
component IDDR2
-----------------------------------------------------------------------------
  generic
  (
    DDR_ALIGNMENT : string := "NONE";
    INIT_Q0 : bit := '0';
    INIT_Q1 : bit := '0';
    SRTYPE : string := "SYNC"
  );
  port
  (
    Q0 : out std_ulogic;
    Q1 : out std_ulogic;
    C0 : in std_ulogic;
    C1 : in std_ulogic;
    CE : in std_ulogic;
    D : in std_ulogic;
    R : in std_ulogic;
    S : in std_ulogic
  );
end component;

-----------------------------------------------------------------------------
component IFDDRRSE
-----------------------------------------------------------------------------
  port
  (
    Q0 : out std_ulogic;
    Q1 : out std_ulogic;
    C0 : in std_ulogic;
    C1 : in std_ulogic;
    CE : in std_ulogic;
    D : in std_ulogic;
    R : in std_ulogic;
    S : in std_ulogic
  );
end component;

-----------------------------------------------------------------------------
-- Internal Signals 
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
-- Signals for the P2L_CLK domain
-----------------------------------------------------------------------------
--  signal P2L_RST            : STD_ULOGIC;
  signal VALIDp,  VALIDn    : STD_ULOGIC;
  signal DFRAMEp, DFRAMEn   : STD_ULOGIC;
  signal DATAp, DATAn       : STD_ULOGIC_VECTOR(P2L_DATA'range);
  signal P2L_DATA_SDR_L     : STD_ULOGIC_VECTOR(P2L_DATA'range);
  signal P2L_DATA_SDR       : STD_ULOGIC_VECTOR(P2L_DATA'length*2-1 downto 0);
  signal ICLK_i, ICLKn_i    : STD_LOGIC;
  signal IRST_FF            : STD_ULOGIC;
  signal IRSTo              : STD_ULOGIC;


begin
-----------------------------------------------------------------------------
-- IRST: ICLK alligned reset
-----------------------------------------------------------------------------
  process (ICLK, L_RST)
  begin  
    if L_RST = '1' then
      IRST_FF <= '1';
    elsif (ICLK'event and ICLK = '1') then
      IRST_FF <= '0';
    end if;
  end process;


   U_IRST : BUFG
      port map (I=>IRST_FF,
                O=>IRSTo);



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



  DDRFF_D: for i in P2L_DATA'range generate
      U: IFDDRRSE
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
    ); -- IFDDRRSE (U)
  end generate;

      DDRFF_F: IFDDRRSE
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
    ); -- IFDDRRSE (U)

      DDRFF_V: IFDDRRSE
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
    ); -- IFDDRRSE (U)




-----------------------------------------------------------------------------
-- Align positive edge data to negative edge clock
-----------------------------------------------------------------------------
  process (ICLKn, IRSTo)
  begin  
    if(IRSTo = '1') then
      P2L_DATA_SDR_L <= (others => '0');
    elsif (ICLKn'event and ICLKn = '1') then
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
    elsif (ICLK'event and ICLK = '1') then
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

ICLK_ibuf: IBUFGDS 
  port map(
   I   => P2L_CLKp, 
    IB  => P2L_CLKn, 
    O   => ICLK_i);
ICLK_bufg: BUFG
  port map(
    I   => ICLK_i,
    O   => ICLK);   
                     
ICLKn_ibuf: IBUFGDS
  port map(
    I   => P2L_CLKn, 
    IB  => P2L_CLKp, 
    O   => ICLKn_i);
ICLKn_bufg: BUFG
  port map(
    I   => ICLKn_i,
    O   => ICLKn);
   

end BEHAVIOUR;


