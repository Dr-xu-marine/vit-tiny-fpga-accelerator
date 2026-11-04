`timescale 1ns/1ps
`include "control_cases.vh"
module tb_control_joint;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,start=0;reg [511:0] command=0;
 wire busy,done,reject;
 w8_command_check dut(.clk(clk),.rst(rst),.start(start),.command(command),.busy(busy),.done(done),.bad(reject));
 `include "legacy_command_bad.vh"
 reg [512:0] cases[0:`CONTROL_CASES-1];
 reg [511:0] saved;reg want;integer i,j,elapsed,compared=0,aborts=0;
 initial begin
  $readmemh(`CONTROL_CASE_PATH,cases);
  repeat(4)@(negedge clk);rst=0;
  for(i=0;i<`CONTROL_CASES;i=i+1)begin
   saved=cases[i][511:0];want=cases[i][512];
   if(bad(saved)!==want)$fatal(1,"LEGACY_ORACLE_MISMATCH index=%0d",i);
   command=saved;start=1;@(negedge clk);start=0;elapsed=0;
   while(!done)begin
    // Mutating pins and ignored busy starts must not change the bound job.
    command=~saved;start=(elapsed==2);@(negedge clk);elapsed=elapsed+1;
    if(elapsed>24)$fatal(1,"CONTROL_TIMEOUT %0d",i);
   end
   start=0;
   if(reject!==(want^($test$plusargs("BAD_EXPECTED")&&i==0)))$fatal(1,"CONTROL_MISMATCH index=%0d actual=%b expected=%b",i,reject,want);
   compared=compared+1;@(negedge clk);
  end
  // Reset every in-flight phase, then require no completion from cancelled job.
  for(j=0;j<15;j=j+1)begin
   command=512'd0;command[31:0]=1;command[159:128]=197;command[191:160]=768;command[223:192]=1000;
   start=1;@(negedge clk);start=0;repeat(j)@(negedge clk);rst=1;@(negedge clk);rst=0;
   repeat(20)begin @(negedge clk);if(done||busy)$fatal(1,"RESET_STALE");end
   aborts=aborts+1;
  end
  $display("CONTROL_JOINT_PASS compared=%0d reset_phases=%0d",compared,aborts);$finish;
 end
 initial begin #10000000;$fatal(1,"CONTROL_GLOBAL_TIMEOUT");end
endmodule
