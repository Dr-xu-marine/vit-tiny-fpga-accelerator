`timescale 1ns/1ps
module w8_upload_ram #(parameter AW=16,LANES=4,STRIDE=2)(
 input wire clk,rst,we,input wire [23:0] byte_addr,input wire [7:0] byte_data,
 input wire re,input wire [AW-1:0] word_addr,output wire [8*LANES-1:0] data,output wire write_pending
);
 reg pending_q=0;always @(posedge clk)pending_q<=we&&!rst;
 assign write_pending=pending_q;
 generate for(genvar lane=0;lane<LANES;lane=lane+1)begin:banks
  (* ram_style="block", cascade_height=2 *)reg [7:0] bytes[0:(1<<AW)-1];reg [7:0] q;
  wire [AW-1:0] wa=byte_addr>>STRIDE;
  (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg we_q=0;
  (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg [AW-1:0] word_q;
  (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg [7:0] data_q;
  (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg forward_q;
  (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg [7:0] forward_data_q;
  always @(posedge clk)begin
   we_q<=we&&!rst&&((byte_addr&((1<<STRIDE)-1))==lane);
   word_q<=wa;data_q<=byte_data;
   if(we_q)bytes[word_q]<=data_q;
   if(rst)begin q<=0;forward_q<=0;forward_data_q<=0;end
   else if(re)begin q<=bytes[word_addr];forward_q<=we_q&&word_q==word_addr;forward_data_q<=data_q;end
  end
  assign data[8*lane+:8]=forward_q?forward_data_q:q;
 end endgenerate
endmodule
module w8_memories(
 input wire clk,rst,compute_lock,gemm_mode,
 input wire host_valid,output wire host_ready,input wire [3:0] host_target,input wire [23:0] host_byte_addr,input wire [7:0] host_wdata,output reg host_error,
 input wire host_read_req,input wire [23:0] host_read_addr,output wire host_read_ready,output wire [7:0] host_read_data,output reg host_read_valid,host_read_error,
 input wire a_req_valid,output wire a_req_ready,input wire [19:0] a_req_addr,input wire [15:0] a_req_keep,a_req_tag,
 output wire a_rsp_valid,input wire a_rsp_ready,output wire [127:0] a_rsp_data,output wire [15:0] a_rsp_keep,a_rsp_tag,output wire a_rsp_error,
 input wire wb_valid,output wire wb_ready,input wire [19:0] wb_addr,input wire [127:0] wb_data,input wire [511:0] wb_raw_data,input wire wb_raw,input wire [15:0] wb_keep,
 input wire [19:0] act_a_addr,act_b_addr,input wire act_a_re,act_b_re,act_b_we,input wire [7:0] act_b_wdata,output wire [7:0] act_a_rdata,act_b_rdata,
 input wire [15:0] weight_addr,input wire [5:0] bias_addr,input wire [13:0] rq_addr,
 output wire [127:0] weight_data,packed_data,output wire [511:0] bias_data,output wire [719:0] rq_data,
 input wire [13:0] packed_addr,input wire [17:0] packed_wr_addr,input wire packed_we,input wire [7:0] packed_wdata,
 input wire [15:0] param_addr,input wire param_re,output wire [31:0] param_data,
 input wire [17:0] gelu_addr,input wire gelu_re,output wire [7:0] gelu_data,
 input wire [14:0] exp_addr,input wire exp_re,output wire [31:0] exp_data,
 input wire [15:0] score_addr,input wire score_re,output wire signed [31:0] score_data,
 input wire [15:0] prob_addr,input wire prob_re,prob_we,input wire [15:0] prob_wdata,output wire [15:0] prob_data,
 output reg mem_error,output wire writes_pending
);
 wire run=compute_lock&&!rst;assign host_ready=!rst&&!compute_lock;assign host_read_ready=host_ready;
 reg address_ok;
 always @*case(host_target)
  0,1:address_ok=host_byte_addr<1048576;
  2:address_ok=host_byte_addr<4096;
  3:address_ok=host_byte_addr<8192&&(host_byte_addr[6:0]<90||host_wdata==0);
  4,11,12:address_ok=host_byte_addr<262144;
  5:address_ok=host_byte_addr<131072;
  9:address_ok=host_byte_addr<65540;
  10:address_ok=host_byte_addr<196608;
  default:address_ok=0;
 endcase
 wire upload=host_valid&&host_ready&&address_ok;wire hr=host_read_req&&host_read_ready&&host_read_addr<1048576;
 wire act_wr_ready,act_wr_error,act_idle;reg [15:0] response_tag;
 wire [6:0] bank_writes_pending;assign writes_pending=|bank_writes_pending;
 reg [3:0] host_read_pipe,host_error_pipe;
 assign a_rsp_tag=response_tag;assign host_read_data=act_a_rdata;assign wb_ready=wb_raw?!rst:act_wr_ready;
 always @(posedge clk)begin
  if(rst)begin host_read_pipe<=0;host_error_pipe<=0;response_tag<=0;host_error<=0;host_read_valid<=0;host_read_error<=0;mem_error<=0;end
  else begin
   if(a_req_valid&&a_req_ready)response_tag<=a_req_tag;
   host_error<=host_valid&&host_ready&&!address_ok;
   host_read_pipe<={host_read_pipe[2:0],hr};host_error_pipe<={host_error_pipe[2:0],host_read_req&&host_read_ready&&host_read_addr>=1048576};
   host_read_valid<=host_read_pipe[3];host_read_error<=host_error_pipe[3];
   mem_error<=run&&((gemm_mode&&!wb_raw&&act_wr_error)||(wb_valid&&wb_raw&&wb_addr>=65536));
  end
 end
 w8_act_local_ram #(.ADDR_W(20)) act_storage(.clk(clk),.rst(rst),.wide_mode(gemm_mode),
 .legacy_a_re((run&&act_a_re)||hr),.legacy_a_addr(compute_lock?act_a_addr:host_read_addr[19:0]),.legacy_a_rdata(act_a_rdata),
 .legacy_b_re(run&&act_b_re),.legacy_b_we((run&&act_b_we)||(upload&&host_target==0)),.legacy_b_addr(run?act_b_addr:host_byte_addr[19:0]),.legacy_b_wdata(run?act_b_wdata:host_wdata),.legacy_b_rdata(act_b_rdata),
 .wr_valid(wb_valid&&gemm_mode&&!wb_raw),.wr_ready(act_wr_ready),.wr_addr({4'd0,wb_addr}),.wr_data(wb_data),.wr_mask(wb_keep),.wr_error(act_wr_error),
 .rd_valid(a_req_valid&&gemm_mode),.rd_ready(a_req_ready),.rd_addr({4'd0,a_req_addr}),.rd_mask(a_req_keep),.rsp_valid(a_rsp_valid),.rsp_ready(a_rsp_ready),.rsp_data(a_rsp_data),.rsp_mask(a_rsp_keep),.rsp_error(a_rsp_error),.wide_idle(act_idle),.write_pending(bank_writes_pending[0]));
 tiny_compute_byte_banks #(.WORD_AW(16),.BYTE_LANES(16),.LOCAL_WRITE_PIPE(1)) learned(.clk(clk),.rst(rst),.wr_en(upload&&host_target==1),.wr_word(host_byte_addr[19:4]),.wr_lane({2'd0,host_byte_addr[3:0]}),.wr_data(host_wdata),.rd_en(gemm_mode),.rd_word(weight_addr),.rd_data(weight_data),.write_pending(bank_writes_pending[1]));
 tiny_compute_byte_banks #(.WORD_AW(6),.BYTE_LANES(64),.RAM_STYLE("distributed")) biases(.clk(clk),.rst(rst),.wr_en(upload&&host_target==2),.wr_word(host_byte_addr[11:6]),.wr_lane(host_byte_addr[5:0]),.wr_data(host_wdata),.rd_en(gemm_mode),.rd_word(bias_addr),.rd_data(bias_data));
 w8_upload_ram #(.AW(6),.LANES(90),.STRIDE(7)) rq(.clk(clk),.rst(rst),.we(upload&&host_target==3&&host_byte_addr[6:0]<90),.byte_addr(host_byte_addr),.byte_data(host_wdata),.re(gemm_mode),.word_addr(rq_addr[5:0]),.data(rq_data),.write_pending(bank_writes_pending[3]));
 tiny_compute_byte_banks #(.WORD_AW(14),.BYTE_LANES(16),.LOCAL_WRITE_PIPE(1)) dynamic_weights(.clk(clk),.rst(rst),.wr_en((run&&packed_we)||(upload&&host_target==4)),.wr_word(run?packed_wr_addr[17:4]:host_byte_addr[17:4]),.wr_lane({2'd0,(run?packed_wr_addr[3:0]:host_byte_addr[3:0])}),.wr_data(run?packed_wdata:host_wdata),.rd_en(gemm_mode),.rd_word(packed_addr),.rd_data(packed_data),.write_pending(bank_writes_pending[2]));
 w8_upload_ram #(.AW(16),.LANES(4),.STRIDE(2)) params(.clk(clk),.rst(rst),.we(upload&&host_target==12),.byte_addr(host_byte_addr),.byte_data(host_wdata),.re(run&&param_re),.word_addr(param_addr),.data(param_data),.write_pending(bank_writes_pending[4]));
 w8_upload_ram #(.AW(18),.LANES(1),.STRIDE(0)) gelu(.clk(clk),.rst(rst),.we(upload&&host_target==10),.byte_addr(host_byte_addr),.byte_data(host_wdata),.re(run&&gelu_re),.word_addr(gelu_addr),.data(gelu_data),.write_pending(bank_writes_pending[5]));
 w8_upload_ram #(.AW(15),.LANES(4),.STRIDE(2)) exponential(.clk(clk),.rst(rst),.we(upload&&host_target==9),.byte_addr(host_byte_addr),.byte_data(host_wdata),.re(run&&exp_re),.word_addr(exp_addr),.data(exp_data),.write_pending(bank_writes_pending[6]));
 generate for(genvar by=0;by<2;by=by+1)begin:probability
  (* ram_style="block" *)reg [7:0] bytes[0:65535];reg [7:0] q;
  wire cw=run&&prob_we;wire hw=upload&&host_target==5&&host_byte_addr[0]==by;
  wire [15:0] wa=run?prob_addr:host_byte_addr[16:1];wire [7:0] wd=run?prob_wdata[8*by+:8]:host_wdata;
  always @(posedge clk)begin if(cw||hw)bytes[wa]<=wd;if(rst)q<=0;else if(run&&prob_re)q<=bytes[prob_addr];end
  assign prob_data[8*by+:8]=q;
 end endgenerate
 // Score read latency TWO: synchronous bank output, then local4-bank gather.
 // All other read contracts remain unchanged. Bank ownership travels with data.
 wire [511:0] score_read;reg [15:0] score_select_q;reg score_read_q;
 reg [31:0] score_group_q[0:3];
 always @(posedge clk)begin
  if(rst)begin score_select_q<=0;score_read_q<=0;end
  else begin score_read_q<=run&&score_re;if(run&&score_re)score_select_q<=16'h1<<score_addr[3:0];end
 end
 generate for(genvar g=0;g<4;g=g+1)begin:SCORE_GATHER
  wire [31:0] local_read=(score_read[32*(4*g)+:32]&{32{score_select_q[4*g]}})|
                              (score_read[32*(4*g+1)+:32]&{32{score_select_q[4*g+1]}})|
                              (score_read[32*(4*g+2)+:32]&{32{score_select_q[4*g+2]}})|
                              (score_read[32*(4*g+3)+:32]&{32{score_select_q[4*g+3]}});
  always @(posedge clk)if(rst)score_group_q[g]<=0;else if(score_read_q)score_group_q[g]<=local_read;
 end endgenerate
 assign score_data=score_group_q[0]|score_group_q[1]|score_group_q[2]|score_group_q[3];
 generate for(genvar bank=0;bank<16;bank=bank+1)begin:score_banks
  wire [3:0] lane=bank-wb_addr[3:0];wire [20:0] dst={1'b0,wb_addr}+lane;
  wire cw=gemm_mode&&wb_valid&&wb_ready&&wb_raw&&wb_keep[lane];
  wire hw=upload&&host_target==11&&host_byte_addr[5:2]==bank;
  wire [11:0] wa=gemm_mode?dst[15:4]:host_byte_addr[17:6];
  for(genvar by=0;by<4;by=by+1)begin:byteslice
   (* ram_style="block" *)reg [7:0] bytes[0:4095];reg [7:0] q;
   always @(posedge clk)begin
    if(cw||(hw&&host_byte_addr[1:0]==by))bytes[wa]<=gemm_mode?wb_raw_data[32*lane+8*by+:8]:host_wdata;
    if(rst)q<=0;else if(run&&score_re&&score_addr[3:0]==bank)q<=bytes[score_addr[15:4]];
   end
   assign score_read[32*bank+8*by+:8]=q;
  end
 end endgenerate
`ifndef SYNTHESIS
 function [7:0] peek_act(input [19:0] address);
 begin case(address[3:0])
  0:peek_act=act_storage.banks[0].bytes[address[19:4]];1:peek_act=act_storage.banks[1].bytes[address[19:4]];2:peek_act=act_storage.banks[2].bytes[address[19:4]];3:peek_act=act_storage.banks[3].bytes[address[19:4]];
  4:peek_act=act_storage.banks[4].bytes[address[19:4]];5:peek_act=act_storage.banks[5].bytes[address[19:4]];6:peek_act=act_storage.banks[6].bytes[address[19:4]];7:peek_act=act_storage.banks[7].bytes[address[19:4]];
  8:peek_act=act_storage.banks[8].bytes[address[19:4]];9:peek_act=act_storage.banks[9].bytes[address[19:4]];10:peek_act=act_storage.banks[10].bytes[address[19:4]];11:peek_act=act_storage.banks[11].bytes[address[19:4]];
  12:peek_act=act_storage.banks[12].bytes[address[19:4]];13:peek_act=act_storage.banks[13].bytes[address[19:4]];14:peek_act=act_storage.banks[14].bytes[address[19:4]];15:peek_act=act_storage.banks[15].bytes[address[19:4]];
 endcase end endfunction
 function [31:0] peek_score(input [15:0] address);begin case(address[3:0])
 0:peek_score={score_banks[0].byteslice[3].bytes[address[15:4]],score_banks[0].byteslice[2].bytes[address[15:4]],score_banks[0].byteslice[1].bytes[address[15:4]],score_banks[0].byteslice[0].bytes[address[15:4]]};
 1:peek_score={score_banks[1].byteslice[3].bytes[address[15:4]],score_banks[1].byteslice[2].bytes[address[15:4]],score_banks[1].byteslice[1].bytes[address[15:4]],score_banks[1].byteslice[0].bytes[address[15:4]]};
 2:peek_score={score_banks[2].byteslice[3].bytes[address[15:4]],score_banks[2].byteslice[2].bytes[address[15:4]],score_banks[2].byteslice[1].bytes[address[15:4]],score_banks[2].byteslice[0].bytes[address[15:4]]};
 3:peek_score={score_banks[3].byteslice[3].bytes[address[15:4]],score_banks[3].byteslice[2].bytes[address[15:4]],score_banks[3].byteslice[1].bytes[address[15:4]],score_banks[3].byteslice[0].bytes[address[15:4]]};
 4:peek_score={score_banks[4].byteslice[3].bytes[address[15:4]],score_banks[4].byteslice[2].bytes[address[15:4]],score_banks[4].byteslice[1].bytes[address[15:4]],score_banks[4].byteslice[0].bytes[address[15:4]]};
 5:peek_score={score_banks[5].byteslice[3].bytes[address[15:4]],score_banks[5].byteslice[2].bytes[address[15:4]],score_banks[5].byteslice[1].bytes[address[15:4]],score_banks[5].byteslice[0].bytes[address[15:4]]};
 6:peek_score={score_banks[6].byteslice[3].bytes[address[15:4]],score_banks[6].byteslice[2].bytes[address[15:4]],score_banks[6].byteslice[1].bytes[address[15:4]],score_banks[6].byteslice[0].bytes[address[15:4]]};
 7:peek_score={score_banks[7].byteslice[3].bytes[address[15:4]],score_banks[7].byteslice[2].bytes[address[15:4]],score_banks[7].byteslice[1].bytes[address[15:4]],score_banks[7].byteslice[0].bytes[address[15:4]]};
 8:peek_score={score_banks[8].byteslice[3].bytes[address[15:4]],score_banks[8].byteslice[2].bytes[address[15:4]],score_banks[8].byteslice[1].bytes[address[15:4]],score_banks[8].byteslice[0].bytes[address[15:4]]};
 9:peek_score={score_banks[9].byteslice[3].bytes[address[15:4]],score_banks[9].byteslice[2].bytes[address[15:4]],score_banks[9].byteslice[1].bytes[address[15:4]],score_banks[9].byteslice[0].bytes[address[15:4]]};
 10:peek_score={score_banks[10].byteslice[3].bytes[address[15:4]],score_banks[10].byteslice[2].bytes[address[15:4]],score_banks[10].byteslice[1].bytes[address[15:4]],score_banks[10].byteslice[0].bytes[address[15:4]]};
 11:peek_score={score_banks[11].byteslice[3].bytes[address[15:4]],score_banks[11].byteslice[2].bytes[address[15:4]],score_banks[11].byteslice[1].bytes[address[15:4]],score_banks[11].byteslice[0].bytes[address[15:4]]};
 12:peek_score={score_banks[12].byteslice[3].bytes[address[15:4]],score_banks[12].byteslice[2].bytes[address[15:4]],score_banks[12].byteslice[1].bytes[address[15:4]],score_banks[12].byteslice[0].bytes[address[15:4]]};
 13:peek_score={score_banks[13].byteslice[3].bytes[address[15:4]],score_banks[13].byteslice[2].bytes[address[15:4]],score_banks[13].byteslice[1].bytes[address[15:4]],score_banks[13].byteslice[0].bytes[address[15:4]]};
 14:peek_score={score_banks[14].byteslice[3].bytes[address[15:4]],score_banks[14].byteslice[2].bytes[address[15:4]],score_banks[14].byteslice[1].bytes[address[15:4]],score_banks[14].byteslice[0].bytes[address[15:4]]};
 15:peek_score={score_banks[15].byteslice[3].bytes[address[15:4]],score_banks[15].byteslice[2].bytes[address[15:4]],score_banks[15].byteslice[1].bytes[address[15:4]],score_banks[15].byteslice[0].bytes[address[15:4]]};
 endcase end endfunction
 function [15:0] peek_prob(input [15:0] address);begin peek_prob={probability[1].bytes[address],probability[0].bytes[address]};end endfunction
`endif
endmodule
