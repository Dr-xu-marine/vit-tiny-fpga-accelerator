# MANUAL RUN ONLY after successful matching Bitstream download.
# Does not program a device, flash, change clocks, or select a guessed AXI master.
set handles [get_hw_axis -quiet]
if {[llength $handles]!=1} {error "Select/check the actual JTAG AXI master; expected exactly one"}
set kit_dir [file normalize [file dirname [info script]]]
source [file join $kit_dir host_w8.tcl]
tiny_host::bind [lindex $handles 0]
if {[tiny_host::read32 0x34]!=0x56313238 || [tiny_host::read32 0x3c]!=128 || [tiny_host::read32 0x38]!=166666666} {error WRONG_166MHZ_128MAC_ABI}
tiny_host::wait_status 8 8 30000
# Scratch is outside the frozen8.99MB payload, within the actual2GiB DDR window.
set pattern {11223344 55667788 deadbeef 80ff0102}
tiny_host::transfer WRITE 0x1ff00000 $pattern
if {[tiny_host::transfer READ 0x1ff00000 {00000000 00000000 00000000 00000000}] ne $pattern} {error DDR_OR_HOST_WORD_ORDER_FAIL}
puts HOST_DDR_SCRATCH_PASS
# The observed output is written here; frozen input/Golden files are never overwritten.
set observed_file [file join $kit_dir observed_1000_[clock seconds].hex]
tiny_host::run [file join $kit_dir ddr.bin] [file join $kit_dir expected_1000.hex] $observed_file
puts "BOARD_TEST_OBSERVED_FILE $observed_file"
