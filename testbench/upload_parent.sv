`timescale 1ns/1ps
module upload_parent #(parameter AW=16,LANES=4,STRIDE=2)(
 input wire clk,rst,we,input wire [23:0] byte_addr,input wire [7:0] byte_data,
 input wire re,input wire [AW-1:0] word_addr,output wire [8*LANES-1:0] data
);
 generate for(genvar lane=0;lane<LANES;lane=lane+1)begin:banks
  (* ram_style="block" *)reg [7:0] bytes[0:(1<<AW)-1];reg [7:0] q;
  wire [AW-1:0] wa=byte_addr>>STRIDE;
  always @(posedge clk)begin if(we&&((byte_addr&((1<<STRIDE)-1))==lane))bytes[wa]<=byte_data;if(rst)q<=0;else if(re)q<=bytes[word_addr];end
  assign data[8*lane+:8]=q;
 end endgenerate
endmodule
