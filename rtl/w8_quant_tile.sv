`timescale 1ns/1ps
module w8_quant_tile #(
 parameter integer CORE_FAULT=0,RQ_FAULT=0,TOP_FAULT=0
)(
 input wire clk,rst,flush,
 input wire a_we,input wire [9:0] a_addr,input wire [63:0] a_data,
 input wire b_we,input wire [9:0] b_addr,input wire [127:0] b_data,
 input wire bias_we,input wire [3:0] bias_col,input wire signed [31:0] bias_data,
 input wire rq_we,input wire [2:0] rq_row,input wire [719:0] rq_data,
 input wire raw_mode,dynamic_zp,input wire signed [7:0] input_zp,
 output wire [511:0] out_raw,
 input wire start_valid,output wire start_ready,
 input wire [9:0] k_len,input wire [3:0] rows_valid,input wire [4:0] cols_valid,
 input wire [127:0] job_tag,input wire feed_enable,
 output wire out_valid,input wire out_ready,output wire [127:0] out_data,
 output wire [15:0] out_keep,output wire [127:0] out_tag,output wire out_last,
 output wire busy,output reg done,output reg error_valid,output reg [7:0] error_code
);
 localparam IDLE=0,CLEAR0=1,CLEAR1=2,CLEAR2=3,RUN=4,WAIT_CORE=5,COLLECT=6,DRAIN=7;
 reg [3:0] state;
 reg [9:0] k_q,issued,retired;
 reg [3:0] rows_q;reg [4:0] cols_q;reg [127:0] tag_q;
 reg [3:0] tickets,received;reg cooldown,abort_q;
 (* ram_style="block" *) reg [63:0] a_memory[0:1023];
 (* ram_style="block" *) reg [127:0] b_memory[0:1023];
 reg signed [31:0] bias_memory[0:15];
 wire idle=(state==IDLE);wire clear_all=rst||flush||abort_q;
 assign busy=!idle;assign start_ready=idle&&!clear_all;
 wire read_req=state==RUN && issued<k_q && feed_enable && !clear_all;
 reg read_v0,read_v1;
 (* KEEP="TRUE", DONT_TOUCH="TRUE" *) reg [3:0] local_read_v1;reg [9:0] read_k0,read_k1;
 reg read_last0,read_last1;
 // Native synchronous-read FFs must be absorbable into RAMB primitives.
 reg [63:0] a_ram_q;
 reg [127:0] b_ram_q;
 (* keep="true" *) reg [63:0] a_do;
 (* keep="true" *) reg [127:0] b_do;
 integer r,c;
 always @(posedge clk) begin
  if(a_we&&idle&&!clear_all) a_memory[a_addr]<=a_data;
  if(b_we&&idle&&!clear_all) b_memory[b_addr]<=b_data;

  if(read_req) begin a_ram_q<=a_memory[issued];b_ram_q<=b_memory[issued];end
  if(read_v0) begin
   for(integer i=0;i<8;i=i+1) a_do[8*i+:8]<=(i<rows_q)?a_ram_q[8*i+:8]:8'b0;
   for(integer i=0;i<16;i=i+1) b_do[8*i+:8]<=(i<cols_q)?b_ram_q[8*i+:8]:8'b0;
  end
  if(clear_all) begin read_v0<=0;read_v1<=0;local_read_v1<=0;read_k0<=0;read_k1<=0;read_last0<=0;read_last1<=0;end
  else begin
   read_v0<=read_req;read_v1<=read_v0;local_read_v1<={4{read_v0}};
   if(read_req) begin read_k0<=issued;read_last0<=issued==k_q-1'b1;end
   if(read_v0) begin read_k1<=read_k0;read_last1<=read_last0;end
  end
 end
 reg signed [19:0] weight_sum[0:15];
 reg bias_pending;reg [3:0] bias_index_q;reg signed [31:0] bias_base_q,bias_correction_q;
 always @(posedge clk)begin
  if(clear_all)begin bias_pending<=0;bias_index_q<=0;bias_base_q<=0;bias_correction_q<=0;for(integer s=0;s<16;s=s+1)weight_sum[s]<=0;end
  else begin
   if(b_we&&idle)for(integer s=0;s<16;s=s+1)begin
    if(b_addr==0)weight_sum[s]<={{12{b_data[8*s+7]}},b_data[8*s+:8]};
    else weight_sum[s]<=weight_sum[s]+$signed(b_data[8*s+:8]);
   end
   bias_pending<=bias_we&&idle;
   if(bias_we&&idle)begin bias_index_q<=bias_col;bias_base_q<=bias_data;bias_correction_q<=dynamic_zp?(-($signed({{24{input_zp[7]}},input_zp})*$signed(weight_sum[bias_col]))):32'sd0;end
   if(bias_pending)bias_memory[bias_index_q]<=bias_base_q+bias_correction_q;
  end
 end
 wire core_clear=flush||abort_q||state==CLEAR0;
 wire [6143:0] p_all;wire commit_valid,commit_last;wire [9:0] commit_k;
 wire dbg_take;wire [9:0] dbg_take_k;
 w8_mac_array_local #(.CORE_FAULT(CORE_FAULT)) core(
  .clk(clk),.rst(rst),.flush(core_clear),.in_valid_group(local_read_v1), .a64(a_do),.b128(b_do),
  .k_index(read_k1),.k_last(read_last1),.p_all(p_all),
  .commit_valid(commit_valid),.commit_k(commit_k),.commit_last(commit_last),
  .take_valid(dbg_take),.take_k(dbg_take_k));
 wire reserve_ready;
 wire reserve_valid=state==COLLECT && tickets<8 && !cooldown && !clear_all;
 wire ticket_fire=reserve_valid&&reserve_ready;
 reg [127:0] ticket_tag;
 always @* begin
  ticket_tag=tag_q;ticket_tag[95:80]=tag_q[95:80]+tickets;
  if(TOP_FAULT==3) ticket_tag[0]=!ticket_tag[0];
 end
 reg [3:0] raw_v;
 reg [511:0] raw_acc_pipe[0:3];reg [15:0] keep_pipe[0:3];
 reg [127:0] tag_pipe[0:3];reg [2:0] row_pipe[0:3];reg last_pipe[0:3];
 // Two collector levels occupy the existing four-cycle raw pipeline.
 reg [511:0] selected_low,selected_high,raw_high0;
 reg [15:0] selected_keep;
 reg selected_overflow_low,selected_overflow_high;
 reg overflow_low0,overflow_high0;
 reg signed [47:0] p_low,p_high;
 always @* begin
  selected_low=0;selected_high=0;selected_keep=0;
  selected_overflow_low=0;selected_overflow_high=0;p_low=0;p_high=0;
  for(integer j=0;j<16;j=j+1) begin
   p_low=$signed(p_all[(tickets[1:0]*16+j)*48+:48]);
   p_high=$signed(p_all[((4+tickets[1:0])*16+j)*48+:48]);
   selected_low[32*j+:32]=p_low[31:0];selected_high[32*j+:32]=p_high[31:0];
   selected_keep[j]=(tickets<rows_q)&&(j<cols_q);
   if(tickets[1:0]<rows_q&&j<cols_q&&p_low[47:32]!={16{p_low[31]}}) selected_overflow_low=1;
   if((4+tickets[1:0])<rows_q&&j<cols_q&&p_high[47:32]!={16{p_high[31]}}) selected_overflow_high=1;
  end
  if(TOP_FAULT==1) selected_keep=selected_keep^16'h8000;
 end
 wire selected_overflow=raw_v[0]&&(row_pipe[0][2]?overflow_high0:overflow_low0);
 wire [511:0] raw_bias;
 generate for(genvar bc=0;bc<16;bc=bc+1) begin: BIAS_BUS
  assign raw_bias[32*bc+:32]=bias_memory[bc];
 end endgenerate
 always @(posedge clk) begin
  if(clear_all) raw_v<=0;
  else begin
   raw_v<={raw_v[2:0],ticket_fire};
   if(ticket_fire) begin
    raw_acc_pipe[0]<=selected_low;raw_high0<=selected_high;
    overflow_low0<=selected_overflow_low;overflow_high0<=selected_overflow_high;keep_pipe[0]<=selected_keep;tag_pipe[0]<=ticket_tag;
    row_pipe[0]<=tickets[2:0];last_pipe[0]<=(tickets==7)^(TOP_FAULT==2);
   end
   for(integer s=1;s<4;s=s+1) if(raw_v[s-1]) begin
    if(s==1) raw_acc_pipe[s]<=row_pipe[0][2]?raw_high0:raw_acc_pipe[0];
    else raw_acc_pipe[s]<=raw_acc_pipe[s-1];keep_pipe[s]<=keep_pipe[s-1];tag_pipe[s]<=tag_pipe[s-1];
    row_pipe[s]<=row_pipe[s-1];last_pipe[s]<=last_pipe[s-1];
   end
  end
 end
 wire rq_error;wire [7:0] rq_error_code;wire [5:0] rq_outstanding;
 w8_rq16 #(.RQ_FAULT(RQ_FAULT)) rq(
  .clk(clk),.rst(rst),.flush(flush||abort_q),.raw_mode(raw_mode),.out_raw(out_raw),
  .param_we(rq_we&&idle&&!clear_all),.param_row(rq_row),.param_data(rq_data),
  .reserve_valid(reserve_valid),.reserve_ready(reserve_ready),.reserve_tag(ticket_tag),
  .raw_valid(raw_v[3]),.raw_row(row_pipe[3]),.raw_acc(raw_acc_pipe[3]),.raw_bias(raw_bias),
  .raw_keep(keep_pipe[3]),.raw_tag(tag_pipe[3]),.raw_last(last_pipe[3]),
  .out_valid(out_valid),.out_ready(out_ready),.out_data(out_data),.out_keep(out_keep),.out_tag(out_tag),.out_last(out_last),
  .error_valid(rq_error),.error_code(rq_error_code),.debug_outstanding(rq_outstanding));
 always @(posedge clk) begin
  done<=0;error_valid<=0;abort_q<=0;
  if(rst||flush) begin
   state<=IDLE;issued<=0;retired<=0;tickets<=0;received<=0;cooldown<=0;
   k_q<=0;rows_q<=0;cols_q<=0;tag_q<=0;
   if(flush&&!rst&&busy) begin error_valid<=1;error_code<=8'h11;end
   else error_code<=0;
  end else if(abort_q) begin state<=IDLE;issued<=0;retired<=0;tickets<=0;received<=0;cooldown<=0;end
  else if(rq_error || selected_overflow) begin
   error_valid<=1;error_code<=rq_error?rq_error_code:8'h07;abort_q<=1;state<=IDLE;
  end else begin
   if(!idle&&(a_we||b_we||bias_we||rq_we)) begin error_valid<=1;error_code<=8'h05;end
   if(cooldown) cooldown<=0;
   case(state)
    IDLE: if(start_valid&&start_ready) begin
     if(k_len<1||k_len>768||rows_valid<1||rows_valid>8||cols_valid<1||cols_valid>16) begin
      error_valid<=1;error_code<=8'h03;
     end else begin
      state<=CLEAR0;k_q<=k_len;rows_q<=rows_valid;cols_q<=cols_valid;tag_q<=job_tag;
      issued<=0;retired<=0;tickets<=0;received<=0;cooldown<=0;
     end
    end
    CLEAR0: state<=CLEAR1;
    CLEAR1: state<=CLEAR2;
    CLEAR2: state<=RUN;
    RUN: if(read_req) begin issued<=issued+1'b1;if(issued==k_q-1'b1) state<=WAIT_CORE;end
    WAIT_CORE: if(commit_valid && commit_last) state<=COLLECT;
    COLLECT: if(ticket_fire) begin tickets<=tickets+1'b1;cooldown<=1;if(tickets==7) state<=DRAIN;end
    DRAIN: begin end
    default: state<=IDLE;
   endcase
   if((state==RUN||state==WAIT_CORE)&&commit_valid) begin
    retired<=retired+1'b1;
    if(commit_k!=retired || (commit_last!=(retired==k_q-1'b1))) begin
     error_valid<=1;error_code<=8'h09;abort_q<=1;state<=IDLE;
    end
   end
   if(out_valid&&out_ready) begin
    received<=received+1'b1;
    if(received==7) begin done<=1;state<=IDLE;end
   end
  end
 end
`ifndef SYNTHESIS
 always @(negedge clk)if(!clear_all && local_read_v1!=={4{read_v1}})
  $fatal(1,"LOCAL_VALID_AGE_MISMATCH");
`endif
endmodule
