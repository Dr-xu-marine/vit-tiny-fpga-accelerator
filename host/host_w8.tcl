# New128 platform host clone; no old ABI fallback.
# Host procedures for an ALREADY configured Tiny platform. No bitstream programming.
# Vivado 2019.x burst convention: address-zero word is rightmost in -data.
namespace eval tiny_host {variable axi {}; variable base 0x80000000}
proc tiny_host::bind {handle} {variable axi;set axi $handle}
proc tiny_host::words_from_bytes {data} {
    if {[string length $data]%4!=0} {error "Host payload is not a multiple of 4 bytes"}
    binary scan $data H* hex
    set words {}
    for {set i 0} {$i<[string length $hex]} {incr i 8} {
        set b [string range $hex $i [expr {$i+7}]]
        lappend words "[string range $b 6 7][string range $b 4 5][string range $b 2 3][string range $b 0 1]"
    }
    return $words
}
proc tiny_host::transfer {type address words} {
    variable axi
    if {$axi eq {}} {error "No selected JTAG AXI master"}
    set count [llength $words]
    if {$count<1 || $count>256 || $address<0 || $address>0xffffffff || $address%4!=0 || ($address%4096)+4*$count>4096} {error "Invalid AXI host transfer"}
    set options [list -force -type $type -address [format %08x $address] -len $count -burst INCR]
    if {$type eq "WRITE"} {
        foreach word $words {if {![regexp {^[0-9a-fA-F]{8}$} $word]} {error "Malformed 32-bit upload word"}}
        lappend options -data [join [lreverse $words] _]
    } elseif {$type ne "READ"} {error "Invalid AXI direction"}
    set txn [create_hw_axi_txn tiny_transfer $axi {*}$options]
    # Do not use -quiet: Vivado's quiet option can conceal Tcl errors.
    run_hw_axi $txn
    # run_hw_axi updates STATUS on the hw_axi OBJECT, not the transaction.
    # UG835 2017.4 documents these properties for the 2019-era JTAG core.
    set channel [expr {$type eq "WRITE" ? "WRITE" : "READ"}]
    set busy [get_property STATUS.AXI_${channel}_BUSY $axi]
    set done [get_property STATUS.AXI_${channel}_DONE $axi]
    if {![string is boolean -strict $busy] || ![string is boolean -strict $done]} {error "Invalid JTAG AXI completion status"}
    if {$busy || !$done} {error "JTAG AXI transaction did not complete type=$type busy=$busy done=$done"}
    set response_name [expr {$type eq "WRITE" ? "BRESP" : "RRESP"}]
    set response [string toupper [string trim [get_property STATUS.$response_name $axi]]]
    if {$response ne "OKAY" && ![regexp {^(0+|0X0+|0B0+)$} $response]} {error "JTAG AXI response error type=$type value=$response"}
    if {$type eq "WRITE"} {return {}}
    set value [string tolower [string map {_ {} { } {} \n {} \r {}} [get_property DATA $txn]]]
    if {[string length $value]!=8*$count || ![regexp {^[0-9a-f]+$} $value]} {error "Missing, truncated or malformed JTAG read data"}
    set observed {}
    for {set i [expr {$count-1}]} {$i>=0} {incr i -1} {lappend observed [string range $value [expr {$i*8}] [expr {$i*8+7}]]}
    return $observed
}
proc tiny_host::read32 {offset} {
    variable base
    return [expr 0x[lindex [transfer READ [expr {$base+$offset}] {00000000}] 0]]
}
proc tiny_host::write32 {offset value} {
    variable base
    transfer WRITE [expr {$base+$offset}] [list [format %08x $value]]
}
proc tiny_host::upload_verified {path} {
    set size [file size $path]
    if {$size<64 || $size%64!=0 || $size>0x80000000} {error "DDR payload must fit DDR and contain whole 64-byte beats"}
    set file [open $path rb]
    set address 0
    set status [catch {
        while {$address<$size} {
            set chunk [read $file [expr {min(1024,$size-$address)}]]
            set words [words_from_bytes $chunk]
            if {[llength $words]==0} {error "Unexpected payload EOF"}
            transfer WRITE $address $words
            set observed [transfer READ $address [lrepeat [llength $words] 00000000]]
            if {$observed ne $words} {error "DDR upload readback mismatch at $address"}
            incr address [string length $chunk]
            if {$address%1048576==0 || $address==$size} {puts "V128_HOST_UPLOAD_VERIFIED bytes=$address total=$size"}
        }
        if {$address!=$size} {error "Incomplete DDR upload"}
    } message options]
    close $file
    if {$status} {return -options $options $message}
    return $address
}
proc tiny_host::wait_status {mask expected timeout_ms} {
    set deadline [expr {[clock milliseconds]+$timeout_ms}]
    while {1} {
        set status [read32 4]
        if {$status&4} {error "Accelerator reports ERROR status=$status"}
        if {($status&$mask)==$expected} {return $status}
        if {[clock milliseconds]>=$deadline} {error "Accelerator timeout status=$status"}
        after 20
    }
}
proc tiny_host::run {payload expected_file observed_file} {
    set f [open $expected_file r];set expected [split [string trim [read $f]] \n];close $f
    if {[llength $expected]!=1000} {error "Expected exactly 1000 Golden logits"}
    foreach value $expected {if {![regexp {^[0-9a-fA-F]{2}$} [string trim $value]]} {error "Malformed Golden logit"}}
    if {[read32 0x34]!=0x56313238 || [read32 0x2c]!=13024 || [read32 0x30]!=1000} {error "Wrong bitstream ABI, instruction count or result count"}
    if {[read32 0x3c]!=128 || [read32 0x38]<10000000} {error "Wrong128MAC/frequency identity"}
    puts "V128_HOST_ID macs=128 requested_compute_hz=[read32 0x38] NOT_MEASURED_FREQUENCY"
    set initial [read32 4]
    if {$initial&1} {error "Engine already busy"}
    # Idle reset clears a prior job's ERROR/DONE before calibration polling.
    write32 0 2
    wait_status 8 8 30000
    set t0 [clock milliseconds]
    set uploaded [upload_verified $payload]
    set upload_ms [expr {[clock milliseconds]-$t0}]
    write32 0 1
    wait_status 0x1b 0x1a 600000
    foreach {offset count} {0x20 13023 0x24 12700 0x28 323} {
        if {[read32 $offset]!=$count} {error "Retirement counter mismatch at $offset"}
    }
    set observed {};set top1 0;set maximum -129
    for {set word 0} {$word<250} {incr word} {
        set packed [read32 [expr {0x1000+4*$word}]]
        for {set byte 0} {$byte<4} {incr byte} {
            set value [expr {($packed>>(8*$byte))&255}]
            set index [llength $observed];set reference [string trim [lindex $expected $index]]
            if {![regexp {^[0-9a-fA-F]{2}$} $reference] || $value!=[expr 0x$reference]} {error "Golden logit mismatch index=$index actual=$value expected=$reference"}
            lappend observed [format %02x $value]
            set signed [expr {$value>=128 ? $value-256 : $value}]
            if {$signed>$maximum} {set top1 $index;set maximum $signed}
        }
    }
    set register_max [read32 0x0c]
    if {[read32 8]!=$top1 || ($register_max&0xffffffff)!=($maximum&0xffffffff)} {error "Signed argmax/register mismatch"}
    set core_cycles [expr {([read32 0x1c]<<32)|[read32 0x18]}]
    set job_cycles [expr {([read32 0x14]<<32)|[read32 0x10]}]
    set f [open $observed_file w];puts $f [join $observed \n];close $f
    puts "V128_HOST_FUNCTIONAL_PASS values=1000 top1=$top1 max_logit=$maximum core_cycles=$core_cycles job_cycles=$job_cycles upload_bytes=$uploaded upload_ms=$upload_ms"
    puts "V128_HOST_SCOPE Physical-board claim requires the real matching implemented bitstream and connected VCU118. JTAG upload is excluded from core cycles."
}
