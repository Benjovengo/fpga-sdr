# Pin assignments for the Terasic DE10-Nano (5CSEBA6U23I7), sourced from Quartus by build.tcl.
#
# Board I/O pins agree in three independent sources: Terasic System Builder output (DE10-Nano
# D8M project), MiSTer Template_MiSTer sys/sys.tcl and LiteX litex_boards terasic_de10nano.py.
# GPIO_0 (header JP1) pins are from the LiteX JP1 connector map; header pin numbers in brackets.

# 50 MHz oscillator, push-button, slide switches, LEDs
set_location_assignment PIN_V11  -to FPGA_CLK1_50
set_location_assignment PIN_AH17 -to KEY[0]
set_location_assignment PIN_AH16 -to KEY[1]
set_location_assignment PIN_Y24  -to SW[0]
set_location_assignment PIN_W24  -to SW[1]
set_location_assignment PIN_W21  -to SW[2]
set_location_assignment PIN_W20  -to SW[3]
set_location_assignment PIN_W15  -to LED[0]
set_location_assignment PIN_AA24 -to LED[1]
set_location_assignment PIN_V16  -to LED[2]
set_location_assignment PIN_V15  -to LED[3]
set_location_assignment PIN_AF26 -to LED[4]
set_location_assignment PIN_AE26 -to LED[5]
set_location_assignment PIN_Y16  -to LED[6]
set_location_assignment PIN_AA23 -to LED[7]

# 12-bit ADC module on GPIO_0 (JP1)
set_location_assignment PIN_V12  -to ADC_D[0]   ;# GPIO_0[0]  [JP1-1]
set_location_assignment PIN_E8   -to ADC_D[1]   ;# GPIO_0[1]  [JP1-2]
set_location_assignment PIN_W12  -to ADC_D[2]   ;# GPIO_0[2]  [JP1-3]
set_location_assignment PIN_D11  -to ADC_D[3]   ;# GPIO_0[3]  [JP1-4]
set_location_assignment PIN_D8   -to ADC_D[4]   ;# GPIO_0[4]  [JP1-5]
set_location_assignment PIN_AH13 -to ADC_D[5]   ;# GPIO_0[5]  [JP1-6]
set_location_assignment PIN_AF7  -to ADC_D[6]   ;# GPIO_0[6]  [JP1-7]
set_location_assignment PIN_AH14 -to ADC_D[7]   ;# GPIO_0[7]  [JP1-8]
set_location_assignment PIN_AF4  -to ADC_D[8]   ;# GPIO_0[8]  [JP1-9]
set_location_assignment PIN_AH3  -to ADC_D[9]   ;# GPIO_0[9]  [JP1-10]
set_location_assignment PIN_AD5  -to ADC_D[10]  ;# GPIO_0[10] [JP1-13]
set_location_assignment PIN_AG14 -to ADC_D[11]  ;# GPIO_0[11] [JP1-14]
set_location_assignment PIN_AE23 -to ADC_OTR    ;# GPIO_0[12] [JP1-15]
set_location_assignment PIN_AE6  -to ADC_CLK    ;# GPIO_0[13] [JP1-16]

# All of the above are 3.3 V banks on this board
foreach port {FPGA_CLK1_50 KEY[*] SW[*] LED[*] ADC_D[*] ADC_OTR ADC_CLK} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to $port
}

# Capture ADC data in the I/O element registers for the tightest, repeatable input timing
set_instance_assignment -name FAST_INPUT_REGISTER ON -to ADC_D[*]
set_instance_assignment -name FAST_INPUT_REGISTER ON -to ADC_OTR
