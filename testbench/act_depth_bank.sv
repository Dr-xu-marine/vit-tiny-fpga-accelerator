`timescale 1ns/1ps
module act_depth_bank(input wire clk,rst,a_enable_q,b_read_q,b_write_q,
 input wire [15:0] a_word_q,b_word_q,input wire [7:0] b_data_q,
 output wire [7:0] a_data,b_data);
 localparam WORD_AW=16;
 wire [127:0] bank_a_data,bank_b_data;localparam bank=0;
  (* ram_style="block", cascade_height=2 *) reg [7:0] bytes[0:(1<<WORD_AW)-1];reg [7:0] a_q,b_q;
  assign bank_a_data[8*bank+:8]=a_q;assign bank_b_data[8*bank+:8]=b_q;
  always @(posedge clk)begin if(rst)a_q<=0;else if(a_enable_q)a_q<=bytes[a_word_q];end
  always @(posedge clk)begin if(b_write_q)bytes[b_word_q]<=b_data_q;if(rst)b_q<=0;else if(b_read_q)b_q<=bytes[b_word_q];end
 assign a_data=a_q;assign b_data=b_q;
endmodule
