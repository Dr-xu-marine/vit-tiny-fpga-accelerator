`include "w8_test_paths.vh"
`timescale 1ns/1ps
module tb_w8_rq;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,ce=1,iv=0,last=0;reg signed [31:0] acc,bias;reg [30:0] m;reg [5:0] shift;reg signed [15:0] zp;reg [15:0] tag;
 wire ov,ol,sat;wire [15:0] ot;wire signed [15:0] y;wire [2:0] err;
 w8_requant_scalar dut(.clk(clk),.rst(rst),.ce(ce),.in_valid(iv),.in_acc(acc),.in_bias_corr(bias),.in_multiplier(m),.in_shift(shift),.in_zero_point(zp),.in_int8(1'b1),.in_last(last),.in_tag(tag),.in_overflow(1'b0),.out_valid(ov),.out_data(y),.out_int8(),.out_last(ol),.out_tag(ot),.out_saturated(sat),.out_error(err));
 integer expected[0:255],f,s,z,e,sc,sent=0,received=0,cycles=0;reg [31:0] va,vb,vm;reg flip;
 always @(negedge clk)if(!rst&&ce&&ov)begin
  if(ot!==received[15:0]||y!==$signed(expected[received]+((flip&&received==19)?1:0))||err!==0||ol!==(received==255))$fatal(1,"RQ mismatch %0d",received);
  received=received+1;
 end
 always @(posedge clk)begin cycles<=cycles+1;if(cycles>10000)$fatal(1,"RQ timeout");end
 initial begin
  flip=$test$plusargs("BAD_EXPECTED");f=$fopen({`W8_ROOT,"/testbench/rq_vectors.txt"},"r");if(!f)$fatal(1,"vectors");repeat(4)@(negedge clk);rst=0;
  while(!$feof(f))begin
   @(negedge clk);iv=0;ce=1;
   sc=$fscanf(f,"%h %h %h %d %d %d\n",va,vb,vm,s,z,e);if(sc!=6)$fatal(1,"vector parse sc=%0d f=%h va=%h vb=%h vm=%h s=%0d z=%0d e=%0d pos=%0d",sc,f,va,vb,vm,s,z,e,$ftell(f));expected[sent]=e;
   // Hold both valid and data when CE=0, matching the scalar pipeline contract.
   if(sent%7==0)begin ce=0;repeat(3)@(negedge clk);ce=1;end
   acc=va;bias=vb;m=vm;shift=s;zp=z;tag=sent;last=sent==255;iv=1;sent=sent+1;
   @(negedge clk);iv=0;
  end
  wait(received==sent);repeat(3)@(negedge clk);rst=1;repeat(2)@(negedge clk);rst=0;repeat(20)@(negedge clk);if(ov)$fatal(1,"stale reset");
  $display("W8_RQ_PASS vectors=%0d cycles=%0d",received,cycles);$finish;
 end
endmodule
