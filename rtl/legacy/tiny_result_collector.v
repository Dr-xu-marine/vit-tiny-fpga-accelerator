// Copy completed logits through the real host port; cache32 and first-index argmax.
`timescale 1ns/1ps
module tiny_result_collector #(
    parameter integer COUNT=1000,
    parameter [23:0] BASE=24'h084000
)(
    input wire clk,rst,start,
    output wire busy,
    output reg done,error,result_valid,
    output wire read_req,
    output wire [23:0] read_addr,
    input wire read_ready,read_valid,read_error,
    input wire [7:0] read_data,
    output reg [9:0] top1,
    output reg signed [7:0] max_logit,
    input wire cache_re,
    input wire [7:0] cache_addr,
    output reg [31:0] cache_data,
    output reg cache_valid,cache_error
);
    localparam IDLE=0,ISSUE=1,WAIT_DATA=2;
    reg [1:0] state;
    reg [9:0] index;
    reg [31:0] packed_word;
    (* ram_style="block" *) reg [31:0] cache[0:(COUNT+3)/4-1];
    wire [31:0] merged=(packed_word & ~(32'hff<<(8*index[1:0]))) | ({24'b0,read_data}<<(8*index[1:0]));
    assign busy=!rst && state!=IDLE;
    assign read_req=!rst && state==ISSUE;
    assign read_addr=BASE+index;
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;index<=0;packed_word<=0;done<=0;error<=0;result_valid<=0;
            top1<=0;max_logit<=8'sh80;cache_valid<=0;cache_error<=0;cache_data<=0;
        end else begin
            done<=0;cache_valid<=0;cache_error<=0;
            if(cache_re) begin
                if(result_valid && !busy && !start && cache_addr<(COUNT+3)/4) begin cache_data<=cache[cache_addr];cache_valid<=1;end
                else cache_error<=1;
            end
            case(state)
                IDLE:if(start) begin index<=0;packed_word<=0;error<=0;result_valid<=0;top1<=0;max_logit<=8'sh80;state<=ISSUE;end
                ISSUE:if(read_ready) state<=WAIT_DATA;
                WAIT_DATA:if(read_error) begin error<=1;done<=1;state<=IDLE;end
                    else if(read_valid) begin
                        if(index==0 || $signed(read_data)>max_logit) begin max_logit<=$signed(read_data);top1<=index;end
                        if(index[1:0]==3 || index==COUNT-1) begin cache[index>>2]<=merged;packed_word<=0;end
                        else packed_word<=merged;
                        if(index==COUNT-1) begin done<=1;result_valid<=1;state<=IDLE;end
                        else begin index<=index+1'b1;state<=ISSUE;end
                    end
                default:begin error<=1;done<=1;state<=IDLE;end
            endcase
        end
    end
`ifndef SYNTHESIS
    initial if(COUNT<1 || COUNT>1000 || BASE+COUNT>1048576) $fatal(1,"RESULT_ERROR invalid extent");
    always @(posedge clk) if(!rst && state==WAIT_DATA && read_valid && ^read_data===1'bx)
        $fatal(1,"RESULT_ERROR unknown input");
`endif
endmodule
