library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


package LOTUS_UTIL is
  function to_mvl ( b: in boolean ) return STD_ULOGIC;
  function to_mvl ( i: in integer ) return STD_ULOGIC;
  function "and"(l: STD_ULOGIC_VECTOR; r: STD_ULOGIC) return STD_ULOGIC_VECTOR;
  function "and"(l: STD_ULOGIC; r: STD_ULOGIC_VECTOR) return STD_ULOGIC_VECTOR;
  function "and"(l: STD_ULOGIC_VECTOR; r: BOOLEAN) return STD_ULOGIC_VECTOR;
  function "and"(l: BOOLEAN; r: STD_ULOGIC_VECTOR) return STD_ULOGIC_VECTOR;
  function "and"(l: BOOLEAN; r: STD_ULOGIC) return STD_ULOGIC;
  function "and"(l: STD_ULOGIC; r: BOOLEAN) return STD_ULOGIC;
  function exp(input: STD_ULOGIC; num_bits: integer) return STD_ULOGIC_VECTOR;
  function exp(input: STD_ULOGIC_VECTOR; num_bits: integer) return STD_ULOGIC_VECTOR;
  function "+"(l: STD_ULOGIC_VECTOR; r: STD_ULOGIC) return STD_ULOGIC_VECTOR;
  function "+"(l: STD_ULOGIC_VECTOR; r: STD_ULOGIC_VECTOR) return STD_ULOGIC_VECTOR;
  function "-"(l: STD_ULOGIC_VECTOR; r: STD_ULOGIC) return STD_ULOGIC_VECTOR;
  function "-"(l: STD_ULOGIC_VECTOR; r: STD_ULOGIC_VECTOR) return STD_ULOGIC_VECTOR;
  function and_reduce(ARG: STD_ULOGIC_VECTOR) return STD_ULOGIC;
  function nand_reduce(ARG: STD_ULOGIC_VECTOR) return STD_ULOGIC;
  function or_reduce(ARG: STD_ULOGIC_VECTOR) return STD_ULOGIC;
  function nor_reduce(ARG: STD_ULOGIC_VECTOR) return STD_ULOGIC;
  function xor_reduce(ARG: STD_ULOGIC_VECTOR) return STD_ULOGIC;
  function xnor_reduce(ARG: STD_ULOGIC_VECTOR) return STD_ULOGIC;
  function maximum ( arg1, arg2 : INTEGER) return INTEGER;
  function minimum ( arg1, arg2 : INTEGER) return INTEGER;
--  function log2(A: in integer) return integer;
    -------------------------------------------------------------------
    -- Declaration of Synthesis directive attributes
    -------------------------------------------------------------------
    ATTRIBUTE synthesis_return : string ;

end LOTUS_UTIL;

