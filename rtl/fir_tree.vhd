-- Direct-form FIR with a fully pipelined binary adder tree (baseline architecture).
--   y[n] = sum_k h[k] * x[n-k]   (full precision, then floor-shift by COEF_FRAC and saturate)
-- Every multiply and every adder level has its own register, which is the textbook way to
-- reach a high clock rate, but it costs 3 + clog2(taps) cycles of structural latency
-- (delay line, products, adder levels, output register): 8 cycles for 31 taps.
-- The pipeline runs every clock; in_valid only advances the delay line.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ddc_params_pkg.all;
use work.dsp_util_pkg.all;

entity fir_tree is
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

architecture rtl of fir_tree is
  constant LEVELS : natural := clog2(FIR_TAPS);
  constant NP     : natural := 2**LEVELS;                 -- leaves, padded to a power of two
  constant ACC_W  : natural := MIX_W + COEF_W + LEVELS;

  subtype acc_t is signed(ACC_W - 1 downto 0);
  type x_arr_t is array (0 to FIR_TAPS - 1) of signed(MIX_W - 1 downto 0);
  -- heap layout: node i has children 2i+1 and 2i+2, leaves are NP-1 .. 2NP-2, root is 0
  type node_arr_t is array (0 to 2 * NP - 2) of acc_t;

  signal x     : x_arr_t := (others => (others => '0'));
  signal node  : node_arr_t := (others => (others => '0'));
  -- vpipe(0): x was just updated; vpipe(1): leaves valid; vpipe(1 + LEVELS): root valid
  signal vpipe : std_logic_vector(0 to LEVELS + 1) := (others => '0');
  signal yv    : std_logic := '0';
  signal y     : signed(OUT_W - 1 downto 0) := (others => '0');
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if in_valid = '1' then
        x(0) <= din;
        for k in 1 to FIR_TAPS - 1 loop
          x(k) <= x(k - 1);
        end loop;
      end if;

      -- leaves: one registered multiply per tap (one DSP slice each)
      for k in 0 to NP - 1 loop
        if k < FIR_TAPS then
          node(NP - 1 + k) <= resize(x(k) * to_signed(G_COEFS(k), COEF_W), ACC_W);
        end if;
      end loop;

      -- adder tree: every level registered
      for i in 0 to NP - 2 loop
        node(i) <= node(2 * i + 1) + node(2 * i + 2);
      end loop;

      vpipe <= in_valid & vpipe(0 to LEVELS);
      yv    <= vpipe(LEVELS + 1);
      y     <= saturate(shift_right(node(0), COEF_FRAC), OUT_W);

      if rst = '1' then
        vpipe <= (others => '0');
        yv    <= '0';
      end if;
    end if;
  end process;

  out_valid <= yv;
  dout      <= y;
end architecture;
