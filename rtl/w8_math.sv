`timescale 1ns/1ps
// One outstanding exact arithmetic transaction. No false/multicycle exception.
// Register multiplier operands before the16x16 product. Carry work is32bit.
// DIV/ROOT use registered32bit carry-select differences, then a select cycle.
// A stall at output holds result/tag/error. reset/flush abort the transaction.
module w8_math(
 input wire clk,rst,flush,in_valid,output wire in_ready,
 input wire [2:0] in_op,input wire signed [127:0] in_a,in_b,
 input wire [6:0] in_shift,input wire [15:0] in_tag,
 output wire out_valid,input wire out_ready,output reg signed [127:0] out_data,
 output reg [15:0] out_tag,output reg out_error
);
 localparam IDLE=0,PART=1,TERM=2,ADD_PART=3,ADV=4,SIGN=5,NEG=6,FINISH=7,
 ROUND_MAG=8,ROUND_NEG=9,SHIFT=10,DECIDE=11,INC=12,DIVIDE=13,DIVROUND=14,ROOT=15,ADD=16,
 ABS_LO=17,ABS_HI=18,MUL_SELECT=19,DIV_APPLY=20,ROOT_APPLY=21,DIV_ROUND_APPLY=22,DIV_ROUND_LO=23,DIV_ROUND_HI=24;
 reg [4:0] st;reg [127:0] acc,term,aa,bb;reg [63:0] am,bm;
 reg [1:0] ai,bi,chunk;reg carry,negative,guardbit,sticky;
 reg [31:0] partial;reg [15:0] mul_a,mul_b;reg abs_ca,abs_cb,round_up;reg [31:0] round_lo;reg round_carry;
 reg [6:0] shift_q,count;reg [63:0] dividend,divisor,quotient;reg [64:0] remainder;
 reg [79:0] rad;reg [81:0] sqrt_rem;reg [39:0] root;
 wire [32:0] add_part={1'b0,acc[32*chunk+:32]}+{1'b0,term[32*chunk+:32]}+carry;
 wire [32:0] negate_part={1'b0,~acc[32*chunk+:32]}+carry;
 wire [32:0] increment_part={1'b0,acc[32*chunk+:32]}+carry;
 wire [32:0] add_ab={1'b0,aa[32*chunk+:32]}+{1'b0,bb[32*chunk+:32]}+carry;
 wire [64:0] div_trial={remainder[63:0],dividend[63]};
 wire [81:0] sqrt_trial_rem=(sqrt_rem<<2)|{80'd0,rad[79:78]};
 wire [81:0] sqrt_trial=({42'd0,root}<<2)|82'd1;
 // Speculate both input carries IN PARALLEL; no wide compare followed by subtract.
 wire [95:0] trial_x=(st==ROOT)?{14'd0,sqrt_trial_rem}:
                           (st==DIVROUND)?{30'd0,remainder,1'b0}:{31'd0,div_trial};
 wire [95:0] trial_y=(st==ROOT)?{14'd0,sqrt_trial}:{32'd0,divisor};
 reg [32:0] sub_c1[0:2],sub_c0[0:2];wire [32:0] chosen[0:2];
 assign chosen[0]=sub_c1[0];
 assign chosen[1]=chosen[0][32]?sub_c1[1]:sub_c0[1];
 assign chosen[2]=chosen[1][32]?sub_c1[2]:sub_c0[2];
 wire trial_take=chosen[2][32];
 wire [95:0] trial_diff={chosen[2][31:0],chosen[1][31:0],chosen[0][31:0]};
 generate for(genvar d=0;d<3;d=d+1)begin: SUB_CHUNK
  always @(posedge clk)if(!rst&&!flush&&(st==DIVIDE||st==ROOT||st==DIVROUND))begin
   sub_c1[d]<={1'b0,trial_x[32*d+:32]}+{1'b0,~trial_y[32*d+:32]}+33'd1;
   sub_c0[d]<={1'b0,trial_x[32*d+:32]}+{1'b0,~trial_y[32*d+:32]};
  end
 end endgenerate
 wire [32:0] abs_a_lo={1'b0,~am[31:0]}+33'd1,abs_b_lo={1'b0,~bm[31:0]}+33'd1;
 wire [32:0] quotient_lo={1'b0,quotient[31:0]}+round_up;
 wire [32:0] quotient_hi={1'b0,quotient[63:32]}+round_carry;
 assign in_ready=!rst&&!flush&&st==IDLE;assign out_valid=!rst&&!flush&&st==FINISH;
 always @(posedge clk) begin
  if(rst||flush)begin st<=IDLE;out_data<=0;out_tag<=0;out_error<=0;acc<=0;term<=0;aa<=0;bb<=0;am<=0;bm<=0;ai<=0;bi<=0;chunk<=0;carry<=0;negative<=0;guardbit<=0;sticky<=0;partial<=0;mul_a<=0;mul_b<=0;abs_ca<=0;abs_cb<=0;round_up<=0;round_lo<=0;round_carry<=0;shift_q<=0;count<=0;dividend<=0;divisor<=0;quotient<=0;remainder<=0;rad<=0;sqrt_rem<=0;root<=0;end
  else case(st)
   IDLE:if(in_valid)begin
    out_tag<=in_tag;out_error<=0;acc<=0;aa<=in_a;bb<=in_b;chunk<=0;carry<=0;count<=0;
    case(in_op)
     0:begin
      if(in_a[127:64]!={64{in_a[63]}}||in_b[127:64]!={64{in_b[63]}})begin out_error<=1;out_data<=0;st<=FINISH;end
      else begin am<=in_a[63:0];bm<=in_b[63:0];negative<=in_a[63]^in_b[63];ai<=0;bi<=0;st<=ABS_LO;end
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
   ABS_LO:begin
    if(aa[63])begin am[31:0]<=abs_a_lo[31:0];abs_ca<=abs_a_lo[32];end
    if(bb[63])begin bm[31:0]<=abs_b_lo[31:0];abs_cb<=abs_b_lo[32];end st<=ABS_HI;
   end
   ABS_HI:begin
    if(aa[63])am[63:32]<=~am[63:32]+abs_ca;
    if(bb[63])bm[63:32]<=~bm[63:32]+abs_cb;st<=MUL_SELECT;
   end
   MUL_SELECT:begin mul_a<=am[16*ai+:16];mul_b<=bm[16*bi+:16];st<=PART;end
   PART:if(mul_a==0||mul_b==0)st<=ADV;
        else begin partial<=mul_a*mul_b;st<=TERM;end
   TERM:begin term<={96'd0,partial}<<(16*(ai+{1'b0,bi}));chunk<=0;carry<=0;st<=ADD_PART;end
   ADD_PART:begin acc[32*chunk+:32]<=add_part[31:0];carry<=add_part[32];if(chunk==3)st<=ADV;else chunk<=chunk+1'b1;end
   ADV:begin if(ai==3&&bi==3)st<=SIGN;else begin if(bi==3)begin bi<=0;ai<=ai+1'b1;end else bi<=bi+1'b1;st<=MUL_SELECT;end end
   SIGN:if(negative)begin chunk<=0;carry<=1;st<=NEG;end else begin out_data<=acc;st<=FINISH;end
   NEG:begin acc[32*chunk+:32]<=negate_part[31:0];carry<=negate_part[32];if(chunk==3)begin out_data<={negate_part[31:0],acc[95:0]};st<=FINISH;end else chunk<=chunk+1'b1;end
   ROUND_MAG:if(negative)begin chunk<=0;carry<=1;st<=ROUND_NEG;end else st<=SHIFT;
   ROUND_NEG:begin acc[32*chunk+:32]<=negate_part[31:0];carry<=negate_part[32];if(chunk==3)st<=SHIFT;else chunk<=chunk+1'b1;end
   SHIFT:if(count==shift_q)st<=DECIDE;else begin if(count==shift_q-1'b1)guardbit<=acc[0];else sticky<=sticky|acc[0];acc<=acc>>1;count<=count+1'b1;end
   DECIDE:if(guardbit&&(sticky||acc[0]))begin chunk<=0;carry<=1;st<=INC;end else st<=SIGN;
   INC:begin acc[32*chunk+:32]<=increment_part[31:0];carry<=increment_part[32];if(chunk==3)st<=SIGN;else chunk<=chunk+1'b1;end
   DIVIDE:st<=DIV_APPLY;
   DIV_APPLY:begin remainder<=trial_take?trial_diff[64:0]:div_trial;dividend<=dividend<<1;quotient<={quotient[62:0],trial_take};if(count==63)st<=DIVROUND;else begin count<=count+1'b1;st<=DIVIDE;end end
   DIVROUND:st<=DIV_ROUND_APPLY;
   DIV_ROUND_APPLY:begin round_up<=trial_take&&((|trial_diff)||quotient[0]);st<=DIV_ROUND_LO;end
   DIV_ROUND_LO:begin round_lo<=quotient_lo[31:0];round_carry<=quotient_lo[32];st<=DIV_ROUND_HI;end
   DIV_ROUND_HI:begin out_data<={64'd0,quotient_hi[31:0],round_lo};st<=FINISH;end
   ROOT:st<=ROOT_APPLY;
   ROOT_APPLY:begin rad<=rad<<2;sqrt_rem<=trial_take?trial_diff[81:0]:sqrt_trial_rem;root<={root[38:0],trial_take};if(count==39)begin out_data<={88'd0,root[38:0],trial_take};st<=FINISH;end else begin count<=count+1'b1;st<=ROOT;end end
   ADD:begin acc[32*chunk+:32]<=add_ab[31:0];carry<=add_ab[32];if(chunk==3)begin out_data<={add_ab[31:0],acc[95:0]};out_error<=(aa[127]==bb[127])&&(add_ab[31]!=aa[127]);st<=FINISH;end else chunk<=chunk+1'b1;end
   FINISH:if(out_ready)st<=IDLE;
   default:begin st<=IDLE;out_error<=1;end
  endcase
 end
endmodule
