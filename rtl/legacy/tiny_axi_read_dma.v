// AXI4 read-only DMA; independent primitive, NOT connected to DDR/compute tile.
// Contract: one command accepted at start && !busy && !rst. Inputs are captured;
// busy starts are ignored. src_addr must be 64-byte aligned. byte_count is an
// exact positive byte count; local_offset may be unaligned. Both exclusive ends
// must fit their address spaces. Invalid commands finish with done+error, no AR.
// ARID=0, INCR, 64 bytes/beat. One outstanding burst, <=MAX_BURST<=16 beats,
// never crossing 4KiB. AR payload is stable while ARVALID && !ARREADY.
// A single registered output slot holds data/address/byte enables until ready.
// Only its final beat may have a partial low-byte strobe. done waits for that
// slot to be consumed, so done is not an early "last AXI beat accepted" signal.
// RRESP!=OKAY, RID!=0 or incorrect RLAST latch sticky error immediately, stop
// forwarding that and later beats, prohibit new AR, and drain through the failed
// burst's actual RLAST. An early RLAST terminates that failed burst. Previously
// accepted good output beats remain valid and are not rolled back. If a broken
// slave NEVER supplies RLAST, safe completion is impossible: busy/error persist
// until shared reset. Port is exclusive to this DMA, no unrelated responses.
// error persists through done/idle until a new accepted command or reset; done
// pulses one cycle. rst synchronously aborts internal state and masks all valid/
// ready signals immediately. Reset recovery REQUIRES the external AXI slave and
// output consumer to reset/abort the same transaction too (no old R responses).
`timescale 1ns/1ps
module tiny_axi_read_dma #(
    parameter integer ID_WIDTH=4,
    parameter integer MAX_BURST=16
)(
    input wire clk,rst,start,
    input wire [30:0] src_addr,
    input wire [23:0] byte_count,local_offset,
    output wire busy,
    output reg done,error,
    output wire [ID_WIDTH-1:0] m_axi_arid,
    output wire [30:0] m_axi_araddr,
    output wire [7:0] m_axi_arlen,
    output wire [2:0] m_axi_arsize,
    output wire [1:0] m_axi_arburst,
    output wire m_axi_arvalid,
    input wire m_axi_arready,
    input wire [ID_WIDTH-1:0] m_axi_rid,
    input wire [511:0] m_axi_rdata,
    input wire [1:0] m_axi_rresp,
    input wire m_axi_rlast,m_axi_rvalid,
    output wire m_axi_rready,
    output wire out_valid,
    input wire out_ready,
    output reg [511:0] out_data,
    output reg [63:0] out_strb,
    output reg [23:0] out_addr
);
    localparam IDLE=0,SETUP=1,ADDRESS=2,READ=3,DRAIN=4,FLUSH=5,REJECT=6;
    reg [2:0] state;
    reg [30:0] source_q;
    reg [23:0] remaining_q,destination_q;
    reg [4:0] burst_beats,beat_index;
    reg slot_valid;
    wire r_fire=m_axi_rvalid && m_axi_rready;
    wire expected_last=(beat_index==burst_beats-1'b1);
    wire bad_beat=(m_axi_rid!={ID_WIDTH{1'b0}}) || (m_axi_rresp!=2'b00) || (m_axi_rlast!=expected_last);
    assign busy=!rst && state!=IDLE;
    assign m_axi_arid={ID_WIDTH{1'b0}};
    assign m_axi_araddr=source_q;
    assign m_axi_arlen={3'b0,burst_beats}-8'd1;
    assign m_axi_arsize=3'd6;
    assign m_axi_arburst=2'b01;
    assign m_axi_arvalid=!rst && state==ADDRESS;
    assign m_axi_rready=!rst && ((state==READ && (!slot_valid || out_ready)) || state==DRAIN);
    assign out_valid=!rst && slot_valid;

    function [4:0] select_beats;
        input [30:0] address;
        input [23:0] remaining;
        reg [24:0] needed;
        reg [6:0] boundary;
        reg [24:0] chosen;
        begin
            needed=({1'b0,remaining}+25'd63)>>6;
            boundary=7'd64-{1'b0,address[11:6]};
            chosen=needed;
            if(chosen>MAX_BURST) chosen=MAX_BURST;
            if(chosen>boundary) chosen=boundary;
            select_beats=chosen[4:0];
        end
    endfunction
    function [63:0] byte_mask;
        input [23:0] remaining;
        begin
            if(remaining>=64) byte_mask=64'hffffffffffffffff;
            else byte_mask=(64'h1<<remaining[5:0])-64'd1;
        end
    endfunction
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;source_q<=0;remaining_q<=0;destination_q<=0;
            burst_beats<=1;beat_index<=0;slot_valid<=0;
            out_data<=0;out_addr<=0;out_strb<=0;done<=0;error<=0;
        end else begin
            done<=0;
            if(slot_valid && out_ready) slot_valid<=0;
            case(state)
                IDLE:if(start) begin
                    source_q<=src_addr;remaining_q<=byte_count;destination_q<=local_offset;
                    error<=0;slot_valid<=0;beat_index<=0;
                    if(src_addr[5:0]!=0 || byte_count==0 ||
                       ({1'b0,src_addr}+{8'b0,byte_count})>32'h80000000 ||
                       ({1'b0,local_offset}+{1'b0,byte_count})>25'h1000000 ||
                       MAX_BURST<1 || MAX_BURST>16 || ID_WIDTH<1)
                        state<=REJECT;
                    else state<=SETUP;
                end
                SETUP:begin
                    burst_beats<=select_beats(source_q,remaining_q);
                    beat_index<=0;state<=ADDRESS;
                end
                ADDRESS:if(m_axi_arready) state<=READ;
                READ:if(r_fire) begin
                    if(bad_beat) begin
                        error<=1;
                        if(m_axi_rlast) state<=FLUSH;else state<=DRAIN;
                    end else begin
                        out_data<=m_axi_rdata;out_addr<=destination_q;
                        out_strb<=byte_mask(remaining_q);slot_valid<=1;
                        source_q<=source_q+31'd64;destination_q<=destination_q+24'd64;
                        if(remaining_q>64) remaining_q<=remaining_q-24'd64;else remaining_q<=0;
                        if(expected_last) state<=FLUSH;else beat_index<=beat_index+1'b1;
                    end
                end
                DRAIN:if(r_fire && m_axi_rlast) state<=FLUSH;
                FLUSH:if(!slot_valid || out_ready) begin
                    if(error || remaining_q==0) begin state<=IDLE;done<=1;end
                    else state<=SETUP;
                end
                REJECT:begin state<=IDLE;done<=1;error<=1;end
                default:begin state<=IDLE;error<=1;done<=1;slot_valid<=0;end
            endcase
        end
    end
endmodule
