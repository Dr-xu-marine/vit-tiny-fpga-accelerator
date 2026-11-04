# Target-specific REAL hardware clock contract. No new clock or exception.
set w8_cores [get_cells -hier -quiet -filter {REF_NAME == w8_hosted_core}]
if {[llength $w8_cores]!=1} {error COMPUTE_CORE_NOT_UNIQUE}
set w8_pin [get_pins -of_objects $w8_cores -filter {REF_PIN_NAME == clk}]
set w8_compute_clock [get_clocks -of_objects $w8_pin]
if {[llength $w8_compute_clock]!=1} {error COMPUTE_CLOCK_NOT_UNIQUE}
set w8_period [get_property PERIOD $w8_compute_clock]
if {abs($w8_period-6.000)>0.001} {error "REAL_COMPUTE_NOT_6NS actual=$w8_period"}
if {![get_property IS_GENERATED $w8_compute_clock]} {error CLOCK_NOT_GENERATED}
set cp [get_pins -quiet [get_property SOURCE_PINS $w8_compute_clock]]
set cm [get_cells -quiet -of_objects $cp]
if {[llength $cm]!=1 || [get_property REF_NAME $cm] ne "MMCME4_ADV" || [get_property REF_PIN_NAME $cp] ne "CLKOUT0"} {error COMPUTE_NOT_MMCM_CLKOUT0}
foreach {k v} {DIVCLK_DIVIDE 3 CLKFBOUT_MULT_F 10.000 CLKOUT0_DIVIDE_F 6.000} {
 if {abs([get_property $k $cm]-$v)>0.000001} {error "ACTUAL_MMCM_RATIO_MISMATCH $k"}
}
set mc [get_clocks -quiet [get_property MASTER_CLOCK $w8_compute_clock]]
if {[llength $mc]!=1 || abs([get_property PERIOD $mc]-1000.0/300)>0.001} {error COMPUTE_MASTER_NOT_UI300}
set mp [get_pins -quiet [get_property SOURCE_PINS $mc]]
set mm [get_cells -quiet -of_objects $mp]
if {[llength $mm]!=1 || [get_property REF_PIN_NAME $mp] ne "CLKOUT0" || [get_property DIVCLK_DIVIDE $mm]!=1 || abs([get_property CLKFBOUT_MULT_F $mm]-6)>0.000001 || abs([get_property CLKOUT0_DIVIDE_F $mm]-5)>0.000001 || abs([get_property CLKIN1_PERIOD $mm]-4)>0.001} {error COMPUTE_MASTER_MIG_RATIO_MISMATCH}
# Exact primary/master ratio: fixed250MHz -> UI300 -> compute166.666667.
set exact_compute_period [expr {4.0*1*5/6*3*6/10}]
if {abs($exact_compute_period-6.0)>0.000001} {error EXACT_CLOCK_RATIO_FAILURE}
set_clock_uncertainty -setup 0.100 $w8_compute_clock
set_clock_uncertainty -hold 0.050 $w8_compute_clock
puts "REAL_COMPUTE_CLOCK_PASS clock=$w8_compute_clock period=$w8_period exact_period=$exact_compute_period MMCM=$cm setup_UU=.100 hold_UU=.050"
