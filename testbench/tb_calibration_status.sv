`timescale 1ns/1ps
`include "w8_test_paths.vh"
module tb_calibration_status;
reg  clk=0;
reg  aresetn=0;
reg  calibrated_async=0;
wire  busy_out;
wire  done_out;
wire  error_out;
reg [31:0] s_axi_awaddr=0;
reg  s_axi_awvalid=0;
wire  s_axi_awready;
reg [31:0] s_axi_wdata=0;
reg [3:0] s_axi_wstrb=0;
reg  s_axi_wvalid=0;
wire  s_axi_wready;
wire [1:0] s_axi_bresp;
wire  s_axi_bvalid;
reg  s_axi_bready=0;
reg [31:0] s_axi_araddr=0;
reg  s_axi_arvalid=0;
wire  s_axi_arready;
wire [31:0] s_axi_rdata;
wire [1:0] s_axi_rresp;
wire  s_axi_rvalid;
reg  s_axi_rready=0;
wire [0:0] m_axi_arid;
wire [30:0] m_axi_araddr;
wire [7:0] m_axi_arlen;
wire [2:0] m_axi_arsize;
wire [1:0] m_axi_arburst;
wire  m_axi_arvalid;
reg  m_axi_arready=0;
reg [0:0] m_axi_rid=0;
reg [511:0] m_axi_rdata=0;
reg [1:0] m_axi_rresp=0;
reg  m_axi_rlast=0;
reg  m_axi_rvalid=0;
wire  m_axi_rready;
always #2.5 clk=~clk;reg ui_clk=0;always #1.6665 ui_clk=~ui_clk;
w8_hosted_core #(.INSTRUCTIONS(6),.PROGRAM_FILE({`W8_ROOT,"/testbench/short_cases/head/program.hex"})) dut(.clk(clk),.aresetn(aresetn),.calibrated_async(calibrated_async),.busy_out(busy_out),.done_out(done_out),.error_out(error_out),.s_axi_awaddr(s_axi_awaddr),.s_axi_awvalid(s_axi_awvalid),.s_axi_awready(s_axi_awready),.s_axi_wdata(s_axi_wdata),.s_axi_wstrb(s_axi_wstrb),.s_axi_wvalid(s_axi_wvalid),.s_axi_wready(s_axi_wready),.s_axi_bresp(s_axi_bresp),.s_axi_bvalid(s_axi_bvalid),.s_axi_bready(s_axi_bready),.s_axi_araddr(s_axi_araddr),.s_axi_arvalid(s_axi_arvalid),.s_axi_arready(s_axi_arready),.s_axi_rdata(s_axi_rdata),.s_axi_rresp(s_axi_rresp),.s_axi_rvalid(s_axi_rvalid),.s_axi_rready(s_axi_rready),.m_axi_arid(m_axi_arid),.m_axi_araddr(m_axi_araddr),.m_axi_arlen(m_axi_arlen),.m_axi_arsize(m_axi_arsize),.m_axi_arburst(m_axi_arburst),.m_axi_arvalid(m_axi_arvalid),.m_axi_arready(m_axi_arready),.m_axi_rid(m_axi_rid),.m_axi_rdata(m_axi_rdata),.m_axi_rresp(m_axi_rresp),.m_axi_rlast(m_axi_rlast),.m_axi_rvalid(m_axi_rvalid),.m_axi_rready(m_axi_rready));
reg [1:0] expected=0;reg sampled_cal=0;integer checks=0,reads=0,k,phase;
always @(posedge clk)begin
 if(!aresetn)expected<=0;else expected<={expected[0],calibrated_async};
 if(s_axi_arvalid&&s_axi_arready)sampled_cal<=expected[1];
end
always @(negedge clk)begin #0.1;if(dut.calibrated_q!==expected)$fatal(1,"CALIBRATION_STAGE_AGE");checks=checks+1;end
task automatic read_status;
begin
 @(negedge clk);s_axi_araddr=4;s_axi_arvalid=1;do @(posedge clk);while(!s_axi_arready);
 @(negedge clk);s_axi_arvalid=0;wait(s_axi_rvalid);
 if(s_axi_rresp!=0||s_axi_rdata[3]!==sampled_cal)$fatal(1,"CALIBRATION_HOST_STATUS");
 repeat(3)@(negedge clk);s_axi_rready=1;@(negedge clk);s_axi_rready=0;reads=reads+1;
end endtask
initial begin
 repeat(5)@(negedge clk);aresetn=1;
 for(k=0;k<20;k=k+1)begin repeat(3+k%5)@(negedge ui_clk);calibrated_async=k[0];repeat(5)@(negedge clk);read_status();end
 for(phase=0;phase<4;phase=phase+1)begin
  @(negedge ui_clk);calibrated_async=1;repeat(phase+1)@(negedge clk);aresetn=0;
  repeat(3)@(negedge clk);aresetn=1;repeat(5)@(negedge clk);read_status();
 end
 $display("CALIBRATION_STATUS_PASS stage_cycle_checks=%0d host_reads=%0d reset_phases=4 digital_protocol_only=1",checks,reads);$finish;
end
initial begin #1000000;$fatal(1,"CALIBRATION_TIMEOUT");end
endmodule
