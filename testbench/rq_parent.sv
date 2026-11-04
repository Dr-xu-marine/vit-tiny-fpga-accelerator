`timescale 1ns/1ps
// 16 reserved rows, one shared exact scalar RQ. In-flight rows are never stalled.
// Ready throttles reservations, FIFO preserves raw/tag/keep/last until consumption.
module rq_parent #(parameter RQ_FAULT=0)(
 input wire clk,rst,flush,param_we,input wire [2:0] param_row,input wire [719:0] param_data,
 input wire raw_mode,reserve_valid,output wire reserve_ready,input wire [127:0] reserve_tag,
 input wire raw_valid,input wire [2:0] raw_row,input wire [511:0] raw_acc,raw_bias,
 input wire [15:0] raw_keep,input wire [127:0] raw_tag,input wire raw_last,
 output wire out_valid,input wire out_ready,output wire [127:0] out_data,
 output wire [511:0] out_raw,output wire [15:0] out_keep,output wire [127:0] out_tag,
 output wire out_last,output reg error_valid,output reg [7:0] error_code,output wire [5:0] debug_outstanding
);
 localparam IDLE=0,FETCH=1,AUTH=2,CHECK=3,PARAM_REQ=4,PARAM_CAP=5,LATCH=6,START=7,WAIT_RQ=8,NEXT=9,OUTPUT=10,LANE_GROUP=11;
 reg [3:0] state,lane,wp,rp,res_wp;reg [4:0] credits,arrivals,rows;
 (* ram_style="block" *) reg [511:0] fifo_acc[0:15],fifo_bias[0:15];
 reg [127:0] fifo_tag[0:15],expected[0:15];reg [15:0] fifo_keep[0:15];reg fifo_last[0:15];reg [2:0] fifo_row[0:15];
 (* ram_style="block" *) reg [719:0] parameters[0:7];reg [719:0] params_q;
 reg [511:0] acc_q,bias_q;reg [127:0] tag_q,expect_q,result_q;reg [15:0] keep_q;reg last_q;reg [2:0] row_q;reg [7:0] auth_q;
 // Registered4-lane group, then4:1 leaf selection. Avoid a16:1 data/parameter
 // selection followed by validity reduction and the scalar input register.
 reg [127:0] group_acc,group_bias;reg [179:0] group_params;
 wire [44:0] selected_param=group_params[45*lane[1:0]+:45];
 reg signed [31:0] lane_acc,lane_bias;reg [30:0] lane_m;reg [5:0] lane_shift;reg signed [7:0] lane_z;
 wire clear=rst||flush;wire reserve_fire=reserve_valid&&reserve_ready;wire consume=out_valid&&out_ready;
 assign reserve_ready=!clear&&!error_valid&&!param_we&&credits<16;
 assign out_valid=!clear&&!error_valid&&state==OUTPUT;assign out_data=raw_mode?128'd0:result_q;assign out_raw=acc_q;
 assign out_keep=keep_q;assign out_tag=tag_q;assign out_last=last_q;assign debug_outstanding={1'b0,credits};
 wire sv;wire signed [15:0] sd;wire [2:0] se;wire [127:0] stag;wire sl;
 w8_requant_scalar #(.TAG_WIDTH(128)) scalar(.clk(clk),.rst(clear),.ce(1'b1),.in_valid(state==START&&!error_valid),
 .in_acc(lane_acc),.in_bias_corr(lane_bias),.in_multiplier(lane_m),.in_shift(lane_shift),.in_zero_point({{8{lane_z[7]}},lane_z}),
 .in_int8(1'b1),.in_last(last_q),.in_tag(tag_q),.in_overflow(1'b0),.out_valid(sv),.out_data(sd),.out_int8(),.out_last(sl),.out_tag(stag),.out_saturated(),.out_error(se));
 integer i;
 always @(posedge clk)begin
  if(clear)begin state<=IDLE;lane<=0;wp<=0;rp<=0;res_wp<=0;credits<=0;arrivals<=0;rows<=0;error_valid<=0;error_code<=0;acc_q<=0;bias_q<=0;tag_q<=0;expect_q<=0;keep_q<=0;last_q<=0;row_q<=0;auth_q<=0;result_q<=0;params_q<=0;lane_acc<=0;lane_bias<=0;lane_m<=0;lane_shift<=0;lane_z<=0;end
  else begin
   if(param_we)parameters[param_row]<=param_data;
   case({reserve_fire,consume})2'b10:credits<=credits+1'b1;2'b01:credits<=credits-1'b1;default:;endcase
   case({reserve_fire,raw_valid})2'b10:arrivals<=arrivals+1'b1;2'b01:arrivals<=arrivals-1'b1;default:;endcase
   case({raw_valid,consume})2'b10:rows<=rows+1'b1;2'b01:rows<=rows-1'b1;default:;endcase
   if(reserve_fire)begin expected[res_wp]<=reserve_tag;res_wp<=res_wp+1'b1;end
   if(raw_valid)begin
    if(arrivals==0||rows==16)begin error_valid<=1;error_code<=8'h31;end
    else begin fifo_acc[wp]<=raw_acc;fifo_bias[wp]<=raw_bias;fifo_tag[wp]<=raw_tag;fifo_keep[wp]<=raw_keep;fifo_last[wp]<=raw_last;fifo_row[wp]<=raw_row;wp<=wp+1'b1;end
   end
   case(state)
    IDLE:if(rows!=0&&!error_valid)state<=FETCH;
    FETCH:begin acc_q<=fifo_acc[rp];bias_q<=fifo_bias[rp];tag_q<=fifo_tag[rp];expect_q<=expected[rp];keep_q<=fifo_keep[rp];last_q<=fifo_last[rp];row_q<=fifo_row[rp];result_q<=0;state<=AUTH;end
    AUTH:begin for(i=0;i<8;i=i+1)auth_q[i]<=tag_q[16*i+:16]==expect_q[16*i+:16];state<=CHECK;end
    CHECK:if(!(&auth_q)||last_q!=(row_q==7))begin error_valid<=1;error_code<=8'h32;end else if(raw_mode)state<=OUTPUT;else state<=PARAM_REQ;
    PARAM_REQ:begin params_q<=parameters[row_q];state<=PARAM_CAP;end
    PARAM_CAP:begin lane<=0;state<=LANE_GROUP;end
    LANE_GROUP:if(!keep_q[lane])begin result_q[8*lane+:8]<=0;state<=NEXT;end
       else begin group_acc<=acc_q[128*lane[3:2]+:128];group_bias<=bias_q[128*lane[3:2]+:128];group_params<=params_q[180*lane[3:2]+:180];state<=LATCH;end
    LATCH:if(selected_param[30:0]==0||selected_param[36:31]==63)begin error_valid<=1;error_code<=8'h35;end else begin lane_acc<=group_acc[32*lane[1:0]+:32];lane_bias<=group_bias[32*lane[1:0]+:32];lane_m<=selected_param[30:0];lane_shift<=selected_param[36:31];lane_z<=selected_param[44:37];state<=START;end
    START:state<=WAIT_RQ;
    WAIT_RQ:if(sv)begin if(se!=0||stag!=tag_q||sl!=last_q)begin error_valid<=1;error_code<=8'h33;end else begin result_q[8*lane+:8]<=sd[7:0]^(RQ_FAULT!=0&&lane==0?8'h1:8'h0);state<=NEXT;end end
    NEXT:if(lane==15)state<=OUTPUT;else begin lane<=lane+1'b1;state<=LANE_GROUP;end
    OUTPUT:if(consume)begin rp<=rp+1'b1;state<=IDLE;end
    default:begin error_valid<=1;error_code<=8'h34;state<=IDLE;end
   endcase
  end
 end
endmodule
