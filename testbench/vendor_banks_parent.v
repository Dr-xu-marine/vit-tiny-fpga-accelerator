`timescale 1ns/1ps
module vendor_banks_parent #(
    parameter WORD_AW=14,
    parameter BYTE_LANES=16,
    parameter RAM_STYLE="block"
)(
    input wire clk,rst,wr_en,
    input wire [WORD_AW-1:0] wr_word,
    input wire [5:0] wr_lane,
    input wire [7:0] wr_data,
    input wire rd_en,
    input wire [WORD_AW-1:0] rd_word,
    output wire [BYTE_LANES*8-1:0] rd_data
);
    genvar lane;
    generate for(lane=0;lane<BYTE_LANES;lane=lane+1) begin: banks
        (* ram_style=RAM_STYLE *) reg [7:0] bytes [0:(1<<WORD_AW)-1];
        reg [7:0] q;
        assign rd_data[lane*8+:8]=q;
        always @(posedge clk) begin
            if(wr_en && !rst && wr_lane==lane) bytes[wr_word]<=wr_data;
            if(rst) q<=0;
            else if(rd_en && !(wr_en && wr_word==rd_word)) q<=bytes[rd_word];
        end
    end endgenerate
endmodule
