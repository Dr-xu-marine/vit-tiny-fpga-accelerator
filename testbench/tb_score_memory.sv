`timescale 1ns/1ps
module tb_score_memory;
 reg clk=0;always #2.5 clk=~clk;
 reg rst=1,lock=0,gemm=0,hv=0;reg [23:0] ha=0;reg [7:0] hd=0;reg [3:0] ht=11;wire hr,he;
 reg sr=0;reg [15:0] sa=0;wire signed [31:0] sd;reg wv=0;wire wr;reg [19:0] wa=0;reg [15:0] wk=0;reg [511:0] wd=0;
 wire me;reg [31:0] expected[0:65535];reg [15:0] addresses[0:287];integer i,j,nreads=0,cycles=0;reg flip;
 reg v0=0,v1=0;reg [15:0] q0=0,q1=0;reg [31:0] held;
 w8_memories dut(.clk(clk),.rst(rst),.compute_lock(lock),.gemm_mode(gemm),
 .host_valid(hv),.host_ready(hr),.host_target(ht),.host_byte_addr(ha),.host_wdata(hd),.host_error(he),
 .host_read_req(1'b0),.host_read_addr(24'd0),.host_read_ready(),.host_read_data(),.host_read_valid(),.host_read_error(),
 .a_req_valid(1'b0),.a_req_ready(),.a_req_addr(20'd0),.a_req_keep(16'd0),.a_req_tag(16'd0),.a_rsp_valid(),.a_rsp_ready(1'b1),.a_rsp_data(),.a_rsp_keep(),.a_rsp_tag(),.a_rsp_error(),
 .wb_valid(wv),.wb_ready(wr),.wb_addr(wa),.wb_data(128'd0),.wb_raw_data(wd),.wb_raw(1'b1),.wb_keep(wk),
 .act_a_addr(20'd0),.act_b_addr(20'd0),.act_a_re(1'b0),.act_b_re(1'b0),.act_b_we(1'b0),.act_b_wdata(8'd0),.act_a_rdata(),.act_b_rdata(),
 .weight_addr(16'd0),.bias_addr(6'd0),.rq_addr(14'd0),.weight_data(),.packed_data(),.bias_data(),.rq_data(),
 .packed_addr(14'd0),.packed_wr_addr(18'd0),.packed_we(1'b0),.packed_wdata(8'd0),
 .param_addr(16'd0),.param_re(1'b0),.param_data(),.gelu_addr(18'd0),.gelu_re(1'b0),.gelu_data(),.exp_addr(15'd0),.exp_re(1'b0),.exp_data(),
 .score_addr(sa),.score_re(sr),.score_data(sd),.prob_addr(16'd0),.prob_re(1'b0),.prob_we(1'b0),.prob_wdata(16'd0),.prob_data(),.mem_error(me));
 always @(posedge clk)begin
  cycles<=cycles+1;if(cycles>20000)$fatal(1,"SCORE_TIMEOUT");
  if(rst)begin v0<=0;v1<=0;end
  else begin v0<=lock&&sr;v1<=v0;q0<=sa;q1<=q0;end
 end
 always @(negedge clk)if(v1)begin
  if(sd!==(expected[q1]^((flip&&nreads==37)?32'd1:0)))$fatal(1,"SCORE_MISMATCH address=%h got=%h want=%h",q1,sd,expected[q1]);nreads=nreads+1;
 end
 task automatic upload(input [15:0] address,input [31:0] value);
 begin for(integer b=0;b<4;b=b+1)begin @(negedge clk);if(!hr)$fatal(1,"SCORE_HOST_NOT_READY");hv=1;ha={6'd0,address,2'b00}+b;hd=value[8*b+:8];end
  @(negedge clk);hv=0;if(he)$fatal(1,"SCORE_HOST_ERROR");expected[address]=value;
 end endtask
 initial begin
  flip=$test$plusargs("BAD_EXPECTED");repeat(5)@(negedge clk);rst=0;
  for(i=0;i<288;i=i+1)begin addresses[i]=(i<256)?i:16'hffe0+(i-256);upload(addresses[i],32'h81234567^(i*65537));end
  @(negedge clk);lock=1;gemm=1;
  // Raw writeback crosses bank15->0 and preserves masked words.
  for(i=0;i<8;i=i+1)begin
   @(negedge clk);wv=1;wa=17+17*i;wk=16'ha5c3;for(j=0;j<16;j=j+1)begin wd[32*j+:32]=32'hfedc0000+i*16+j;if(wk[j])expected[wa+j]=wd[32*j+:32];end
   @(negedge clk);wv=0;if(!wr||me)$fatal(1,"SCORE_WB_ERROR");
  end
  // All16banks, row boundaries, high addresses; back-to-back reads plus bubbles.
  for(i=0;i<576;i=i+1)begin @(negedge clk);sr=(i%7!=0);sa=addresses[(i*37)%288];end
  @(negedge clk);sr=0;repeat(4)@(negedge clk);held=sd;
  repeat(4)begin @(negedge clk);if(sd!==held)$fatal(1,"SCORE_IDLE_HOLD");end
  // Host is blocked while compute owns RAM.
  hv=1;ha=0;hd=8'hff;repeat(3)begin @(negedge clk);if(hr||he)$fatal(1,"SCORE_OWNERSHIP");end hv=0;
  @(negedge clk);sr=1;sa=0;@(negedge clk);rst=1;sr=0;repeat(2)@(negedge clk);rst=0;
  repeat(3)@(negedge clk);if(sd!==0)$fatal(1,"SCORE_RESET_PIPE");
  for(i=0;i<288;i=i+1)begin @(negedge clk);sr=1;sa=addresses[i];end
  @(negedge clk);sr=0;repeat(4)@(negedge clk);
  $display("SCORE_MEMORY_PASS comparisons=%0d upload_words=288 masked_wb_rows=8 latency=2 cycles=%0d",nreads,cycles);$finish;
 end
endmodule
