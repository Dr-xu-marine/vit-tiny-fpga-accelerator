`timescale 1ns/1ps
module tb_receiver_write;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,we=0,re=0;reg [15:0] wa=0,ra=0;reg [5:0] lane=0;reg [7:0] wd=0;
 reg [23:0] ua=0;reg [5:0] ur=0;wire [127:0] a,b;wire [719:0] u,v;wire pending,up;
 tiny_compute_byte_banks #(.WORD_AW(16),.BYTE_LANES(16),.LOCAL_WRITE_PIPE(1)) dut(clk,rst,we,wa,lane,wd,re,ra,a,pending);
 vendor_banks_parent #(.WORD_AW(16),.BYTE_LANES(16)) old(clk,rst,we,wa,lane,wd,re,ra,b);
 wire upload_we=we&&!rst; // actual w8_memories upload acceptance contract
 w8_upload_ram #(.AW(6),.LANES(90),.STRIDE(7)) rq(clk,rst,upload_we,ua,wd,re,ur,u,up);
 upload_parent #(.AW(6),.LANES(90),.STRIDE(7)) rq_old(clk,rst,upload_we,ua,wd,re,ur,v);
 integer checks=0,cycles=0,writes=0,reset_writes=0;reg prior_accept=0;
 reg [31:0] rng=32'h5c2143ab;reg bad=0;
 task tick;begin
  @(posedge clk);#0.3;
  if(bad)force dut.banks[0].local_write.data_q=8'h31;
  if(a!==b||u!==v)$fatal(1,"RECEIVER_MISMATCH cycle=%0d A=%h B=%h U=%h V=%h",cycles,a,b,u,v);
  if(pending!==(!rst&&we)||up!==(!rst&&we))$fatal(1,"RECEIVER_MISMATCH pending");
  checks=checks+106;cycles=cycles+1;if(we&&!rst)writes=writes+1;if(rst&&prior_accept)reset_writes=reset_writes+1;
  prior_accept=we&&!rst;@(negedge clk);
 end endtask
 initial begin
  tick();rst=0;
  // Fully initialized selected rows, including both address extremes.
  for(integer r=0;r<4;r=r+1)for(integer l=0;l<90;l=l+1)begin
   we=1;wa=(r==3)?65535:r;lane=l%16;wd=(r*73+l*19);ua=r*128+l;ur=r;ra=wa;tick();
  end
  we=0;re=1;tick();
  for(integer i=0;i<4000;i=i+1)begin
   rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
   rst=(i%131==1)||(i%131==2);we=rng[2]||i%131==0;re=rng[3];
   wa=(rng[5:4]==3)?65535:{14'd0,rng[5:4]};ra=(rng[7:6]==3)?65535:{14'd0,rng[7:6]};
   lane=rng[13:8];wd=rng[23:16];ua={15'd0,rng[25:24],7'd0}+((i%5==0)?7'd127:(rng%90));ur=rng[27:26];
   tick();
  end
  rst=0;we=1;re=0;lane=0;wa=0;ua=0;wd=8'hc5;
  if($test$plusargs("CORRUPT_RECEIVER"))bad=1;
  tick();we=0;re=1;ra=0;ur=0;tick();tick();
  if(reset_writes<10)$fatal(1,"RECEIVER_MISMATCH reset coverage");
  $display("RECEIVER_WRITE_PASS checks=%0d cycles=%0d writes=%0d accepted_before_reset=%0d full_depth_weight=65536 rq_lanes=90",checks,cycles,writes,reset_writes);$finish;
 end
 initial begin #1000000;$fatal(1,"RECEIVER_MISMATCH timeout");end
endmodule
