library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;


package LOTUS_UTIL is
  function to_mvl (b           : in boolean) return std_ulogic;
  function to_mvl (i           : in integer) return std_ulogic;
  function "and"(l             :    std_ulogic_vector; r : std_ulogic) return std_ulogic_vector;
  function "and"(l             :    std_ulogic; r : std_ulogic_vector) return std_ulogic_vector;
  function "and"(l             :    std_ulogic_vector; r : boolean) return std_ulogic_vector;
  function "and"(l             :    boolean; r : std_ulogic_vector) return std_ulogic_vector;
  function "and"(l             :    boolean; r : std_ulogic) return std_ulogic;
  function "and"(l             :    std_ulogic; r : boolean) return std_ulogic;
  function exp(input           :    std_ulogic; num_bits : integer) return std_ulogic_vector;
  function exp(input           :    std_ulogic_vector; num_bits : integer) return std_ulogic_vector;
  function "+"(l               :    std_ulogic_vector; r : std_ulogic) return std_ulogic_vector;
  function "+"(l               :    std_ulogic_vector; r : std_ulogic_vector) return std_ulogic_vector;
  function "-"(l               :    std_ulogic_vector; r : std_ulogic) return std_ulogic_vector;
  function "-"(l               :    std_ulogic_vector; r : std_ulogic_vector) return std_ulogic_vector;
  function and_reduce(ARG      :    std_ulogic_vector) return std_ulogic;
  function nand_reduce(ARG     :    std_ulogic_vector) return std_ulogic;
  function or_reduce(ARG       :    std_ulogic_vector) return std_ulogic;
  function nor_reduce(ARG      :    std_ulogic_vector) return std_ulogic;
  function xor_reduce(ARG      :    std_ulogic_vector) return std_ulogic;
  function xnor_reduce(ARG     :    std_ulogic_vector) return std_ulogic;
  function maximum (arg1, arg2 :    integer) return integer;
  function minimum (arg1, arg2 :    integer) return integer;
--  function log2(A: in integer) return integer;
  -------------------------------------------------------------------
  -- Declaration of Synthesis directive attributes
  -------------------------------------------------------------------
  attribute synthesis_return   :    string;

end LOTUS_UTIL;

