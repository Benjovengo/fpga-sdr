-- Terasic DE10-Nano (Intel Cyclone V SoC 5CSEBA6U23I7) top level for the low-latency DDC.
--
--   FPGA_CLK1_50  50 MHz clock = sample clock (one sample per clock, output rate 6.25 MSPS)
--   KEY[0]        reset (active low)
--   SW[3]         input: 0 = built-in 10 MHz test tone, 1 = external ADC on GPIO_0
--   SW[2:0]       tuning: NCO at 6 + SW[2:0] MHz (6..13 MHz; the test tone is at 10 MHz = "100")
--   LED[7:0]      signal level in the selected channel, 6 dB per LED; LED[7] also shows ADC overrange
--   ADC_*         AD9226-style 12-bit parallel ADC module on the GPIO_0 header (see README.md)
--
-- The DDC runs in its low-latency configuration (transposed FIR, minimum-phase coefficients).
-- Port names follow the Terasic System Builder; pins are assigned in pins.tcl.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ddc_params_pkg.all;

entity de10nano_top is
  port (
    FPGA_CLK1_50 : in  std_logic;
    KEY          : in  std_logic_vector(1 downto 0);
    SW           : in  std_logic_vector(3 downto 0);
    LED          : out std_logic_vector(7 downto 0);
    ADC_CLK      : out std_logic;
    ADC_D        : in  std_logic_vector(11 downto 0);   -- offset binary
    ADC_OTR      : in  std_logic
  );
end entity;

architecture rtl of de10nano_top is
  constant F_CLK_HZ : real := 50.0e6;

  function phase_inc_for(f_hz : real) return natural is
  begin
    return natural(f_hz / F_CLK_HZ * 2.0**PHASE_W);
  end function;

  type inc_table_t is array (0 to 7) of natural;
  function make_tuning_table return inc_table_t is
    variable t : inc_table_t;
  begin
    for k in t'range loop
      t(k) := phase_inc_for((6.0 + real(k)) * 1.0e6);
    end loop;
    return t;
  end function;
  constant TUNING : inc_table_t := make_tuning_table;

  signal clk       : std_logic;
  signal rst_sync  : std_logic_vector(1 downto 0) := (others => '1');
  signal rst       : std_logic;
  signal sw_meta   : std_logic_vector(3 downto 0) := (others => '0');
  signal sw_sync   : std_logic_vector(3 downto 0) := (others => '0');

  signal adc_r     : std_logic_vector(11 downto 0) := (others => '0');
  signal otr_r     : std_logic := '0';
  signal adc_s     : signed(IN_W - 1 downto 0) := (others => '0');
  signal tone      : signed(IN_W - 1 downto 0);
  signal ddc_in    : signed(IN_W - 1 downto 0) := (others => '0');
  signal phase_inc : unsigned(PHASE_W - 1 downto 0) := (others => '0');

  signal out_valid : std_logic;
  signal out_i     : signed(OUT_W - 1 downto 0);
  signal out_q     : signed(OUT_W - 1 downto 0);
  signal bar       : std_logic_vector(7 downto 0);
begin
  clk <= FPGA_CLK1_50;

  -- The ADC is clocked in phase with the FPGA: a sample it starts on edge n is output a few ns
  -- later and captured by the FPGA on edge n+1, a full period later (generous setup and hold).
  ADC_CLK <= clk;

  process (clk)
  begin
    if rising_edge(clk) then
      -- asynchronous push-button and switches: two-flop synchronizers
      rst_sync <= rst_sync(0) & not KEY(0);
      sw_meta  <= SW;
      sw_sync  <= sw_meta;

      -- ADC capture (placed in the I/O registers, see pins.tcl); offset binary -> two's
      -- complement, then scaled to the DDC's 16-bit input
      adc_r <= ADC_D;
      otr_r <= ADC_OTR;
      adc_s <= signed(not adc_r(11) & adc_r(10 downto 0)) & to_signed(0, IN_W - 12);

      if sw_sync(3) = '1' then
        ddc_in <= adc_s;
      else
        ddc_in <= tone;
      end if;
      phase_inc <= to_unsigned(TUNING(to_integer(unsigned(sw_sync(2 downto 0)))), PHASE_W);
    end if;
  end process;
  rst <= rst_sync(1);

  u_tone : entity work.tone_gen
    generic map (G_PHASE_INC => phase_inc_for(10.0e6))
    port map (clk => clk, rst => rst, dout => tone);

  -- Real input: I = signal, Q = 0. The mixer turns it into a complex baseband signal.
  u_ddc : entity work.ddc_top
    generic map (G_TRANSPOSED => true, G_MINPHASE => true)
    port map (
      clk => clk, rst => rst, phase_inc => phase_inc,
      in_valid => '1', in_i => ddc_in, in_q => (others => '0'),
      out_valid => out_valid, out_i => out_i, out_q => out_q);

  u_meter : entity work.level_meter
    port map (clk => clk, rst => rst, in_valid => out_valid, in_i => out_i, in_q => out_q,
              leds => bar);

  LED(7)          <= bar(7) or (otr_r and sw_sync(3));
  LED(6 downto 0) <= bar(6 downto 0);
end architecture;
