// B1 autonomous FSM core. External AXI memory must contain the matching
// frozen package. RGB preprocessing and physical DDR controller are external.
`timescale 1ns/1ps
module w8_inference_core #(
    // Compatibility status metadata only; there is no instruction memory.
    parameter integer INSTRUCTIONS=17432,
    parameter PARAM_DIR="assets/fsm_v4_parameters",
    parameter PROGRAM_FILE="program.hex",
    parameter integer USE_RESET_BRANCHES=0,parameter integer ID_WIDTH=4
)(
    input wire clk,rst,start,input wire [4:0] reset_branches,
    output wire busy,done,error,
    output wire [15:0] retired_instructions,completed_commands,completed_loads,
    input wire host_read_req,
    input wire [23:0] host_read_addr,
    output wire host_read_ready,
    output wire [7:0] host_read_data,
    output wire host_read_valid,host_read_error,
    output wire [ID_WIDTH-1:0] m_axi_arid,
    output wire [30:0] m_axi_araddr,
    output wire [7:0] m_axi_arlen,
    output wire [2:0] m_axi_arsize,
    output wire [1:0] m_axi_arburst,
    output wire m_axi_arvalid,
    input wire m_axi_arready,
    input wire [ID_WIDTH-1:0] m_axi_rid,
    input wire [511:0] m_axi_rdata,
    input wire [1:0] m_axi_rresp,
    input wire m_axi_rlast,m_axi_rvalid,
    output wire m_axi_rready
);
    w8_fsm_compute_system #(.USE_RESET_BRANCHES(USE_RESET_BRANCHES),.ID_WIDTH(ID_WIDTH),.PARAM_DIR(PARAM_DIR),.PROGRAM_FILE(PROGRAM_FILE),.INSTRUCTIONS(INSTRUCTIONS)) compute(
        .clk(clk),.rst(rst),.reset_branches(reset_branches),.start(start),.busy(busy),.done(done),.error(error),
        .retired_instructions(retired_instructions),.completed_commands(completed_commands),.completed_loads(completed_loads),
        .host_read_req(host_read_req),.host_read_addr(host_read_addr),.host_read_ready(host_read_ready),
        .host_read_data(host_read_data),.host_read_valid(host_read_valid),.host_read_error(host_read_error),
        .m_axi_arid(m_axi_arid),.m_axi_araddr(m_axi_araddr),.m_axi_arlen(m_axi_arlen),.m_axi_arsize(m_axi_arsize),.m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),.m_axi_arready(m_axi_arready),.m_axi_rid(m_axi_rid),.m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),.m_axi_rlast(m_axi_rlast),.m_axi_rvalid(m_axi_rvalid),.m_axi_rready(m_axi_rready));
endmodule
