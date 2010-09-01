--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: L2P_SER (l2p_ser.vhd)
--
-- author:
--
-- date:
--
-- version: 0.0
--
-- description: Generates the DDR L2P bus from SDR that is synchronous to ICLK
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
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity L2P_SER is
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
end L2P_SER;

architecture BEHAVIOUR of L2P_SER is

-----------------------------------------------------------------------------
  component DDR_OUT
-----------------------------------------------------------------------------
    generic
      (
        WIDTH : integer := 20
        );
    port
      (
        -- Reset
        RESET : in  std_ulogic;
        -- Clock
        CLKp  : in  std_ulogic;
        CLKn  : in  std_ulogic;
        -- Clock Enable
        CE    : in  std_ulogic;
        -- Input Data
        Dp    : in  std_ulogic_vector(WIDTH-1 downto 0);
        Dn    : in  std_ulogic_vector(WIDTH-1 downto 0);
        -- Output Data
        Q     : out std_ulogic_vector(WIDTH-1 downto 0)
        );
  end component;


-----------------------------------------------------------------------------
-- Internal Signals
-----------------------------------------------------------------------------
  signal Q_DFRAME    : std_ulogic;
  signal Q_VALID     : std_ulogic;
  signal Q_DATA      : std_ulogic_vector(ICLK_DATA'range);
  signal L2P_CLK_SDR : std_ulogic;

begin

-----------------------------------------------------------------------------
-- Re-allign Data tightly for the +'ve clock edge
-----------------------------------------------------------------------------
  process (ICLKp, IRST)
  begin
    if(IRST = '1') then
      Q_DFRAME <= '0';
      Q_VALID  <= '0';
      Q_DATA   <= (others => '0');
    elsif (ICLKp'event and ICLKp = '1') then
      Q_DFRAME <= ICLK_DFRAME;
      Q_VALID  <= ICLK_VALID;
      Q_DATA   <= ICLK_DATA;
    end if;
  end process;

  process (ICLKn, IRST)
  begin
    if(IRST = '1') then
      L2P_VALID  <= '0';
      L2P_DFRAME <= '0';
    elsif (ICLKn'event and ICLKn = '1') then
      L2P_VALID  <= Q_VALID;
      L2P_DFRAME <= Q_DFRAME;
    end if;
  end process;

-----------------------------------------------------------------------------
-- Data/Control/Clock Outputs
-----------------------------------------------------------------------------
  U_DDR_OUT : DDR_OUT
    generic map
    (
--    WIDTH => 20
      WIDTH => 16
      )
    port map
    (
      -- Reset
      RESET           => IRST,
      -- Clock
      CLKp            => ICLKp,
      CLKn            => ICLKn,
      -- Clock Enable
      CE              => '1',
      -- Input Data
--    Dp(19)          => '0',
--    Dp(18)          => '1',
----    Dp(17)          => Q_VALID,
----    Dp(16)          => Q_DFRAME,
      DP(15 downto 0) => Q_DATA(31 downto 16),
--    Dn(19)          => '1',
--    Dn(18)          => '0',
----    Dn(17)          => Q_VALID,
----    Dn(16)          => Q_DFRAME,
      Dn(15 downto 0) => Q_DATA(15 downto 0),
      -- Output Data
--    Q(19)           => L2P_CLKp,
--    Q(18)           => L2P_CLKn,
----    Q(17)           => L2P_VALID,
----    Q(16)           => L2P_DFRAME,
      Q(15 downto 0)  => L2P_DATA
      );


  L2P_CLK_BUF : OBUFDS
    port map(
      O  => L2P_CLKp,
      OB => L2P_CLKn,
      I  => L2P_CLK_SDR);

  L2P_CLK_int : FDDRRSE
    port map(
      Q  => L2P_CLK_SDR,
      C0 => ICLKn,
      C1 => ICLKp,
      CE => '1',
      D0 => '1',
      D1 => '0',
      R  => '0',
      S  => '0');

end BEHAVIOUR;


