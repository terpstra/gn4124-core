--==========================================================================--
--
-- *Module      : lotus_pkg
--
-- *Description : Constants for the lotus design
--
--
--==========================================================================--
library IEEE;
use IEEE.std_logic_1164.all;

package lotus_pkg is

  constant PKG_EPI_RD_TIME : integer := 20;  -- Determines the width of the EPI_RD pulse in units of ICLK
                                             -- Valid range is 4 to 34
  constant PKG_EPI_WR_TIME : integer := 5;   -- Determines the width of the EPI_WR pulse in units of ICLK
                                             -- Valid range is 1 to 31
  constant PKG_EPI_ADDR_N  : integer := 16;  -- Size of the EPI_ADDRESSo bus
  constant PKG_EPI_DATA_N  : integer := 32;  -- Size of the EPI_DATA bus


end lotus_pkg;
