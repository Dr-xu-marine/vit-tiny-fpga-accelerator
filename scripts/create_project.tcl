# Publication preparation entry point, NOT executed/tested during release packaging.
set ::public_root [file normalize [file join [file dirname [info script]] ..]]
if {![regexp {^2023\.2([^0-9]|$)} [version -short]]} {error VIVADO_2023_2_REQUIRED}
if {[llength [get_projects -quiet]]} {error CLOSE_EXISTING_PROJECT_FIRST}
set output [file join $::public_root build board166]
if {[file exists $output]} {error FRESH_OUTPUT_REQUIRED}
set rom [file join $::public_root data package program.hex]
if {![file isfile $rom]} {error MATCHING_PROGRAM_ROM_REQUIRED}
set_param general.maxThreads 1
set_param board.repoPaths [list [file join $::public_root ip board_repo]]
file mkdir $output
create_project public166 $output -part xcvu9p-flga2104-2L-e
if {[llength [get_board_parts -quiet xilinx.com:vcu118:part0:2.3]]!=1} {error EXACT_BOARD_PART_2_3_REQUIRED}
set_property board_part xilinx.com:vcu118:part0:2.3 [current_project]
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property include_dirs [list [file join $::public_root rtl] [file join $::public_root rtl legacy]] [current_fileset]
source [file join $::public_root scripts active_sources.tcl]
foreach rel $public_sources {add_files -norecurse [file join $::public_root $rel]}
add_files -norecurse [file join $::public_root rtl w8_program_meta.vh]
set_property file_type {Verilog Header} [get_files *.vh]
update_compile_order -fileset sources_1
source [file join $::public_root scripts bd_166p7.tcl]
set bd [get_files -all -quiet *w8_platform.bd]
if {[llength $bd]!=1} {error BD_NOT_UNIQUE}
# These are user constraints. Keep vendor-generated constraints from the BD.
add_files -fileset constrs_1 -norecurse [list [file join $::public_root constraints vcu118_pins.xdc] [file join $::public_root constraints configuration.xdc]]
generate_target all $bd
set wrappers [make_wrapper -files $bd -top]
add_files -norecurse $wrappers
set_property top w8_platform_wrapper [current_fileset]
update_compile_order -fileset sources_1
puts "PROJECT_PREPARED_ONLY_NOT_SYNTHESIZED $output"
close_project
