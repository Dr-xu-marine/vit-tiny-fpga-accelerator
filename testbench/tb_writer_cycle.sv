`timescale 1ns/1ps
module tb_writer_cycle;
 reg clk=0;always #2.5 clk=~clk;reg rst=1,start=0,bv=0,hr=0,he=0;
 reg [3:0] target=0;reg [511:0] bd=0;reg [63:0] mask=0;reg [23:0] addr=0;
 wire br0,br1,hv0,hv1,busy0,busy1,done0,done1,err0,err1;wire [3:0] t0,t1;wire [23:0] a0,a1;wire [7:0] d0,d1;
 writer_parent oracle(.clk(clk),.rst(rst),.job_start(start),.job_target(target),.beat_valid(bv),.beat_ready(br0),.beat_data(bd),.beat_strb(mask),.beat_addr(addr),.host_valid(hv0),.host_ready(hr),.host_error(he),.host_target(t0),.host_byte_addr(a0),.host_wdata(d0),.busy(busy0),.beat_done(done0),.error(err0));
 tiny_dma_byte_writer dut(.clk(clk),.rst(rst),.job_start(start),.job_target(target),.beat_valid(bv),.beat_ready(br1),.beat_data(bd),.beat_strb(mask),.beat_addr(addr),.host_valid(hv1),.host_ready(hr),.host_error(he),.host_target(t1),.host_byte_addr(a1),.host_wdata(d1),.busy(busy1),.beat_done(done1),.error(err1));
 integer cycles=0,checks=0,accepted=0,beats=0,stalls=0,i,j,phase,seed;
 reg [31:0] rng=32'h6c892bf3;
 always @(posedge clk)begin cycles<=cycles+1;if(cycles>30000)$fatal(1,"WRITER_TIMEOUT");if(hv1&&hr)accepted<=accepted+1;if(hv1&&!hr)stalls<=stalls+1;end
 always @(negedge clk)begin
  rng=1664525*rng+1013904223;hr=!rst&&rng[3:0]!=0&&rng[2:0]!=3;
  #0.2;
  if({br0,hv0,busy0,done0,err0}!=={br1,hv1,busy1,done1,err1})$fatal(1,"WRITER_CYCLE_MISMATCH control cycle=%0d",cycles);
  if(hv1&&{t0,a0,d0}!=={t1,a1,d1})$fatal(1,"WRITER_CYCLE_MISMATCH payload cycle=%0d addr=%h expected=%h",cycles,a1,a0);
  checks=checks+1;
 end
 task automatic configure(input [3:0] t);
 begin @(negedge clk);target=t;start=1;@(negedge clk);start=0;end endtask
 task automatic beat(input [23:0] a,input [63:0] m,input integer s);
 begin
  @(negedge clk);addr=a;mask=m;for(integer k=0;k<64;k=k+1)bd[8*k+:8]=8'(s+29*k);bv=1;
  do @(posedge clk);while(!br1);@(negedge clk);bv=0;
  wait(done1);@(negedge clk);beats=beats+1;
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;configure(0);
  beat(24'd17,64'hffffffffffffffff,31);beat(24'd4090,64'h55aa55aa55aa55aa,51);beat(24'd0,64'd0,77);
  for(i=0;i<64;i=i+1)begin configure(i%13);beat(8192+61*i,64'h92317ab84c65d0ef^(64'h0101010101010101*i),i*7);end
  configure(0);beat(24'hffffe0,64'hffffffffffffffff,19);if(!err1)$fatal(1,"WRITER_OVERFLOW_MISSED");
  configure(2);beat(24'hffffe0,64'h00000000ffffffff,29);if(err1)$fatal(1,"WRITER_MASKED_OVERFLOW");
  // Error response and reset at different byte positions; no hidden advance.
  configure(4);@(negedge clk);bv=1;addr=65530;mask=~64'd0;bd=~512'd0;do @(posedge clk);while(!br1);@(negedge clk);bv=0;
  repeat(9)@(negedge clk);he=1;@(negedge clk);he=0;wait(done1);@(negedge clk);if(!err1)$fatal(1,"WRITER_HOST_ERROR_MISSED");
  for(phase=0;phase<16;phase=phase+1)begin
   configure(phase%13);@(negedge clk);bv=1;addr=1234;mask=~64'd0;do @(posedge clk);while(!br1);@(negedge clk);bv=0;
   repeat(phase+1)@(negedge clk);rst=1;@(negedge clk);rst=0;repeat(3)@(negedge clk);
   if(hv1||busy1||done1||err1)$fatal(1,"WRITER_RESET_STALE");
  end
  configure(1);beat(12345,64'h8000000000000001,93);
  $display("WRITER_CYCLE_PASS checks=%0d beats=%0d accepted_bytes=%0d stalled_cycles=%0d reset_phases=16 cycles=%0d",checks,beats,accepted,stalls,cycles);$finish;
 end
 initial if($test$plusargs("CORRUPT_WRITER"))begin wait(hv1);force dut.byte_address_q=25'd0;end
endmodule
