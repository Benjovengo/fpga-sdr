-- Built-in test signal: a real sine at a fixed frequency, from the same Q1.15 table as the NCO.
-- Lets the board demo run with no ADC attached (SW[3] = 0 selects it).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ddc_params_pkg.all;

entity tone_gen is
  generic (
    G_PHASE_INC : natural;            -- tone frequency = G_PHASE_INC / 2**32 * f_clk
    G_SHIFT     : natural := 1        -- amplitude = full scale / 2**G_SHIFT
  );
  port (
    clk  : in  std_logic;
    rst  : in  std_logic;
    dout : out signed(IN_W - 1 downto 0)
  );
end entity;

architecture rtl of tone_gen is
  signal phase : unsigned(PHASE_W - 1 downto 0) := (others => '0');
  signal y     : signed(IN_W - 1 downto 0) := (others => '0');
begin
  process (clk)
  begin
    if rising_edge(clk) then
      phase <= phase + G_PHASE_INC;
      y     <= shift_right(to_signed(COS_LUT(to_integer(phase(PHASE_W - 1 downto PHASE_W - LUT_AW))), IN_W),
                           G_SHIFT);
      if rst = '1' then
        phase <= (others => '0');
      end if;
    end if;
  end process;

  dout <= y;
end architecture;
