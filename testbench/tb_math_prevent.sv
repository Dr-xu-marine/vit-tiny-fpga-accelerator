`timescale 1ns/1ps
`include "w8_test_paths.vh"
module tb_math_prevent;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,flush=0,iv=0,ready=0;reg [2:0] op;reg signed [127:0] a,b;reg [6:0] sh;reg [15:0] tag;
 wire ir,ov,err,bir,bov,berr;wire [127:0] data,bd;wire [15:0] ot,bt;
 w8_math dut(clk,rst,flush,iv,ir,op,a,b,sh,tag,ov,ready,data,ot,err);
 w8_math_baseline baseline(clk,rst,flush,iv,bir,op,a,b,sh,tag,bov,ready,bd,bt,berr);
 integer f,scan,code,s,e,n=0,cycles=0,begin_cycle,old_latency,new_latency,total_old=0,total_new=0,target,aborts=0;
 reg [127:0] va,vb,expected,held;reg flip;
 always @(posedge clk)begin cycles<=cycles+1;if(cycles>3000000)$fatal(1,"MATH_TIMEOUT");end
 // First DIV vector has divisor>1. Force a wrong first subtraction decision.
 initial if($test$plusargs("CARRY_FAULT"))begin
  wait(n==2&&dut.st==20);@(negedge clk);force dut.trial_take=1'b1;
  @(negedge clk);release dut.trial_take;
 end
 initial begin
  flip=$test$plusargs("BAD_EXPECTED");f=$fopen({`W8_ROOT,"/testbench/math_prevent_vectors.txt"},"r");if(!f)$fatal(1,"vectors missing");repeat(4)@(negedge clk);rst=0;
  while(!$feof(f))begin
   scan=$fscanf(f,"%d %h %h %d %h %d\n",code,va,vb,s,expected,e);if(scan!=6)$fatal(1,"MATH_VECTOR_PARSE");
   wait(ir&&bir);@(negedge clk);op=code;a=va;b=vb;sh=s;tag=n;iv=1;begin_cycle=cycles;@(negedge clk);iv=0;
   old_latency=-1;new_latency=-1;
   while(!(ov&&bov))begin @(negedge clk);if(bov&&old_latency<0)old_latency=cycles-begin_cycle;if(ov&&new_latency<0)new_latency=cycles-begin_cycle;end
   if(old_latency<0)old_latency=cycles-begin_cycle;if(new_latency<0)new_latency=cycles-begin_cycle;
   if(data!==(expected^((flip&&n==7)?128'd1:0))||err!==(e!=0)||ot!==n[15:0]||bd!==expected||berr!==(e!=0)||bt!==n[15:0])$fatal(1,"MATH_PREVENT_MISMATCH n=%0d op=%0d got=%h old=%h want=%h",n,code,data,bd,expected);
   total_old=total_old+old_latency;total_new=total_new+new_latency;held=data;
   repeat(4)begin @(negedge clk);if(!ov||data!==held||ot!==n[15:0]||err!==(e!=0))$fatal(1,"MATH_HOLD");end
   $display("MATH_LATENCY vector=%0d op=%0d old=%0d new=%0d",n,code,old_latency,new_latency);
   ready=1;@(negedge clk);ready=0;n=n+1;
  end
  // Every reachable datapath phase: cancel, then prove no stale completion.
  for(target=1;target<=24;target=target+1)begin
   wait(ir&&bir);@(negedge clk);op=0;a=-128'sh1234567812345678;b=128'sh7654321876543218;sh=0;tag=16'hf000+target;iv=1;
   if(target==8||target==9||target==10||target==11||target==12)begin op=1;a=-7;sh=1;end
   if(target==13||target==14||target==20||target>=22)begin op=2;a=128'h123456789abcdef0;b=97;end
   if(target==15||target==21)begin op=3;a=128'h123456789abcdef01234;end
   if(target==16)begin op=4;a=5;b=7;end
   @(negedge clk);iv=0;wait(dut.st==target);@(negedge clk);
   if(target%2)flush=1;else rst=1;@(negedge clk);flush=0;rst=0;
   repeat(5)begin @(negedge clk);if(ov||bov)$fatal(1,"MATH_STALE_ABORT phase=%0d",target);end
   if(!ir||!bir)$fatal(1,"MATH_ABORT_READY");aborts=aborts+1;
  end
  $display("MATH_PREVENT_PASS vectors=%0d abort_phases=%0d old_latency_sum=%0d new_latency_sum=%0d cycles=%0d",n,aborts,total_old,total_new,cycles);$finish;
 end
endmodule
