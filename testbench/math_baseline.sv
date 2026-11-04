`timescale 1ns/1ps
// One outstanding exact arithmetic transaction. No false/multicycle exception.
// MUL uses a registered16x16 product and FOUR32-bit carry steps per partial.
// A stall at output holds result/tag/error. reset/flush abort the transaction.
module w8_math_baseline(
 input wire clk,rst,flush,in_valid,output wire in_ready,
 input wire [2:0] in_op,input wire signed [127:0] in_a,in_b,
 input wire [6:0] in_shift,input wire [15:0] in_tag,
 output wire out_valid,input wire out_ready,output reg signed [127:0] out_data,
 output reg [15:0] out_tag,output reg out_error
);
 localparam IDLE=0,PART=1,TERM=2,ADD_PART=3,ADV=4,SIGN=5,NEG=6,FINISH=7,
 ROUND_MAG=8,ROUND_NEG=9,SHIFT=10,DECIDE=11,INC=12,DIVIDE=13,DIVROUND=14,ROOT=15,ADD=16;
 reg [4:0] st;reg [127:0] acc,term,aa,bb;reg [63:0] am,bm;
 reg [1:0] ai,bi,chunk;reg carry,negative,guardbit,sticky;
 reg [31:0] partial;reg [6:0] shift_q,count;reg [63:0] dividend,divisor,quotient;reg [64:0] remainder;
 reg [79:0] rad;reg [81:0] sqrt_rem;reg [39:0] root;
 wire [32:0] add_part={1'b0,acc[32*chunk+:32]}+{1'b0,term[32*chunk+:32]}+carry;
 wire [32:0] negate_part={1'b0,~acc[32*chunk+:32]}+carry;
 wire [32:0] increment_part={1'b0,acc[32*chunk+:32]}+carry;
 wire [32:0] add_ab={1'b0,aa[32*chunk+:32]}+{1'b0,bb[32*chunk+:32]}+carry;
 wire [64:0] div_trial={remainder[63:0],dividend[63]};wire div_take=div_trial>={1'b0,divisor};
 wire [81:0] sqrt_trial_rem=(sqrt_rem<<2)|{80'd0,rad[79:78]};
 wire [81:0] sqrt_trial=({42'd0,root}<<2)|82'd1;wire sqrt_take=sqrt_trial_rem>=sqrt_trial;
 assign in_ready=!rst&&!flush&&st==IDLE;assign out_valid=!rst&&!flush&&st==FINISH;
 always @(posedge clk) begin
  if(rst||flush)begin st<=IDLE;out_data<=0;out_tag<=0;out_error<=0;acc<=0;term<=0;aa<=0;bb<=0;am<=0;bm<=0;ai<=0;bi<=0;chunk<=0;carry<=0;negative<=0;guardbit<=0;sticky<=0;partial<=0;shift_q<=0;count<=0;dividend<=0;divisor<=0;quotient<=0;remainder<=0;rad<=0;sqrt_rem<=0;root<=0;end
  else case(st)
   IDLE:if(in_valid)begin
    out_tag<=in_tag;out_error<=0;acc<=0;aa<=in_a;bb<=in_b;chunk<=0;carry<=0;count<=0;
    case(in_op)
     0:begin
      if(in_a[127:64]!={64{in_a[63]}}||in_b[127:64]!={64{in_b[63]}})begin out_error<=1;out_data<=0;st<=FINISH;end
      else begin am<=in_a[63]?(~in_a[63:0]+64'd1):in_a[63:0];bm<=in_b[63]?(~in_b[63:0]+64'd1):in_b[63:0];negative<=in_a[63]^in_b[63];ai<=0;bi<=0;st<=PART;end
     end
     1:begin negative<=in_a[127];acc<=in_a;shift_q<=in_shift;guardbit<=0;sticky<=0;st<=ROUND_MAG;end
     2:begin
      if(in_a[127:64]!=0||in_b[127:64]!=0||in_b[63:0]==0)begin out_error<=1;out_data<=0;st<=FINISH;end
      else begin dividend<=in_a[63:0];divisor<=in_b[63:0];quotient<=0;remainder<=0;st<=DIVIDE;end
     end
     3:begin if(in_a[127:80]!=0)begin out_error<=1;out_data<=0;st<=FINISH;end else begin rad<=in_a[79:0];sqrt_rem<=0;root<=0;st<=ROOT;end end
     4:st<=ADD;
     default:begin out_error<=1;out_data<=0;st<=FINISH;end
    endcase
   end
   PART:begin
    if(am[16*ai+:16]==0||bm[16*bi+:16]==0)st<=ADV;
    else begin partial<=am[16*ai+:16]*bm[16*bi+:16];st<=TERM;end
   end
   TERM:begin term<={96'd0,partial}<<(16*(ai+{1'b0,bi}));chunk<=0;carry<=0;st<=ADD_PART;end
   ADD_PART:begin acc[32*chunk+:32]<=add_part[31:0];carry<=add_part[32];if(chunk==3)st<=ADV;else chunk<=chunk+1'b1;end
   ADV:begin if(ai==3&&bi==3)st<=SIGN;else begin if(bi==3)begin bi<=0;ai<=ai+1'b1;end else bi<=bi+1'b1;st<=PART;end end
   SIGN:if(negative)begin chunk<=0;carry<=1;st<=NEG;end else begin out_data<=acc;st<=FINISH;end
   NEG:begin acc[32*chunk+:32]<=negate_part[31:0];carry<=negate_part[32];if(chunk==3)begin out_data<={negate_part[31:0],acc[95:0]};st<=FINISH;end else chunk<=chunk+1'b1;end
   ROUND_MAG:if(negative)begin chunk<=0;carry<=1;st<=ROUND_NEG;end else st<=SHIFT;
   ROUND_NEG:begin acc[32*chunk+:32]<=negate_part[31:0];carry<=negate_part[32];if(chunk==3)st<=SHIFT;else chunk<=chunk+1'b1;end
   SHIFT:if(count==shift_q)st<=DECIDE;else begin if(count==shift_q-1'b1)guardbit<=acc[0];else sticky<=sticky|acc[0];acc<=acc>>1;count<=count+1'b1;end
   DECIDE:if(guardbit&&(sticky||acc[0]))begin chunk<=0;carry<=1;st<=INC;end else st<=SIGN;
   INC:begin acc[32*chunk+:32]<=increment_part[31:0];carry<=increment_part[32];if(chunk==3)st<=SIGN;else chunk<=chunk+1'b1;end
   DIVIDE:begin remainder<=div_take?(div_trial-{1'b0,divisor}):div_trial;dividend<=dividend<<1;quotient<={quotient[62:0],div_take};if(count==63)st<=DIVROUND;else count<=count+1'b1;end
   DIVROUND:begin out_data<={64'd0,quotient}+((({1'b0,remainder}<<1)>{2'b0,divisor})||((({1'b0,remainder}<<1)=={2'b0,divisor})&&quotient[0]));st<=FINISH;end
   ROOT:begin rad<=rad<<2;sqrt_rem<=sqrt_take?(sqrt_trial_rem-sqrt_trial):sqrt_trial_rem;root<={root[38:0],sqrt_take};if(count==39)begin out_data<={88'd0,root[38:0],sqrt_take};st<=FINISH;end else count<=count+1'b1;end
   ADD:begin acc[32*chunk+:32]<=add_ab[31:0];carry<=add_ab[32];if(chunk==3)begin out_data<={add_ab[31:0],acc[95:0]};out_error<=(aa[127]==bb[127])&&(add_ab[31]!=aa[127]);st<=FINISH;end else chunk<=chunk+1'b1;end
   FINISH:if(out_ready)st<=IDLE;
   default:begin st<=IDLE;out_error<=1;end
  endcase
 end
endmodule
