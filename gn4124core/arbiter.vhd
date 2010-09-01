-------------------------------------------------------------------------------
--                                                                           --
-- CERN BE-CO-HT         GN4124 core for PCIe FMC carrier                    --
--                       http://www.ohwr.org/projects/gn4124-core            --
-------------------------------------------------------------------------------
--
-- unit name: GN4124 core arbiter (arbiter.vhd)
--
-- author: Simon Deprez (simon.deprez@cern.ch)
--
-- date: 12-08-2010
--
-- version: 0.1
--
-- description: Arbitrate between Wishbone master, DMA master and DMA pdmuencer
--
-- dependencies:
--
-------------------------------------------------------------------------------
-- last changes:
--       - 08-06-2010,
-------------------------------------------------------------------------------
-- TODO: -
--       -
--       -
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
--use IEEE.STD_LOGIC_ARITH.all;
--use IEEE.STD_LOGIC_UNSIGNED.all;

entity arbiter is
  port
    (
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- Clock/Reset
      --
      clk_i            : in  std_logic;
      rst_i            : in  std_logic;
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- From Wishbone master (wbm) to arbiter (arb)
      --
      wbm_arb_valid_i  : in  std_logic;
      wbm_arb_dframe_i : in  std_logic;
      wbm_arb_data_i   : in  std_logic_vector(31 downto 0);
      wbm_arb_req_i    : in  std_logic;
      arb_wbm_gnt_o    : out std_logic;
      --
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- From DMA pdmuencer (pdm) to arbiter (arb)
      --
      pdm_arb_valid_i  : in  std_logic;
      pdm_arb_dframe_i : in  std_logic;
      pdm_arb_data_i   : in  std_logic_vector(31 downto 0);
      pdm_arb_req_i    : in  std_logic;
      arb_pdm_gnt_o    : out std_logic;
      --
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- From P2L DMA master (ldm) to arbiter (arb)
      --
      ldm_arb_valid_i  : in  std_logic;
      ldm_arb_dframe_i : in  std_logic;
      ldm_arb_data_i   : in  std_logic_vector(31 downto 0);
      ldm_arb_req_i    : in  std_logic;
      arb_ldm_gnt_o    : out std_logic;
      --
      ---------------------------------------------------------

      ---------------------------------------------------------
      -- From arbiter (arb) to serializer (ser)
      --
      arb_ser_valid_o  : out std_logic;
      arb_ser_dframe_o : out std_logic;
      arb_ser_data_o   : out std_logic_vector(31 downto 0)
      --
      ---------------------------------------------------------
      );
end arbiter;

architecture behaviour of arbiter is
  ---------------------------------------------------------
  -- Signal declarations
  --
  signal wbm_arb_req_valid : std_logic;
  signal pdm_arb_req_valid : std_logic;
  signal ldm_arb_req_valid : std_logic;
  signal arb_req_valid     : std_logic;
  signal arb_wbm_gnt       : std_logic;
  signal arb_pdm_gnt       : std_logic;
  signal arb_ldm_gnt       : std_logic;
  signal eop               : std_logic;  -- End of packet
  --
  ---------------------------------------------------------
begin
  wbm_arb_req_valid <= wbm_arb_req_i;
  pdm_arb_req_valid <= pdm_arb_req_i;
  ldm_arb_req_valid <= ldm_arb_req_i;

  -- Detect any valid request to allow arbitration
  arb_req_valid <= (wbm_arb_req_valid or pdm_arb_req_valid or ldm_arb_req_valid) and
                   (not arb_wbm_gnt and not arb_pdm_gnt and not arb_ldm_gnt);

  -- Detect end of packet to delimit the arbitration phase
  eop <= ((arb_wbm_gnt and not wbm_arb_dframe_i) or
          (arb_pdm_gnt and not pdm_arb_dframe_i) or
          (arb_ldm_gnt and not ldm_arb_dframe_i));

  -----------------------------------------------------------------------------
  -- Arbitration is started when a valid request is present and ends when the
  -- EOP condition is detected
  --
  -- Strict priority arbitration scheme
  -- Highest : WBM request
  --         : LDM request
  -- Lowest  : PDM request
  -----------------------------------------------------------------------------


  process (clk_i, rst_i)
  begin
    if(rst_i = '1') then
      arb_wbm_gnt <= '0';
      arb_pdm_gnt <= '0';
      arb_ldm_gnt <= '0';
    elsif rising_edge(clk_i) then
      if (arb_req_valid = '1') then
        if (wbm_arb_req_valid = '1') then
          arb_wbm_gnt <= '1';
          arb_pdm_gnt <= '0';
          arb_ldm_gnt <= '0';
        elsif (ldm_arb_req_valid = '1') then
          arb_wbm_gnt <= '0';
          arb_pdm_gnt <= '0';
          arb_ldm_gnt <= '1';
        elsif (pdm_arb_req_valid = '1') then
          arb_wbm_gnt <= '0';
          arb_pdm_gnt <= '1';
          arb_ldm_gnt <= '0';
        else
          arb_wbm_gnt <= '0';
          arb_pdm_gnt <= '0';
          arb_ldm_gnt <= '0';
        end if;
      elsif (eop = '1') then
        arb_wbm_gnt <= '0';
        arb_pdm_gnt <= '0';
        arb_ldm_gnt <= '0';
      end if;
    end if;
  end process;

  arb_ser_valid_o <= wbm_arb_valid_i when (arb_wbm_gnt = '1') else
                     pdm_arb_valid_i when (arb_pdm_gnt = '1') else
                     ldm_arb_valid_i when (arb_ldm_gnt = '1') else '0';

  arb_ser_dframe_o <= wbm_arb_dframe_i when (arb_wbm_gnt = '1') else
                      pdm_arb_dframe_i when (arb_pdm_gnt = '1') else
                      ldm_arb_dframe_i when (arb_ldm_gnt = '1') else '0';

  arb_ser_data_o <= wbm_arb_data_i when (arb_wbm_gnt = '1') else
                    pdm_arb_data_i when (arb_pdm_gnt = '1') else
                    ldm_arb_data_i when (arb_ldm_gnt = '1') else x"00000000";

  arb_wbm_gnt_o <= arb_wbm_gnt;
  arb_pdm_gnt_o <= arb_pdm_gnt;
  arb_ldm_gnt_o <= arb_ldm_gnt;

end behaviour;