package body LOTUS_UTIL is


    --------------------------------------------------------------------

  function to_mvl ( b: in boolean ) return STD_ULOGIC is
  begin
    if ( b = TRUE ) then
      return( '1' );
    else
      return( '0' );
    end if;
  end to_mvl;

    --------------------------------------------------------------------

  function to_mvl ( i: in integer ) return STD_ULOGIC is
  begin
    if ( i = 1 ) then
      return( '1' );
    else
      return( '0' );
    end if;
  end to_mvl;

    --------------------------------------------------------------------

  function "and"(l: STD_ULOGIC; r: STD_ULOGIC_VECTOR) return STD_ULOGIC_VECTOR is
  variable rr: STD_ULOGIC_vector(r'range);
  begin
    if (l = '1') then
      rr := r;
    else
      rr := (others => '0');
    end if;
    return(rr);
  end;

    --------------------------------------------------------------------

  function "and"(l: STD_ULOGIC_VECTOR; r: STD_ULOGIC) return STD_ULOGIC_VECTOR is
  variable ll: STD_ULOGIC_vector(l'range);
  begin
    if (r = '1') then
      ll := l;
    else
      ll := (others => '0');
    end if;
    return(ll);
  end;

    --------------------------------------------------------------------

  function "and"(l: BOOLEAN; r: STD_ULOGIC_VECTOR) return STD_ULOGIC_VECTOR is
  variable rr: STD_ULOGIC_vector(r'range);
  begin
    if (l) then
      rr := r;
    else
      rr := (others => '0');
    end if;
    return(rr);
  end;

    --------------------------------------------------------------------

  function "and"(l: STD_ULOGIC_VECTOR; r: BOOLEAN) return STD_ULOGIC_VECTOR is
  variable ll: STD_ULOGIC_vector(l'range);
  begin
    if (r) then
      ll := l;
    else
      ll := (others => '0');
    end if;
    return(ll);
  end;

    --------------------------------------------------------------------

  function "and"(l: BOOLEAN; r: STD_ULOGIC) return STD_ULOGIC is
  variable ll: STD_ULOGIC;
  begin
    if (l) then
      ll := r;
    else
      ll := '0';
    end if;
    return(ll);
  end;

    --------------------------------------------------------------------

  function "and"(l: STD_ULOGIC; r: BOOLEAN) return STD_ULOGIC is
  variable ll: STD_ULOGIC;
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

  FUNCTION  exp(input:STD_ULOGIC; num_bits:integer) RETURN STD_ULOGIC_VECTOR IS
  VARIABLE result:STD_ULOGIC_VECTOR(num_bits-1 DOWNTO 0);
  BEGIN
    FOR i in result'HIGH DOWNTO result'LOW LOOP
      result(i) := input;
    END LOOP;
    RETURN result;
  END exp;

  --------------------------------------------------------------------
  -- exp: Expand n bits into m bits
  --------------------------------------------------------------------

  FUNCTION  exp(input:STD_ULOGIC_VECTOR; num_bits:integer) RETURN STD_ULOGIC_VECTOR IS
  VARIABLE result:STD_ULOGIC_VECTOR(num_bits-1 DOWNTO 0);
  BEGIN
    result := (others => '0');
    result(input'length-1 downto 0) := input;
    RETURN result;
  END exp;


  --------------------------------------------------------------------
  -- "+" Increment function
  --------------------------------------------------------------------
  function "+"(L: STD_ULOGIC_VECTOR; R: STD_ULOGIC) return STD_ULOGIC_VECTOR is
  variable Q: STD_ULOGIC_VECTOR(L'range);
  begin
    Q := To_StdULogicVector(To_StdLogicVector(L) + R);
    return Q;
  end;

  --------------------------------------------------------------------
  -- "+" adder function
  --------------------------------------------------------------------
  function "+"(L: STD_ULOGIC_VECTOR; R: STD_ULOGIC_VECTOR) return STD_ULOGIC_VECTOR is
  variable Q: STD_ULOGIC_VECTOR(L'range);
  begin
    Q := To_StdULogicVector(To_StdLogicVector(L) + To_StdLogicVector(R));
    return Q;
  end;

  --------------------------------------------------------------------
  -- "-" Decrement function
  --------------------------------------------------------------------
  function "-"(L: STD_ULOGIC_VECTOR; R: STD_ULOGIC) return STD_ULOGIC_VECTOR is
  variable Q: STD_ULOGIC_VECTOR(L'range);
  begin
    Q := To_StdULogicVector(To_StdLogicVector(L) - R);
    return Q;
  end;

  --------------------------------------------------------------------
  -- "-" subtractor function
  --------------------------------------------------------------------
  function "-"(L: STD_ULOGIC_VECTOR; R: STD_ULOGIC_VECTOR) return STD_ULOGIC_VECTOR is
  variable Q: STD_ULOGIC_VECTOR(L'range);
  begin
    Q := To_StdULogicVector(To_StdLogicVector(L) - To_StdLogicVector(R));
    return Q;
  end;

  --------------------------------------------------------------------
  -- Reduce Functions
  --------------------------------------------------------------------
  function and_reduce(ARG: STD_ULOGIC_VECTOR) return STD_ULOGIC is
  variable result: STD_ULOGIC;
  begin
  result := '1';
  for i in ARG'range loop
    result := result and ARG(i);
  end loop;
  return result;
  end;

  function nand_reduce(ARG: STD_ULOGIC_VECTOR) return STD_ULOGIC is
  begin
  return not and_reduce(ARG);
  end;

  function or_reduce(ARG: STD_ULOGIC_VECTOR) return STD_ULOGIC is
  variable result: STD_ULOGIC;
  begin
  result := '0';
  for i in ARG'range loop
    result := result or ARG(i);
  end loop;
  return result;
  end;

  function nor_reduce(ARG: STD_ULOGIC_VECTOR) return STD_ULOGIC is
  begin
  return not or_reduce(ARG);
  end;

  function xor_reduce(ARG: STD_ULOGIC_VECTOR) return STD_ULOGIC is
  variable result: STD_ULOGIC;
  begin
  result := '0';
  for i in ARG'range loop
    result := result xor ARG(i);
  end loop;
  return result;
  end;

  function xnor_reduce(ARG: STD_ULOGIC_VECTOR) return STD_ULOGIC is
  begin
  return not xor_reduce(ARG);
  end;

  --------------------------------------------------------------------
  -- Some useful generic functions
  --------------------------------------------------------------------

  FUNCTION maximum (arg1,arg2:INTEGER) RETURN INTEGER IS
  BEGIN
    IF(arg1 > arg2) THEN
      RETURN(arg1) ;
    ELSE
      RETURN(arg2) ;
    END IF;
  END ;

  FUNCTION minimum (arg1,arg2:INTEGER) RETURN INTEGER IS
  BEGIN
    IF(arg1 < arg2) THEN
      RETURN(arg1) ;
    ELSE
      RETURN(arg2) ;
    END IF;
  END ;


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

