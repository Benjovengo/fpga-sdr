# Out-of-context synthesis + implementation of ddc_top for resource and timing numbers.
# Usage (from the repo root):
#   vivado -mode batch -source syn/build.tcl -tclargs <transposed 0|1> <minphase 0|1> [part]
# Default part: xc7z010clg225-1 (Zynq-7010, as on the ADALM-PLUTO). Reports go to build/vivado/.
set transposed [expr {[llength $argv] > 0 ? [lindex $argv 0] : 1}]
set minphase   [expr {[llength $argv] > 1 ? [lindex $argv 1] : 1}]
set part       [expr {[llength $argv] > 2 ? [lindex $argv 2] : "xc7z010clg225-1"}]

set root [file normalize [file dirname [info script]]/..]
set name [expr {$transposed ? "transposed" : "tree"}]_[expr {$minphase ? "minphase" : "linear"}]
set out  $root/build/vivado/$name
file mkdir $out

read_vhdl -vhdl2008 [list \
  $root/rtl/ddc_params_pkg.vhd \
  $root/rtl/dsp_util_pkg.vhd \
  $root/rtl/nco_mixer.vhd \
  $root/rtl/cic_decim.vhd \
  $root/rtl/fir_tree.vhd \
  $root/rtl/fir_transposed.vhd \
  $root/rtl/ddc_top.vhd]
read_xdc -mode out_of_context $root/syn/ddc.xdc

synth_design -top ddc_top -part $part -mode out_of_context \
  -generic G_TRANSPOSED=[expr {$transposed ? "true" : "false"}] \
  -generic G_MINPHASE=[expr {$minphase ? "true" : "false"}]
opt_design
place_design
route_design

report_utilization    -file $out/utilization.rpt
report_timing_summary -file $out/timing.rpt -max_paths 10
puts "Reports written to $out"
