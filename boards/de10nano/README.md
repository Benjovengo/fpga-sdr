# Terasic DE10-Nano board target

Runs the low-latency DDC (transposed FIR, minimum-phase coefficients) on a
[Terasic DE10-Nano](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=1046):
Intel Cyclone V SoC **5CSEBA6U23I7**, 110K LEs, 112 variable-precision DSP blocks.

The board has no radio front-end, so the demo works in two modes:

* **Built-in test tone** (no extra hardware): a 10 MHz sine generated in the FPGA.
* **External ADC**: a 12-bit parallel ADC module (AD9226 class, up to 65 MSPS) on the GPIO_0
  header, clocked at 50 MSPS by the FPGA. Feed it from a signal generator or an antenna front-end.

## Controls

| Control | Function |
|---|---|
| `KEY0` | Reset |
| `SW3` | Input: **down** = built-in 10 MHz tone, **up** = external ADC |
| `SW2..SW0` | Tuning: NCO at **6 + SW[2:0] MHz** (000 = 6 MHz … 111 = 13 MHz; 100 = 10 MHz) |
| `LED7..LED0` | Signal level in the tuned channel: a bar graph, **6 dB per LED**. With the ADC selected, `LED7` also lights on ADC overrange |

The channel passband is ±0.78 MHz (output rate 6.25 MSPS), with the stopband from ±1.41 MHz.
Flip the tuning switches with the built-in tone selected (bit-accurate model):

| SW[2:0] | NCO | Tone offset | LEDs |
|---|---|---|---|
| `000`, `001`, `010` | 6, 7, 8 MHz | −4, −3, −2 MHz | 0 |
| `011` | 9 MHz | −1 MHz | 7 (transition band, ~2 dB down) |
| `100` | 10 MHz | 0 | **8** |
| `101` | 11 MHz | +1 MHz | 7 (transition band) |
| `110`, `111` | 12, 13 MHz | +2, +3 MHz | 0 |

That's the CIC + FIR selectivity at work: more than 60 dB between the tuned channel and a tone
2 MHz away.

## ADC wiring (GPIO_0 / JP1)

| Signal | FPGA pin | GPIO_0 | JP1 pin |
|---|---|---|---|
| `ADC_D[0]` (LSB) | V12 | GPIO_0[0] | 1 |
| `ADC_D[1]` | E8 | GPIO_0[1] | 2 |
| `ADC_D[2]` | W12 | GPIO_0[2] | 3 |
| `ADC_D[3]` | D11 | GPIO_0[3] | 4 |
| `ADC_D[4]` | D8 | GPIO_0[4] | 5 |
| `ADC_D[5]` | AH13 | GPIO_0[5] | 6 |
| `ADC_D[6]` | AF7 | GPIO_0[6] | 7 |
| `ADC_D[7]` | AH14 | GPIO_0[7] | 8 |
| `ADC_D[8]` | AF4 | GPIO_0[8] | 9 |
| `ADC_D[9]` | AH3 | GPIO_0[9] | 10 |
| `ADC_D[10]` | AD5 | GPIO_0[10] | 13 |
| `ADC_D[11]` (MSB) | AG14 | GPIO_0[11] | 14 |
| `ADC_OTR` | AE23 | GPIO_0[12] | 15 |
| `ADC_CLK` (output) | AE6 | GPIO_0[13] | 16 |
| GND | | | 12 or 30 |

JP1 pins 11 (5 V), 12 (GND), 29 (3.3 V) and 30 (GND) are power. The data format is offset binary
(AD9226 default), converted to two's complement in the FPGA.

> **The GPIO header is 3.3 V only.** Check that the ADC module's digital outputs (DRVDD) run at
> 3.3 V before connecting it. Many AD9226 modules are powered from 5 V but have 3.3 V outputs;
> some don't. Keep the jumper wires short: the data is captured at 50 MHz.

## Building

Requires Intel Quartus Prime Lite (free) with Cyclone V support.

```bash
quartus_sh -t boards/de10nano/build.tcl      # from the repository root
quartus_pgm -m jtag -o "p;build/quartus/de10nano/output_files/de10nano.sof@2"
```

`@2` is the FPGA's position in the JTAG chain (the HPS is device 1). `make quartus` runs the
build step.

## Files

| File | Contents |
|---|---|
| `de10nano_top.vhd` | Top level: reset/switch synchronizers, ADC capture, tuning table, DDC, meter |
| `tone_gen.vhd` | Built-in 10 MHz test tone |
| `level_meter.vhd` | \|I\| + \|Q\| envelope, smoothing, logarithmic LED bar |
| `pins.tcl` | Pin assignments, I/O standards, fast input registers |
| `de10nano.sdc` | Clock and ADC input timing constraints |
| `build.tcl` | Quartus project creation and compilation |

## Verification

`tb/tb_de10nano.vhd` drives the real top-level pins in simulation (`make sim`):

| Test | Setup | Result |
|---|---|---|
| `test_tone_tuned` | built-in tone, NCO at 10 MHz | 8 of 8 LEDs |
| `test_tone_detuned` | built-in tone, NCO at 6 MHz | 0 of 8 LEDs |
| `adc_tone_tuned` | ADC model on GPIO_0, 10 MHz at half scale | 8 of 8 LEDs |
| `adc_overrange` | ADC model asserts OTR | LED7 on |

**Pin sources.** The board I/O pins agree across three independent sources: a Terasic System
Builder project, MiSTer's `sys/sys.tcl` and LiteX's `terasic_de10nano.py`. The GPIO_0 pins come
from LiteX's JP1 connector map. Quartus synthesis and on-board testing have not been done yet.
