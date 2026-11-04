`timescale 1ns/1ps
// INT8-only128MAC array assembled from FOUR unchanged verified4x8 groups.
// This wrapper adds wiring only: no arithmetic, retiming, RAM or handshake.
// With in_valid sampled at e0: leaf=e0, DSPtake=e1, POST-edge P/commit=e3.
// DSPtake->P latency2edges, dense II1; reset/flush uses the existing group
// registered clear and therefore the parent's original clear barrier.
// P is signed48 per PE, row-major: p_all[48*(16*r+c)+:48].
// Caller masks invalid physical rows/columns and enforces the legal K range.
// This module does not provide A16/AV arithmetic or claim physical timing.
module w8_mac_array_local #(
    parameter integer CORE_FAULT=0
)(
    input wire clk,rst,flush,input wire [3:0] in_valid_group,
    input wire [63:0] a64,
    input wire [127:0] b128,
    input wire [9:0] k_index,
    input wire k_last,
    output wire [6143:0] p_all,
    output wire commit_valid,
    output wire [9:0] commit_k,
    output wire commit_last,
    output wire take_valid,
    output wire [9:0] take_k
);
    wire [1535:0] group_p[0:3];
    wire [3:0] group_commit_valid,group_commit_last,group_take_valid;
    wire [9:0] group_commit_k[0:3],group_take_k[0:3];
    genvar gr,gc,lr,lc;
    generate for(gr=0;gr<2;gr=gr+1)begin:G_R
        for(gc=0;gc<2;gc=gc+1)begin:G_C
            localparam integer GROUP=2*gr+gc;
            v2_mac_group4x8 #(.CORE_FAULT(CORE_FAULT)) u_group(
                .clk(clk),.rst(rst),.flush(flush),.in_valid(in_valid_group[GROUP]),
                .a32(a64[32*gr+:32]),.b64(b128[64*gc+:64]),
                .k_index(k_index),.k_last(k_last),
                .p_all(group_p[GROUP]),
                .commit_valid(group_commit_valid[GROUP]),
                .commit_k(group_commit_k[GROUP]),
                .commit_last(group_commit_last[GROUP]),
                .take_valid(group_take_valid[GROUP]),
                .take_k(group_take_k[GROUP])
            );
            for(lr=0;lr<4;lr=lr+1)begin:MAP_R
                for(lc=0;lc<8;lc=lc+1)begin:MAP_C
                    localparam integer R=4*gr+lr,C=8*gc+lc;
                    assign p_all[48*(16*R+C)+:48]=group_p[GROUP][48*(8*lr+lc)+:48];
                end
            end
        end
    end endgenerate

    // Identical timing in every group permits one canonical metadata bundle.
    // Assertions below verify that choice without synthesizing a global
    // comparison/reduction control path or changing the observed latency.
    assign commit_valid=group_commit_valid[0];
    assign commit_k=group_commit_k[0];
    assign commit_last=group_commit_last[0];
    assign take_valid=group_take_valid[0];
    assign take_k=group_take_k[0];
`ifndef SYNTHESIS
    integer group_index;
    always @(negedge clk)begin
        if(!rst&&!flush)begin
            for(group_index=1;group_index<4;group_index=group_index+1)begin
                if(group_take_valid[group_index]!==group_take_valid[0])
                    $fatal(1,"V2_128_ERROR group take-valid age group=%0d",group_index);
                if(group_commit_valid[group_index]!==group_commit_valid[0])
                    $fatal(1,"V2_128_ERROR group commit-valid age group=%0d",group_index);
                if(group_take_valid[0]&&group_take_k[group_index]!==group_take_k[0])
                    $fatal(1,"V2_128_ERROR group take-K group=%0d",group_index);
                if(group_commit_valid[0]&&(group_commit_k[group_index]!==group_commit_k[0]||group_commit_last[group_index]!==group_commit_last[0]))
                    $fatal(1,"V2_128_ERROR group commit metadata group=%0d",group_index);
            end
        end
    end
`endif
endmodule
