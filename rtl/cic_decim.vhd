-- CIC decimator (Hogenauer), CIC_N stages, CIC_R:1, differential delay 1, one real channel.
-- Integrators run at the input rate, combs only on decimated samples. Registers wrap around
-- (two's complement), which is exact for a CIC as long as CIC_W >= MIX_W + N*log2(R).
-- The gain R**N = 2**CIC_GROWTH is removed with a shift, so the DC gain is exactly 1.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ddc_params_pkg.all;

entity cic_decim is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    in_valid  : in  std_logic;
    din       : in  signed(MIX_W - 1 downto 0);
    out_valid : out std_logic;
    dout      : out signed(MIX_W - 1 downto 0)
  );
end entity;

architecture rtl of cic_decim is
  subtype acc_t is signed(CIC_W - 1 downto 0);
  type acc_arr_t is array (0 to CIC_N - 1) of acc_t;

  signal integ : acc_arr_t := (others => (others => '0'));
  signal delay : acc_arr_t := (others => (others => '0'));
  signal comb  : acc_arr_t := (others => (others => '0'));
  signal cnt   : natural range 0 to CIC_R - 1 := 0;
  signal dec   : acc_t := (others => '0');
  -- cv(0): dec holds a new decimated sample; cv(k): comb(k-1) holds a new sample
  signal cv    : std_logic_vector(0 to CIC_N) := (others => '0');
  signal yv    : std_logic := '0';
  signal y     : signed(MIX_W - 1 downto 0) := (others => '0');
begin
  process (clk)
    variable comb_in : acc_t;
  begin
    if rising_edge(clk) then
      -- integrators and decimation
      cv(0) <= '0';
      if in_valid = '1' then
        integ(0) <= integ(0) + resize(din, CIC_W);
        for k in 1 to CIC_N - 1 loop
          integ(k) <= integ(k) + integ(k - 1);
        end loop;
        if cnt = CIC_R - 1 then
          cnt   <= 0;
          dec   <= integ(CIC_N - 1);
          cv(0) <= '1';
        else
          cnt <= cnt + 1;
        end if;
      end if;

      -- comb chain: each stage works only when its input carries a new sample
      for k in 0 to CIC_N - 1 loop
        cv(k + 1) <= cv(k);
        if cv(k) = '1' then
          if k = 0 then
            comb_in := dec;
          else
            comb_in := comb(k - 1);
          end if;
          comb(k)  <= comb_in - delay(k);
          delay(k) <= comb_in;
        end if;
      end loop;

      -- remove the R**N gain
      yv <= cv(CIC_N);
      if cv(CIC_N) = '1' then
        y <= resize(shift_right(comb(CIC_N - 1), CIC_GROWTH), MIX_W);
      end if;

      if rst = '1' then
        integ <= (others => (others => '0'));
        delay <= (others => (others => '0'));
        cnt   <= 0;
        cv    <= (others => '0');
        yv    <= '0';
      end if;
    end if;
  end process;

  out_valid <= yv;
  dout      <= y;
end architecture;
