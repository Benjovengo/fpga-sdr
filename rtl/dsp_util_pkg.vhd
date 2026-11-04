-- Small helpers shared by the DSP blocks.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package dsp_util_pkg is
  -- ceil(log2(n)), with clog2(1) = 0
  function clog2(n : positive) return natural;
  -- Clamp x to the range of a width-bit signed number.
  function saturate(x : signed; width : positive) return signed;
end package;

package body dsp_util_pkg is
  function clog2(n : positive) return natural is
    variable r : natural := 0;
  begin
    while 2**r < n loop
      r := r + 1;
    end loop;
    return r;
  end function;

  function saturate(x : signed; width : positive) return signed is
    constant MAX : signed(width - 1 downto 0) := '0' & (width - 2 downto 0 => '1');
    constant MIN : signed(width - 1 downto 0) := '1' & (width - 2 downto 0 => '0');
  begin
    if x > resize(MAX, x'length) then
      return MAX;
    elsif x < resize(MIN, x'length) then
      return MIN;
    end if;
    return resize(x, width);
  end function;
end package body;
