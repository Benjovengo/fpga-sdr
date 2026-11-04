# Quartus Prime (Lite or Standard) build for the Terasic DE10-Nano.
# Usage, from the repository root:
#   quartus_sh -t boards/de10nano/build.tcl
# Output: build/quartus/de10nano/output_files/de10nano.sof (program with quartus_pgm or the GUI)
load_package flow

set root  [file normalize [file dirname [info script]]/../..]
set board $root/boards/de10nano
set out   $root/build/quartus/de10nano
file mkdir $out
cd $out

project_new de10nano -overwrite
set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE 5CSEBA6U23I7
set_global_assignment -name TOP_LEVEL_ENTITY de10nano_top
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files

foreach f {
    rtl/ddc_params_pkg.vhd rtl/dsp_util_pkg.vhd rtl/nco_mixer.vhd rtl/cic_decim.vhd
    rtl/fir_tree.vhd rtl/fir_transposed.vhd rtl/ddc_top.vhd
    boards/de10nano/tone_gen.vhd boards/de10nano/level_meter.vhd boards/de10nano/de10nano_top.vhd
} {
    set_global_assignment -name VHDL_FILE $root/$f
}
set_global_assignment -name SDC_FILE $board/de10nano.sdc
source $board/pins.tcl

# Unused pins as inputs with weak pull-ups: safe with whatever is plugged into the headers
set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED WITH WEAK PULL-UP"

execute_flow -compile
project_close
puts "Bitstream: $out/output_files/de10nano.sof"
