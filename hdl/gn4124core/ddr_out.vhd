--------------------------------------------------------------------------------
--                                                                            --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                     --
--                       http://www.ohwr.org/projects/gn4124-core             --
--------------------------------------------------------------------------------
--
-- unit name: DDR_OUT (ddr_out.vhd)
--
-- author: 
--
-- date: 
--
-- version: 0.1
--
-- description: Generic technology dependent DDR output for Xilinx.
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
use IEEE.std_logic_1164.all;

Library UNISIM;
use UNISIM.vcomponents.all;

entity DDR_OUT is
	generic
	(
		WIDTH   : INTEGER := 20
	);
	port
	( 
		-- Reset
		RESET   : in   STD_ULOGIC;
		-- Clock
		CLKp    : in   STD_ULOGIC;
		CLKn    : in   STD_ULOGIC;
		-- Clock Enable
		CE      : in   STD_ULOGIC;
		-- Input Data
		Dp      : in   STD_ULOGIC_VECTOR(WIDTH-1 downto 0);
		Dn      : in   STD_ULOGIC_VECTOR(WIDTH-1 downto 0);
		-- Output Data
		Q       : out  STD_ULOGIC_VECTOR(WIDTH-1 downto 0)
	);
end DDR_OUT;

architecture BEHAVIOUR of DDR_OUT is

--component OFDDRRSE
--  port(
--    Q : out std_ulogic;
--    C0 : in std_ulogic;
--    C1 : in std_ulogic;
--    CE : in std_ulogic;
--    D0 : in std_ulogic;
--    D1 : in std_ulogic;
--    R  : in std_ulogic;
--    S  : in std_ulogic
--    );
--end component; --OFDDRRSE

begin


	DDROUT: for i in 0 to WIDTH-1 generate
	    U: OFDDRRSE 
		port map
		(
		    Q  => Q(i),
		    C0 => CLKn,
		    C1 => CLKp,
		    CE => CE,
		    D0 => Dn(i),
		    D1 => Dp(i),
		    R  => RESET,
		    S  => '0'
		);
	end generate;

end BEHAVIOUR;


