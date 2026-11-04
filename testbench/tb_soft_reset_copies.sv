`timescale 1ns/1ps
module tb_soft_reset_copies;
reg  clk=0;
reg  rst=0;
reg [31:0] s_axi_awaddr=0;
reg  s_axi_awvalid=0;
wire  old_s_axi_awready,new_s_axi_awready;
reg [31:0] s_axi_wdata=0;
reg [3:0] s_axi_wstrb=0;
reg  s_axi_wvalid=0;
wire  old_s_axi_wready,new_s_axi_wready;
wire [1:0] old_s_axi_bresp,new_s_axi_bresp;
wire  old_s_axi_bvalid,new_s_axi_bvalid;
reg  s_axi_bready=0;
reg [31:0] s_axi_araddr=0;
reg  s_axi_arvalid=0;
wire  old_s_axi_arready,new_s_axi_arready;
wire [31:0] old_s_axi_rdata,new_s_axi_rdata;
wire [1:0] old_s_axi_rresp,new_s_axi_rresp;
wire  old_s_axi_rvalid,new_s_axi_rvalid;
reg  s_axi_rready=0;
reg  busy=0;
reg  job_done=0;
reg  job_error=0;
reg  calibrated=0;
reg  result_valid=0;
reg [9:0] top1=0;
reg [7:0] max_logit=0;
reg [63:0] job_cycles=0;
reg [63:0] core_cycles=0;
reg [15:0] retired=0;
reg [15:0] commands=0;
reg [15:0] loads=0;
wire  old_start_pulse,new_start_pulse;
wire  old_idle_reset_pulse,new_idle_reset_pulse;
wire  old_cache_re,new_cache_re;
wire [7:0] old_cache_addr,new_cache_addr;
reg [31:0] cache_data=0;
reg  cache_valid=0;
reg  cache_error=0;
always #2.5 clk=~clk;wire [5:0] copies;integer checks=0,soft_events=0;
tiny_axi_lite_control_reference reference(.clk(clk),.rst(rst),.s_axi_awaddr(s_axi_awaddr),.s_axi_awvalid(s_axi_awvalid),.s_axi_awready(old_s_axi_awready),.s_axi_wdata(s_axi_wdata),.s_axi_wstrb(s_axi_wstrb),.s_axi_wvalid(s_axi_wvalid),.s_axi_wready(old_s_axi_wready),.s_axi_bresp(old_s_axi_bresp),.s_axi_bvalid(old_s_axi_bvalid),.s_axi_bready(s_axi_bready),.s_axi_araddr(s_axi_araddr),.s_axi_arvalid(s_axi_arvalid),.s_axi_arready(old_s_axi_arready),.s_axi_rdata(old_s_axi_rdata),.s_axi_rresp(old_s_axi_rresp),.s_axi_rvalid(old_s_axi_rvalid),.s_axi_rready(s_axi_rready),.busy(busy),.job_done(job_done),.job_error(job_error),.calibrated(calibrated),.result_valid(result_valid),.top1(top1),.max_logit(max_logit),.job_cycles(job_cycles),.core_cycles(core_cycles),.retired(retired),.commands(commands),.loads(loads),.start_pulse(old_start_pulse),.idle_reset_pulse(old_idle_reset_pulse),.cache_re(old_cache_re),.cache_addr(old_cache_addr),.cache_data(cache_data),.cache_valid(cache_valid),.cache_error(cache_error));
tiny_axi_lite_control_v128 dut(.clk(clk),.rst(rst),.s_axi_awaddr(s_axi_awaddr),.s_axi_awvalid(s_axi_awvalid),.s_axi_awready(new_s_axi_awready),.s_axi_wdata(s_axi_wdata),.s_axi_wstrb(s_axi_wstrb),.s_axi_wvalid(s_axi_wvalid),.s_axi_wready(new_s_axi_wready),.s_axi_bresp(new_s_axi_bresp),.s_axi_bvalid(new_s_axi_bvalid),.s_axi_bready(s_axi_bready),.s_axi_araddr(s_axi_araddr),.s_axi_arvalid(s_axi_arvalid),.s_axi_arready(new_s_axi_arready),.s_axi_rdata(new_s_axi_rdata),.s_axi_rresp(new_s_axi_rresp),.s_axi_rvalid(new_s_axi_rvalid),.s_axi_rready(s_axi_rready),.busy(busy),.job_done(job_done),.job_error(job_error),.calibrated(calibrated),.result_valid(result_valid),.top1(top1),.max_logit(max_logit),.job_cycles(job_cycles),.core_cycles(core_cycles),.retired(retired),.commands(commands),.loads(loads),.start_pulse(new_start_pulse),.idle_reset_pulse(new_idle_reset_pulse),.cache_re(new_cache_re),.cache_addr(new_cache_addr),.cache_data(cache_data),.cache_valid(cache_valid),.cache_error(cache_error),.idle_reset_copies(copies));
always @(negedge clk)begin #0.1;
 if(!rst)begin
  if({new_s_axi_awready,new_s_axi_wready,new_s_axi_bresp,new_s_axi_bvalid,new_s_axi_arready,new_s_axi_rdata,new_s_axi_rresp,new_s_axi_rvalid,new_start_pulse,new_idle_reset_pulse,new_cache_re,new_cache_addr}!=={old_s_axi_awready,old_s_axi_wready,old_s_axi_bresp,old_s_axi_bvalid,old_s_axi_arready,old_s_axi_rdata,old_s_axi_rresp,old_s_axi_rvalid,old_start_pulse,old_idle_reset_pulse,old_cache_re,old_cache_addr})$fatal(1,"HOST_CONTROL_CYCLE_MISMATCH");
  if(copies!=={6{old_idle_reset_pulse}})$fatal(1,"SOFT_RESET_AGE_MISMATCH");
  checks=checks+1;if(old_idle_reset_pulse)soft_events=soft_events+1;
 end
end
task automatic write_word(input [31:0] address,value,input integer order,input [1:0] response);
begin
 @(negedge clk);s_axi_awaddr=address;s_axi_wdata=value;
 if(order==0)begin s_axi_awvalid=1;@(negedge clk);s_axi_awvalid=0;repeat(2)@(negedge clk);s_axi_wvalid=1;@(negedge clk);s_axi_wvalid=0;end
 else if(order==1)begin s_axi_wvalid=1;@(negedge clk);s_axi_wvalid=0;repeat(2)@(negedge clk);s_axi_awvalid=1;@(negedge clk);s_axi_awvalid=0;end
 else begin s_axi_awvalid=1;s_axi_wvalid=1;@(negedge clk);s_axi_awvalid=0;s_axi_wvalid=0;end
 wait(new_s_axi_bvalid);if(new_s_axi_bresp!==response)$fatal(1,"HOST_CONTROL_BRESP");repeat(3)@(negedge clk);s_axi_bready=1;@(negedge clk);s_axi_bready=0;
end endtask
integer k;
initial begin
 rst=1;s_axi_wstrb=15;calibrated=1;repeat(4)@(negedge clk);rst=0;
 for(k=0;k<24;k=k+1)begin write_word(0,2,k%3,0);write_word(0,1,(k+1)%3,0);end
 busy=1;write_word(0,2,0,2);write_word(0,1,1,2);busy=0;
 calibrated=0;write_word(0,1,2,2);write_word(0,2,2,0);calibrated=1;
 write_word(4,2,0,2);write_word(0,3,1,2);write_word(0,4,2,2);write_word(0,0,2,0);
 s_axi_wstrb=0;write_word(0,2,0,0);s_axi_wstrb=15;
 @(negedge clk);s_axi_awvalid=1;s_axi_awaddr=0;@(negedge clk);s_axi_awvalid=0;rst=1;@(negedge clk);rst=0;
 repeat(8)@(negedge clk);if(new_s_axi_bvalid||new_idle_reset_pulse)$fatal(1,"HOST_CONTROL_RESET_STALE");write_word(0,2,1,0);
 if(soft_events!=26)$fatal(1,"SOFT_RESET_EVENT_COUNT %0d",soft_events);
 $display("SOFT_RESET_COPIES_PASS cycle_checks=%0d events=%0d copies=6",checks,soft_events);$finish;
end
initial if($test$plusargs("CORRUPT_RESET"))begin wait(new_idle_reset_pulse);force dut.idle_reset_local=6'bxxxxxx;end
initial begin #1000000;$fatal(1,"SOFT_RESET_TIMEOUT");end
endmodule

// V128 ABI, request-Hz and MAC-count metadata only; control/collector math unchanged.
// One outstanding write/read, independent AW/W capture, held B/R responses.
// Offsets are relative to a platform-decoded 64KiB region (board: 0x80000000).
`timescale 1ns/1ps
module tiny_axi_lite_control_reference #(
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
    output wire cache_re,
    output reg [7:0] cache_addr,
    input wire [31:0] cache_data,
    input wire cache_valid,cache_error
);
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
