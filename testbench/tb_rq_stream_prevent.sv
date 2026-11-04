`timescale 1ns/1ps
`include "w8_test_paths.vh"
module tb_rq_stream_prevent;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,ce=1,iv=0,last=0,mode=0,overflow=0;
 reg signed [31:0] acc=0,bias=0;reg [30:0] mult=0;reg [5:0] sh=0;reg signed [15:0] zp=0;reg [15:0] tag=0;
 wire ov,ol,om,sat;wire [15:0] ot;wire signed [15:0] y;wire [2:0] err;
 w8_requant_scalar dut(.clk(clk),.rst(rst),.ce(ce),.in_valid(iv),.in_acc(acc),.in_bias_corr(bias),.in_multiplier(mult),.in_shift(sh),.in_zero_point(zp),.in_int8(mode),.in_last(last),.in_tag(tag),.in_overflow(overflow),.out_valid(ov),.out_data(y),.out_int8(om),.out_last(ol),.out_tag(ot),.out_saturated(sat),.out_error(err));
 reg [31:0] expected[0:1023],errors[0:1023],sats[0:1023],modes[0:1023];
 integer f,sc,sent=0,received=0,cycles=0,phase=0,ce_cycles=0,ii1_pairs=0;integer accepted_age[0:1023];reg previous_fire=0;reg [31:0] a,b,m,s,z,md,o,v,e,st;reg [38:0] held;reg flip;
 always @(posedge clk)begin
  cycles<=cycles+1;if(cycles>20000)$fatal(1,"RQ_STREAM_TIMEOUT");
  previous_fire<=!rst&&ce&&iv;
  if(rst)ce_cycles<=0;
  else if(ce)begin ce_cycles<=ce_cycles+1;if(iv&&phase==0)begin accepted_age[tag]=ce_cycles;if(previous_fire)ii1_pairs=ii1_pairs+1;end end
  if(!rst&&ce&&ov&&phase==0)begin
   if(ce_cycles-accepted_age[ot]!=12)$fatal(1,"RQ_ENABLED_LATENCY");
   if(ot!==received[15:0]||y!==16'(expected[received]^((flip&&received==73)?32'd1:0))||err!==3'(errors[received])||sat!==1'(sats[received])||om!==1'(modes[received])||ol!==(received==1023))$fatal(1,"RQ_STREAM_MISMATCH %0d",received);
   received=received+1;
  end
 end
 initial begin
  flip=$test$plusargs("BAD_EXPECTED");f=$fopen({`W8_ROOT,"/testbench/rq_stream_vectors.txt"},"r");if(!f)$fatal(1,"RQ_STREAM_VECTORS");repeat(4)@(negedge clk);rst=0;
  while(!$feof(f))begin
   sc=$fscanf(f,"%h %h %h %h %h %h %h %h %h %h\n",a,b,m,s,z,md,o,v,e,st);if(sc!=10)$fatal(1,"RQ_STREAM_PARSE");
   @(negedge clk);iv=0;
   if(sent%11==0)begin ce=0;#0.2;held={ov,ol,om,sat,err,ot,y};repeat(3)begin @(negedge clk);if({ov,ol,om,sat,err,ot,y}!==held)$fatal(1,"RQ_CE_HOLD");end ce=1;end
   expected[sent]=v;errors[sent]=e;sats[sent]=st;modes[sent]=md;
   acc=a;bias=b;mult=m;sh=s;zp=z;mode=md;overflow=o;tag=sent;last=sent==1023;iv=1;sent=sent+1;
   if(sent%5==0)begin @(negedge clk);iv=0;repeat(2)@(negedge clk);end
  end
  @(negedge clk);iv=0;wait(received==sent);if(ii1_pairs<10)$fatal(1,"RQ_NO_II1_COVERAGE");@(negedge clk);phase=1;iv=1;acc=7;bias=0;mult=1;sh=0;overflow=0;tag=16'hdead;
  @(negedge clk);iv=0;repeat(5)@(negedge clk);rst=1;repeat(2)@(negedge clk);rst=0;
  repeat(20)begin @(negedge clk);if(ov)$fatal(1,"RQ_RESET_STALE");end
  $display("RQ_STREAM_PREVENT_PASS vectors=%0d int8_int16=1 ce_hold=1 bubbles=1 reset_inflight=1 latency=12 ii1_pairs=%0d cycles=%0d",received,ii1_pairs,cycles);$finish;
 end
endmodule
