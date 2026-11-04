-- Self-checking testbench for ddc_top (VUnit).
--   bit_exact_tone : tone + interferer + noise; every output sample must equal the Python model.
--   latency_step   : DC step on I; also bit-exact, and measures latency in clock cycles:
--                    first_response = input edge -> first non-zero output register update
--                    step_50        = input edge -> output reaches 50 % of its final value
-- Latency is counted in clock edges between the edge that captures the input sample and the
-- edge that registers the output (a purely combinational path would count as 0).
-- One input sample per clock (in_valid always high), CIC_R input samples per output sample.
library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.ddc_params_pkg.all;

entity tb_ddc is
  generic (
    runner_cfg    : string;
    G_TRANSPOSED  : boolean := true;
    G_MINPHASE    : boolean := true;
    G_VEC_DIR     : string;   -- written by run.py from the Python model
    G_RESULT_FILE : string    -- prefix for the latency results this configuration writes
  );
end entity;

architecture tb of tb_ddc is
  constant CLK_PERIOD : time := 4 ns;

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal phase_inc : unsigned(PHASE_W - 1 downto 0) := (others => '0');
  signal in_valid  : std_logic := '0';
  signal in_i      : signed(IN_W - 1 downto 0) := (others => '0');
  signal in_q      : signed(IN_W - 1 downto 0) := (others => '0');
  signal out_valid : std_logic;
  signal out_i     : signed(OUT_W - 1 downto 0);
  signal out_q     : signed(OUT_W - 1 downto 0);

  function coef_name(minphase : boolean) return string is
  begin
    if minphase then
      return "minphase";
    end if;
    return "linear";
  end function;
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.ddc_top
    generic map (G_TRANSPOSED => G_TRANSPOSED, G_MINPHASE => G_MINPHASE)
    port map (
      clk => clk, rst => rst, phase_inc => phase_inc,
      in_valid => in_valid, in_i => in_i, in_q => in_q,
      out_valid => out_valid, out_i => out_i, out_q => out_q);

  main : process
    -- Streams <case>_in.txt into the DUT, checks against <case>_<coefs>_out.txt and
    -- returns the measured latencies (-1 if never reached).
    procedure run_case(name : string; first_response, step_50 : out integer) is
      file fin  : text open read_mode is G_VEC_DIR & "/" & name & "_in.txt";
      file fexp : text open read_mode is G_VEC_DIR & "/" & name & "_" & coef_name(G_MINPHASE) & "_out.txt";
      variable lin, lexp      : line;
      variable inc, xi, xq    : integer;
      variable exp_count      : integer;
      variable final_i        : integer;
      variable ei, eq         : integer;
      variable edge, n_out    : natural := 0;
      variable first_in_edge  : integer := -1;
      variable idle           : natural := 0;
    begin
      first_response := -1;
      step_50        := -1;
      readline(fin, lin);
      read(lin, inc);
      readline(fexp, lexp);
      read(lexp, exp_count);
      read(lexp, final_i);
      phase_inc <= to_unsigned(inc, PHASE_W);

      rst <= '1';
      for k in 1 to 4 loop
        wait until rising_edge(clk);
      end loop;
      rst <= '0';

      while idle < 200 loop
        -- drive the sample that the next edge (number `edge`) captures
        if not endfile(fin) then
          readline(fin, lin);
          read(lin, xi);
          read(lin, xq);
          in_valid <= '1';
          in_i     <= to_signed(xi, IN_W);
          in_q     <= to_signed(xq, IN_W);
          if first_in_edge < 0 and (xi /= 0 or xq /= 0) then
            first_in_edge := edge;
          end if;
        else
          in_valid <= '0';
          idle     := idle + 1;
        end if;

        wait until rising_edge(clk);
        -- outputs seen here were registered by the previous edge, number edge - 1
        if out_valid = '1' then
          check(not endfile(fexp), "more output samples than the model produced");
          readline(fexp, lexp);
          read(lexp, ei);
          read(lexp, eq);
          check_equal(to_integer(out_i), ei, "out_i, output sample " & integer'image(n_out));
          check_equal(to_integer(out_q), eq, "out_q, output sample " & integer'image(n_out));
          if first_in_edge >= 0 then
            if first_response < 0 and (out_i /= 0 or out_q /= 0) then
              first_response := edge - 1 - first_in_edge;
            end if;
            if step_50 < 0 and 2 * abs(to_integer(out_i)) >= abs(final_i) then
              step_50 := edge - 1 - first_in_edge;
            end if;
          end if;
          n_out := n_out + 1;
        end if;
        edge := edge + 1;
      end loop;

      check_equal(n_out, exp_count, "number of output samples");
    end procedure;

    procedure write_result(name : string; first_response, step_50 : integer) is
      file fout : text open write_mode is G_RESULT_FILE & "_" & name & ".txt";
      variable l : line;
    begin
      write(l, integer'image(first_response) & " " & integer'image(step_50) & " " & integer'image(CIC_R));
      writeline(fout, l);
    end procedure;

    variable first_response, step_50 : integer;
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("bit_exact_tone") then
        run_case("tone", first_response, step_50);
      elsif run("latency_step") then
        run_case("step", first_response, step_50);
        check(first_response >= 0, "output never responded to the step");
        check(step_50 >= 0, "output never reached 50 % of the final value");
        info("latency: first response " & integer'image(first_response) & " cycles, 50 % of step "
             & integer'image(step_50) & " cycles");
        write_result("step", first_response, step_50);
      end if;
    end loop;
    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 1 ms);
end architecture;
