`include "w8_test_paths.vh"
`timescale 1ns/1ps
module tb_w8_tile #(parameter CORE_FAULT=0,RQ_FAULT=0,TOP_FAULT=0);
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,flush=0,aw=0,bw=0,biasw=0,rqw=0,start=0,feed=1,ready=0,raw_mode=0,dyn=0;
 reg [9:0] addr=0,K=1;reg [63:0] a;reg [127:0] b;reg [3:0] bc=0,rows=3;reg signed [31:0] bias;
 reg [2:0] rqrow;reg [719:0] rq;reg [4:0] cols=9;reg [127:0] tag=0;
 wire sr,ov,last,busy,done,err;wire [7:0] ec;wire [127:0] out_data,out_tag;wire [511:0] raw;wire [15:0] keep;
 w8_quant_tile #(.CORE_FAULT(CORE_FAULT),.RQ_FAULT(RQ_FAULT),.TOP_FAULT(TOP_FAULT)) dut(.clk(clk),.rst(rst),.flush(flush),.a_we(aw),.a_addr(addr),.a_data(a),.b_we(bw),.b_addr(addr),.b_data(b),.bias_we(biasw),.bias_col(bc),.bias_data(bias),.rq_we(rqw),.rq_row(rqrow),.rq_data(rq),.raw_mode(raw_mode),.dynamic_zp(dyn),.input_zp(8'sh80),.out_raw(raw),.start_valid(start),.start_ready(sr),.k_len(K),.rows_valid(rows),.cols_valid(cols),.job_tag(tag),.feed_enable(feed),.out_valid(ov),.out_ready(ready),.out_data(out_data),.out_keep(keep),.out_tag(out_tag),.out_last(last),.busy(busy),.done(done),.error_valid(err),.error_code(ec));
 integer aa[0:767][0:7],bb[0:767][0:15],prefix[0:127],expected[0:127];integer cycles=0,rc=0,rv_count=0,job=0,kk,r,c,j,pk;reg [127:0] expected_tag;longint signed v,mag,q,remv;reg flip,aborting=0;
 function automatic integer rne20(input longint signed val);
 longint signed u,t,remn;begin u=val<0?-val:val;t=u>>20;remn=u-(t<<20);if(remn>524288||(remn==524288&&(t&1)))t=t+1;rne20=val<0?-t:t;end endfunction
 always @(posedge clk)begin cycles<=cycles+1;if(cycles>500000)$fatal(1,"TILE timeout");if(!rst&&!flush&&err&&!aborting)$fatal(1,"TILE error %h",ec);end
 always @(negedge clk)begin
  if(rst||flush||dut.core_clear)for(pk=0;pk<128;pk=pk+1)prefix[pk]=0;
  else if(dut.commit_valid)begin
   for(pk=0;pk<128;pk=pk+1)begin
    prefix[pk]=prefix[pk]+((pk/16<rows&&pk%16<cols)?aa[dut.commit_k][pk/16]*bb[dut.commit_k][pk%16]:0);
    if(dut.p_all[48*pk+:32]!==prefix[pk])$fatal(1,"TILE_PREFIX_MISMATCH job=%0d k=%0d lane=%0d",job,dut.commit_k,pk);
   end
  end
 end
 task automatic runjob(input integer len,nr,nc,input bit dynamic_mode,raw_mode_arg);
 integer kr,rr,cc,sum,ws,quant;reg [15:0] mask;reg [127:0] helddata;reg [511:0] heldraw;
 begin
  wait(sr);K=len;rows=nr;cols=nc;dyn=dynamic_mode;raw_mode=raw_mode_arg;tag={64'd1234,48'd0,job[15:0]};
  for(kr=0;kr<len;kr=kr+1)begin
   @(negedge clk);addr=kr;aw=1;bw=1;
   for(rr=0;rr<8;rr=rr+1)begin aa[kr][rr]=((kr*17+rr*11+job*3)%256)-128;a[8*rr+:8]=aa[kr][rr];end
   for(cc=0;cc<16;cc=cc+1)begin bb[kr][cc]=((kr*13+cc*7+job*5)%256)-128;b[8*cc+:8]=bb[kr][cc];end
  end
  @(negedge clk);aw=0;bw=0;
  for(cc=0;cc<16;cc=cc+1)begin @(negedge clk);biasw=1;bc=cc;bias=cc*31-177;end
  @(negedge clk);biasw=0;rq=0;for(cc=0;cc<16;cc=cc+1)rq[45*cc+:45]={8'd0,6'd20,31'd65537};
  for(rr=0;rr<8;rr=rr+1)begin @(negedge clk);rqw=1;rqrow=rr;end
  @(negedge clk);rqw=0;repeat(3)@(negedge clk);start=1;@(negedge clk);start=0;rc=0;
  while(rc<8)begin
   @(negedge clk);feed=cycles%5!=0;ready=0;
   if(ov)begin
    helddata=out_data;heldraw=raw;expected_tag=tag;expected_tag[95:80]=tag[95:80]+rc;
    mask=rc<nr?((17'd1<<nc)-1):0;
    if(out_tag!==expected_tag||keep!==mask||last!==(rc==7))$fatal(1,"TILE protocol row=%0d",rc);
    for(cc=0;cc<nc&&rc<nr;cc=cc+1)begin
     sum=0;ws=0;for(kr=0;kr<len;kr=kr+1)begin sum=sum+aa[kr][rc]*bb[kr][cc];ws=ws+bb[kr][cc];end
     if(raw_mode)begin if(raw[32*cc+:32]!==sum)$fatal(1,"TILE_RAW_MISMATCH");end
     else begin quant=rne20((64'sd0+sum+cc*31-177+(dyn?128*ws:0))*65537);if(quant>127)quant=127;if(quant< -128)quant=-128;
      if($signed(out_data[8*cc+:8])!==(quant+((flip&&rc==0&&cc==0)?1:0)))$fatal(1,"TILE_RQ_MISMATCH row=%0d col=%0d",rc,cc);
     end
    end
    repeat(3)begin @(negedge clk);if(!ov||out_data!==helddata||raw!==heldraw||out_tag!==expected_tag)$fatal(1,"TILE backpressure");end
    ready=1;@(negedge clk);ready=0;rc=rc+1;
   end
  end
  wait(sr);job=job+1;
 end endtask
 initial begin
  flip=$test$plusargs("BAD_EXPECTED");repeat(4)@(negedge clk);rst=0;
  runjob(1,1,1,0,0);runjob(3,3,9,0,0);runjob(192,8,16,0,0);runjob(197,3,9,1,0);runjob(768,8,16,0,1);
  // Deliberate cancellation: no stale row may survive the flush/reset barrier.
  aborting=1;@(negedge clk);start=1;@(negedge clk);start=0;repeat(17)@(negedge clk);flush=1;@(negedge clk);flush=0;repeat(300)@(negedge clk);if(ov||busy)$fatal(1,"flush stale");
  rst=1;@(negedge clk);rst=0;aborting=0;runjob(3,1,7,0,0);
  $display("W8_TILE_PASS jobs=%0d cycles=%0d",job,cycles);$finish;
 end
endmodule
