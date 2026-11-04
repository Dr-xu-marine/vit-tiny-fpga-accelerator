`timescale 1ns/1ps
// Gate1 INT8 only: local per-PE leaf registers; four independent quadrant CE trees.
module v2_mac_group4x8 #(parameter integer CORE_FAULT=0)(
 input wire clk,rst,flush,in_valid,
 input wire [31:0] a32,input wire [63:0] b64,
 input wire [9:0] k_index,input wire k_last,
 output wire [1535:0] p_all,
 output wire commit_valid,output wire [9:0] commit_k,output wire commit_last,
 output wire take_valid,output wire [9:0] take_k
);
 wire [31:0] cell_commit;
 genvar qr,qc,lr,lc;
 generate for(qr=0;qr<2;qr=qr+1) begin: GR
  for(qc=0;qc<2;qc=qc+1) begin: GC
   (* keep="true", dont_touch="true" *) reg valid_q;
   (* keep="true", dont_touch="true" *) reg rst_q,flush_q;
   reg [9:0] k_q;reg last_q;
   always @(posedge clk) begin
    rst_q<=rst;flush_q<=flush;
    if(rst||flush) begin valid_q<=0;k_q<=0;last_q<=0;end
    else begin valid_q<=in_valid;if(in_valid) begin k_q<=k_index;last_q<=k_last;end end
   end
   for(lr=0;lr<2;lr=lr+1) begin: LR
    for(lc=0;lc<4;lc=lc+1) begin: LC
     localparam integer R=2*qr+lr,C=4*qc+lc,I=8*R+C;
     // Per-PE copies preserve physical locality, including the sign-bit loads.
     (* keep="true", dont_touch="true" *) reg signed [7:0] a_leaf,b_leaf;
     always @(posedge clk) if(in_valid) begin a_leaf<=a32[8*R+:8];b_leaf<=b64[8*C+:8];end
     v2_c0_mac_cell #(.FAULT(CORE_FAULT)) pe(
      .clk(clk),.rst(rst_q),.flush(flush_q),.take(valid_q),
      .a(a_leaf),.b(b_leaf),.p(p_all[48*I+:48]),.commit_valid(cell_commit[I]));
    end
   end
  end
 end endgenerate
 reg [9:0] k_ab,k_m,k_p;
 reg last_ab,last_m,last_p;
 always @(posedge clk) begin
  if(rst||flush) begin k_ab<=0;k_m<=0;k_p<=0;last_ab<=0;last_m<=0;last_p<=0;end
  else begin
   k_ab<=GR[0].GC[0].k_q;k_m<=k_ab;k_p<=k_m;
   last_ab<=GR[0].GC[0].last_q;last_m<=last_ab;last_p<=last_m;
  end
 end
 assign commit_valid=cell_commit[0];assign commit_k=k_p;assign commit_last=last_p;
 assign take_valid=GR[0].GC[0].valid_q;assign take_k=GR[0].GC[0].k_q;
endmodule
