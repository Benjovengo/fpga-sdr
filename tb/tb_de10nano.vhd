-- Board-level testbench for de10nano_top: drives the real top-level pins (50 MHz clock, KEY,
-- SW, the ADC header) and checks the LED level meter.
--   test_tone_tuned    : built-in 10 MHz tone, NCO at 10 MHz      -> at least 6 LEDs on
--   test_tone_detuned  : built-in 10 MHz tone, NCO at 6 MHz       -> at most 1 LED on
--   adc_tone_tuned     : ADC model on GPIO_0 sends a 10 MHz tone  -> at least 6 LEDs on
--   adc_overrange      : ADC asserts OTR                          -> LED[7] on
library vunit_lib;
context vunit_lib.vunit_context;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_de10nano is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_de10nano is
  constant CLK_PERIOD : time := 20 ns;    -- FPGA_CLK1_50
  constant ADC_TPD    : time := 5 ns;     -- ADC data output delay after its clock edge

  signal clk      : std_logic := '0';
  signal key      : std_logic_vector(1 downto 0) := "11";
  signal sw       : std_logic_vector(3 downto 0) := "0000";
  signal led      : std_logic_vector(7 downto 0);
  signal adc_clk  : std_logic;
  signal adc_d    : std_logic_vector(11 downto 0) := x"800";
  signal adc_otr  : std_logic := '0';
  signal adc_amp  : real := 0.0;          -- ADC model tone amplitude, in LSB
  signal adc_n    : natural := 0;

  function leds_on(v : std_logic_vector) return natural is
    variable n : natural := 0;
  begin
    for k in v'range loop
      if v(k) = '1' then
        n := n + 1;
      end if;
    end loop;
    return n;
  end function;
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.de10nano_top
    port map (FPGA_CLK1_50 => clk, KEY => key, SW => sw, LED => led,
              ADC_CLK => adc_clk, ADC_D => adc_d, ADC_OTR => adc_otr);

  -- 12-bit offset-binary ADC clocked by ADC_CLK: a 10 MHz tone at 50 MSPS
  adc_model : process (adc_clk)
    variable x : integer;
  begin
    if rising_edge(adc_clk) then
      x := 2048 + integer(round(adc_amp * cos(MATH_2_PI * 10.0e6 * real(adc_n) / 50.0e6)));
      adc_d <= std_logic_vector(to_unsigned(x, 12)) after ADC_TPD;
      adc_n <= adc_n + 1;
    end if;
  end process;

  main : process
    procedure reset_and_settle is
    begin
      key(0) <= '0';
      wait for 10 * CLK_PERIOD;
      key(0) <= '1';
      wait for 4000 * CLK_PERIOD;       -- ~500 output samples: DDC and meter fully settled
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("test_tone_tuned") then
        sw <= "0100";                   -- built-in tone, NCO at 6 + 4 = 10 MHz
        reset_and_settle;
        info("LEDs on: " & integer'image(leds_on(led)));
        check(leds_on(led) >= 6, "tuned tone should light at least 6 LEDs");

      elsif run("test_tone_detuned") then
        sw <= "0000";                   -- NCO at 6 MHz, 4 MHz away from the tone
        reset_and_settle;
        info("LEDs on: " & integer'image(leds_on(led)));
        check(leds_on(led) <= 1, "a tone 4 MHz outside the channel should be rejected");

      elsif run("adc_tone_tuned") then
        adc_amp <= 1000.0;              -- about half of full scale
        sw <= "1100";                   -- external ADC, NCO at 10 MHz
        reset_and_settle;
        info("LEDs on: " & integer'image(leds_on(led)));
        check(leds_on(led) >= 6, "ADC tone in the channel should light at least 6 LEDs");

      elsif run("adc_overrange") then
        sw <= "1000";
        adc_otr <= '1';
        reset_and_settle;
        check_equal(led(7), '1', "LED[7] must show ADC overrange");
      end if;
    end loop;
    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 1 ms);
end architecture;
