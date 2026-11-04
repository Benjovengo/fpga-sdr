-- NCO (32-bit phase accumulator + sin/cos table) and complex mixer:
--   y = x * exp(-j*phase),  i.e.  y_i = i*cos + q*sin,  y_q = q*cos - i*sin
-- Three register stages: table read | four multiplies | add/sub + scale.
-- One sample per clock maximum; in_valid may be low between samples.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ddc_params_pkg.all;

entity nco_mixer is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    phase_inc : in  unsigned(PHASE_W - 1 downto 0);
    in_valid  : in  std_logic;
    in_i      : in  signed(IN_W - 1 downto 0);
    in_q      : in  signed(IN_W - 1 downto 0);
    out_valid : out std_logic;
    out_i     : out signed(MIX_W - 1 downto 0);
    out_q     : out signed(MIX_W - 1 downto 0)
  );
end entity;

architecture rtl of nco_mixer is
  subtype prod_t is signed(IN_W + LUT_W - 1 downto 0);
  subtype sum_t is signed(IN_W + LUT_W downto 0);

  signal phase      : unsigned(PHASE_W - 1 downto 0) := (others => '0');
  signal v1, v2, v3 : std_logic := '0';
  signal i1, q1     : signed(IN_W - 1 downto 0) := (others => '0');
  signal cos1, sin1 : signed(LUT_W - 1 downto 0) := (others => '0');
  signal p_ic, p_qs, p_qc, p_is : prod_t := (others => '0');
  signal yi, yq     : signed(MIX_W - 1 downto 0) := (others => '0');
begin
  process (clk)
    variable addr         : natural range 0 to 2**LUT_AW - 1;
    variable sum_i, sum_q : sum_t;
  begin
    if rising_edge(clk) then
      -- stage 1: table lookup for the current phase, register the sample
      v1 <= in_valid;
      if in_valid = '1' then
        addr  := to_integer(phase(PHASE_W - 1 downto PHASE_W - LUT_AW));
        cos1  <= to_signed(COS_LUT(addr), LUT_W);
        sin1  <= to_signed(SIN_LUT(addr), LUT_W);
        i1    <= in_i;
        q1    <= in_q;
        phase <= phase + phase_inc;
      end if;

      -- stage 2: products (maps onto four DSP multipliers)
      v2   <= v1;
      p_ic <= i1 * cos1;
      p_qs <= q1 * sin1;
      p_qc <= q1 * cos1;
      p_is <= i1 * sin1;

      -- stage 3: complex combine and scale back by the table's Q1.15 format
      v3    <= v2;
      sum_i := resize(p_ic, sum_t'length) + resize(p_qs, sum_t'length);
      sum_q := resize(p_qc, sum_t'length) - resize(p_is, sum_t'length);
      yi    <= resize(shift_right(sum_i, MIX_SHIFT), MIX_W);
      yq    <= resize(shift_right(sum_q, MIX_SHIFT), MIX_W);

      if rst = '1' then
        phase <= (others => '0');
        v1    <= '0';
        v2    <= '0';
        v3    <= '0';
      end if;
    end if;
  end process;

  out_valid <= v3;
  out_i     <= yi;
  out_q     <= yq;
end architecture;
