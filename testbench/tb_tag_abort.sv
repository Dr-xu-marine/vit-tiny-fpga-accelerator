`timescale 1ns/1ps
module tb_tag_abort;
 tb_adopted_case #(.HEAD(1),.BEATS(3216)) actual();
 integer seen_abort=0,ticks;
 always @(negedge actual.clk)if(actual.dut.engine.compute.system_unit.tile.gemm.state==19)begin
  if(!actual.dut.engine.compute.system_unit.tile.gemm.tile_abort_q)$fatal(1,"TAG_ABORT_WRONG_RESET_AGE");seen_abort=seen_abort+1;
 end
 initial begin
  wait(actual.dut.engine.compute.system_unit.a_rsp_valid);@(negedge actual.clk);
  // Poison the real transport tag. Match only the outer TB's copy to allow
  // the GEMM's own private owner checker and ABORT logic to handle the fault.
  force actual.dut.engine.compute.system_unit.buffers.response_tag=16'hdead;
  force actual.pending_tag=16'hdead;
  ticks=0;
  while(!actual.dut.engine.compute.system_unit.tile.gemm.error_valid)begin @(negedge actual.clk);ticks=ticks+1;if(ticks>20)$fatal(1,"TAG_ABORT_UNDETECTED");end
  if(actual.dut.engine.compute.system_unit.tile.gemm.error_code!==8'h0b||seen_abort!=1)$fatal(1,"TAG_ABORT_WRONG_ERROR");
  release actual.dut.engine.compute.system_unit.buffers.response_tag;release actual.pending_tag;
  $display("TAG_ABORT_PASS error=0b same_age_abort_cycles=%0d",seen_abort);$finish;
 end
endmodule
