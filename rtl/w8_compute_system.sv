// Command compute tile + real synchronous buffers + AXI read loader.
// This is NOT a physical DDR controller or a complete ViT accelerator.
// See docs/compute_system_contract.md. No implicit clearing/rollback of RAM.
`timescale 1ns/1ps
module w8_compute_system #(
    parameter integer ID_WIDTH=4,parameter integer USE_RESET_BRANCHES=0
)(
    input wire clk,rst,input wire [4:0] reset_branches,
    input wire cmd_valid,
    input wire [511:0] cmd_data,
    output wire cmd_ready,busy,
    output reg done,error,
    input wire load_start,
    input wire [30:0] load_src_addr,
    input wire [23:0] load_nbytes,load_local_offset,
    input wire [3:0] load_target,
    output wire load_ready,load_busy,
    output reg load_done,load_error,
    input wire host_read_req,
    input wire [23:0] host_read_addr,
    output wire host_read_ready,
    output wire [7:0] host_read_data,
    output wire host_read_valid,host_read_error,
    output wire [ID_WIDTH-1:0] m_axi_arid,
    output wire [30:0] m_axi_araddr,
    output wire [7:0] m_axi_arlen,
    output wire [2:0] m_axi_arsize,
    output wire [1:0] m_axi_arburst,
    output wire m_axi_arvalid,
    input wire m_axi_arready,
    input wire [ID_WIDTH-1:0] m_axi_rid,
    input wire [511:0] m_axi_rdata,
    input wire [1:0] m_axi_rresp,
    input wire m_axi_rlast,m_axi_rvalid,
    output wire m_axi_rready
);
 wire tile_ready,tile_busy,tile_done,tile_error,dma_busy,dma_done,dma_error,writer_busy,writer_error;
 wire dma_valid,dma_ready,host_valid,host_ready,host_error,read_ready,read_valid,read_error,mem_error;
 wire [511:0] dma_data;wire [63:0] dma_strb;wire [23:0] dma_addr,host_byte_addr;wire [3:0] host_target;wire [7:0] host_wdata;
 reg loading,dma_finished,compute_mem_error;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg compute_owner_q;
 wire memory_writes_pending;
 wire load_accept=load_start&&load_ready;
 assign load_ready=!rst&&!loading&&!tile_busy&&!compute_owner_q&&!memory_writes_pending&&!writer_busy&&!dma_busy;
 assign load_busy=!rst&&loading;assign busy=!rst&&tile_busy;
 assign cmd_ready=!rst&&tile_ready&&!compute_owner_q&&!memory_writes_pending&&!loading&&!writer_busy&&!dma_busy&&!load_start&&!load_error;
 wire command_accept=cmd_valid&&cmd_ready;
 // Registered owner removes command_ready/accept from ACT decode. CHECK states
 // precede requests; same-edge Host reads remain blocked by command_accept.
 wire compute_lock=!rst&&compute_owner_q;
 wire read_allowed=!rst&&!loading&&!load_start&&!compute_lock&&!command_accept&&!memory_writes_pending;
 assign host_read_ready=read_allowed&&read_ready;assign host_read_valid=!rst&&read_valid;assign host_read_error=!rst&&read_error;
 always @(posedge clk)begin
  if(rst)begin loading<=0;dma_finished<=0;load_done<=0;load_error<=0;done<=0;error<=0;compute_mem_error<=0;compute_owner_q<=0;end
  else begin
   load_done<=0;done<=0;error<=0;
   if(command_accept)compute_owner_q<=1;else if(tile_done)compute_owner_q<=0;
   if(load_accept)begin loading<=1;dma_finished<=0;load_error<=0;end
   if(loading)begin
    if(dma_done)dma_finished<=1;
    if(dma_error||writer_error||host_error)load_error<=1;
    if((dma_finished||dma_done)&&!dma_busy&&!writer_busy&&!dma_valid&&!memory_writes_pending)begin loading<=0;load_done<=1;load_error<=load_error||dma_error||writer_error||host_error;end
   end
   if(command_accept)compute_mem_error<=0;
   if(compute_lock&&mem_error)compute_mem_error<=1;
   if(tile_done)begin done<=1;error<=tile_error||compute_mem_error||mem_error;end
  end
 end
 wire loader_rst=USE_RESET_BRANCHES?reset_branches[1]:rst;
 wire memory_rst=USE_RESET_BRANCHES?reset_branches[2]:rst;
 tiny_axi_read_dma #(.ID_WIDTH(ID_WIDTH)) loader(.clk(clk),.rst(loader_rst),.start(load_accept),.src_addr(load_src_addr),.byte_count(load_nbytes),.local_offset(load_local_offset),.busy(dma_busy),.done(dma_done),.error(dma_error),
 .m_axi_arid(m_axi_arid),.m_axi_araddr(m_axi_araddr),.m_axi_arlen(m_axi_arlen),.m_axi_arsize(m_axi_arsize),.m_axi_arburst(m_axi_arburst),.m_axi_arvalid(m_axi_arvalid),.m_axi_arready(m_axi_arready),.m_axi_rid(m_axi_rid),.m_axi_rdata(m_axi_rdata),.m_axi_rresp(m_axi_rresp),.m_axi_rlast(m_axi_rlast),.m_axi_rvalid(m_axi_rvalid),.m_axi_rready(m_axi_rready),.out_valid(dma_valid),.out_ready(dma_ready),.out_data(dma_data),.out_strb(dma_strb),.out_addr(dma_addr));
 tiny_dma_byte_writer writer(.clk(clk),.rst(loader_rst),.job_start(load_accept),.job_target(load_target),.beat_valid(dma_valid),.beat_ready(dma_ready),.beat_data(dma_data),.beat_strb(dma_strb),.beat_addr(dma_addr),.host_valid(host_valid),.host_ready(host_ready),.host_error(host_error),.host_target(host_target),.host_byte_addr(host_byte_addr),.host_wdata(host_wdata),.busy(writer_busy),.beat_done(),.error(writer_error));
 wire gemm_mode;
 wire a_req_valid;
 wire a_req_ready;
 wire [19:0] a_req_addr;
 wire [15:0] a_req_keep;
 wire [15:0] a_req_tag;
 wire a_rsp_valid;
 wire a_rsp_ready;
 wire [127:0] a_rsp_data;
 wire [15:0] a_rsp_keep;
 wire [15:0] a_rsp_tag;
 wire a_rsp_error;
 wire wb_valid;
 wire wb_ready;
 wire [19:0] wb_addr;
 wire [127:0] wb_data;
 wire [511:0] wb_raw_data;
 wire wb_raw;
 wire [15:0] wb_keep;
 wire [19:0] act_a_addr;
 wire [19:0] act_b_addr;
 wire act_a_re;
 wire act_b_re;
 wire act_b_we;
 wire [7:0] act_b_wdata;
 wire [7:0] act_a_rdata;
 wire [7:0] act_b_rdata;
 wire [15:0] weight_addr;
 wire [5:0] bias_addr;
 wire [13:0] rq_addr;
 wire [127:0] weight_data;
 wire [127:0] packed_data;
 wire [511:0] bias_data;
 wire [719:0] rq_data;
 wire [13:0] packed_addr;
 wire [17:0] packed_wr_addr;
 wire packed_we;
 wire [7:0] packed_wdata;
 wire [15:0] param_addr;
 wire param_re;
 wire [31:0] param_data;
 wire [17:0] gelu_addr;
 wire gelu_re;
 wire [7:0] gelu_data;
 wire [14:0] exp_addr;
 wire exp_re;
 wire [31:0] exp_data;
 wire [15:0] score_addr;
 wire score_re;
 wire signed [31:0] score_data;
 wire [15:0] prob_addr;
 wire prob_re;
 wire prob_we;
 wire [15:0] prob_wdata;
 wire [15:0] prob_data;
 w8_compute_tile #(.ACT_READ_LATENCY(5),.USE_RESET_BRANCHES(USE_RESET_BRANCHES)) tile(.clk(clk),.rst(rst),.reset_branches(reset_branches[4:3]),.cmd_valid(command_accept),.cmd_data(cmd_data),.cmd_ready(tile_ready),.busy(tile_busy),.done(tile_done),.error(tile_error),.gemm_mode(gemm_mode),.a_req_valid(a_req_valid),.a_req_ready(a_req_ready),.a_req_addr(a_req_addr),.a_req_keep(a_req_keep),.a_req_tag(a_req_tag),.a_rsp_valid(a_rsp_valid),.a_rsp_ready(a_rsp_ready),.a_rsp_data(a_rsp_data),.a_rsp_keep(a_rsp_keep),.a_rsp_tag(a_rsp_tag),.a_rsp_error(a_rsp_error),.wb_valid(wb_valid),.wb_ready(wb_ready),.wb_addr(wb_addr),.wb_data(wb_data),.wb_raw_data(wb_raw_data),.wb_raw(wb_raw),.wb_keep(wb_keep),.act_a_addr(act_a_addr),.act_b_addr(act_b_addr),.act_a_re(act_a_re),.act_b_re(act_b_re),.act_b_we(act_b_we),.act_b_wdata(act_b_wdata),.act_a_rdata(act_a_rdata),.act_b_rdata(act_b_rdata),.weight_addr(weight_addr),.bias_addr(bias_addr),.rq_addr(rq_addr),.weight_data(weight_data),.packed_data(packed_data),.bias_data(bias_data),.rq_data(rq_data),.packed_addr(packed_addr),.packed_wr_addr(packed_wr_addr),.packed_we(packed_we),.packed_wdata(packed_wdata),.param_addr(param_addr),.param_re(param_re),.param_data(param_data),.gelu_addr(gelu_addr),.gelu_re(gelu_re),.gelu_data(gelu_data),.exp_addr(exp_addr),.exp_re(exp_re),.exp_data(exp_data),.score_addr(score_addr),.score_re(score_re),.score_data(score_data),.prob_addr(prob_addr),.prob_re(prob_re),.prob_we(prob_we),.prob_wdata(prob_wdata),.prob_data(prob_data));
 w8_memories buffers(.clk(clk),.rst(memory_rst),.compute_lock(compute_lock),.gemm_mode(gemm_mode),.host_valid(host_valid&&loading),.host_ready(host_ready),.host_target(host_target),.host_byte_addr(host_byte_addr),.host_wdata(host_wdata),.host_error(host_error),.host_read_req(host_read_req&&read_allowed),.host_read_addr(host_read_addr),.host_read_ready(read_ready),.host_read_data(host_read_data),.host_read_valid(read_valid),.host_read_error(read_error),.a_req_valid(a_req_valid),.a_req_ready(a_req_ready),.a_req_addr(a_req_addr),.a_req_keep(a_req_keep),.a_req_tag(a_req_tag),.a_rsp_valid(a_rsp_valid),.a_rsp_ready(a_rsp_ready),.a_rsp_data(a_rsp_data),.a_rsp_keep(a_rsp_keep),.a_rsp_tag(a_rsp_tag),.a_rsp_error(a_rsp_error),.wb_valid(wb_valid),.wb_ready(wb_ready),.wb_addr(wb_addr),.wb_data(wb_data),.wb_raw_data(wb_raw_data),.wb_raw(wb_raw),.wb_keep(wb_keep),.act_a_addr(act_a_addr),.act_b_addr(act_b_addr),.act_a_re(act_a_re),.act_b_re(act_b_re),.act_b_we(act_b_we),.act_b_wdata(act_b_wdata),.act_a_rdata(act_a_rdata),.act_b_rdata(act_b_rdata),.weight_addr(weight_addr),.bias_addr(bias_addr),.rq_addr(rq_addr),.weight_data(weight_data),.packed_data(packed_data),.bias_data(bias_data),.rq_data(rq_data),.packed_addr(packed_addr),.packed_wr_addr(packed_wr_addr),.packed_we(packed_we),.packed_wdata(packed_wdata),.param_addr(param_addr),.param_re(param_re),.param_data(param_data),.gelu_addr(gelu_addr),.gelu_re(gelu_re),.gelu_data(gelu_data),.exp_addr(exp_addr),.exp_re(exp_re),.exp_data(exp_data),.score_addr(score_addr),.score_re(score_re),.score_data(score_data),.prob_addr(prob_addr),.prob_re(prob_re),.prob_we(prob_we),.prob_wdata(prob_wdata),.prob_data(prob_data),.mem_error(mem_error),.writes_pending(memory_writes_pending));
endmodule
