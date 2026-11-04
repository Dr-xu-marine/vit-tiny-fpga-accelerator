// 512-bit DMA output -> byte-upload bridge for tiny_compute_buffers.
// All signals use clk. job_start is accepted only while !busy, has priority over
// beat acceptance, latches target, clears sticky error, and enables beat_ready.
// No beat may be accepted after reset before the first accepted job_start.
// A valid&&ready beat latches every input field. Lane i is data[8*i+:8], writes
// byte_addr=beat_addr+i if strb[i]. Zero strobes are skipped. Host valid/payload
// remain stable under backpressure. Address addition is 25-bit BEFORE truncation;
// overflowing enabled bytes cause error and are never written to wrapped aliases.
// Earlier writes are partial results and are not rolled back on any error.
// host_error is the HOST'S REGISTERED ONE-CYCLE response to an accepted byte.
// It combinationally blocks further host_valid immediately, then latches error.
// RESP waits at least one clock after the last byte acceptance to observe the
// final registered error, then pulses beat_done and returns idle.
// error is sticky across beats. Error-state beats are accepted/discarded without
// host writes to let the read DMA drain; only idle accepted job_start/reset clears
// error. Busy job_start cannot change target or clear error.
// IMPORTANT: DMA done means its final beat was TAKEN BY THIS BRIDGE, not that its
// bytes reached RAM. The system must also wait !busy && !error before compute.
// Reset synchronously aborts state and masks beat_ready/host_valid immediately;
// AXI/DMA/buffer endpoints must abort/reset together. RAM is not cleared here.
`timescale 1ns/1ps
module writer_parent(
    input wire clk,rst,job_start,
    input wire [3:0] job_target,
    input wire beat_valid,
    output wire beat_ready,
    input wire [511:0] beat_data,
    input wire [63:0] beat_strb,
    input wire [23:0] beat_addr,
    output wire host_valid,
    input wire host_ready,host_error,
    output wire [3:0] host_target,
    output wire [23:0] host_byte_addr,
    output wire [7:0] host_wdata,
    output wire busy,
    output reg beat_done,error
);
    localparam IDLE=0,WALK=1,RESP=2;
    reg [1:0] state;
    reg configured;
    reg [3:0] target_q;
    reg [511:0] data_q;
    reg [63:0] mask_q;
    reg [23:0] base_q;
    reg [5:0] index_q;
    wire [24:0] wide_address={1'b0,base_q}+{19'b0,index_q};
    assign busy=!rst && state!=IDLE;
    assign beat_ready=!rst && state==IDLE && configured && !job_start;
    assign host_valid=!rst && state==WALK && mask_q[index_q] && !error && !host_error && !wide_address[24];
    assign host_target=target_q;
    assign host_byte_addr=wide_address[23:0];
    assign host_wdata=data_q[index_q*8+:8];
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;configured<=0;target_q<=0;data_q<=0;mask_q<=0;
            base_q<=0;index_q<=0;beat_done<=0;error<=0;
        end else begin
            beat_done<=0;
            case(state)
                IDLE:begin
                    if(job_start) begin target_q<=job_target;error<=0;configured<=1;end
                    else if(beat_valid && beat_ready) begin
                        data_q<=beat_data;mask_q<=beat_strb;base_q<=beat_addr;index_q<=0;
                        if(error || beat_strb==0) state<=RESP;else state<=WALK;
                    end
                end
                WALK:begin
                    if(host_error) begin error<=1;state<=RESP;end
                    else if(mask_q[index_q] && wide_address[24]) begin error<=1;state<=RESP;end
                    else if(!mask_q[index_q] || host_ready) begin
                        if(index_q==63) state<=RESP;else index_q<=index_q+1'b1;
                    end
                end
                RESP:begin
                    if(host_error) error<=1;
                    state<=IDLE;beat_done<=1;
                end
                default:begin state<=IDLE;error<=1;beat_done<=1;end
            endcase
        end
    end
endmodule
