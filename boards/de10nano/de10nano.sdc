# Timing constraints for the DE10-Nano DDC build.
create_clock -name clk50 -period 20.000 [get_ports FPGA_CLK1_50]
derive_clock_uncertainty

# ADC_CLK is the 50 MHz clock forwarded to the ADC on GPIO_0.
create_generated_clock -name adc_clk -source [get_ports FPGA_CLK1_50] [get_ports ADC_CLK]

# ADC data output delay after its clock edge: take the max/min from the datasheet of the module's
# converter (AD9226 class: a few ns) plus board and jumper-wire skew. The data is captured by the
# next clk50 edge, a full 20 ns period after the ADC clock edge that launched it.
set_input_delay -clock adc_clk -max 9.0 [get_ports {ADC_D[*] ADC_OTR}]
set_input_delay -clock adc_clk -min 1.0 [get_ports {ADC_D[*] ADC_OTR}]

# Human-speed I/O: buttons and switches are synchronized in logic, LEDs are not timing-critical.
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LED[*]}]
