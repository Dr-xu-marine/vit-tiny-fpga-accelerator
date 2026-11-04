// Metadata-only wire for the generated MIG dbg_clk output, whose BD TYPE is
// undef despite the real MMCM250MHz*6/20 and existing BUFG output being75MHz.
// No divider, clock gate, oscillator, synchronizer, or arithmetic is introduced.
module w8_debug_clock_metadata (
    (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 raw_clk CLK",
       X_INTERFACE_PARAMETER="XIL_INTERFACENAME raw_clk, FREQ_HZ 75000000, PHASE 0.0, CLK_DOMAIN w8_platform_memory_dbg75" *)
    input wire raw_clk,
    (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 debug_clk CLK",
       X_INTERFACE_PARAMETER="XIL_INTERFACENAME debug_clk, FREQ_HZ 75000000, PHASE 0.0, CLK_DOMAIN w8_platform_memory_dbg75" *)
    output wire debug_clk
);
    assign debug_clk=raw_clk;
endmodule