package body LOTUS_UTIL is


  --------------------------------------------------------------------

  function to_mvl (b : in boolean) return std_ulogic is
  begin
    if (b = true) then
      return('1');
    else
      return('0');
    end if;
  end to_mvl;

  --------------------------------------------------------------------

  function to_mvl (i : in integer) return std_ulogic is
  begin
    if (i = 1) then
      return('1');
    else
      return('0');
    end if;
  end to_mvl;

  --------------------------------------------------------------------

  function "and"(l : std_ulogic; r : std_ulogic_vector) return std_ulogic_vector is
    variable rr : std_ulogic_vector(r'range);
  begin
    if (l = '1') then
      rr := r;
    else
      rr := (others => '0');
    end if;
    return(rr);
  end;

  --------------------------------------------------------------------

  function "and"(l : std_ulogic_vector; r : std_ulogic) return std_ulogic_vector is
    variable ll : std_ulogic_vector(l'range);
  begin
    if (r = '1') then
      ll := l;
    else
      ll := (others => '0');
    end if;
    return(ll);
  end;

  --------------------------------------------------------------------

  function "and"(l : boolean; r : std_ulogic_vector) return std_ulogic_vector is
    variable rr : std_ulogic_vector(r'range);
  begin
    if (l) then
      rr := r;
    else
      rr := (others => '0');
    end if;
    return(rr);
  end;

  --------------------------------------------------------------------

  function "and"(l : std_ulogic_vector; r : boolean) return std_ulogic_vector is
    variable ll : std_ulogic_vector(l'range);
  begin
    if (r) then
      ll := l;
    else
      ll := (others => '0');
    end if;
    return(ll);
  end;

  --------------------------------------------------------------------

  function "and"(l : boolean; r : std_ulogic) return std_ulogic is
    variable ll : std_ulogic;
  begin
    if (l) then
      ll := r;
    else
      ll := '0';
    end if;
    return(ll);
  end;

  --------------------------------------------------------------------

  function "and"(l : std_ulogic; r : boolean) return std_ulogic is
    variable ll : std_ulogic;
  begin
    if (r) then
      ll := l;
    else
      ll := '0';
    end if;
    return(ll);
  end;

  --------------------------------------------------------------------
  -- exp: Expand one bit into many
  --------------------------------------------------------------------

  function exp(input : std_ulogic; num_bits : integer) return std_ulogic_vector is
    variable result : std_ulogic_vector(num_bits-1 downto 0);
  begin
    for i in result'high downto result'low loop
      result(i) := input;
    end loop;
    return result;
  end exp;

  --------------------------------------------------------------------
  -- exp: Expand n bits into m bits
  --------------------------------------------------------------------

  function exp(input : std_ulogic_vector; num_bits : integer) return std_ulogic_vector is
    variable result : std_ulogic_vector(num_bits-1 downto 0);
  begin
    result                          := (others => '0');
    result(input'length-1 downto 0) := input;
    return result;
  end exp;


  --------------------------------------------------------------------
  -- "+" Increment function
  --------------------------------------------------------------------
  function "+"(L : std_ulogic_vector; R : std_ulogic) return std_ulogic_vector is
    variable Q : std_ulogic_vector(L'range);
  begin
    Q := To_StdULogicVector(To_StdLogicVector(L) + R);
    return Q;
  end;

  --------------------------------------------------------------------
  -- "+" adder function
  --------------------------------------------------------------------
  function "+"(L : std_ulogic_vector; R : std_ulogic_vector) return std_ulogic_vector is
    variable Q : std_ulogic_vector(L'range);
  begin
    Q := To_StdULogicVector(To_StdLogicVector(L) + To_StdLogicVector(R));
    return Q;
  end;

  --------------------------------------------------------------------
  -- "-" Decrement function
  --------------------------------------------------------------------
  function "-"(L : std_ulogic_vector; R : std_ulogic) return std_ulogic_vector is
    variable Q : std_ulogic_vector(L'range);
  begin
    Q := To_StdULogicVector(To_StdLogicVector(L) - R);
    return Q;
  end;

  --------------------------------------------------------------------
  -- "-" subtractor function
  --------------------------------------------------------------------
  function "-"(L : std_ulogic_vector; R : std_ulogic_vector) return std_ulogic_vector is
    variable Q : std_ulogic_vector(L'range);
  begin
    Q := To_StdULogicVector(To_StdLogicVector(L) - To_StdLogicVector(R));
    return Q;
  end;

  --------------------------------------------------------------------
  -- Reduce Functions
  --------------------------------------------------------------------
  function and_reduce(ARG : std_ulogic_vector) return std_ulogic is
    variable result : std_ulogic;
  begin
    result := '1';
    for i in ARG'range loop
      result := result and ARG(i);
    end loop;
    return result;
  end;

  function nand_reduce(ARG : std_ulogic_vector) return std_ulogic is
  begin
    return not and_reduce(ARG);
  end;

  function or_reduce(ARG : std_ulogic_vector) return std_ulogic is
    variable result : std_ulogic;
  begin
    result := '0';
    for i in ARG'range loop
      result := result or ARG(i);
    end loop;
    return result;
  end;

  function nor_reduce(ARG : std_ulogic_vector) return std_ulogic is
  begin
    return not or_reduce(ARG);
  end;

  function xor_reduce(ARG : std_ulogic_vector) return std_ulogic is
    variable result : std_ulogic;
  begin
    result := '0';
    for i in ARG'range loop
      result := result xor ARG(i);
    end loop;
    return result;
  end;

  function xnor_reduce(ARG : std_ulogic_vector) return std_ulogic is
  begin
    return not xor_reduce(ARG);
  end;

  --------------------------------------------------------------------
  -- Some useful generic functions
  --------------------------------------------------------------------

  function maximum (arg1, arg2 : integer) return integer is
  begin
    if(arg1 > arg2) then
      return(arg1);
    else
      return(arg2);
    end if;
  end;

  function minimum (arg1, arg2 : integer) return integer is
  begin
    if(arg1 < arg2) then
      return(arg1);
    else
      return(arg2);
    end if;
  end;


  ---------------------------------------------------------------------
  -- log base 2 function
  ---------------------------------------------------------------------
--  function log2 ( A: in integer ) return integer is
--    variable B  : integer;
--    begin
--      B := 1;
--      for i in 0 to 31 loop
--        if not ( A > B ) then
--          return ( i );
--          exit;
--        end if;
--        B := B * 2;
--      end loop;
--  end log2;



end LOTUS_UTIL;

