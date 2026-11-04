`timescale 1ns/1ps
`include "w8_test_paths.vh"
`define SYS dut.engine.compute.system_unit
`define SEQ dut.engine.compute.sequencer
`define TILE dut.engine.compute.system_unit.tile.gemm.tile
module tb_adopted_case #(parameter HEAD=1,parameter BEATS=1);
 localparam COUNT=HEAD?1000:16;localparam K=HEAD?192:768;
 localparam string DIR=HEAD?{`W8_ROOT,"/testbench/short_cases/head"}:{`W8_ROOT,"/testbench/short_cases/patch"};
 reg clk=0;always #2.5 clk=~clk;
 reg aresetn=0,calibrated=0;reg [31:0] awaddr=0,wdata=0,araddr=0;reg [3:0] wstrb=15;
 reg awvalid=0,wvalid=0,bready=0,arvalid=0,rready=0;wire awready,wready,bvalid,arready,rvalid;wire [1:0] bresp,rresp;wire [31:0] rdata;wire busy,done,error;
 wire did;wire [30:0] daddr;wire [7:0] dlen;wire [2:0] dsize;wire [1:0] dburst;wire dv,dr,rrdy;
 reg [511:0] rd=0;reg [1:0] rp=0;reg rv=0,rl=0;
 w8_hosted_core #(.INSTRUCTIONS(6),.RESULT_COUNT(COUNT),.PROGRAM_FILE({DIR,"/program.hex"})) dut(
 .clk(clk),.aresetn(aresetn),.calibrated_async(calibrated),.busy_out(busy),.done_out(done),.error_out(error),
 .s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),.s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),.s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
 .s_axi_araddr(araddr),.s_axi_arvalid(arvalid),.s_axi_arready(arready),.s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),
 .m_axi_arid(did),.m_axi_araddr(daddr),.m_axi_arlen(dlen),.m_axi_arsize(dsize),.m_axi_arburst(dburst),.m_axi_arvalid(dv),.m_axi_arready(dr),.m_axi_rid(1'b0),.m_axi_rdata(rd),.m_axi_rresp(rp),.m_axi_rlast(rl),.m_axi_rvalid(rv),.m_axi_rready(rrdy));
 reg [511:0] ddr[0:BEATS-1];reg [7:0] expected[0:COUNT-1],input_bytes[0:K-1];reg [COUNT-1:0] written=0;reg [K-1:0] read_seen=0;
 reg active=0,first_response=1,pending=0;integer base=0,beat=0,beats=0,pending_addr=0;reg [15:0] pending_tag,pending_keep;
 longint cycles=0,load_cycles=0,run_cycles=0,collect_cycles=0,prefix_count=0;integer prefix[0:127];integer lane,product,q,index,write_count=0,input_count=0,job=0,jobs=1,i,host_count,fd;reg [31:0] observed;
 reg bad_expected,ddr_error,bad_input,early_reset;
 assign dr=aresetn&&!active&&(cycles%5!=0);
 always @(posedge clk)begin
  if(!aresetn)begin active<=0;rv<=0;rl<=0;rp<=0;rd<=0;first_response<=1;cycles<=0;load_cycles<=0;run_cycles<=0;collect_cycles<=0;written<=0;read_seen<=0;write_count<=0;input_count<=0;pending<=0;end
  else begin
   cycles<=cycles+1;if(cycles>3000000)$fatal(1,"SHORT_TIMEOUT");
   if(dut.engine.compute.load_busy)load_cycles<=load_cycles+1;if(dut.engine.compute.compute_busy)run_cycles<=run_cycles+1;if(dut.collect_busy)collect_cycles<=collect_cycles+1;
   if(dv&&dr)begin
    if(dsize!=6||dburst!=1||daddr[5:0]!=0||did!=0||daddr+64*(dlen+1)>BEATS*64||daddr[11:0]+64*(dlen+1)>4096)$fatal(1,"DDR_ADDRESS_PROTOCOL");
    active<=1;base<=daddr>>6;beats<=dlen+1;beat<=0;
   end
   if(rv&&rrdy)begin rv<=0;if(rl)active<=0;else beat<=beat+1;end
   if(active&&!rv&&cycles%7!=0)begin rd<=ddr[base+beat];rl<=beat==beats-1;rp<=ddr_error&&first_response?2:0;first_response<=0;rv<=1;end
   if(`SYS.a_req_valid&&`SYS.a_req_ready)begin
    if(pending)$fatal(1,"A_TWO_OUTSTANDING");pending<=1;pending_addr<=`SYS.a_req_addr;pending_tag<=`SYS.a_req_tag;pending_keep<=`SYS.a_req_keep;
   end
   if(`SYS.a_rsp_valid&&`SYS.a_rsp_ready)begin
    if(!pending||`SYS.a_rsp_error||`SYS.a_rsp_tag!==pending_tag||`SYS.a_rsp_keep!==pending_keep)$fatal(1,"A_TAG_OWNER");pending<=0;
    for(integer b=0;b<16;b=b+1)if(pending_keep[b])begin
     if(pending_addr+b>=K||read_seen[pending_addr+b])$fatal(1,"A_BOUNDARY_DUPLICATE");
     if(`SYS.a_rsp_data[8*b+:8]!==input_bytes[pending_addr+b])$fatal(1,"INPUT_ENCODING_MISMATCH index=%0d got=%h expected=%h",pending_addr+b,`SYS.a_rsp_data[8*b+:8],input_bytes[pending_addr+b]);
     read_seen[pending_addr+b]<=1;
    end
    input_count<=input_count+$countones(pending_keep);
   end
   if(`SYS.wb_valid&&`SYS.wb_ready)begin
    for(integer b=0;b<16;b=b+1)if(`SYS.wb_keep[b])begin
     if(`SYS.wb_raw||`SYS.wb_addr+b<20'h84000||`SYS.wb_addr+b>=20'h84000+COUNT)$fatal(1,"WB_BOUNDARY");
     if(written[`SYS.wb_addr+b-20'h84000])$fatal(1,"WB_DUPLICATE");
     if(`SYS.wb_data[8*b+:8]!==expected[`SYS.wb_addr+b-20'h84000])$fatal(1,"ACT_WRITE_MISMATCH index=%0d",`SYS.wb_addr+b-20'h84000);
     written[`SYS.wb_addr+b-20'h84000]<=1;
    end
    write_count<=write_count+$countones(`SYS.wb_keep);
   end
  end
 end
 always @(negedge clk)begin
  if(!aresetn||`TILE.core_clear)for(q=0;q<128;q=q+1)prefix[q]=0;
  else if(`TILE.commit_valid)begin
   for(q=0;q<128;q=q+1)begin
    product=(q/16<`TILE.rows_q&&q%16<`TILE.cols_q)?$signed(`TILE.a_memory[`TILE.commit_k][8*(q/16)+:8])*$signed(`TILE.b_memory[`TILE.commit_k][8*(q%16)+:8]):0;
    prefix[q]=prefix[q]+product;if(`TILE.p_all[48*q+:32]!==prefix[q])$fatal(1,"REAL128_PREFIX_MISMATCH k=%0d lane=%0d",`TILE.commit_k,q);prefix_count=prefix_count+1;
   end
  end
 end
 task automatic axi_write(input [31:0] address,value,input [1:0] response);
 begin @(negedge clk);awaddr=address;awvalid=1;do @(posedge clk);while(!awready);@(negedge clk);awvalid=0;repeat(2)@(negedge clk);wdata=value;wvalid=1;do @(posedge clk);while(!wready);@(negedge clk);wvalid=0;wait(bvalid);repeat(3)begin @(negedge clk);if(!bvalid||bresp!==response)$fatal(1,"AXI_WRITE_RESPONSE");end bready=1;@(negedge clk);bready=0;end endtask
 task automatic axi_read(input [31:0] address,output [31:0] value,input [1:0] response);
 reg [31:0] held;begin @(negedge clk);araddr=address;arvalid=1;do @(posedge clk);while(!arready);@(negedge clk);arvalid=0;wait(rvalid);held=rdata;repeat(3)begin @(negedge clk);if(!rvalid||rdata!==held||rresp!==response)$fatal(1,"HOST_BACKPRESSURE");end value=rdata;rready=1;@(negedge clk);rready=0;end endtask
 initial begin
  bad_expected=$test$plusargs("BAD_EXPECTED");ddr_error=$test$plusargs("DDR_RRESP");bad_input=$test$plusargs("BAD_INPUT_ENCODING");early_reset=$test$plusargs("EARLY_RESET");if($test$plusargs("REPEAT_JOB"))jobs=2;
  if(bad_input&&!HEAD)$readmemh({DIR,"/ddr_bad_input.hex"},ddr);else $readmemh({DIR,"/ddr512.hex"},ddr);
  $readmemh({DIR,"/input.hex"},input_bytes);$readmemh({DIR,"/expected.hex"},expected);
  repeat(5)@(negedge clk);aresetn=1;calibrated=1;repeat(8)@(negedge clk);axi_read(32'h1000,observed,2);
  for(job=0;job<jobs;job=job+1)begin
   written=0;read_seen=0;write_count=0;input_count=0;pending=0;prefix_count=0;load_cycles=0;run_cycles=0;collect_cycles=0;
   axi_write(0,1,0);
   if(early_reset&&job==0)begin repeat(127)@(negedge clk);aresetn=0;repeat(5)@(negedge clk);aresetn=1;repeat(8)@(negedge clk);axi_write(0,1,0);end
   wait(busy);if(!ddr_error)axi_write(0,1,2);wait(done);
   if(ddr_error)begin if(!error)$fatal(1,"DDR_ERROR_UNDETECTED");$display("ADOPTED_DDR_FI_PASS");$finish;end
   if(error||written!=={COUNT{1'b1}}||read_seen!=={K{1'b1}}||prefix_count==0||write_count!=COUNT||input_count!=K)$fatal(1,"CLOSEDLOOP_COMPLETION");
   if(dut.engine.compute.sequencer.completed_commands!=1||dut.engine.compute.sequencer.completed_loads!=4)$fatal(1,"PROGRAM_SCOPE");
   fd=$fopen($sformatf("host_%0d.hex",job),"w");host_count=0;
   for(i=0;i<COUNT/4;i=i+1)begin axi_read(32'h1000+4*i,observed,0);for(integer b=0;b<4;b=b+1)begin
    if(observed[8*b+:8]!==(expected[4*i+b]^((bad_expected&&4*i+b==(HEAD?37:7))?8'h1:8'h0)))$fatal(1,"HOST_GOLDEN_MISMATCH index=%0d",4*i+b);
    $fdisplay(fd,"%02x",observed[8*b+:8]);host_count=host_count+1;end end
   $fclose(fd);axi_read(32'h1000+COUNT,observed,2);if(host_count!=COUNT)$fatal(1,"HOST_COUNT");
   $display("ADOPTED_JOB_PASS head=%0d job=%0d host=%0d prefixes=%0d cycles=%0d load=%0d compute=%0d collect=%0d",HEAD,job,host_count,prefix_count,cycles,load_cycles,run_cycles,collect_cycles);
  end
  $display("ADOPTED_CLOSEDLOOP_PASS head=%0d jobs=%0d",HEAD,jobs);$finish;
 end
endmodule
`include "adopted_case_wrappers.vh"
