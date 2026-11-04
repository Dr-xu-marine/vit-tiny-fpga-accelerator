`include "w8_program_meta.vh"
// Private full128 board wrapper. Compute source set is bound separately.
// Board-facing AXI-Lite control/result port + autonomous read-only AXI engine.
// All interfaces use clk. Platform interconnect performs the DDR clock crossing.
`timescale 1ns/1ps
module w8_hosted_core #(
    parameter integer COMPUTE_HZ=200000000,
    parameter integer INSTRUCTIONS=`W8_INSTRUCTIONS,
    parameter PROGRAM_FILE="data/package/program.hex",
    parameter PARAM_DIR="data/package",
    parameter integer RESULT_COUNT=1000,
    parameter [23:0] RESULT_BASE=24'h084000
)(
    (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER="ASSOCIATED_BUSIF S_AXI:M_AXI, ASSOCIATED_RESET aresetn" *) input wire clk,
    (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 aresetn RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *) input wire aresetn,
    input wire calibrated_async,
    output wire busy_out,done_out,error_out,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWADDR", X_INTERFACE_PARAMETER="PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 32, READ_WRITE_MODE READ_WRITE" *) input wire [31:0] s_axi_awaddr,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *) input wire s_axi_awvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *) output wire s_axi_awready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WDATA" *) input wire [31:0] s_axi_wdata,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *) input wire [3:0] s_axi_wstrb,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WVALID" *) input wire s_axi_wvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WREADY" *) output wire s_axi_wready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BRESP" *) output wire [1:0] s_axi_bresp,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BVALID" *) output wire s_axi_bvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BREADY" *) input wire s_axi_bready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *) input wire [31:0] s_axi_araddr,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *) input wire s_axi_arvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *) output wire s_axi_arready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RDATA" *) output wire [31:0] s_axi_rdata,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RRESP" *) output wire [1:0] s_axi_rresp,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RVALID" *) output wire s_axi_rvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RREADY" *) input wire s_axi_rready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARID" *) output wire [0:0] m_axi_arid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARADDR", X_INTERFACE_PARAMETER="PROTOCOL AXI4, DATA_WIDTH 512, ADDR_WIDTH 31, ID_WIDTH 1, READ_WRITE_MODE READ_ONLY, MAX_BURST_LENGTH 16" *) output wire [30:0] m_axi_araddr,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARLEN" *) output wire [7:0] m_axi_arlen,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARSIZE" *) output wire [2:0] m_axi_arsize,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARBURST" *) output wire [1:0] m_axi_arburst,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARVALID" *) output wire m_axi_arvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI ARREADY" *) input wire m_axi_arready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RID" *) input wire [0:0] m_axi_rid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RDATA" *) input wire [511:0] m_axi_rdata,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RRESP" *) input wire [1:0] m_axi_rresp,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RLAST" *) input wire m_axi_rlast,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RVALID" *) input wire m_axi_rvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 M_AXI RREADY" *) output wire m_axi_rready
);
    wire rst=!aresetn;
    (* ASYNC_REG="TRUE" *) reg [1:0] calibrated_q;
    always @(posedge clk) if(rst) calibrated_q<=0;else calibrated_q<={calibrated_q[0],calibrated_async};
    wire start_pulse,idle_reset_pulse,core_busy,core_done,core_error,collect_busy,collect_done,collect_error,result_valid;
    wire core_rst=rst || idle_reset_pulse;
    wire [5:0] idle_reset_copies;wire [4:0] reset_branches= {5{rst}}|idle_reset_copies[4:0];
    wire host_req,host_ready,host_valid,host_error;
    wire [23:0] host_addr;
    wire [7:0] host_data;
    wire [15:0] retired,commands,loads;
    wire [9:0] top1;
    wire signed [7:0] max_logit;
    wire cache_re,cache_valid,cache_error;
    wire [7:0] cache_addr;
    wire [31:0] cache_data;
    reg done_sticky,error_sticky;
    reg [63:0] live_job_cycles,live_core_cycles,job_cycles,core_cycles;
    assign busy_out=core_busy || collect_busy || start_pulse || core_done;
    assign done_out=done_sticky;
    assign error_out=error_sticky;
    always @(posedge clk) begin
        if(rst || idle_reset_pulse || start_pulse) begin
            done_sticky<=0;error_sticky<=0;live_job_cycles<=0;live_core_cycles<=0;job_cycles<=0;core_cycles<=0;
        end else begin
            if(busy_out) live_job_cycles<=live_job_cycles+1'b1;
            if(core_busy) live_core_cycles<=live_core_cycles+1'b1;
            if(core_done) begin
                core_cycles<=live_core_cycles;
                if(core_error) begin done_sticky<=1;error_sticky<=1;job_cycles<=live_job_cycles;end
            end
            if(collect_done) begin done_sticky<=1;error_sticky<=collect_error;job_cycles<=live_job_cycles;end
        end
    end
    tiny_axi_lite_control_v128 #(.COMPUTE_HZ(COMPUTE_HZ),.RESULT_COUNT(RESULT_COUNT),.INSTRUCTIONS(INSTRUCTIONS)) control(
        .clk(clk),.rst(rst),
        .s_axi_awaddr(s_axi_awaddr),.s_axi_awvalid(s_axi_awvalid),.s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),.s_axi_wstrb(s_axi_wstrb),.s_axi_wvalid(s_axi_wvalid),.s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),.s_axi_bvalid(s_axi_bvalid),.s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),.s_axi_arvalid(s_axi_arvalid),.s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),.s_axi_rresp(s_axi_rresp),.s_axi_rvalid(s_axi_rvalid),.s_axi_rready(s_axi_rready),
        .busy(busy_out),.job_done(done_sticky),.job_error(error_sticky),.calibrated(calibrated_q[1]),.result_valid(result_valid),
        .top1(top1),.max_logit(max_logit),.job_cycles(job_cycles),.core_cycles(core_cycles),
        .retired(retired),.commands(commands),.loads(loads),.start_pulse(start_pulse),.idle_reset_pulse(idle_reset_pulse),.idle_reset_copies(idle_reset_copies),
        .cache_re(cache_re),.cache_addr(cache_addr),.cache_data(cache_data),.cache_valid(cache_valid),.cache_error(cache_error));
    w8_inference_core #(.INSTRUCTIONS(INSTRUCTIONS),.PROGRAM_FILE(PROGRAM_FILE),.PARAM_DIR(PARAM_DIR),.ID_WIDTH(1),.USE_RESET_BRANCHES(1)) engine(
        .clk(clk),.rst(core_rst),.reset_branches(reset_branches),.start(start_pulse),.busy(core_busy),.done(core_done),.error(core_error),
        .retired_instructions(retired),.completed_commands(commands),.completed_loads(loads),
        .host_read_req(host_req),.host_read_addr(host_addr),.host_read_ready(host_ready),.host_read_data(host_data),.host_read_valid(host_valid),.host_read_error(host_error),
        .m_axi_arid(m_axi_arid),.m_axi_araddr(m_axi_araddr),.m_axi_arlen(m_axi_arlen),.m_axi_arsize(m_axi_arsize),.m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),.m_axi_arready(m_axi_arready),.m_axi_rid(m_axi_rid),.m_axi_rdata(m_axi_rdata),.m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),.m_axi_rvalid(m_axi_rvalid),.m_axi_rready(m_axi_rready));
    tiny_result_collector #(.COUNT(RESULT_COUNT),.BASE(RESULT_BASE)) collector(
        .clk(clk),.rst(rst || idle_reset_copies[5] || start_pulse),.start(core_done && !core_error),.busy(collect_busy),.done(collect_done),.error(collect_error),.result_valid(result_valid),
        .read_req(host_req),.read_addr(host_addr),.read_ready(host_ready),.read_data(host_data),.read_valid(host_valid),.read_error(host_error),
        .top1(top1),.max_logit(max_logit),.cache_re(cache_re),.cache_addr(cache_addr),.cache_data(cache_data),.cache_valid(cache_valid),.cache_error(cache_error));
endmodule
