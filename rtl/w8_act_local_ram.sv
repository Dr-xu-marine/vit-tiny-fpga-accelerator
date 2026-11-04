`timescale 1ns/1ps
// Request fence -> bank-local fence -> original BRAM. Scalar read: FIVE
// edges, wide response: SIX edges including acceptance. Accepted writes remain
// durable across reset, commit two edges later; reset cancels read responses.
module w8_act_local_ram #(parameter integer ADDR_W=20)(
 input wire clk,rst,wide_mode,
 input wire legacy_a_re,input wire [ADDR_W-1:0] legacy_a_addr,output reg [7:0] legacy_a_rdata,
 input wire legacy_b_re,legacy_b_we,input wire [ADDR_W-1:0] legacy_b_addr,input wire [7:0] legacy_b_wdata,output reg [7:0] legacy_b_rdata,
 input wire wr_valid,output wire wr_ready,input wire [23:0] wr_addr,input wire [127:0] wr_data,input wire [15:0] wr_mask,output reg wr_error,
 input wire rd_valid,output wire rd_ready,input wire [23:0] rd_addr,input wire [15:0] rd_mask,
 output reg rsp_valid,input wire rsp_ready,output reg [127:0] rsp_data,output reg [15:0] rsp_mask,output reg rsp_error,
 output wire wide_idle,output wire write_pending
);
 localparam integer WORD_AW=ADDR_W-4;
 localparam [24:0] CAPACITY=25'd1<<ADDR_W;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg raw_w_valid=0,raw_legacy_b_we=0;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg raw_r_valid,raw_legacy_a_re,raw_legacy_b_re;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [23:0] raw_wr_addr,raw_rd_addr;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [127:0] raw_wr_data;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [15:0] raw_wr_mask,raw_rd_mask;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [ADDR_W-1:0] raw_legacy_a_addr,raw_legacy_b_addr;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [7:0] raw_legacy_b_data;
 reg write_commit_pending=0;reg [3:0] wide_pipe;
 wire legacy_active=!rst&&!wide_mode&&!rsp_valid&&!(|wide_pipe)&&!raw_r_valid;
 wire [15:0] collision;
 assign wr_ready=!rst&&wide_mode;
 wire wide_write_fire=wr_valid&&wr_ready;
 assign rd_ready=!rst&&wide_mode&&!raw_r_valid&&!(|wide_pipe)&&(!rsp_valid||rsp_ready)&&!(|collision);
 wire wide_read_fire=rd_valid&&rd_ready;
 assign write_pending=raw_w_valid||raw_legacy_b_we||write_commit_pending;
 assign wide_idle=!rsp_valid&&!(|wide_pipe)&&!raw_r_valid&&!write_pending;
 // Write flags are not reset after acceptance: the old RAM had already
 // committed these writes. No new request is accepted while rst is asserted.
 always @(posedge clk)begin
  raw_w_valid<=wide_write_fire;raw_legacy_b_we<=legacy_active&&legacy_b_we;
  write_commit_pending<=raw_w_valid||raw_legacy_b_we;
  if(wide_write_fire)begin raw_wr_addr<=wr_addr;raw_wr_data<=wr_data;raw_wr_mask<=wr_mask;end
  if(legacy_active&&(legacy_b_re||legacy_b_we))begin raw_legacy_b_addr<=legacy_b_addr;raw_legacy_b_data<=legacy_b_wdata;end
  if(rst)begin raw_r_valid<=0;raw_legacy_a_re<=0;raw_legacy_b_re<=0;end
  else begin
   raw_r_valid<=wide_read_fire;raw_legacy_a_re<=legacy_active&&legacy_a_re;raw_legacy_b_re<=legacy_active&&legacy_b_re;
   if(wide_read_fire)begin raw_rd_addr<=rd_addr;raw_rd_mask<=rd_mask;end
   if(legacy_active&&legacy_a_re)raw_legacy_a_addr<=legacy_a_addr;
  end
 end
 wire legacy_a_fire=raw_legacy_a_re&&!(raw_legacy_b_we&&raw_legacy_a_addr==raw_legacy_b_addr);
 wire legacy_b_fire=raw_legacy_b_re&&!raw_legacy_b_we;
 reg [15:0] read_keep;reg write_bad,read_bad;reg [24:0] checked_waddr,checked_raddr;
 always @*begin
  read_keep=0;write_bad=0;read_bad=0;checked_waddr=0;checked_raddr=0;
  for(integer i=0;i<16;i=i+1)begin
   checked_waddr={1'b0,raw_wr_addr}+i;checked_raddr={1'b0,raw_rd_addr}+i;
   if(raw_wr_mask[i]&&checked_waddr>=CAPACITY)write_bad=1;
   if(raw_rd_mask[i])begin if(checked_raddr<CAPACITY)read_keep[i]=1;else read_bad=1;end
  end
 end
 wire [127:0] bank_a_data,bank_b_data;
 reg [3:0] legacy_a_lane_q,legacy_b_lane_q,legacy_a_ram_lane_q,legacy_b_ram_lane_q,read_offset_q;
 reg legacy_a_live,legacy_b_live,legacy_a_ram_live,legacy_b_ram_live,legacy_a_group_live,legacy_b_group_live;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [7:0] a_group[0:3],b_group[0:3];
 reg [15:0] read_keep_q;reg read_error_q;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [127:0] wide_bank_q,wide_low_q;
 always @(posedge clk)begin
  if(rst)begin
   legacy_a_live<=0;legacy_b_live<=0;legacy_a_ram_live<=0;legacy_b_ram_live<=0;legacy_a_group_live<=0;legacy_b_group_live<=0;
   legacy_a_lane_q<=0;legacy_b_lane_q<=0;legacy_a_ram_lane_q<=0;legacy_b_ram_lane_q<=0;legacy_a_rdata<=0;legacy_b_rdata<=0;
   for(integer g=0;g<4;g=g+1)begin a_group[g]<=0;b_group[g]<=0;end
   wide_pipe<=0;wide_bank_q<=0;wide_low_q<=0;rsp_valid<=0;rsp_data<=0;rsp_mask<=0;rsp_error<=0;
   read_keep_q<=0;read_error_q<=0;read_offset_q<=0;wr_error<=0;
  end else begin
   legacy_a_live<=legacy_a_fire;legacy_b_live<=legacy_b_fire;
   legacy_a_ram_live<=legacy_a_live;legacy_b_ram_live<=legacy_b_live;
   legacy_a_group_live<=legacy_a_ram_live;legacy_b_group_live<=legacy_b_ram_live;
   if(legacy_a_fire)legacy_a_lane_q<=raw_legacy_a_addr[3:0];if(legacy_b_fire)legacy_b_lane_q<=raw_legacy_b_addr[3:0];
   if(legacy_a_live)legacy_a_ram_lane_q<=legacy_a_lane_q;if(legacy_b_live)legacy_b_ram_lane_q<=legacy_b_lane_q;
   for(integer g=0;g<4;g=g+1)begin
    if(legacy_a_ram_live)a_group[g]<=(legacy_a_ram_lane_q[3:2]==g)?bank_a_data[8*(4*g+legacy_a_ram_lane_q[1:0])+:8]:8'd0;
    if(legacy_b_ram_live)b_group[g]<=(legacy_b_ram_lane_q[3:2]==g)?bank_b_data[8*(4*g+legacy_b_ram_lane_q[1:0])+:8]:8'd0;
   end
   if(legacy_a_group_live)legacy_a_rdata<=a_group[0]|a_group[1]|a_group[2]|a_group[3];
   if(legacy_b_group_live)legacy_b_rdata<=b_group[0]|b_group[1]|b_group[2]|b_group[3];
   wr_error<=raw_w_valid&&write_bad;wide_pipe<={wide_pipe[2:0],raw_r_valid};
   if(rsp_valid&&rsp_ready)rsp_valid<=0;
   if(raw_r_valid)begin read_offset_q<=raw_rd_addr[3:0];read_keep_q<=read_keep;read_error_q<=read_bad;end
   if(wide_pipe[1])wide_bank_q<=bank_a_data;
   if(wide_pipe[2])for(integer lane=0;lane<16;lane=lane+1)wide_low_q[8*lane+:8]<=wide_bank_q[8*((lane+read_offset_q[1:0])%16)+:8];
   if(wide_pipe[3])begin
    rsp_valid<=1;rsp_mask<=read_keep_q;rsp_error<=read_error_q;
    for(integer lane=0;lane<16;lane=lane+1)rsp_data[8*lane+:8]<=read_keep_q[lane]?wide_low_q[8*((lane+4*read_offset_q[3:2])%16)+:8]:8'd0;
   end
  end
 end
 generate for(genvar bank=0;bank<16;bank=bank+1)begin:banks
  localparam [3:0] BANK=bank;
  // Keep the original acceptance-time same-word collision backpressure.
  wire [3:0] live_w_index=BANK-wr_addr[3:0],live_r_index=BANK-rd_addr[3:0];
  wire [24:0] live_w_full={1'b0,wr_addr}+{21'd0,live_w_index},live_r_full={1'b0,rd_addr}+{21'd0,live_r_index};
  assign collision[bank]=wide_write_fire&&wr_mask[live_w_index]&&live_w_full<CAPACITY&&rd_mask[live_r_index]&&live_r_full<CAPACITY&&live_w_full[ADDR_W-1:4]==live_r_full[ADDR_W-1:4];
  wire [3:0] w_index=BANK-raw_wr_addr[3:0],r_index=BANK-raw_rd_addr[3:0];
  wire [24:0] w_full={1'b0,raw_wr_addr}+{21'd0,w_index},r_full={1'b0,raw_rd_addr}+{21'd0,r_index};
  wire decoded_a_re=(raw_r_valid&&raw_rd_mask[r_index]&&r_full<CAPACITY)||(legacy_a_fire&&raw_legacy_a_addr[3:0]==BANK);
  wire decoded_b_we=(raw_w_valid&&raw_wr_mask[w_index]&&w_full<CAPACITY)||(raw_legacy_b_we&&raw_legacy_b_addr[3:0]==BANK);
  wire decoded_b_re=legacy_b_fire&&raw_legacy_b_addr[3:0]==BANK;
  (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg a_enable_q,b_read_q,b_write_q=0;
  (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [WORD_AW-1:0] a_word_q,b_word_q;
  (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [7:0] b_data_q;
  always @(posedge clk)begin
   a_enable_q<=!rst&&decoded_a_re;b_read_q<=!rst&&decoded_b_re;b_write_q<=decoded_b_we;
   if(decoded_a_re)a_word_q<=raw_r_valid?r_full[ADDR_W-1:4]:raw_legacy_a_addr[ADDR_W-1:4];
   if(decoded_b_we||decoded_b_re)begin b_word_q<=raw_w_valid?w_full[ADDR_W-1:4]:raw_legacy_b_addr[ADDR_W-1:4];b_data_q<=raw_w_valid?raw_wr_data[8*w_index+:8]:raw_legacy_b_data;end
  end
  // Limit native CASDOUT chains; preserves the original synchronous ports.
  (* ram_style="block", cascade_height=2 *) reg [7:0] bytes[0:(1<<WORD_AW)-1];reg [7:0] a_q,b_q;
  assign bank_a_data[8*bank+:8]=a_q;assign bank_b_data[8*bank+:8]=b_q;
  always @(posedge clk)begin if(rst)a_q<=0;else if(a_enable_q)a_q<=bytes[a_word_q];end
  always @(posedge clk)begin if(b_write_q)bytes[b_word_q]<=b_data_q;if(rst)b_q<=0;else if(b_read_q)b_q<=bytes[b_word_q];end
 end endgenerate
`ifndef SYNTHESIS
 initial if(ADDR_W<5||ADDR_W>20)$fatal(1,"ACT_CACHE_ERROR unsupported address width");
 always @(posedge clk)if(!rst&&!wide_mode&&(rsp_valid||(|wide_pipe)||raw_r_valid))$fatal(1,"ACT_CACHE_ERROR ownership changed before read drained");
`endif
endmodule
