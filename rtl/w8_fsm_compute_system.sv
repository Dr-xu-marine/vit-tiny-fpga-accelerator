// B1: algorithm FSM + original 16-lane compute/AXI loader. No task ROM.
// Physical DDR and clock crossing remain external.
`timescale 1ns/1ps
module w8_fsm_compute_system #(
    parameter PARAM_DIR="data/package",parameter PROGRAM_FILE="data/package/program.hex",parameter integer INSTRUCTIONS=16384,
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
    wire cmd_valid,cmd_ready,cmd_done,cmd_error,compute_busy;
    wire sequencer_rst=USE_RESET_BRANCHES?reset_branches[0]:rst;
    wire [511:0] cmd_data;
    wire load_start,load_ready,load_done,load_error,load_busy;
    wire [30:0] load_src_addr;
    wire [23:0] load_nbytes,load_local_offset;
    wire [3:0] load_target;
    wire read_ready;
    // Block host reads over the entire job, including gaps between instructions
    // and the same edge which accepts start. No host port owns active ACT RAM.
    wire host_allowed=!rst && !busy && !start;
    assign host_read_ready=host_allowed && read_ready;
    w8_program_sequencer #(.PROGRAM_FILE(PROGRAM_FILE),.INSTRUCTIONS(INSTRUCTIONS)) sequencer(
        .clk(clk),.rst(sequencer_rst),.start(start),
        .busy(busy),.done(done),.error(error),
        .cmd_valid(cmd_valid),.cmd_data(cmd_data),.cmd_ready(cmd_ready),.cmd_done(cmd_done),.cmd_error(cmd_error),
        .load_start(load_start),.load_src_addr(load_src_addr),.load_nbytes(load_nbytes),.load_local_offset(load_local_offset),.load_target(load_target),
        .load_ready(load_ready),.load_done(load_done),.load_error(load_error),
        .retired_instructions(retired_instructions),.completed_commands(completed_commands),.completed_loads(completed_loads));
    w8_compute_system #(.ID_WIDTH(ID_WIDTH),.USE_RESET_BRANCHES(USE_RESET_BRANCHES)) system_unit(
        .clk(clk),.rst(rst),.reset_branches(reset_branches),.cmd_valid(cmd_valid),.cmd_data(cmd_data),.cmd_ready(cmd_ready),.busy(compute_busy),.done(cmd_done),.error(cmd_error),
        .load_start(load_start),.load_src_addr(load_src_addr),.load_nbytes(load_nbytes),.load_local_offset(load_local_offset),.load_target(load_target),
        .load_ready(load_ready),.load_busy(load_busy),.load_done(load_done),.load_error(load_error),
        .host_read_req(host_read_req && host_allowed),.host_read_addr(host_read_addr),.host_read_ready(read_ready),
        .host_read_data(host_read_data),.host_read_valid(host_read_valid),.host_read_error(host_read_error),
        .m_axi_arid(m_axi_arid),.m_axi_araddr(m_axi_araddr),.m_axi_arlen(m_axi_arlen),.m_axi_arsize(m_axi_arsize),.m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),.m_axi_arready(m_axi_arready),.m_axi_rid(m_axi_rid),.m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),.m_axi_rlast(m_axi_rlast),.m_axi_rvalid(m_axi_rvalid),.m_axi_rready(m_axi_rready));
endmodule
