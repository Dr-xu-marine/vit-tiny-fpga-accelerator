`timescale 1ns/1ps
// Internal-source/sink physical test, not a board or external-I/O acceptance.
module act_depth_platform(input wire sys_clk_p,sys_clk_n);
 wire ci,cf,fb,mc,clk,locked;
 IBUFDS #(.DIFF_TERM("FALSE"),.IBUF_LOW_PWR("FALSE")) ib(.I(sys_clk_p),.IB(sys_clk_n),.O(ci));
 MMCME4_BASE #(.CLKIN1_PERIOD(4.0),.DIVCLK_DIVIDE(1),.CLKFBOUT_MULT_F(4.0),.CLKOUT0_DIVIDE_F(5.0)) mm
 (.CLKIN1(ci),.CLKFBIN(fb),.CLKFBOUT(cf),.CLKOUT0(mc),.LOCKED(locked),.RST(1'b0),.PWRDWN(1'b0));
 BUFG feedback(.I(cf),.O(fb));BUFG compute_clock(.I(mc),.O(clk));
 // No unconstrained observation port: dynamic, kept register sources/sinks.
 // This is a timing probe, not a runtime board self-test or error detector.
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg [15:0] address=0;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg [31:0] random_q=32'h6789abcd;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg [15:0] a_word_q,b_word_q;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg [7:0] b_data_q;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg a_enable_q=0,b_read_q=0,b_write_q=0;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg [2:0] startup=0;
 wire rst=!startup[2];wire [7:0] a_data,b_data,weight_data,param_data;wire wp,pp;
 always @(posedge clk)begin
  startup<={startup[1:0],1'b1};address<=address+1;
  random_q<={random_q[30:0],random_q[31]^random_q[21]^random_q[1]^random_q[0]};
  a_word_q<=address^16'h6349;b_word_q<=address;b_data_q<=random_q[7:0];
  a_enable_q<=random_q[0];b_read_q<=random_q[1];b_write_q<=!random_q[1];
 end
 (* KEEP_HIERARCHY="TRUE" *)act_depth_bank bank(clk,rst,a_enable_q,b_read_q,b_write_q,a_word_q,b_word_q,b_data_q,a_data,b_data);
 // One full-depth production Weight bank and one production parameter bank.
 // This checks real inference/forwarding, not the board-wide broadcast span.
 (* KEEP_HIERARCHY="TRUE" *)tiny_compute_byte_banks #(.WORD_AW(16),.BYTE_LANES(1),.LOCAL_WRITE_PIPE(1)) weight_bank
 (.clk(clk),.rst(rst),.wr_en(b_write_q),.wr_word(b_word_q),.wr_lane({5'd0,random_q[3]}),.wr_data(b_data_q),.rd_en(a_enable_q),.rd_word(a_word_q),.rd_data(weight_data),.write_pending(wp));
 (* KEEP_HIERARCHY="TRUE" *)w8_upload_ram #(.AW(16),.LANES(1),.STRIDE(2)) param_bank
 (.clk(clk),.rst(rst),.we(b_write_q),.byte_addr({6'd0,b_word_q,2'd0}),.byte_data(b_data_q),.re(a_enable_q),.word_addr(a_word_q),.data(param_data),.write_pending(pp));
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg [7:0] a_sink,b_sink,weight_sink,param_sink;
 (* KEEP="TRUE",DONT_TOUCH="TRUE" *)reg [1:0] pending_sink;
 always @(posedge clk)begin a_sink<=a_data;b_sink<=b_data;weight_sink<=weight_data;param_sink<=param_data;pending_sink<={wp,pp};end
endmodule
