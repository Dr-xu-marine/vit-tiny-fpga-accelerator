`timescale 1ns/1ps
module tb_w8_rqlimits;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,ce=1,iv=0;reg signed [31:0] acc,bias;reg [30:0] mult;reg [5:0] shift;reg signed [15:0] zp;reg overflow;reg [15:0] tag;
 wire valid,last,saturated;wire signed [15:0] data;wire [15:0] outtag;wire [2:0] error;
 w8_requant_scalar dut(.clk(clk),.rst(rst),.ce(ce),.in_valid(iv),.in_acc(acc),.in_bias_corr(bias),.in_multiplier(mult),.in_shift(shift),.in_zero_point(zp),.in_int8(1'b1),.in_last(1'b0),.in_tag(tag),.in_overflow(overflow),.out_valid(valid),.out_data(data),.out_int8(),.out_last(last),.out_tag(outtag),.out_saturated(saturated),.out_error(error));
 integer f,sc,s,z,o,y,e,received=0,sent=0,cycles=0;reg [31:0] a,b,m;integer golden[0:127],errors[0:127];reg flip,held=0;reg [37:0] holdword;
 always @(posedge clk)begin
  cycles<=cycles+1;if(cycles>10000)$fatal(1,"RQLIMIT timeout");
  if(!rst)begin
   if(held&&{valid,data,outtag,error,last,saturated}!==holdword)$fatal(1,"RQLIMIT CE hold");held=!ce;holdword={valid,data,outtag,error,last,saturated};
   if(ce&&valid)begin
    if(outtag!==received[15:0]||data!==16'(golden[received]+((flip&&received==7)?1:0))||error!==3'(errors[received])||last)$fatal(1,"RQLIMIT_MISMATCH index=%0d",received);
    received=received+1;
   end
  end
 end
 initial begin
  flip=$test$plusargs("BAD_EXPECTED");f=$fopen("testbench/rq_limits.txt","r");if(!f)$fatal(1,"limits missing");repeat(4)@(negedge clk);rst=0;
  while(!$feof(f))begin
   sc=$fscanf(f,"%h %h %h %h %h %h %h %h\n",a,b,m,s,z,o,y,e);if(sc!=8)$fatal(1,"limit parse");golden[sent]=y;errors[sent]=e;
   @(negedge clk);iv=0;if(sent%5==0)begin ce=0;repeat(3)@(negedge clk);end ce=1;acc=a;bias=b;mult=m;shift=s;zp=z;overflow=o;tag=sent;iv=1;sent=sent+1;@(negedge clk);iv=0;
  end
  wait(received==sent);repeat(3)@(negedge clk);$display("W8_RQLIMITS_PASS vectors=%0d cycles=%0d",received,cycles);$finish;
 end
endmodule
