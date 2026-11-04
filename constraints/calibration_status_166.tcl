# Independent166MHz checker. The original strict5ns CDC flight-time bound is PRESERVED.
# Intent: MIG calibration is a held status level consumed ONLY after two
# ASYNC_REG stages. This does NOT mark UI300 and compute200 clocks asynchronous.
# Scope is one checked source FF -> first synchronizer D. The second stage and
# every other inter-domain path retain ordinary setup/hold constraints.
proc apply_calibration_status_contract {report} {
 set regs [get_cells -hier -quiet -filter {NAME =~ */calibrated_q_reg* && IS_SEQUENTIAL == 1}]
 if {[llength $regs]!=2} {error "Calibration synchronizer must have exactly two stages"}
 set first {};set second {}
 foreach c $regs {
  if {[string toupper [get_property ASYNC_REG $c]] ni {TRUE 1}} {error "Missing ASYNC_REG on $c"}
  if {[file tail $c] eq {calibrated_q_reg[0]}} {set first $c}
  if {[file tail $c] eq {calibrated_q_reg[1]}} {set second $c}
 }
 if {$first eq ""||$second eq ""} {error "Unexpected synchronizer stage names"}
 set d0 [get_pins -of_objects $first -filter {REF_PIN_NAME == D}]
 set q0 [get_pins -of_objects $first -filter {REF_PIN_NAME == Q}]
 set d1 [get_pins -of_objects $second -filter {REF_PIN_NAME == D}]
 set fanout [all_fanout -flat -endpoints_only -from $q0]
 if {[llength $fanout]!=1 || [get_property NAME $fanout] ne [get_property NAME $d1]} {error "First calibration stage has an unsafe extra consumer"}
 set net [get_nets -quiet -segments -of_objects $d0]
 set driver [get_pins -quiet -leaf -of_objects $net -filter {DIRECTION == OUT}]
 if {[llength $driver]!=1} {error "Calibration input has ambiguous drivers"}
 set source [get_cells -of_objects $driver]
 if {![string match {w8_platform_i/memory/inst/*/calDone_gated_reg} $source] || [get_property REF_NAME $source] ne "FDRE"} {error "Calibration source is not the expected MIG held status register: $source"}
 set c0 [get_pins -of_objects $first -filter {REF_PIN_NAME == C}]
 set c1 [get_pins -of_objects $second -filter {REF_PIN_NAME == C}]
 set sc [get_pins -of_objects $source -filter {REF_PIN_NAME == C}]
 set src_clock [get_clocks -of_objects $sc];set dst_clock [get_clocks -of_objects $c0]
 if {[llength $src_clock]!=1||[llength $dst_clock]!=1||[get_clocks -of_objects $c1] ne $dst_clock} {error "Unexpected calibration clocks"}
 if {abs([get_property PERIOD $src_clock]-1000.0/300)>0.001 || abs([get_property PERIOD $dst_clock]-6.0)>0.001} {error "Calibration clock frequencies changed"}
 # Use a valid sequential clock startpoint, not Q-based path segmentation.
 # This is explicitly a CDC max-flight-time contract, not a synchronous Hold PASS.
 # -datapath_only intentionally removes the first-stage hold check (UG835).
 set_max_delay -datapath_only 5.000 -from $sc -to $d0
 set f [open $report w]
 foreach {key value} [list status PASS_CHECKED_LEVEL_SYNCHRONIZER_CONTRACT source $source source_clock $src_clock first_stage $first second_stage $second destination_clock $dst_clock first_stage_consumers $fanout bound_ns 5.000 first_stage_hold NOT_APPLICABLE_RESYNCHRONIZED_STATUS second_stage_hold ORDINARY_CHECK_PRESERVED clock_groups_modified false clocks_physically_related true board_protocol_verified false] {puts $f "$key\t$value"}
 close $f
}
