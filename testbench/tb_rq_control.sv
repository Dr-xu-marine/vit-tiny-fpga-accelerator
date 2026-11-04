`timescale 1ns/1ps
module tb_rq_control;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,flush=0,pwe=0,raw_mode=0,resv=0,rv=0,ready=0,rl=0;reg [2:0] prow=0,row=0;reg [719:0] pdata=0;reg [127:0] rtag=0,tag=0;reg [511:0] acc=0,bias=0;reg [15:0] keep=16'hffff;
 wire resready,ov,last,err;wire [127:0] data,otag;wire [511:0] raw;wire [15:0] okeep;wire [7:0] ec;wire [5:0] credits;
 w8_rq16 dut(.clk(clk),.rst(rst),.flush(flush),.param_we(pwe),.param_row(prow),.param_data(pdata),.raw_mode(raw_mode),.reserve_valid(resv),.reserve_ready(resready),.reserve_tag(rtag),.raw_valid(rv),.raw_row(row),.raw_acc(acc),.raw_bias(bias),.raw_keep(keep),.raw_tag(tag),.raw_last(rl),.out_valid(ov),.out_ready(ready),.out_data(data),.out_raw(raw),.out_keep(okeep),.out_tag(otag),.out_last(last),.error_valid(err),.error_code(ec),.debug_outstanding(credits));
 wire prr,pov,p_last,p_err;wire [127:0] p_data,p_tag;wire [511:0] p_raw;wire [15:0] p_keep;wire [7:0] p_ec;wire [5:0] p_credit;
 rq_parent oracle(.clk(clk),.rst(rst),.flush(flush),.param_we(pwe),.param_row(prow),.param_data(pdata),.raw_mode(raw_mode),.reserve_valid(resv),.reserve_ready(prr),.reserve_tag(rtag),.raw_valid(rv),.raw_row(row),.raw_acc(acc),.raw_bias(bias),.raw_keep(keep),.raw_tag(tag),.raw_last(rl),.out_valid(pov),.out_ready(ready),.out_data(p_data),.out_raw(p_raw),.out_keep(p_keep),.out_tag(p_tag),.out_last(p_last),.error_valid(p_err),.error_code(p_ec),.debug_outstanding(p_credit));
 integer cycles=0,batch,i,j,rr;reg [127:0] hd,ht;reg [511:0] hr;reg [15:0] hk;reg hl;
 integer checks=0;
 always @(negedge clk)begin
  #0.2;
  if({resready,ov,err,ec,credits}!=={prr,pov,p_err,p_ec,p_credit})$fatal(1,"RQ_CONTROL_MISMATCH cycle=%0d",cycles);
  if(ov&&{data,raw,okeep,otag,last}!=={p_data,p_raw,p_keep,p_tag,p_last})$fatal(1,"RQ_CONTROL_MISMATCH payload cycle=%0d",cycles);
  checks=checks+1;
 end
 initial if($test$plusargs("CORRUPT_RQ_LEGALITY"))begin wait(dut.group_bad!=0);force dut.group_bad=4'd0;end

 always @(posedge clk)begin cycles<=cycles+1;if(cycles>50000)$fatal(1,"RQQUEUE timeout");end
 task automatic barrier;
 begin @(negedge clk);flush=1;resv=0;rv=0;ready=0;@(negedge clk);flush=0;repeat(3)@(negedge clk);if(ov||credits!=0||err)$fatal(1,"queue barrier");end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(j=0;j<16;j=j+1)pdata[45*j+:45]={8'd0,6'd0,31'd1};
  for(i=0;i<8;i=i+1)begin @(negedge clk);pwe=1;prow=i;end
  @(negedge clk);pwe=0;
  for(batch=0;batch<2;batch=batch+1)begin
   raw_mode=batch==1;
   // Fill all16 reservations while output is blocked, then all16 raw rows.
   for(i=0;i<16;i=i+1)begin @(negedge clk);if(!resready)$fatal(1,"early credit full");resv=1;rtag=batch*100+i;end
   @(negedge clk);resv=0;if(resready||credits!=16)$fatal(1,"credit overflow boundary");
   for(i=0;i<16;i=i+1)begin
    @(negedge clk);rv=1;row=i%8;rl=i%8==7;tag=batch*100+i;keep=i%8==7?16'h01ff:16'hffff;
    for(j=0;j<16;j=j+1)acc[32*j+:32]=i*5+j-70;
   end
   @(negedge clk);rv=0;
   for(i=0;i<16;i=i+1)begin
    wait(ov);@(negedge clk);hd=data;ht=otag;hr=raw;hk=okeep;hl=last;
    if(ht!==128'(batch*100+i)||hl!==(i%8==7)||hk!==(i%8==7?16'h01ff:16'hffff))$fatal(1,"queue metadata");
    for(j=0;j<16;j=j+1)begin
     if(hr[32*j+:32]!==32'(i*5+j-70))$fatal(1,"queue raw");
     if(!raw_mode&&hk[j]&&$signed(hd[8*j+:8])!==(i*5+j-70))$fatal(1,"queue data");
    end
    repeat(4)begin @(negedge clk);if(!ov||data!==hd||otag!==ht||raw!==hr||okeep!==hk||last!==hl)$fatal(1,"queue hold");end
    ready=1;@(negedge clk);ready=0;
   end
   repeat(3)@(negedge clk);if(err||credits!=0||ov)$fatal(1,"queue drain");
  end
  // Protocol faults must raise sticky errors, with a flush recovery barrier.
  @(negedge clk);rv=1;@(negedge clk);rv=0;repeat(4)@(negedge clk);if(!err)$fatal(1,"unreserved row not detected");barrier();
  resv=1;rtag=17;@(negedge clk);resv=0;rv=1;row=0;rl=0;tag=18;@(negedge clk);rv=0;repeat(20)@(negedge clk);if(!err)$fatal(1,"tag fault not detected");barrier();
  // Strict frozen RQ contract rejects active-lane multiplier0 and shift63.
  raw_mode=0;
  for(batch=0;batch<2;batch=batch+1)begin
   @(negedge clk);pwe=1;prow=0;pdata[44:0]=batch==0?{8'd0,6'd0,31'd0}:{8'd0,6'd63,31'd1};
   @(negedge clk);pwe=0;resv=1;rtag=91+batch;
   @(negedge clk);resv=0;rv=1;row=0;rl=0;tag=91+batch;keep=16'hffff;
   @(negedge clk);rv=0;repeat(30)@(negedge clk);if(!err||ec!==8'h35)$fatal(1,"invalid RQ parameter missed");barrier();
  end
  for(batch=0;batch<16;batch=batch+1)begin
   for(j=0;j<16;j=j+1)pdata[45*j+:45]={8'd0,6'd0,31'd1};
   pdata[45*batch+:45]={8'd0,6'd0,31'd0};
   @(negedge clk);pwe=1;prow=0;@(negedge clk);pwe=0;resv=1;rtag=200+batch;
   @(negedge clk);resv=0;rv=1;row=0;rl=0;tag=200+batch;keep=16'hffff;
   @(negedge clk);rv=0;wait(err);if(ec!==8'h35)$fatal(1,"wrong lane parameter error");barrier();
  end
  // The same illegal parameter is ignored when its lane is masked off.
  for(j=0;j<16;j=j+1)pdata[45*j+:45]={8'd0,6'd0,31'd1};pdata[45*15+:45]=0;
  @(negedge clk);pwe=1;prow=0;@(negedge clk);pwe=0;resv=1;rtag=300;
  @(negedge clk);resv=0;rv=1;row=0;rl=0;tag=300;keep=16'h7fff;
  @(negedge clk);rv=0;wait(ov);if(err||data[127:120]!==0)$fatal(1,"masked parameter was used");ready=1;
  @(negedge clk);ready=0;barrier();
  rst=1;@(negedge clk);rst=0;repeat(3)@(negedge clk);if(ov||credits!=0)$fatal(1,"queue reset");
  $display("RQ_CONTROL_PASS rows=33 credit_boundary=16 invalid_active_lanes=16 masked_invalid=1 checks=%0d",checks);$finish;
 end
endmodule
