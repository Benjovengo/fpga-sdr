-- Digital down-converter: NCO/mixer -> CIC decimator (CIC_R:1) -> FIR channel filter, per I/Q.
-- Two generics select the latency-relevant design choices, so all four variants can be
-- simulated and synthesized from the same source:
--   G_TRANSPOSED : FIR structure  -- false: pipelined adder tree, true: transposed form
--   G_MINPHASE   : FIR phase      -- false: linear phase,         true: minimum phase
-- Streaming interface without back-pressure (a radio front-end cannot be stalled).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ddc_params_pkg.all;

entity ddc_top is
  generic (
    G_TRANSPOSED : boolean := true;
    G_MINPHASE   : boolean := true
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    phase_inc : in  unsigned(PHASE_W - 1 downto 0);
    in_valid  : in  std_logic;
    in_i      : in  signed(IN_W - 1 downto 0);
    in_q      : in  signed(IN_W - 1 downto 0);
    out_valid : out std_logic;
    out_i     : out signed(OUT_W - 1 downto 0);
    out_q     : out signed(OUT_W - 1 downto 0)
  );
end entity;

architecture rtl of ddc_top is
  function select_coefs(minphase : boolean) return coef_t is
  begin
    if minphase then
      return COEF_MINPHASE;
    end if;
    return COEF_LINEAR;
  end function;

  constant COEFS : coef_t := select_coefs(G_MINPHASE);

  signal mix_valid : std_logic;
  signal mix_i     : signed(MIX_W - 1 downto 0);
  signal mix_q     : signed(MIX_W - 1 downto 0);
  signal cic_valid : std_logic;
  signal cic_i     : signed(MIX_W - 1 downto 0);
  signal cic_q     : signed(MIX_W - 1 downto 0);
begin
  u_mix : entity work.nco_mixer
    port map (
      clk => clk, rst => rst, phase_inc => phase_inc,
      in_valid => in_valid, in_i => in_i, in_q => in_q,
      out_valid => mix_valid, out_i => mix_i, out_q => mix_q);

  u_cic_i : entity work.cic_decim
    port map (clk => clk, rst => rst, in_valid => mix_valid, din => mix_i,
              out_valid => cic_valid, dout => cic_i);

  u_cic_q : entity work.cic_decim
    port map (clk => clk, rst => rst, in_valid => mix_valid, din => mix_q,
              out_valid => open, dout => cic_q);

  gen_fir_transposed : if G_TRANSPOSED generate
    u_fir_i : entity work.fir_transposed
      generic map (G_COEFS => COEFS)
      port map (clk => clk, rst => rst, in_valid => cic_valid, din => cic_i,
                out_valid => out_valid, dout => out_i);
    u_fir_q : entity work.fir_transposed
      generic map (G_COEFS => COEFS)
      port map (clk => clk, rst => rst, in_valid => cic_valid, din => cic_q,
                out_valid => open, dout => out_q);
  end generate;

  gen_fir_tree : if not G_TRANSPOSED generate
    u_fir_i : entity work.fir_tree
      generic map (G_COEFS => COEFS)
      port map (clk => clk, rst => rst, in_valid => cic_valid, din => cic_i,
                out_valid => out_valid, dout => out_i);
    u_fir_q : entity work.fir_tree
      generic map (G_COEFS => COEFS)
      port map (clk => clk, rst => rst, in_valid => cic_valid, din => cic_q,
                out_valid => open, dout => out_q);
  end generate;
end architecture;
