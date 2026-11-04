// V128 ABI, request-Hz and MAC-count metadata only; control/collector math unchanged.
// One outstanding write/read, independent AW/W capture, held B/R responses.
// Offsets are relative to a platform-decoded 64KiB region (board: 0x80000000).
`timescale 1ns/1ps
module tiny_axi_lite_control_v128 #(
    parameter integer COMPUTE_HZ=300000000,
    parameter integer RESULT_COUNT=1000,
    parameter integer INSTRUCTIONS=1
)(
    input wire clk,rst,
    input wire [31:0] s_axi_awaddr,
    input wire s_axi_awvalid,
    output wire s_axi_awready,
    input wire [31:0] s_axi_wdata,
    input wire [3:0] s_axi_wstrb,
    input wire s_axi_wvalid,
    output wire s_axi_wready,
    output reg [1:0] s_axi_bresp,
    output reg s_axi_bvalid,
    input wire s_axi_bready,
    input wire [31:0] s_axi_araddr,
    input wire s_axi_arvalid,
    output wire s_axi_arready,
    output reg [31:0] s_axi_rdata,
    output reg [1:0] s_axi_rresp,
    output reg s_axi_rvalid,
    input wire s_axi_rready,
    input wire busy,job_done,job_error,calibrated,result_valid,
    input wire [9:0] top1,
    input wire signed [7:0] max_logit,
    input wire [63:0] job_cycles,core_cycles,
    input wire [15:0] retired,commands,loads,
    output reg start_pulse,idle_reset_pulse,
    output wire [5:0] idle_reset_copies,
    output wire cache_re,
    output reg [7:0] cache_addr,
    input wire [31:0] cache_data,
    input wire cache_valid,cache_error
);
    (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [5:0] idle_reset_local;
    assign idle_reset_copies=idle_reset_local;
    reg aw_pending,w_pending;
    reg [15:0] aw_address;
    reg [31:0] w_data;
    reg [3:0] w_strb;
    reg [1:0] read_state;
    wire [31:0] masked=w_data & {{8{w_strb[3]}},{8{w_strb[2]}},{8{w_strb[1]}},{8{w_strb[0]}}};
    assign s_axi_awready=!rst && !aw_pending && !s_axi_bvalid;
    assign s_axi_wready=!rst && !w_pending && !s_axi_bvalid;
    assign s_axi_arready=!rst && !s_axi_rvalid && read_state==0;
    assign cache_re=!rst && read_state==1;
    wire idle_reset_commit=aw_pending&&w_pending&&!s_axi_bvalid&&aw_address==0&&masked==2&&!busy&&read_state==0&&!s_axi_arvalid;
    always @(posedge clk)if(rst)idle_reset_local<=0;else idle_reset_local<={6{idle_reset_commit}};
`ifndef SYNTHESIS
    always @(negedge clk)if(!rst&&idle_reset_local!=={6{idle_reset_pulse}})$fatal(1,"SOFT_RESET_AGE_MISMATCH");
`endif
    always @(posedge clk) begin
        if(rst) begin
            aw_pending<=0;w_pending<=0;aw_address<=0;w_data<=0;w_strb<=0;
            s_axi_bresp<=0;s_axi_bvalid<=0;s_axi_rdata<=0;s_axi_rresp<=0;s_axi_rvalid<=0;
            read_state<=0;cache_addr<=0;start_pulse<=0;idle_reset_pulse<=0;
        end else begin
            start_pulse<=0;idle_reset_pulse<=0;
            if(s_axi_bvalid && s_axi_bready) s_axi_bvalid<=0;
            if(s_axi_rvalid && s_axi_rready) s_axi_rvalid<=0;
            if(s_axi_awvalid && s_axi_awready) begin aw_address<=s_axi_awaddr[15:0];aw_pending<=1;end
            if(s_axi_wvalid && s_axi_wready) begin w_data<=s_axi_wdata;w_strb<=s_axi_wstrb;w_pending<=1;end
            if(aw_pending && w_pending && !s_axi_bvalid) begin
                aw_pending<=0;w_pending<=0;s_axi_bvalid<=1;s_axi_bresp<=0;
                if(aw_address!=0 || masked>3 || masked==3) s_axi_bresp<=2;
                else if(masked!=0) begin
                    // An idle-only soft reset never aborts an outstanding AXI
                    // DMA. A busy abort requires shared platform reset.
                    if(busy || read_state!=0 || s_axi_arvalid || (masked==1 && !calibrated)) s_axi_bresp<=2;
                    else if(masked==1) start_pulse<=1;
                    else idle_reset_pulse<=1;
                end
            end
            if(s_axi_arvalid && s_axi_arready) begin
                s_axi_rdata<=0;s_axi_rresp<=0;
                if(s_axi_araddr[1:0]!=0) begin s_axi_rvalid<=1;s_axi_rresp<=2;end
                else if(s_axi_araddr[15:0]>=16'h1000 && s_axi_araddr[15:0]<16'h1000+((RESULT_COUNT+3)/4)*4) begin
                    if(!result_valid || busy) begin s_axi_rvalid<=1;s_axi_rresp<=2;end
                    else begin cache_addr<=(s_axi_araddr[15:0]-16'h1000)>>2;read_state<=1;end
                end else begin
                    s_axi_rvalid<=1;
                    case(s_axi_araddr[15:0])
                        16'h0000:s_axi_rdata<=0;
                        16'h0004:s_axi_rdata<={27'b0,result_valid,calibrated,job_error,job_done,busy};
                        16'h0008:if(result_valid) s_axi_rdata<={22'b0,top1};else s_axi_rresp<=2;
                        16'h000c:if(result_valid) s_axi_rdata<={{24{max_logit[7]}},max_logit};else s_axi_rresp<=2;
                        16'h0010:s_axi_rdata<=job_cycles[31:0];16'h0014:s_axi_rdata<=job_cycles[63:32];
                        16'h0018:s_axi_rdata<=core_cycles[31:0];16'h001c:s_axi_rdata<=core_cycles[63:32];
                        16'h0020:s_axi_rdata<={16'b0,retired};16'h0024:s_axi_rdata<={16'b0,commands};16'h0028:s_axi_rdata<={16'b0,loads};
                        16'h002c:s_axi_rdata<=INSTRUCTIONS;16'h0030:s_axi_rdata<=RESULT_COUNT;16'h0034:s_axi_rdata<=32'h56313238;
                        16'h0038:s_axi_rdata<=COMPUTE_HZ;16'h003c:s_axi_rdata<=128;
                        default:s_axi_rresp<=2;
                    endcase
                end
            end
            if(read_state==1) read_state<=2;
            if(read_state==2 && (cache_valid || cache_error)) begin
                read_state<=0;s_axi_rvalid<=1;s_axi_rresp<=cache_error?2:0;s_axi_rdata<=cache_error?0:cache_data;
            end
        end
    end
endmodule
