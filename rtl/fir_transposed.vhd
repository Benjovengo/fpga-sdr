-- Transposed-form FIR (low-latency architecture).
--   y[n] = h[0]*x[n] + z0,   z_k <= z_{k+1} + h[k+1]*x[n],   z_last <= h[N-1]*x[n]
-- The new sample is multiplied by every coefficient at once and added into a chain of partial
-- sums, so the output is registered one clock after the input: 1 cycle of structural latency
-- instead of 3 + clog2(taps). Each tap is one multiply-add, which maps onto a DSP slice
-- with its adder (A*B + C) and the partial-sum register in its output register.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ddc_params_pkg.all;
use work.dsp_util_pkg.all;

entity fir_transposed is
  generic (
    G_COEFS : coef_t
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    in_valid  : in  std_logic;
    din       : in  signed(MIX_W - 1 downto 0);
    out_valid : out std_logic;
    dout      : out signed(OUT_W - 1 downto 0)
  );
end entity;

architecture rtl of fir_transposed is
  constant ACC_W : natural := MIX_W + COEF_W + clog2(FIR_TAPS);

  subtype acc_t is signed(ACC_W - 1 downto 0);
  type z_arr_t is array (0 to FIR_TAPS - 2) of acc_t;

  signal z  : z_arr_t := (others => (others => '0'));
  signal yv : std_logic := '0';
  signal y  : signed(OUT_W - 1 downto 0) := (others => '0');

  function mul(x : signed; k : natural) return acc_t is
  begin
    return resize(x * to_signed(G_COEFS(k), COEF_W), ACC_W);
  end function;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      yv <= '0';
      if in_valid = '1' then
        for k in 0 to FIR_TAPS - 3 loop
          z(k) <= z(k + 1) + mul(din, k + 1);
        end loop;
        z(FIR_TAPS - 2) <= mul(din, FIR_TAPS - 1);
        y  <= saturate(shift_right(z(0) + mul(din, 0), COEF_FRAC), OUT_W);
        yv <= '1';
      end if;

      if rst = '1' then
        z  <= (others => (others => '0'));
        yv <= '0';
      end if;
    end if;
  end process;

  out_valid <= yv;
  dout      <= y;
end architecture;
