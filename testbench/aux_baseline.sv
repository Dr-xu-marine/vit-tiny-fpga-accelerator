`timescale 1ns/1ps
// Exact integer auxiliary engine. All external memories have ONE registered read.
// op2 LN192, op3 Softmax197, op5 GELU, op6 residual, op9 probability map,
// op10 Patch/CLS/position. Nonlinear runtime contains no real/FP operators.
module w8_aux_engine_baseline(
 input wire clk,rst,flush,start,input wire [511:0] command,
 output wire busy,output reg done,error,
 output reg [19:0] a_addr,b_addr,output reg a_re,b_re,b_we,output reg [7:0] b_wdata,
 input wire [7:0] a_rdata,b_rdata,
 output reg [15:0] param_addr,output reg param_re,input wire [31:0] param_rdata,
 output reg [17:0] gelu_addr,output reg gelu_re,input wire [7:0] gelu_rdata,
 output reg [14:0] exp_addr,output reg exp_re,input wire [31:0] exp_rdata,
 output reg [15:0] score_addr,output reg score_re,input wire signed [31:0] score_rdata,
 output reg [15:0] prob_addr,output reg prob_re,prob_we,output reg [15:0] prob_wdata,input wire [15:0] prob_rdata
);
 localparam IDLE=0,INIT=1,PF=2,PW=3,MS=4,MW=5,
 NAF=6,NAW=7,NM=8,NMR=9,NQ=10,NSQ=11,NSUM=12,V0=13,V1=14,V2=15,V3=16,V4=17,ROOTED=18,INVERTED=19,
 XF=20,XW=21,D0=22,D1=23,D2=24,DN=25,DNROUND=26,GAMMA=27,GROUND=28,BETA=29,OUTMUL=30,OUTROUND=31,OUTZ=32,WRITE=33,
 RF=34,RW=35,RM0=36,RM1=37,RSUM=38,RPOST=39,RRND=40,RZ=41,
 POSF=42,POSW=43,POSACT=44,POSCAP=45,POSM=46,POSADD=47,
 GF=48,GW=49,GLF=50,GLW=51,PFROM=52,PWAIT=53,
 SF=54,SW=55,SMUL=56,SROUND=57,SMAX=58,SRESET=59,SEF=60,SEW=61,SEL=62,SELC=63,SETOTAL=64,SPF=65,SPW=66,SPDIV=67,SPWRITE=68;
 reg [7:0] state,return_state,p_return;reg [511:0] cmd;wire [31:0] w[0:15];genvar gi;
 generate for(gi=0;gi<16;gi=gi+1)begin:C assign w[gi]=cmd[32*gi+:32];end endgenerate
 wire [3:0] op=w[0][3:0];reg [17:0] index;reg [9:0] channel;reg [2:0] pi;reg [31:0] p[0:7];
 reg signed [7:0] ax,bx;reg signed [31:0] const_q,x_q,total;reg [53:0] sum_sq;reg [63:0] t_square,v_part,variance,v_eps,inv;
 reg signed [33:0] d_part,d_center;reg signed [127:0] r_value,term_a;
 (* ram_style="block" *)reg signed [31:0] x_cache[0:191];
 (* ram_style="block" *)reg signed [31:0] score_cache[0:196];
 (* ram_style="block" *)reg [31:0] exp_cache[0:196];
 reg signed [31:0] scaled_score,max_score,cache_score_q;reg [31:0] exponent_q,cache_exp_q;reg [39:0] exp_total;
 reg [7:0] write_data;reg [6:0] math_shift;reg [2:0] math_op;reg signed [127:0] math_a,math_b;reg math_valid;reg [15:0] sequence_q,expected_tag;
 wire math_ready,math_out_valid,math_error;wire signed [127:0] math_result;wire [15:0] math_tag;
 w8_math_baseline arithmetic(.clk(clk),.rst(rst),.flush(flush),.in_valid(math_valid),.in_ready(math_ready),.in_op(math_op),.in_a(math_a),.in_b(math_b),.in_shift(math_shift),.in_tag(expected_tag),.out_valid(math_out_valid),.out_ready(state==MW),.out_data(math_result),.out_tag(math_tag),.out_error(math_error));
 function automatic signed [127:0] sx8(input [7:0] v);sx8={{120{v[7]}},v};endfunction
 function automatic signed [127:0] sx32(input [31:0] v);sx32={{96{v[31]}},v};endfunction
 function automatic signed [127:0] sx64(input [63:0] v);sx64={{64{v[63]}},v};endfunction
 function automatic [7:0] sat(input signed [127:0] v);if(v>127)sat=8'h7f;else if(v< -128)sat=8'h80;else sat=v[7:0];endfunction
 task automatic calc(input [2:0] code,input signed [127:0] aa,bb,input [6:0] sh,input [7:0] ret);
 begin math_op<=code;math_a<=aa;math_b<=bb;math_shift<=sh;expected_tag<=sequence_q;sequence_q<=sequence_q+1'b1;math_valid<=1;return_state<=ret;state<=MS;end endtask
 task automatic params(input [7:0] ret);begin pi<=0;p_return<=ret;state<=PF;end endtask
 task automatic fail;begin done<=1;error<=1;math_valid<=0;state<=IDLE;end endtask
 wire clear=rst||flush;assign busy=!clear&&state!=IDLE;
 wire [32:0] exponent_delta=$signed({max_score[31],max_score})-$signed({cache_score_q[31],cache_score_q});
 always @*begin
  a_addr=0;b_addr=0;a_re=0;b_re=0;b_we=0;b_wdata=write_data;param_addr=0;param_re=0;gelu_addr=0;gelu_re=0;exp_addr=0;exp_re=0;score_addr=0;score_re=0;prob_addr=0;prob_re=0;prob_we=0;prob_wdata=0;
  if(!clear)begin
   case(state)
    PF:begin param_re=1;param_addr=((op==10)?16'd40000:16'd0)+({6'd0,channel}<<3)+pi;end
    NAF:begin a_re=1;a_addr=w[1][19:0]+index;end
    RF:begin a_re=1;b_re=1;a_addr=w[1][19:0]+index;b_addr=w[2][19:0]+index;end
    POSF:begin param_re=1;param_addr=index[15:0];end
    POSACT:if(index>=192)begin a_re=1;a_addr=w[1][19:0]+index-192;end
    GF:begin a_re=1;a_addr=w[1][19:0]+index;end
    GLF:begin gelu_re=1;gelu_addr={channel[9:0],8'd0}+({ax[7],ax[6:0]}^8'h80);end
    WRITE:begin b_we=1;b_addr=w[3][19:0]+index;end
    PFROM:begin prob_re=1;prob_addr=w[1][15:0]+index[15:0];end
    SF:begin score_re=1;score_addr=w[1][15:0]+index[15:0];end
    SEL:begin exp_re=1;exp_addr=exponent_delta[14:0];end
    SPWRITE:begin prob_we=(r_value>=0&&r_value<=255);prob_addr=w[3][15:0]+index[15:0];prob_wdata={8'd0,r_value[7:0]};end
    default:;
   endcase
  end
 end
 integer j;
 always @(posedge clk)begin
  done<=0;
  if(clear)begin state<=IDLE;error<=0;cmd<=0;index<=0;channel<=0;pi<=0;p_return<=0;return_state<=0;ax<=0;bx<=0;const_q<=0;x_q<=0;total<=0;sum_sq<=0;t_square<=0;v_part<=0;variance<=0;v_eps<=0;inv<=0;d_part<=0;d_center<=0;r_value<=0;term_a<=0;scaled_score<=0;max_score<=32'sh80000000;cache_score_q<=0;exponent_q<=0;cache_exp_q<=0;exp_total<=0;write_data<=0;math_valid<=0;math_op<=0;math_a<=0;math_b<=0;math_shift<=0;sequence_q<=0;expected_tag<=0;for(j=0;j<8;j=j+1)p[j]<=0;end
  else case(state)
   IDLE:if(start)begin cmd<=command;index<=0;channel<=0;total<=0;sum_sq<=0;error<=0;state<=INIT;end
   INIT:case(op)2:params(NAF);3:begin if(w[8]==0||w[8][31]||w[9]>62)fail();else begin max_score<=32'sh80000000;exp_total<=0;state<=SF;end end 5:state<=GF;6:params(RF);9:state<=PFROM;10:params(POSF);default:fail();endcase
   PF:state<=PW;
   PW:begin p[pi]<=param_rdata;if(pi==7)state<=p_return;else begin pi<=pi+1'b1;state<=PF;end end
   MS:if(math_ready)begin math_valid<=0;state<=MW;end
   MW:if(math_out_valid)begin if(math_error||math_tag!=expected_tag)fail();else begin r_value<=math_result;state<=return_state;end end
   NAF:state<=NAW;
   NAW:begin ax<=a_rdata;state<=NM;end
   NM:if(p[0]==0||p[0][31]||p[1]>62)fail();else calc(0,sx8(ax),{96'd0,p[0]},0,NMR);
   NMR:calc(1,r_value,0,p[1][6:0],NQ);
   NQ:if(r_value>8388607||r_value< -8388608)fail();else begin x_q<=r_value[31:0];x_cache[index[7:0]]<=r_value[31:0];total<=total+$signed(r_value[31:0]);state<=NSQ;end
   NSQ:calc(0,sx32(x_q),sx32(x_q),0,NSUM);
   NSUM:begin
    if(r_value[127:54]!=0)fail();else begin sum_sq<=sum_sq+r_value[53:0];if(index==191)begin index<=0;channel<=0;calc(0,sx32(total),sx32(total),0,V0);end else begin index<=index+1'b1;channel<=channel+1'b1;params(NAF);end end
   end
   V0:begin t_square<=r_value[63:0];v_part<={10'd0,sum_sq}<<7;state<=V1;end
   V1:begin v_part<=v_part+({10'd0,sum_sq}<<6);state<=V2;end
   V2:if(v_part<t_square)fail();else begin variance<=v_part-t_square;state<=V3;end
   V3:begin v_eps<=variance+64'd2473901;state<=V4;end
   V4:if(v_eps[63:62]!=0)fail();else calc(3,{48'd0,v_eps,16'd0},0,0,ROOTED);
   ROOTED:if(r_value==0)fail();else calc(2,128'd9007199254740992,r_value,0,INVERTED);
   INVERTED:begin inv<=r_value[63:0];index<=0;channel<=0;params(XF);end
   XF:begin x_q<=x_cache[index[7:0]];state<=XW;end
   XW:begin d_part<=$signed(x_q)<<<7;state<=D0;end
   D0:begin d_part<=d_part+($signed(x_q)<<<6);state<=D1;end
   D1:begin d_center<=d_part-$signed(total);state<=D2;end
   D2:calc(0,{{94{d_center[33]}},d_center},{64'd0,inv},0,DN);
   DN:calc(1,r_value,0,7'd25,DNROUND);
   DNROUND:calc(0,r_value,sx32(p[2]),0,GAMMA);
   GAMMA:calc(1,r_value,0,7'd20,GROUND);
   GROUND:calc(4,r_value,sx32(p[3]),0,BETA);
   BETA:if(r_value>128'sd549755813887||r_value< -128'sd549755813888||p[4]==0||p[4][31]||p[5]>62||$signed(p[6])< -128||$signed(p[6])>127)fail();else calc(0,r_value,{96'd0,p[4]},0,OUTMUL);
   OUTMUL:calc(1,r_value,0,p[5][6:0],OUTROUND);
   OUTROUND:calc(4,r_value,sx32(p[6]),0,OUTZ);
   OUTZ:begin write_data<=sat(r_value);state<=WRITE;end
   RF:state<=RW;
   RW:begin ax<=a_rdata;bx<=b_rdata;state<=RM0;end
   RM0:if(p[0][31]||p[1][31]||p[2]==0||p[2][31]||p[3]>62||$signed(p[4])< -128||$signed(p[4])>127)fail();else calc(0,sx8(ax),{96'd0,p[0]},0,RM1);
   RM1:begin term_a<=r_value;calc(0,sx8(bx),{96'd0,p[1]},0,RSUM);end
   RSUM:calc(4,term_a,r_value,0,RPOST);
   RPOST:if(r_value>128'sd549755813887||r_value< -128'sd549755813888)fail();else calc(0,r_value,{96'd0,p[2]},0,RRND);
   RRND:calc(1,r_value,0,p[3][6:0],RZ);
   RZ:calc(4,r_value,sx32(p[4]),0,OUTZ);
   POSF:state<=POSW;
   POSW:begin const_q<=param_rdata;state<=POSACT;end
   POSACT:state<=POSCAP;
   POSCAP:begin ax<=(index<192)?8'sd0:a_rdata;state<=POSM;end
   POSM:if(p[0][31]||p[2]==0||p[2][31]||p[3]>62||$signed(p[4])< -128||$signed(p[4])>127)fail();else calc(0,sx8(ax),{96'd0,p[0]},0,POSADD);
   POSADD:calc(4,r_value,sx32(const_q),0,RPOST);
   GF:state<=GW;
   GW:begin ax<=a_rdata;state<=GLF;end
   GLF:state<=GLW;
   GLW:begin write_data<=gelu_rdata;state<=WRITE;end
   PFROM:state<=PWAIT;
   PWAIT:if(prob_rdata[15:8]!=0)fail();else begin write_data<=prob_rdata[7:0]^8'h80;state<=WRITE;end
   WRITE:begin
    if((op==2&&index==191)||(op!=2&&index==w[7]-1))begin done<=1;state<=IDLE;end
    else begin
     index<=index+1'b1;
     if(channel==((op==5)?w[6]-1:191))channel<=0;else channel<=channel+1'b1;
     case(op)2:params(XF);5:state<=GF;6:params(RF);9:state<=PFROM;10:params(POSF);default:fail();endcase
    end
   end
   SF:state<=SW;
   SW:begin scaled_score<=score_rdata;state<=SMUL;end
   SMUL:calc(0,sx32(scaled_score),{96'd0,w[8]},0,SROUND);
   SROUND:calc(1,r_value,0,w[9][6:0],SMAX);
   SMAX:if(r_value>2147483647||r_value< -128'sd2147483648)fail();else begin score_cache[index[7:0]]<=r_value[31:0];if($signed(r_value[31:0])>max_score)max_score<=r_value[31:0];if(index==196)begin index<=0;state<=SRESET;end else begin index<=index+1'b1;state<=SF;end end
   SRESET:begin exp_total<=0;state<=SEF;end
   SEF:begin cache_score_q<=score_cache[index[7:0]];state<=SEW;end
   SEW:if(exponent_delta>16384)begin exponent_q<=0;state<=SETOTAL;end else state<=SEL;
   SEL:state<=SELC;
   SELC:begin exponent_q<=exp_rdata;state<=SETOTAL;end
   SETOTAL:begin exp_cache[index[7:0]]<=exponent_q;exp_total<=exp_total+exponent_q;if(index==196)begin index<=0;state<=SPF;end else begin index<=index+1'b1;state<=SEF;end end
   SPF:begin cache_exp_q<=exp_cache[index[7:0]];state<=SPW;end
   SPW:if(exp_total==0)fail();else state<=SPDIV;
   SPDIV:calc(2,({96'd0,cache_exp_q}<<8)-{96'd0,cache_exp_q},{88'd0,exp_total},0,SPWRITE);
   SPWRITE:begin
    // Write data is derived from the held result on this same memory edge.
    if(r_value<0||r_value>255)fail();else if(index==196)begin done<=1;state<=IDLE;end else begin index<=index+1'b1;state<=SPF;end
   end
   default:fail();
  endcase
 end
endmodule
