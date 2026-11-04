-- Signal-level meter for the DDC output: |I| + |Q| (an envelope estimate within -3 dB of the
-- true magnitude), smoothed by a leaky integrator, then shown as an 8-LED logarithmic bar:
-- LED k lights when the level is at least 2**(G_LSB_EXP + k), i.e. 6 dB per LED.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ddc_params_pkg.all;

entity level_meter is
  generic (
    G_LSB_EXP : natural := 6;   -- LED 0 threshold = 2**G_LSB_EXP
    G_AVG     : natural := 4    -- smoothing: time constant ~ 2**G_AVG output samples
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    in_valid : in  std_logic;
    in_i     : in  signed(OUT_W - 1 downto 0);
    in_q     : in  signed(OUT_W - 1 downto 0);
    leds     : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of level_meter is
  constant ACC_W : natural := OUT_W + 1 + G_AVG;
  signal acc     : unsigned(ACC_W - 1 downto 0) := (others => '0');
  signal bar     : std_logic_vector(7 downto 0) := (others => '0');
begin
  process (clk)
    variable mag   : unsigned(OUT_W downto 0);
    variable level : unsigned(ACC_W - 1 downto 0);
  begin
    if rising_edge(clk) then
      if in_valid = '1' then
        mag := resize(unsigned(abs(resize(in_i, OUT_W + 1))), OUT_W + 1)
             + resize(unsigned(abs(resize(in_q, OUT_W + 1))), OUT_W + 1);
        -- acc converges to mag * 2**G_AVG
        acc <= acc - shift_right(acc, G_AVG) + resize(mag, ACC_W);
      end if;

      level := shift_right(acc, G_AVG);
      for k in 0 to 7 loop
        if level >= to_unsigned(2**(G_LSB_EXP + k), ACC_W) then
          bar(k) <= '1';
        else
          bar(k) <= '0';
        end if;
      end loop;

      if rst = '1' then
        acc <= (others => '0');
        bar <= (others => '0');
      end if;
    end if;
  end process;

  leds <= bar;
end architecture;
