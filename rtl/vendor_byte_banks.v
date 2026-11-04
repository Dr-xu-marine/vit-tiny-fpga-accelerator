`timescale 1ns/1ps
module tiny_compute_byte_banks #(
    parameter WORD_AW=14,
    parameter BYTE_LANES=16,
    parameter RAM_STYLE="block",
    parameter LOCAL_WRITE_PIPE=0
)(
    input wire clk,rst,wr_en,
    input wire [WORD_AW-1:0] wr_word,
    input wire [5:0] wr_lane,
    input wire [7:0] wr_data,
    input wire rd_en,
    input wire [WORD_AW-1:0] rd_word,
    output wire [BYTE_LANES*8-1:0] rd_data,
    output wire write_pending
);
    reg pending_q=0;
    always @(posedge clk) pending_q<=LOCAL_WRITE_PIPE && wr_en && !rst;
    assign write_pending=pending_q;
    genvar lane;
    generate for(lane=0;lane<BYTE_LANES;lane=lane+1) begin: banks
        (* ram_style=RAM_STYLE, cascade_height=2 *) reg [7:0] bytes [0:(1<<WORD_AW)-1];
        reg [7:0] q;
        if(LOCAL_WRITE_PIPE) begin: local_write
          // Same acceptance edge; one-cycle physical commit. Accepted writes
          // survive a later reset, as in the original non-rollback memory.
          (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg we_q=0;
          (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [WORD_AW-1:0] word_q;
          (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [7:0] data_q;
          // Native synchronous BRAM read plus a same-age external bypass.
          // A mux inside q<=...bytes[...] made this RAM infer as LUTRAM.
          (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg forward_q;
          (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [7:0] forward_data_q;
          assign rd_data[lane*8+:8]=forward_q?forward_data_q:q;
          always @(posedge clk) begin
            we_q<=wr_en&&!rst&&wr_lane==lane;
            word_q<=wr_word;data_q<=wr_data;
            if(we_q) bytes[word_q]<=data_q;
            if(rst)begin q<=0;forward_q<=0;forward_data_q<=0;end
            else if(rd_en && !(wr_en && wr_word==rd_word))begin
              q<=bytes[rd_word];forward_q<=we_q&&word_q==rd_word;forward_data_q<=data_q;
            end
          end
        end else begin: direct_write
        assign rd_data[lane*8+:8]=q;
        always @(posedge clk) begin
            if(wr_en && !rst && wr_lane==lane) bytes[wr_word]<=wr_data;
            if(rst) q<=0;
            else if(rd_en && !(wr_en && wr_word==rd_word)) q<=bytes[rd_word];
        end
        end
    end endgenerate
endmodule
