`timescale 1ns/1ps

// Experimental single-PE C0 only. Does not modify the accepted PE or V4 rules.
// FAULT: 0=normal, 1=CEP follows take, 2=zero extension, 3=stale replay,
//        4=drop drain commits, 5=P ignores flush, 6=product-only OPMODE.
module v2_c0_mac_cell #(
    parameter integer FAULT = 0
) (
    input wire clk,
    input wire rst,
    input wire flush,
    input wire take,
    input wire signed [7:0] a,
    input wire signed [7:0] b,
    output wire signed [47:0] p,
    output reg commit_valid
);
    wire clear = rst | flush;
    reg v_ab;
    reg v_m;

    // This stable RTL name is available to experimental fault-injection TBs.
    // The registered commit_valid is a POST-edge observation of this enable.
    wire cep_enable = (FAULT == 1) ? take :
                      (FAULT == 3) ? (v_m | commit_valid) :
                      (FAULT == 4) ? (v_m & take) : v_m;
    wire p_clear = (FAULT == 5) ? rst : clear;
    wire [29:0] a_dsp = (FAULT == 2) ? {22'b0, a} : {{22{a[7]}}, a};
    wire [17:0] b_dsp = (FAULT == 2) ? {10'b0, b} : {{10{b[7]}}, b};
    wire [8:0] opmode = (FAULT == 6) ? 9'b000000101 : 9'b000100101;

    always @(posedge clk) begin
        if (clear) begin
            v_ab <= 1'b0;
            v_m <= 1'b0;
            commit_valid <= 1'b0;
        end else begin
            v_ab <= take;
            v_m <= v_ab;
            commit_valid <= cep_enable;
        end
    end

    // A/B at e0, M at e1, P at e2. The internal P register is the sole
    // accumulator state; C is not an external feedback or a second state FF.
    DSP48E2 #(
        .ACASCREG(1), .ADREG(0), .ALUMODEREG(0),
        .AMULTSEL("A"), .AREG(1),
        .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
        .A_INPUT("DIRECT"), .BCASCREG(1), .BMULTSEL("B"),
        .BREG(1), .B_INPUT("DIRECT"),
        .CARRYINREG(0), .CARRYINSELREG(0), .CREG(0), .DREG(0),
        .INMODEREG(0), .MREG(1), .OPMODEREG(0),
        .PREADDINSEL("A"), .PREG(1), .RND(48'b0),
        .MASK(48'hffffffffffff), .PATTERN(48'b0),
        .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
        .USE_MULT("MULTIPLY"), .USE_PATTERN_DETECT("NO_PATDET"),
        .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
        .XORSIMD("XOR24_48_96"),
        .IS_ALUMODE_INVERTED(4'b0), .IS_CARRYIN_INVERTED(1'b0),
        .IS_CLK_INVERTED(1'b0), .IS_INMODE_INVERTED(5'b0),
        .IS_OPMODE_INVERTED(9'b0),
        .IS_RSTALLCARRYIN_INVERTED(1'b0), .IS_RSTALUMODE_INVERTED(1'b0),
        .IS_RSTA_INVERTED(1'b0), .IS_RSTB_INVERTED(1'b0),
        .IS_RSTCTRL_INVERTED(1'b0), .IS_RSTC_INVERTED(1'b0),
        .IS_RSTD_INVERTED(1'b0), .IS_RSTINMODE_INVERTED(1'b0),
        .IS_RSTM_INVERTED(1'b0), .IS_RSTP_INVERTED(1'b0)
    ) u_dsp (
        .CLK(clk), .A(a_dsp), .B(b_dsp), .C(48'b0), .D(27'b0),
        .ACIN(30'b0), .BCIN(18'b0), .PCIN(48'b0),
        .ALUMODE(4'b0000), .INMODE(5'b00000), .OPMODE(opmode),
        .CARRYINSEL(3'b000), .CARRYIN(1'b0),
        .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0),
        .CEA1(1'b0), .CEA2(take), .CEB1(1'b0), .CEB2(take),
        .CEM(v_ab), .CEP(cep_enable),
        .CEAD(1'b0), .CEALUMODE(1'b0), .CEC(1'b0),
        .CECARRYIN(1'b0), .CECTRL(1'b0), .CED(1'b0), .CEINMODE(1'b0),
        .RSTA(clear), .RSTB(clear), .RSTM(clear), .RSTP(p_clear),
        .RSTALLCARRYIN(clear), .RSTALUMODE(clear), .RSTC(clear),
        .RSTCTRL(clear), .RSTD(clear), .RSTINMODE(clear),
        .P(p), .ACOUT(), .BCOUT(), .CARRYCASCOUT(), .CARRYOUT(),
        .MULTSIGNOUT(), .OVERFLOW(), .PATTERNBDETECT(),
        .PATTERNDETECT(), .PCOUT(), .UNDERFLOW(), .XOROUT()
    );
endmodule
