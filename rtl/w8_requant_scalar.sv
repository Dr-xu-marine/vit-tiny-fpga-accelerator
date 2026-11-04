`timescale 1ns/1ps
module w8_requant_scalar #(
    parameter integer TAG_WIDTH = 16
) (
    input  wire clk,
    input  wire rst,
    input  wire ce,
    input  wire in_valid,
    input  wire signed [31:0] in_acc,
    input  wire signed [31:0] in_bias_corr,
    input  wire [30:0] in_multiplier,
    input  wire [5:0] in_shift,
    input  wire signed [15:0] in_zero_point,
    input  wire in_int8,
    input  wire in_last,
    input  wire [TAG_WIDTH-1:0] in_tag,
    input  wire in_overflow,
    output wire out_valid,
    output wire signed [15:0] out_data,
    output wire out_int8,
    output wire out_last,
    output wire [TAG_WIDTH-1:0] out_tag,
    output wire out_saturated,
    output wire [2:0] out_error
);
    typedef struct packed {
        logic signed [15:0] zp;
        logic [5:0] shift;
        logic int8_mode;
        logic last;
        logic [TAG_WIDTH-1:0] tag;
        logic [2:0] error;
    } metadata_t;
    metadata_t meta [0:11];
    reg [11:0] valid;
    reg signed [32:0] sum0;
    reg [30:0] multiplier0;
    (* use_dsp = "yes" *) reg [33:0] p00_1;
    (* use_dsp = "yes" *) reg [30:0] p01_1;
    (* use_dsp = "yes" *) reg signed [33:0] p10_1;
    (* use_dsp = "yes" *) reg signed [30:0] p11_1;
    reg [47:0] low2;
    reg signed [47:0] high2;
    reg signed [63:0] product3;
    reg [63:0] magnitude4;
    reg negative4;
    // Coarse byte selection, then fine bit selection, then RNE decision.
    reg [63:0] coarse5,quotient6,quotient7;
    reg [7:0] tail5,below_guard5,guard5;
    reg negative5,negative6,negative7,negative8,guard6,sticky6,increment7;
    reg [63:0] rounded8;
    reg signed [64:0] signed9;
    reg signed [65:0] shifted10;
    reg signed [15:0] data11;
    reg saturated11;

    wire signed [32:0] input_sum = $signed({in_acc[31],in_acc}) +
                                        $signed({in_bias_corr[31],in_bias_corr});
    wire [2:0] input_error = {
        (in_shift == 6'd63) || (in_int8 && ((in_zero_point < -16'sd128) || (in_zero_point > 16'sd127))),
        input_sum[32] != input_sum[31],
        in_overflow
    };

    wire [63:0] fine_quotient=coarse5 >> meta[5].shift[2:0];
    reg fine_guard,fine_sticky;
    always @* begin
        fine_guard=0;fine_sticky=0;
        case(meta[5].shift[2:0])
          3'd1:begin fine_guard=coarse5[0];fine_sticky=1'b0;end
          3'd2:begin fine_guard=coarse5[1];fine_sticky=|coarse5[0:0];end
          3'd3:begin fine_guard=coarse5[2];fine_sticky=|coarse5[1:0];end
          3'd4:begin fine_guard=coarse5[3];fine_sticky=|coarse5[2:0];end
          3'd5:begin fine_guard=coarse5[4];fine_sticky=|coarse5[3:0];end
          3'd6:begin fine_guard=coarse5[5];fine_sticky=|coarse5[4:0];end
          3'd7:begin fine_guard=coarse5[6];fine_sticky=|coarse5[5:0];end
          default:;
        endcase
    end

    assign out_valid = valid[11];
    assign out_data = data11;
    assign out_saturated = saturated11;
    assign out_int8 = meta[11].int8_mode;
    assign out_last = meta[11].last;
    assign out_tag = meta[11].tag;
    assign out_error = meta[11].error;

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            valid <= 12'd0;
            for (i=0;i<12;i=i+1) meta[i] <= '0;
            sum0 <= 33'sd0;
            multiplier0 <= 31'd0;
            p00_1 <= 34'd0;
            p01_1 <= 31'd0;
            p10_1 <= 34'sd0;
            p11_1 <= 31'sd0;
            low2 <= 48'd0;
            high2 <= 48'sd0;
            product3 <= 64'sd0;
            magnitude4 <= 64'd0;
            negative4 <= 1'b0;
            coarse5<=0;quotient6<=0;quotient7<=0;tail5<=0;below_guard5<=0;guard5<=0;
            negative5<=0;negative6<=0;negative7<=0;negative8<=0;guard6<=0;sticky6<=0;increment7<=0;
            rounded8<=0;signed9<=0;shifted10<=0;data11<=0;saturated11<=0;
        end else if (ce) begin
            valid <= {valid[10:0],in_valid};
            // Invalid metadata is unobserved by contract. Removing per-bit valid
            // MUXes avoids broadcasting a valid signal over128-bit tags each stage.
            meta[0] <= {in_zero_point,in_shift,in_int8,in_last,in_tag,input_error};
            for (i=1;i<12;i=i+1) meta[i] <= meta[i-1];
            sum0 <= in_valid ? input_sum : 33'sd0;
            multiplier0 <= in_valid ? in_multiplier : 31'd0;

            // sum = low17_unsigned + high16_signed * 2**17.
            // M   = low17_unsigned + high14_unsigned * 2**17.
            p00_1 <= valid[0] ? ($unsigned(sum0[16:0]) * $unsigned(multiplier0[16:0])) : 34'd0;
            p01_1 <= valid[0] ? ($unsigned(sum0[16:0]) * $unsigned(multiplier0[30:17])) : 31'd0;
            p10_1 <= valid[0] ? ($signed(sum0[32:17]) * $signed({1'b0,multiplier0[16:0]})) : 34'sd0;
            p11_1 <= valid[0] ? ($signed(sum0[32:17]) * $signed({1'b0,multiplier0[30:17]})) : 31'sd0;

            low2 <= valid[1] ? ({14'd0,p00_1} + ({17'd0,p01_1} << 17)) : 48'd0;
            high2 <= valid[1] ? ($signed({{14{p10_1[33]}},p10_1}) +
                                 ($signed({{17{p11_1[30]}},p11_1}) <<< 17)) : 48'sd0;
            product3 <= valid[2] ? ($signed({16'd0,low2}) +
                                      ($signed({{16{high2[47]}},high2}) <<< 17)) : 64'sd0;
            magnitude4 <= valid[3] ? (product3[63] ? (~$unsigned(product3)+64'd1) : $unsigned(product3)) : 64'd0;
            negative4 <= valid[3] ? product3[63] : 1'b0;
            coarse5 <= magnitude4 >> {meta[4].shift[5:3],3'b000};
            tail5[0]<=0;below_guard5[0]<=0;guard5[0]<=0;
            tail5[1]<=|magnitude4[7:0];below_guard5[1]<=|magnitude4[6:0];guard5[1]<=magnitude4[7];
            tail5[2]<=|magnitude4[15:0];below_guard5[2]<=|magnitude4[14:0];guard5[2]<=magnitude4[15];
            tail5[3]<=|magnitude4[23:0];below_guard5[3]<=|magnitude4[22:0];guard5[3]<=magnitude4[23];
            tail5[4]<=|magnitude4[31:0];below_guard5[4]<=|magnitude4[30:0];guard5[4]<=magnitude4[31];
            tail5[5]<=|magnitude4[39:0];below_guard5[5]<=|magnitude4[38:0];guard5[5]<=magnitude4[39];
            tail5[6]<=|magnitude4[47:0];below_guard5[6]<=|magnitude4[46:0];guard5[6]<=magnitude4[47];
            tail5[7]<=|magnitude4[55:0];below_guard5[7]<=|magnitude4[54:0];guard5[7]<=magnitude4[55];
            negative5 <= negative4;
            quotient6 <= fine_quotient;negative6<=negative5;
            guard6 <= (meta[5].shift[2:0]==0)?guard5[meta[5].shift[5:3]]:fine_guard;
            sticky6 <= (meta[5].shift[2:0]==0)?below_guard5[meta[5].shift[5:3]]:(tail5[meta[5].shift[5:3]]|fine_sticky);
            quotient7<=quotient6;negative7<=negative6;
            increment7<=guard6&&(sticky6||quotient6[0]);
            rounded8<=quotient7+{63'd0,increment7};negative8<=negative7;
            signed9<=negative8?-$signed({1'b0,rounded8}):$signed({1'b0,rounded8});
            shifted10<=$signed({signed9[64],signed9})+$signed({{50{meta[9].zp[15]}},meta[9].zp});
            data11<=0;saturated11<=0;
            if(valid[10] && meta[10].error==0)begin
                if(meta[10].int8_mode)begin
                    if(shifted10>66'sd127)begin data11<=16'sd127;saturated11<=1;end
                    else if(shifted10< -66'sd128)begin data11<=-16'sd128;saturated11<=1;end
                    else data11<=shifted10[15:0];
                end else begin
                    if(shifted10>66'sd32767)begin data11<=16'sd32767;saturated11<=1;end
                    else if(shifted10< -66'sd32768)begin data11<=-16'sd32768;saturated11<=1;end
                    else data11<=shifted10[15:0];
                end
            end
        end
    end
endmodule
