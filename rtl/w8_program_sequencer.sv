`timescale 1ns/1ps
module w8_program_sequencer #(
 parameter PROGRAM_FILE="data/package/program.hex",parameter integer INSTRUCTIONS=16384
)(
 input wire clk,rst,start,output wire busy,output reg done,error,
 output wire cmd_valid,output wire [511:0] cmd_data,input wire cmd_ready,cmd_done,cmd_error,
 output wire load_start,output wire [30:0] load_src_addr,output wire [23:0] load_nbytes,load_local_offset,output wire [3:0] load_target,
 input wire load_ready,load_done,load_error,
 output reg [15:0] retired_instructions,completed_commands,completed_loads
);
 localparam IDLE=0,FETCH=1,DECODE=2,CSEND=3,CWAIT=4,LSEND=5,LWAIT=6,ADVANCE=7;
 reg [3:0] state;reg [15:0] pc;reg [511:0] ir;
 (* rom_style="block" *)reg [511:0] instruction_rom[0:INSTRUCTIONS-1];
 initial $readmemh(PROGRAM_FILE,instruction_rom);
 assign busy=!rst&&state!=IDLE;assign cmd_valid=!rst&&state==CSEND;assign cmd_data=ir;
 assign load_start=!rst&&state==LSEND;assign load_src_addr=ir[32+:31];assign load_target=ir[64+:4];assign load_nbytes=ir[96+:24];assign load_local_offset=ir[128+:24];
 task automatic fail;begin done<=1;error<=1;state<=IDLE;end endtask
 always @(posedge clk)begin
  done<=0;
  if(rst)begin state<=IDLE;pc<=0;ir<=0;error<=0;retired_instructions<=0;completed_commands<=0;completed_loads<=0;end
  else case(state)
   IDLE:if(start)begin pc<=0;error<=0;retired_instructions<=0;completed_commands<=0;completed_loads<=0;state<=FETCH;end
   FETCH:if(pc>=INSTRUCTIONS)fail();else begin ir<=instruction_rom[pc];state<=DECODE;end
   DECODE:if(ir[3:0]==15)begin done<=1;state<=IDLE;end else if(ir[3:0]==8)begin if(ir[63]||ir[37:32]!=0||ir[127:96]==0||ir[127:120]!=0||ir[159:152]!=0||ir[95:68]!=0)fail();else state<=LSEND;end else state<=CSEND;
   CSEND:if(cmd_ready)state<=CWAIT;
   CWAIT:if(cmd_done)begin if(cmd_error)fail();else begin completed_commands<=completed_commands+1'b1;state<=ADVANCE;end end
   LSEND:if(load_ready)state<=LWAIT;
   LWAIT:if(load_done)begin if(load_error)fail();else begin completed_loads<=completed_loads+1'b1;state<=ADVANCE;end end
   ADVANCE:begin retired_instructions<=retired_instructions+1'b1;pc<=pc+1'b1;state<=FETCH;end
   default:fail();
  endcase
 end
endmodule
