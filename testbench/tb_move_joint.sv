`timescale 1ns/1ps
module tb_move_joint;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,start=0;reg [19:0] a=0,y=0,srs=0,scs=0,drs=0,dcs=0;
 reg [9:0] rows=1,cols=1;
 wire sr0,sr1,we0,we1,busy0,busy1,done0,done1,err0,err1;
 wire [19:0] sa0,sa1,da0,da1;wire [7:0] wd0,wd1;reg [7:0] rd0=0,rd1=0;
 tiny_tensor_move old(.clk(clk),.rst(rst),.start(start),.src_base(a),.dst_base(y),.rows(rows),.cols(cols),.src_row_stride(srs),.src_col_stride(scs),.dst_row_stride(drs),.dst_col_stride(dcs),.src_re(sr0),.src_addr(sa0),.src_rdata(rd0),.dst_we(we0),.dst_addr(da0),.dst_wdata(wd0),.busy(busy0),.done(done0),.error(err0));
 w8_tensor_move dut(.clk(clk),.rst(rst),.start(start),.src_base(a),.dst_base(y),.rows(rows),.cols(cols),.src_row_stride(srs),.src_col_stride(scs),.dst_row_stride(drs),.dst_col_stride(dcs),.src_re(sr1),.src_addr(sa1),.src_rdata(rd1),.dst_we(we1),.dst_addr(da1),.dst_wdata(wd1),.busy(busy1),.done(done1),.error(err1));
 function automatic [7:0] memory(input [19:0] addr);memory=addr[7:0]^addr[15:8]^{4'd0,addr[19:16]}^8'h97;endfunction
 reg [19:0] old_src[0:1023],old_dst[0:1023];reg [7:0] old_data[0:1023];
 integer reads0=0,reads1=0,writes0=0,writes1=0,job=0,cycles=0,comparisons=0;
 reg checking=0;
 always @(posedge clk)begin
  cycles<=cycles+1;
  if(sr0)begin rd0<=memory(sa0);if(checking)begin old_src[reads0]=sa0;reads0=reads0+1;end end
  if(sr1)begin
   rd1<=memory(sa1);
   if(checking)begin
    if(reads1>=reads0||sa1!==old_src[reads1])$fatal(1,"MOVE_READ_MISMATCH job=%0d",job);
    reads1=reads1+1;comparisons=comparisons+1;
   end
  end
  if(we0&&checking)begin old_dst[writes0]=da0;old_data[writes0]=wd0;writes0=writes0+1;end
  if(we1&&checking)begin
   if(writes1>=writes0||da1!==old_dst[writes1]||wd1!==(old_data[writes1]^(($test$plusargs("BAD_EXPECTED")&&job==0&&writes1==0)?8'd1:8'd0)))$fatal(1,"MOVE_WRITE_MISMATCH job=%0d idx=%0d",job,writes1);
   writes1=writes1+1;comparisons=comparisons+2;
  end
 end
 task automatic runjob(input integer nr,nc,ab,yb,rs,cs,rt,ct,input bit expected_bad);
  integer ticks;reg seen0,seen1,e0,e1;
  begin
   @(negedge clk);rows=nr;cols=nc;a=ab;y=yb;srs=rs;scs=cs;drs=rt;dcs=ct;
   reads0=0;reads1=0;writes0=0;writes1=0;checking=1;
   start=1;@(negedge clk);start=0;seen0=done0;seen1=done1;e0=err0;e1=err1;ticks=0;
   while(!seen0||!seen1)begin
    // Live config pins may change once accepted; starts during validation/copy ignored.
    a=20'hf9876;y=20'hfff00;rows=0;cols=0;
    start=(ticks==1&&busy0&&busy1);
    @(negedge clk);if(done0)begin seen0=1;e0=err0;end
    if(done1)begin seen1=1;e1=err1;end
    ticks=ticks+1;if(ticks>4000)$fatal(1,"MOVE_TIMEOUT");
   end
   start=0;checking=0;
   if(e0!==expected_bad||e1!==expected_bad||reads0!=reads1||writes0!=writes1||writes1!=(expected_bad?0:nr*nc))$fatal(1,"MOVE_COMPLETION_MISMATCH job=%0d olderr=%b newerr=%b count=%0d",job,e0,e1,writes1);
   job=job+1;@(negedge clk);
  end
 endtask
 integer phase;
 initial begin
  repeat(4)@(negedge clk);rst=0;
  runjob(1,1,1048575,1048575,1048575,1048575,1048575,1048575,0);
  runjob(3,7,93,997,91,3,111,5,0);runjob(7,3,0,37,3,7,9,2,0);
  runjob(768,1,0,0,1,1048575,2,1048575,0);runjob(1,768,0,0,1048575,1,1048575,3,0);
  runjob(0,1,0,0,0,0,0,0,1);runjob(769,1,0,0,0,0,0,0,1);
  runjob(1,1023,0,0,0,0,0,0,1);runjob(2,1,1048575,0,1,0,0,0,1);
  runjob(1,2,0,1048575,0,0,0,1,1);runjob(768,768,0,0,1048575,1048575,1048575,1048575,1);
  // Reset cancels at each new validation phase and in the copy loop.
  for(phase=0;phase<24;phase=phase+1)begin
   @(negedge clk);rows=3;cols=7;a=0;y=100;srs=7;scs=1;drs=7;dcs=1;start=1;
   @(negedge clk);start=0;repeat(phase)@(negedge clk);rst=1;#0.1;if(sr1||we1)$fatal(1,"MOVE_RESET_MASK");
   @(negedge clk);rst=0;repeat(25)begin @(negedge clk);if(sr1||we1||done1||busy1)$fatal(1,"MOVE_RESET_STALE");end
  end
  runjob(3,3,9,19,3,1,3,1,0);
  $display("MOVE_JOINT_PASS jobs=%0d comparisons=%0d reset_phases=24 cycles=%0d",job,comparisons,cycles);$finish;
 end
 initial begin #1000000;$fatal(1,"MOVE_GLOBAL_TIMEOUT");end
endmodule
