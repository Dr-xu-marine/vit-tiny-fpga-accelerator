`timescale 1ns/1ps
module w8_compute_tile #(parameter integer ACT_READ_LATENCY=1,USE_RESET_BRANCHES=0)(
 input wire clk,rst,cmd_valid,input wire [1:0] reset_branches,input wire [511:0] cmd_data,output wire cmd_ready,busy,output reg done,error,
 output wire gemm_mode,
 output wire a_req_valid,input wire a_req_ready,output wire [19:0] a_req_addr,output wire [15:0] a_req_keep,a_req_tag,
 input wire a_rsp_valid,output wire a_rsp_ready,input wire [127:0] a_rsp_data,input wire [15:0] a_rsp_keep,a_rsp_tag,input wire a_rsp_error,
 output wire wb_valid,input wire wb_ready,output wire [19:0] wb_addr,output wire [127:0] wb_data,output wire [511:0] wb_raw_data,output wire wb_raw,output wire [15:0] wb_keep,
 output reg [19:0] act_a_addr,act_b_addr,output reg act_a_re,act_b_re,act_b_we,output reg [7:0] act_b_wdata,input wire [7:0] act_a_rdata,act_b_rdata,
 output wire [15:0] weight_addr,output wire [5:0] bias_addr,output wire [13:0] rq_addr,input wire [127:0] weight_data,packed_data,input wire [511:0] bias_data,input wire [719:0] rq_data,
 output wire [13:0] packed_addr,output wire [17:0] packed_wr_addr,output wire packed_we,output wire [7:0] packed_wdata,
 output wire [15:0] param_addr,output wire param_re,input wire [31:0] param_data,
 output wire [17:0] gelu_addr,output wire gelu_re,input wire [7:0] gelu_data,
 output wire [14:0] exp_addr,output wire exp_re,input wire [31:0] exp_data,
 output wire [15:0] score_addr,output wire score_re,input wire signed [31:0] score_data,
 output wire [15:0] prob_addr,output wire prob_re,prob_we,output wire [15:0] prob_wdata,input wire [15:0] prob_data
);
 localparam IDLE=0,LAUNCH=1,WAITING=2,REJECT=3,CHECK_START=4,CHECK_WAIT=5,DRAIN=6;reg [2:0] state;reg [1:0] drain_count;reg [511:0] cmd;reg [63:0] job_sequence;
 wire [31:0] w[0:15];generate for(genvar z=0;z<16;z=z+1)begin:W assign w[z]=cmd[32*z+:32];end endgenerate
 wire [3:0] op=w[0][3:0];wire is_gemm=op==1||op==4;wire launch=state==LAUNCH&&!rst;
 assign cmd_ready=!rst&&state==IDLE;assign busy=!rst&&state!=IDLE;assign gemm_mode=!rst&&(state==LAUNCH||state==WAITING||state==DRAIN)&&is_gemm;
 wire check_done,check_bad;
 w8_command_check range_check(.clk(clk),.rst(rst),.start(state==CHECK_START),.command(cmd),.busy(),.done(check_done),.bad(check_bad));
 wire gd,ge,ad,ae,md,me;wire [7:0] gec;
 wire gemm_rst=USE_RESET_BRANCHES?reset_branches[0]:rst;
 wire aux_rst=USE_RESET_BRANCHES?reset_branches[1]:rst;
 w8_gemm128 gemm(.clk(clk),.rst(gemm_rst),.flush(1'b0),.start(launch&&is_gemm),.start_ready(),
 .a_base(w[1][19:0]),.out_base(w[3][19:0]),.n_rows(w[4][11:0]),.k_dim(w[5][11:0]),.n_out(w[6][11:0]),
 .b_is_laneram(1'b0),.pack_row(1'b0),.pack_lb(1'b0),.bias_en(w[0][9]),.raw_mode(w[0][11]),.dynamic_zp(w[0][12]),.input_zp(-8'sd128),.job_tag(job_sequence),
 .a_req_valid(a_req_valid),.a_req_ready(a_req_ready),.a_req_addr(a_req_addr),.a_req_keep(a_req_keep),.a_req_tag(a_req_tag),.a_rsp_valid(a_rsp_valid),.a_rsp_ready(a_rsp_ready),.a_rsp_data(a_rsp_data),.a_rsp_keep(a_rsp_keep),.a_rsp_tag(a_rsp_tag),.a_rsp_error(a_rsp_error),
 .wrom_addr(weight_addr),.wrom_rdata(w[0][8]?packed_data:weight_data),.bias_addr(bias_addr),.bias_rdata(bias_data),.rq_addr(rq_addr),.rq_rdata(rq_data),.lb_read_addr(),.lb_rdata(128'd0),
 .wb_valid(wb_valid),.wb_ready(wb_ready),.wb_addr(wb_addr),.wb_data(wb_data),.wb_raw_data(wb_raw_data),.wb_raw(wb_raw),.wb_tag(),.wb_keep(wb_keep),.wb_last(),.wb_pack_row(),.wb_pack_lb(),.wb_pack_addr(),.wb_lb_addr(),.busy(),.done(gd),.error_valid(ge),.error_code(gec));
 assign packed_addr=weight_addr<16384?weight_addr[13:0]:14'd0;
 wire [19:0] aa,ab,ms,mt;wire ar,br,bw,mre,mwe;wire [7:0] bd,mdata;
 w8_aux_engine #(.ACT_READ_LATENCY(ACT_READ_LATENCY)) aux(.clk(clk),.rst(aux_rst),.flush(1'b0),.start(launch&&!is_gemm&&op!=7),.command(cmd),.busy(),.done(ad),.error(ae),
 .a_addr(aa),.b_addr(ab),.a_re(ar),.b_re(br),.b_we(bw),.b_wdata(bd),.a_rdata(act_a_rdata),.b_rdata(act_b_rdata),
 .param_addr(param_addr),.param_re(param_re),.param_rdata(param_data),.gelu_addr(gelu_addr),.gelu_re(gelu_re),.gelu_rdata(gelu_data),.exp_addr(exp_addr),.exp_re(exp_re),.exp_rdata(exp_data),.score_addr(score_addr),.score_re(score_re),.score_rdata(score_data),.prob_addr(prob_addr),.prob_re(prob_re),.prob_we(prob_we),.prob_wdata(prob_wdata),.prob_rdata(prob_data));
 w8_tensor_move #(.ACT_READ_LATENCY(ACT_READ_LATENCY)) move(.clk(clk),.rst(aux_rst),.start(launch&&op==7),.src_base(w[1][19:0]),.dst_base(w[3][19:0]),.rows(w[4][9:0]),.cols(w[6][9:0]),.src_row_stride(w[13][19:0]),.src_col_stride(w[14][19:0]),.dst_row_stride(w[15][19:0]),.dst_col_stride(w[12][19:0]),.src_re(mre),.src_addr(ms),.src_rdata(act_a_rdata),.dst_we(mwe),.dst_addr(mt),.dst_wdata(mdata),.busy(),.done(md),.error(me));
 assign packed_we=!rst&&(state==LAUNCH||state==WAITING)&&op==7&&w[0][10]&&mwe;
 assign packed_wr_addr=mt[17:0];assign packed_wdata=mdata;
 always @*begin
  act_a_addr=0;act_b_addr=0;act_a_re=0;act_b_re=0;act_b_we=0;act_b_wdata=0;
  if(!rst&&(state==LAUNCH||state==WAITING)&&!is_gemm)begin
   if(op==7)begin act_a_addr=ms;act_a_re=mre;act_b_addr=mt;act_b_we=mwe&&!w[0][10];act_b_wdata=mdata;end
   else begin act_a_addr=aa;act_a_re=ar;act_b_addr=ab;act_b_re=br;act_b_we=bw;act_b_wdata=bd;end
  end
 end
 always @(posedge clk)begin
  done<=0;
  if(rst)begin state<=IDLE;cmd<=0;job_sequence<=0;error<=0;drain_count<=0;end
  else case(state)
   IDLE:if(cmd_valid)begin cmd<=cmd_data;job_sequence<=job_sequence+1'b1;error<=0;state<=CHECK_START;end
   CHECK_START:state<=CHECK_WAIT;
   CHECK_WAIT:if(check_done)state<=check_bad?REJECT:LAUNCH;
   LAUNCH:state<=WAITING;
   WAITING:if((is_gemm&&gd)||(op==7&&md)||(!is_gemm&&op!=7&&ad))begin error<=is_gemm?ge:(op==7?me:ae);drain_count<=3;state<=DRAIN;end
   DRAIN:if(drain_count!=0)drain_count<=drain_count-1'b1;else begin done<=1;state<=IDLE;end
   REJECT:begin done<=1;error<=1;state<=IDLE;end
   default:begin done<=1;error<=1;state<=IDLE;end
  endcase
 end
endmodule
