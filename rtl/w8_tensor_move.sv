// Same byte/address order and copy-loop timing; new bounded validation precedes reads.
`timescale 1ns/1ps
module w8_tensor_move #(
    parameter AW=20,parameter integer ACT_READ_LATENCY=1
)(
    input wire clk, rst, start,
    input wire [AW-1:0] src_base, dst_base,
    input wire [9:0] rows, cols,
    input wire [AW-1:0] src_row_stride, src_col_stride,
    input wire [AW-1:0] dst_row_stride, dst_col_stride,
    output wire src_re,
    output wire [AW-1:0] src_addr,
    input wire [7:0] src_rdata,
    output wire dst_we,
    output wire [AW-1:0] dst_addr,
    output wire [7:0] dst_wdata,
    output wire busy,
    output reg done, error
);
    localparam S_IDLE=0,S_ISSUE=1,S_CAPTURE=2,S_WRITE=3,S_CHECK_START=4,S_CHECK_WAIT=5,S_READ_WAIT=6;
    reg [2:0] read_wait;
    initial if(AW!=20)$error("w8_tensor_move supports AW20 only");
    reg [2:0] state;
    reg [9:0] row, col, rows_q, cols_q;
    reg [AW-1:0] src_row_q, dst_row_q, src_q, dst_q;
    reg [AW-1:0] srs_q, scs_q, drs_q, dcs_q;
    reg [7:0] data_q;

    wire check_done,check_bad;
    // Validated descriptor uses full unsigned strides, not a truncated sum.
    wire [511:0] descriptor={12'd0,drs_q,12'd0,scs_q,12'd0,srs_q,12'd0,dcs_q,128'd0,
                            32'd0,22'd0,cols_q,32'd0,22'd0,rows_q,
                            12'd0,dst_row_q,32'd0,12'd0,src_row_q,32'd7};
    w8_command_check range_check(.clk(clk),.rst(rst),.start(state==S_CHECK_START),
                            .command(descriptor),.busy(),.done(check_done),.bad(check_bad));
    assign busy = state!=S_IDLE;
    assign src_re = !rst && state==S_ISSUE;
    assign src_addr = src_q;
    assign dst_we = !rst && state==S_WRITE;
    assign dst_addr = dst_q;
    assign dst_wdata = data_q;

    always @(posedge clk) begin
        if(rst) begin
            read_wait<=0;state<=S_IDLE; done<=0; error<=0;
            row<=0; col<=0; rows_q<=0; cols_q<=0;
            src_row_q<=0; dst_row_q<=0; src_q<=0; dst_q<=0;
            srs_q<=0; scs_q<=0; drs_q<=0; dcs_q<=0; data_q<=0;
        end else begin
            done<=0; error<=0;
            case(state)
                S_IDLE: if(start) begin
                    begin
                        rows_q<=rows; cols_q<=cols; row<=0; col<=0;
                        src_row_q<=src_base; dst_row_q<=dst_base;
                        src_q<=src_base; dst_q<=dst_base;
                        srs_q<=src_row_stride; scs_q<=src_col_stride;
                        drs_q<=dst_row_stride; dcs_q<=dst_col_stride;
                        state<=S_CHECK_START;
                    end
                end
                S_CHECK_START:state<=S_CHECK_WAIT;
                S_CHECK_WAIT:if(check_done)begin
                    if(check_bad)begin state<=S_IDLE;done<=1;error<=1;end
                    else state<=S_ISSUE;
                end
                S_ISSUE: if(ACT_READ_LATENCY==1)state<=S_CAPTURE;else begin read_wait<=ACT_READ_LATENCY-1;state<=S_READ_WAIT;end
                S_READ_WAIT:if(read_wait==1)state<=S_CAPTURE;else read_wait<=read_wait-1'b1;
                S_CAPTURE: begin data_q<=src_rdata; state<=S_WRITE; end
                S_WRITE: begin
                    if(col==cols_q-1'b1) begin
                        col<=0;
                        if(row==rows_q-1'b1) begin state<=S_IDLE; done<=1; end
                        else begin
                            row<=row+1'b1;
                            src_row_q<=src_row_q+srs_q; dst_row_q<=dst_row_q+drs_q;
                            src_q<=src_row_q+srs_q; dst_q<=dst_row_q+drs_q;
                            state<=S_ISSUE;
                        end
                    end else begin
                        col<=col+1'b1; src_q<=src_q+scs_q; dst_q<=dst_q+dcs_q;
                        state<=S_ISSUE;
                    end
                end
                default: begin state<=S_IDLE; done<=1; error<=1; end
            endcase
        end
    end
endmodule
