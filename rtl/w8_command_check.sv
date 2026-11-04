`timescale 1ns/1ps
// Range validation only. No arithmetic/quantization datapath changes.
// Full-width fields are rejected before narrowing the bounded loop counters.
// Four unsigned 10x32 products use ten shift/add steps, never a cascaded
// multiplier->adder->comparator on the command acceptance edge.
module w8_command_check(
 input wire clk,rst,start,input wire [511:0] command,
 output wire busy,output reg done,bad
);
 localparam IDLE=0,PREP=1,MUL=2,SUM0=3,SUM1=4,CHECK=5,FINISH=6;
 reg [2:0] state;
 reg [511:0] q;
 wire [31:0] h=q[31:0],a=q[63:32],b=q[95:64],y=q[127:96];
 wire [31:0] m=q[159:128],k=q[191:160],n=q[223:192],count=q[255:224];
 reg [9:0] factor[0:3];
 reg [41:0] term[0:3],product[0:3];
 reg [42:0] src_sum,dst_sum;
 reg [3:0] step;
 integer i;
 assign busy=state!=IDLE;
 function automatic small_bad(input [511:0] c);
  reg [31:0] hh,aa,bb,yy,mm,kk,nn,cc;
  begin
   hh=c[31:0];aa=c[63:32];bb=c[95:64];yy=c[127:96];
   mm=c[159:128];kk=c[191:160];nn=c[223:192];cc=c[255:224];
   small_bad=(|(hh&32'hffffe0f0))||aa>=1048576||bb>=1048576||yy>=1048576;
   case(hh[3:0])
    1,4:small_bad=small_bad||mm<1||mm>197||kk<1||kk>768||nn<1||nn>1000;
    2:small_bad=small_bad||(|hh[12:8])||mm!=1||nn!=192||aa+192>1048576||yy+192>1048576;
    3:small_bad=small_bad||(|hh[12:8])||nn!=197||aa+197>65536||yy+197>65536;
    5,6,9,10:begin
     small_bad=small_bad||(|hh[12:8])||cc<1||cc>151296||{1'b0,yy}+cc>1048576;
     if(hh[3:0]==6)small_bad=small_bad||{1'b0,aa}+cc>1048576||{1'b0,bb}+cc>1048576;
     if(hh[3:0]==5)small_bad=small_bad||nn<1||nn>768||{1'b0,aa}+cc>1048576;
     if(hh[3:0]==9)small_bad=small_bad||{1'b0,aa}+cc>65536;
     if(hh[3:0]==10)small_bad=small_bad||cc!=37824||nn!=192||{1'b0,aa}+37632>1048576;
    end
    7:small_bad=small_bad||hh[8]||hh[9]||hh[11]||hh[12]||mm<1||mm>768||nn<1||nn>768;
    default:small_bad=1;
   endcase
  end
 endfunction
 always @(posedge clk)begin
  done<=0;
  if(rst)begin
   state<=IDLE;q<=0;bad<=0;step<=0;src_sum<=0;dst_sum<=0;
   for(i=0;i<4;i=i+1)begin factor[i]<=0;term[i]<=0;product[i]<=0;end
  end else case(state)
   IDLE:if(start)begin q<=command;bad<=0;state<=PREP;end
   PREP:begin
    bad<=small_bad(q);step<=0;
    for(i=0;i<4;i=i+1)begin product[i]<=0;factor[i]<=0;term[i]<=0;end
    if(small_bad(q))state<=FINISH;
    else if(h[3:0]==1||h[3:0]==4)begin
     factor[0]<=m[9:0];term[0]<={10'd0,k};
     factor[1]<=m[9:0];term[1]<={10'd0,n};
     factor[2]<=k[9:0];term[2]<=({10'd0,n}+42'd15)>>4;
     state<=MUL;
    end else if(h[3:0]==7)begin
     factor[0]<=m[9:0]-1'b1;term[0]<={10'd0,q[447:416]};
     factor[1]<=n[9:0]-1'b1;term[1]<={10'd0,q[479:448]};
     factor[2]<=m[9:0]-1'b1;term[2]<={10'd0,q[511:480]};
     factor[3]<=n[9:0]-1'b1;term[3]<={10'd0,q[415:384]};
     state<=MUL;
    end else state<=FINISH;
   end
   MUL:begin
    for(i=0;i<4;i=i+1)begin
     if(factor[i][0])product[i]<=product[i]+term[i];
     factor[i]<=factor[i]>>1;term[i]<=term[i]<<1;
    end
    if(step==9)state<=SUM0;else step<=step+1'b1;
   end
   SUM0:begin
    src_sum<={11'd0,a}+{1'b0,product[0]};
    dst_sum<={11'd0,y}+{1'b0,product[h[3:0]==7?2:1]};
    state<=SUM1;
   end
   SUM1:begin
    if(h[3:0]==7)begin src_sum<=src_sum+{1'b0,product[1]};dst_sum<=dst_sum+{1'b0,product[3]};end
    state<=CHECK;
   end
   CHECK:begin
    if(h[3:0]==7)bad<=src_sum>=1048576||dst_sum>=(h[10]?262144:1048576);
    else bad<=src_sum>1048576||dst_sum>(h[11]?65536:1048576)||(h[8]&&product[2]>16384);
    state<=FINISH;
   end
   FINISH:begin done<=1;state<=IDLE;end
   default:begin done<=1;bad<=1;state<=IDLE;end
  endcase
 end
endmodule
