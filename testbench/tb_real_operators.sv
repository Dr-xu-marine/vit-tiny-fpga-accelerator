`timescale 1ns/1ps
`include "w8_test_paths.vh"
module tb_real_operators;
 reg clk=0;always #2.5 clk=~clk;reg rst=1,flush=0,start=0,move_start=0,move_mode=0,loading=0,checking=0;
 reg [511:0] command=0;wire busy,done,error;
 wire [19:0] aa,ba;wire ar,br,bw;wire [7:0] wd,aq,bq;
 reg [19:0] host_addr=0;reg [7:0] host_byte=0;reg host_re=0;
 wire [15:0] pa;wire pr;reg [31:0] pq=0;wire [17:0] ga;wire gr;reg [7:0] gq=0;
 wire [14:0] ea;wire er;reg [31:0] eq=0;wire [15:0] sa;wire sr;reg signed [31:0] sq=0,score_pipe=0;reg score_v=0;
 wire [15:0] qa,qw;wire qr,qwe;reg [15:0] qq=0;
 reg [7:0] act_input[0:131071],gelu[0:196607],pattern[0:4095];
 reg [31:0] params_mem[0:65535],exps[0:16384],scores[0:196],expected[0:37823];reg [15:0] probs[0:196];
 wire mr,mw,mbusy,mdone,merror;wire [19:0] ma,my;wire [7:0] mdata;
 w8_tensor_move #(.ACT_READ_LATENCY(5)) mover(.clk(clk),.rst(rst),.start(move_start),.src_base(20'd17),.dst_base(20'd70000),.rows(10'd9),.cols(10'd7),.src_row_stride(20'd31),.src_col_stride(20'd3),.dst_row_stride(20'd29),.dst_col_stride(20'd2),.src_re(mr),.src_addr(ma),.src_rdata(aq),.dst_we(mw),.dst_addr(my),.dst_wdata(mdata),.busy(mbusy),.done(mdone),.error(merror));
 w8_aux_engine #(.ACT_READ_LATENCY(5)) dut(.clk(clk),.rst(rst),.flush(flush),.start(start),.command(command),.busy(busy),.done(done),.error(error),.a_addr(aa),.b_addr(ba),.a_re(ar),.b_re(br),.b_we(bw),.b_wdata(wd),.a_rdata(aq),.b_rdata(bq),.param_addr(pa),.param_re(pr),.param_rdata(pq),.gelu_addr(ga),.gelu_re(gr),.gelu_rdata(gq),.exp_addr(ea),.exp_re(er),.exp_rdata(eq),.score_addr(sa),.score_re(sr),.score_rdata(sq),.prob_addr(qa),.prob_re(qr),.prob_we(qwe),.prob_wdata(qw),.prob_rdata(qq));
 wire actual_ar=checking?host_re:move_mode?mr:ar;
 wire [19:0] actual_aa=checking?host_addr:move_mode?ma:aa;
 wire actual_bw=loading?1'b1:move_mode?mw:bw;
 wire [19:0] actual_ba=loading?host_addr:move_mode?my:ba;
 wire [7:0] actual_bd=loading?host_byte:move_mode?mdata:wd;
 w8_act_local_ram storage(.clk(clk),.rst(rst||flush),.wide_mode(1'b0),.legacy_a_re(actual_ar),.legacy_a_addr(actual_aa),.legacy_a_rdata(aq),.legacy_b_re(!loading&&!move_mode&&br),.legacy_b_we(actual_bw),.legacy_b_addr(actual_ba),.legacy_b_wdata(actual_bd),.legacy_b_rdata(bq),.wr_valid(1'b0),.wr_ready(),.wr_addr(24'd0),.wr_data(128'd0),.wr_mask(16'd0),.wr_error(),.rd_valid(1'b0),.rd_ready(),.rd_addr(24'd0),.rd_mask(16'd0),.rsp_valid(),.rsp_ready(1'b1),.rsp_data(),.rsp_mask(),.rsp_error(),.wide_idle());
 longint cycles=0;integer f,n,op,space,count,i,j,passed=0,comparisons=0,phase;string prefix;reg [31:0] actual;reg [7:0] got;reg flip;
 always @(posedge clk)begin
  cycles<=cycles+1;if(cycles>30000000)$fatal(1,"REAL_OPERATOR_TIMEOUT");
  if(pr)pq<=params_mem[pa];if(gr)gq<=gelu[ga];if(er)eq<=exps[ea];score_v<=sr;if(sr)score_pipe<=scores[sa];if(score_v)sq<=score_pipe;if(qr)qq<=probs[qa];if(qwe)probs[qa]<=qw;
 end
 task automatic read_actual(input [19:0] address,output [7:0] value);
 begin @(negedge clk);host_addr=address;host_re=1;@(negedge clk);host_re=0;repeat(4)@(negedge clk);value=aq;end endtask
 initial begin
  flip=$test$plusargs("BAD_EXPECTED");f=$fopen({`W8_ROOT,"/testbench/aux_cases/cases.txt"},"r");if(!f)$fatal(1,"Missing frozen aux cases");
  repeat(4)@(negedge clk);rst=0;
  while(!$feof(f))begin
   n=$fscanf(f,"%d %h %d %d\n",op,command,space,count);if(n!=4)$fatal(1,"Case parse");prefix=$sformatf("%s/tests/aux/%0d_",`W8_ROOT,op);
   // Fixed representative prefix: CLS192 + first65 image values, no retuning.
   if(op==10)begin count=257;command[255:224]=257;end
   $readmemh({prefix,"act.hex"},act_input);$readmemh({prefix,"param.hex"},params_mem);$readmemh({prefix,"gelu.hex"},gelu);$readmemh({prefix,"exp.hex"},exps);$readmemh({prefix,"score.hex"},scores);$readmemh({prefix,"prob.hex"},probs);$readmemh({prefix,"expected.hex"},expected,0,count-1);
   @(negedge clk);loading=1;for(i=0;i<131072;i=i+1)begin host_addr=i;host_byte=act_input[i];@(negedge clk);end loading=0;
   start=1;@(negedge clk);start=0;wait(done);@(negedge clk);if(error)$fatal(1,"REAL_OPERATOR_ERROR op=%0d",op);
   repeat(3)@(negedge clk);checking=1;for(i=0;i<count;i=i+1)begin
    if(space==0)begin read_actual(65536+i,got);actual={{24{got[7]}},got};end else actual={16'd0,probs[i]};
    if(actual!==(expected[i]^((flip&&op==2&&i==0)?32'd1:32'd0)))$fatal(1,"REAL_OPERATOR_MISMATCH op=%0d index=%0d actual=%h expected=%h",op,i,actual,expected[i]);comparisons=comparisons+1;
   end checking=0;passed=passed+1;$display("REAL_OPERATOR_CASE_PASS op=%0d values=%0d cycles=%0d",op,count,cycles);
  end
  $readmemh({`W8_ROOT,"/testbench/act_pattern.hex"},pattern);@(negedge clk);loading=1;
  for(i=0;i<4096;i=i+1)begin host_addr=i;host_byte=pattern[i];@(negedge clk);end loading=0;
  move_mode=1;move_start=1;@(negedge clk);move_start=0;wait(mdone);@(negedge clk);if(merror)$fatal(1,"REAL_MOVE_ERROR");
  repeat(3)@(negedge clk);checking=1;for(i=0;i<9;i=i+1)for(j=0;j<7;j=j+1)begin read_actual(70000+29*i+2*j,got);if(got!==pattern[17+31*i+3*j])$fatal(1,"REAL_MOVE_MISMATCH");comparisons=comparisons+1;end checking=0;
  for(phase=0;phase<4;phase=phase+1)begin
   @(negedge clk);move_start=1;@(negedge clk);move_start=0;repeat(22+phase)@(negedge clk);rst=1;@(negedge clk);rst=0;
   repeat(30)begin @(negedge clk);if(mw||mr||mbusy||mdone)$fatal(1,"REAL_MOVE_RESET_STALE");end
  end
  move_mode=0;command=0;command[3:0]=6;command[223:192]=192;@(negedge clk);start=1;@(negedge clk);start=0;repeat(20)@(negedge clk);flush=1;@(negedge clk);flush=0;
  repeat(300)begin @(negedge clk);if(bw||qwe||busy)$fatal(1,"REAL_AUX_FLUSH_STALE");end
  $display("REAL_OPERATORS_PASS aux_cases=%0d move_values=63 total_values=%0d reset_phases=4 cycles=%0d",passed,comparisons,cycles);$finish;
 end
endmodule
