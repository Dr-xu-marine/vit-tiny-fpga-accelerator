`timescale 1ns/1ps
// R2 private complete GEMM. Fixed one-cycle W/Bias/RQ/LB read memories.
// A and WB are real ready/valid transactions. Reset/flush cancels BOTH ends
// of the A transport; no response from before that barrier may be delivered.
// Exactly one A request outstanding; response tag must equal accepted tag.
// WB transfer atomically commits masked ACT bytes and requested LB/PACK views.
// Zero-keep padded rows are legal transfers with no memory side effect.
module w8_gemm128 #(
 parameter AW=20,CNTW=12,WAW=16,BAW=6,LBW=14,QKW=8,RQAW=14,
 parameter FAULT=0
)(
 input wire clk,rst,flush,start,
 output wire start_ready,
 input wire [AW-1:0] a_base,out_base,
 input wire [CNTW-1:0] n_rows,k_dim,n_out,
 input wire b_is_laneram,pack_row,pack_lb,bias_en,
 input wire raw_mode,dynamic_zp,input wire signed [7:0] input_zp,
 output wire wb_raw,output wire [511:0] wb_raw_data,
 input wire [63:0] job_tag,
 output wire a_req_valid,input wire a_req_ready,
 output wire [AW-1:0] a_req_addr,
 output wire [15:0] a_req_keep,a_req_tag,
 input wire a_rsp_valid,output wire a_rsp_ready,
 input wire [127:0] a_rsp_data,input wire [15:0] a_rsp_keep,a_rsp_tag,
 input wire a_rsp_error,
 output wire [WAW-1:0] wrom_addr,input wire [127:0] wrom_rdata,
 output wire [BAW-1:0] bias_addr,input wire [511:0] bias_rdata,
 output wire [RQAW-1:0] rq_addr,input wire [719:0] rq_rdata,
 output wire [LBW-1:0] lb_read_addr,input wire [127:0] lb_rdata,
 output wire wb_valid,input wire wb_ready,
 output wire [AW-1:0] wb_addr,output wire [127:0] wb_data,wb_tag,
 output wire [15:0] wb_keep,output wire wb_last,
 output wire wb_pack_row,wb_pack_lb,
 output wire [QKW-1:0] wb_pack_addr,output wire [LBW-1:0] wb_lb_addr,
 output wire busy,output reg done,error_valid,output reg [7:0] error_code
);
    localparam IDLE=0,CFG_INIT=1,CFG_MUL=2,CFG_SUM=3,CFG_CHECK=4,
        A_REQUEST=5,A_RESPONSE=6,TILE_PREP=7,FILL=8,FILL_DRAIN=9,
        BIAS_REQ=10,BIAS_CAPTURE=11,BIAS_WRITE=12,RQ_REQ=13,RQ_CAPTURE=14,
        START_TILE=15,WAIT_ROW=16,WB_HOLD=17,FINISH_TILE=18,ABORT=19,CHECK_ROW=20;
    reg [4:0] state;
    (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg tile_abort_q;
    wire clear=rst|flush;
    reg [AW-1:0] a_base_q,out_base_q;
    reg [CNTW-1:0] cfg_rows_q,cfg_k_q,cfg_n_q;
    reg [63:0] job_tag_q;
    reg source_lb_q,pack_row_q,pack_lb_q,bias_en_q,single_row_q;
    reg raw_mode_q,dynamic_zp_q;reg signed [7:0] input_zp_q;
    reg [7:0] rows_q,rows_left,m_base;
    reg [9:0] k_q,n_q;
    reg [5:0] nc_q,col_panel;
    reg [9:0] col_byte;
    reg [3:0] active_rows,expected_row;
    reg [4:0] active_cols;
    reg [5:0] a_words;
    reg [7:0] a_load_row;
    reg [5:0] a_word_index;
    reg [AW-1:0] a_request_addr,a_row_start;
    reg [AW-1:0] out_block_base,out_next_block,out_row_cursor;
    reg [13:0] rq_block_base,rq_next_block,rq_parameter_cursor,output_lb_cursor;
    reg [15:0] request_sequence,pending_tag,pending_keep;
    reg [7:0] pending_error;

    // Ten bounded shift/add steps compute descriptor spans once per job.
    // Runtime addressing below uses only registered, bounded increments.
    reg [7:0] cfg_m_shift;
    reg [9:0] cfg_k_shift;
    reg [3:0] cfg_step;
    reg [17:0] cfg_a_span,cfg_y_span,cfg_a_term,cfg_y_term;
    reg [15:0] cfg_b_span,cfg_b_term;
    reg [13:0] cfg_rq_span,cfg_rq_term;
    reg [AW:0] cfg_a_end,cfg_y_end;
    wire unsupported_parameters=(AW<18)||(AW>32)||(CNTW<10)||(CNTW>32)||
        (WAW<16)||(WAW>32)||(BAW<6)||(BAW>CNTW)||(LBW<1)||(LBW>32)||
        (RQAW<14)||(RQAW>32)||(QKW<8)||(QKW>CNTW);
    wire cfg_simple_bad=unsupported_parameters||cfg_rows_q<1||cfg_rows_q>197||
        cfg_k_q<1||cfg_k_q>768||cfg_n_q<1||cfg_n_q>1000||
        (pack_row_q&&cfg_n_q>16);
    wire [32:0] lb_capacity=33'd1<<LBW;
    // The top carry is allowed ONLY for the exact one-past-memory endpoint.
    wire cfg_a_bounds_bad=cfg_a_end[AW]&&(|cfg_a_end[AW-1:0]);
    wire cfg_y_bounds_bad=cfg_y_end[AW]&&(|cfg_y_end[AW-1:0]);

    function [15:0] low_keep(input [4:0] bytes);
        begin low_keep=16'hffff>>(5'd16-bytes);end
    endfunction
    wire [4:0] request_bytes=(a_word_index==a_words-1'b1&&k_q[3:0]!=0)?
        {1'b0,k_q[3:0]}:5'd16;
    assign start_ready=!clear&&(state==IDLE);
    assign busy=!clear&&(state!=IDLE);
    assign a_req_valid=!clear&&(state==A_REQUEST);
    assign a_req_addr=a_request_addr;
    assign a_req_keep=low_keep(request_bytes);
    assign a_req_tag=request_sequence;
    assign a_rsp_ready=!clear&&(state==A_RESPONSE);
    wire request_take=a_req_valid&&a_req_ready;
    wire response_take=a_rsp_valid&&a_rsp_ready;
    wire response_owner_bad=(a_rsp_tag!=pending_tag)||(a_rsp_keep!=pending_keep);
    wire response_write=response_take&&!a_rsp_error&&!response_owner_bad;
    wire unexpected_response=a_rsp_valid&&(state!=A_RESPONSE)&&
        !((state==A_REQUEST)&&request_take);
    reg [127:0] masked_response;
    integer response_byte;
    always @* begin
        masked_response=0;
        for(response_byte=0;response_byte<16;response_byte=response_byte+1)
            if(pending_keep[response_byte])
                masked_response[8*response_byte+:8]=a_rsp_data[8*response_byte+:8];
        if(FAULT==1) masked_response[7:0]=masked_response[7:0]^8'h01;
    end

    // Eight128-bit BRAM rows, each48 words (maximumK768). Read all rows at
    // one K, then register the selected byte beside each bank. Those bytes and
    // the same one-cycle W/LB response enter Tile on the same later edge.
    reg [9:0] fill_k,fill_read_k,fill_address,fill_loaded;
    reg [2:0] parameter_row;
    reg [15:0] b_word_cursor;
    reg fill_read_valid,fill_leaf_valid;
    reg [127:0] b_leaf;
    wire fill_issue=!clear&&(state==FILL);
    wire tile_load=!clear&&fill_leaf_valid&&((state==FILL)||(state==FILL_DRAIN));
    wire [63:0] tile_a_word;
    genvar bank;
    generate for(bank=0;bank<8;bank=bank+1) begin:A_BANK
        (* ram_style="block" *) reg [127:0] words[0:47];
        reg [127:0] read_word;
        (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [3:0] read_byte;
        (* KEEP="TRUE",DONT_TOUCH="TRUE" *) reg [7:0] byte_leaf;
        always @(posedge clk) begin
            if(!clear&&response_write&&a_load_row==bank) words[a_word_index]<=masked_response;
            if(fill_issue) read_word<=words[fill_k[9:4]];
            if(clear) begin read_byte<=0;byte_leaf<=0;end
            else begin
                if(fill_issue) read_byte<=fill_k[3:0];
                if(fill_read_valid) begin
                    if(bank<active_rows) byte_leaf<=read_word[8*read_byte+:8];
                    else byte_leaf<=0;
                end
            end
        end
        assign tile_a_word[8*bank+:8]=byte_leaf;
    end endgenerate
    assign wrom_addr=(state==FILL)?b_word_cursor:{WAW{1'b0}};
    assign lb_read_addr=(state==FILL)?b_word_cursor:{LBW{1'b0}};
    assign bias_addr=col_panel;
    // NewW8A8 params are per output channel, identical for every row.
    assign rq_addr={{(RQAW-6){1'b0}},col_panel};

    reg [511:0] bias_shift;
    reg [3:0] bias_column;
    reg tile_done_seen;
    reg [127:0] tile_tag,wanted_tag;
    reg [15:0] wanted_keep;
    reg [25:0] row_checks;
    integer check_chunk,check_lane;
    wire [7:0] expected_global_row=m_base+expected_row;
    always @* begin
        tile_tag=0;tile_tag[63:0]=job_tag_q;
        tile_tag[95:80]={8'd0,m_base};tile_tag[111:96]={6'd0,col_byte};
        wanted_tag=tile_tag;wanted_tag[95:80]={8'd0,expected_global_row};
        wanted_keep=(expected_row<active_rows)?low_keep(active_cols):16'd0;
    end
    wire tile_start_ready,tile_busy,tile_done,tile_error,tile_out_valid,tile_out_last;
    wire [7:0] tile_error_code;
    wire [127:0] tile_out_data,tile_out_tag;wire [511:0] tile_out_raw;
    wire [15:0] tile_out_keep;
    wire tile_out_ready=!clear&&(state==WAIT_ROW);
    wire tile_out_fire=tile_out_ready&&tile_out_valid;
    w8_quant_tile #(.CORE_FAULT(0),.RQ_FAULT(0),.TOP_FAULT(0)) tile(
        .clk(clk),.rst(clear||tile_abort_q),.flush(1'b0),.raw_mode(raw_mode_q),.dynamic_zp(dynamic_zp_q),.input_zp(input_zp_q),.out_raw(tile_out_raw),
        .a_we(tile_load),.a_addr(fill_address),.a_data(tile_a_word),
        .b_we(tile_load),.b_addr(fill_address),.b_data(b_leaf),
        .bias_we(!clear&&state==BIAS_WRITE),.bias_col(bias_column),.bias_data(bias_shift[31:0]),
        .rq_we(!clear&&state==RQ_CAPTURE),.rq_row(parameter_row),
        .rq_data((parameter_row<active_rows)?rq_rdata:720'd0),
        .start_valid(!clear&&state==START_TILE),.start_ready(tile_start_ready),
        .k_len(k_q),.rows_valid(active_rows),.cols_valid(active_cols),.job_tag(tile_tag),
        .feed_enable(1'b1),.out_valid(tile_out_valid),.out_ready(tile_out_ready),
        .out_data(tile_out_data),.out_keep(tile_out_keep),.out_tag(tile_out_tag),.out_last(tile_out_last),
        .busy(tile_busy),.done(tile_done),.error_valid(tile_error),.error_code(tile_error_code));

    // A single registered WB owner. No row retires while ready is low. Pack
    // flags describe the request even on keep0 rows; transport MUST gate every
    // ACT/LB/PACK side effect with fire AND nonzero keep, atomically.
    reg [AW-1:0] wb_addr_q;
    reg [127:0] wb_data_q,wb_tag_q;reg [511:0] wb_raw_q;
    assign wb_raw=raw_mode_q;assign wb_raw_data=wb_raw_q;
    reg [15:0] wb_keep_q;
    reg wb_last_q,wb_tile_last;
    reg [QKW-1:0] wb_pack_addr_q;
    reg [LBW-1:0] wb_lb_addr_q;
    assign wb_valid=!clear&&(state==WB_HOLD);
    assign wb_addr=(FAULT==2)?(wb_addr_q^{{(AW-1){1'b0}},1'b1}):wb_addr_q;
    assign wb_data=wb_data_q;
    assign wb_tag=(FAULT==3)?(wb_tag_q^128'h1):wb_tag_q;
    assign wb_keep=(FAULT==4)?(wb_keep_q^16'h1):wb_keep_q;
    assign wb_last=(FAULT==5)?!wb_last_q:wb_last_q;
    assign wb_pack_row=pack_row_q;
    assign wb_pack_lb=pack_lb_q;
    assign wb_pack_addr=wb_pack_addr_q;
    assign wb_lb_addr=wb_lb_addr_q;
    wire wb_fire=wb_valid&&wb_ready;

    always @(posedge clk) begin
        done<=0;error_valid<=0;tile_abort_q<=0;
        if(clear) begin
            state<=IDLE;a_base_q<=0;out_base_q<=0;raw_mode_q<=0;dynamic_zp_q<=0;input_zp_q<=0;wb_raw_q<=0;
            cfg_rows_q<=0;cfg_k_q<=0;cfg_n_q<=0;job_tag_q<=0;
            source_lb_q<=0;pack_row_q<=0;pack_lb_q<=0;bias_en_q<=0;single_row_q<=0;
            rows_q<=0;rows_left<=0;m_base<=0;k_q<=0;n_q<=0;nc_q<=0;col_panel<=0;col_byte<=0;
            active_rows<=0;active_cols<=0;expected_row<=0;a_words<=0;a_load_row<=0;a_word_index<=0;
            a_request_addr<=0;a_row_start<=0;out_block_base<=0;out_next_block<=0;out_row_cursor<=0;
            rq_block_base<=0;rq_next_block<=0;rq_parameter_cursor<=0;output_lb_cursor<=0;
            request_sequence<=0;pending_tag<=0;pending_keep<=0;pending_error<=0;error_code<=0;
            cfg_m_shift<=0;cfg_k_shift<=0;cfg_step<=0;
            cfg_a_span<=0;cfg_y_span<=0;cfg_a_term<=0;cfg_y_term<=0;
            cfg_b_span<=0;cfg_b_term<=0;cfg_rq_span<=0;cfg_rq_term<=0;cfg_a_end<=0;cfg_y_end<=0;
            fill_k<=0;fill_read_k<=0;fill_address<=0;fill_loaded<=0;b_word_cursor<=0;
            fill_read_valid<=0;fill_leaf_valid<=0;b_leaf<=0;
            bias_shift<=0;bias_column<=0;parameter_row<=0;tile_done_seen<=0;
            wb_addr_q<=0;wb_data_q<=0;wb_tag_q<=0;wb_keep_q<=0;wb_last_q<=0;wb_tile_last<=0;
            wb_pack_addr_q<=0;wb_lb_addr_q<=0;row_checks<=0;
        end else begin
            fill_read_valid<=fill_issue;fill_leaf_valid<=fill_read_valid;
            if(fill_issue) fill_read_k<=fill_k;
            if(fill_read_valid) begin
                b_leaf<=source_lb_q?lb_rdata:wrom_rdata;fill_address<=fill_read_k;
            end
            if(tile_load) fill_loaded<=fill_loaded+1'b1;
            if(tile_done) tile_done_seen<=1;
            if(state!=IDLE&&state!=ABORT&&tile_error) begin
                pending_error<=tile_error_code;state<=ABORT;tile_abort_q<=1;
            end else if(state!=IDLE&&state!=ABORT&&unexpected_response) begin
                pending_error<=8'h0b;state<=ABORT;tile_abort_q<=1;
            end else begin
                case(state)
                    IDLE:if(start)begin
                        a_base_q<=a_base;out_base_q<=out_base;raw_mode_q<=raw_mode;dynamic_zp_q<=dynamic_zp;input_zp_q<=input_zp;
                        cfg_rows_q<=n_rows;cfg_k_q<=k_dim;cfg_n_q<=n_out;job_tag_q<=job_tag;
                        source_lb_q<=b_is_laneram;pack_row_q<=pack_row;pack_lb_q<=pack_lb;bias_en_q<=bias_en;
                        single_row_q<=b_is_laneram&&pack_lb;pending_error<=0;error_code<=0;state<=CFG_INIT;
                    end
                    CFG_INIT:begin
                        if(cfg_simple_bad||FAULT<0||FAULT>5)begin pending_error<=8'h03;state<=ABORT;tile_abort_q<=1;end
                        else begin
                            rows_q<=cfg_rows_q[7:0];rows_left<=cfg_rows_q[7:0];
                            k_q<=cfg_k_q[9:0];n_q<=cfg_n_q[9:0];nc_q<=(cfg_n_q+15)>>4;
                            cfg_m_shift<=cfg_rows_q[7:0];cfg_k_shift<=cfg_k_q[9:0];cfg_step<=0;
                            cfg_a_term<={8'd0,cfg_k_q[9:0]};cfg_y_term<={8'd0,cfg_n_q[9:0]};
                            cfg_b_term<=(cfg_n_q+15)>>4;cfg_rq_term<=(cfg_n_q+15)>>4;
                            cfg_a_span<=0;cfg_y_span<=0;cfg_b_span<=0;cfg_rq_span<=0;
                            state<=CFG_MUL;
                        end
                    end
                    CFG_MUL:begin
                        if(cfg_m_shift[0])begin
                            cfg_a_span<=cfg_a_span+cfg_a_term;cfg_y_span<=cfg_y_span+cfg_y_term;
                            cfg_rq_span<=cfg_rq_span+cfg_rq_term;
                        end
                        if(cfg_k_shift[0])cfg_b_span<=cfg_b_span+cfg_b_term;
                        cfg_m_shift<=cfg_m_shift>>1;cfg_k_shift<=cfg_k_shift>>1;
                        cfg_a_term<=cfg_a_term<<1;cfg_y_term<=cfg_y_term<<1;
                        cfg_rq_term<=cfg_rq_term<<1;cfg_b_term<=cfg_b_term<<1;
                        cfg_step<=cfg_step+1'b1;if(cfg_step==9)state<=CFG_SUM;
                    end
                    CFG_SUM:begin
                        cfg_a_end<={1'b0,a_base_q}+cfg_a_span;
                        cfg_y_end<={1'b0,out_base_q}+cfg_y_span;state<=CFG_CHECK;
                    end
                    CFG_CHECK:begin
                        if(cfg_a_bounds_bad||cfg_y_bounds_bad||
                           (source_lb_q&&({17'd0,cfg_b_span}>lb_capacity))||
                           (pack_lb_q&&({19'd0,cfg_rq_span}>lb_capacity)))begin
                            pending_error<=8'h03;state<=ABORT;tile_abort_q<=1;
                        end else begin
                            active_rows<=single_row_q?4'd1:((rows_q<8)?rows_q:4'd8);
                            active_cols<=(n_q<16)?n_q:5'd16;
                            a_words<=(k_q+10'd15)>>4;
                            a_load_row<=0;a_word_index<=0;a_request_addr<=a_base_q;a_row_start<=a_base_q;
                            m_base<=0;col_panel<=0;col_byte<=0;
                            out_block_base<=out_base_q;out_next_block<=out_base_q;
                            rq_block_base<=0;rq_next_block<=0;tile_done_seen<=0;
                            state<=A_REQUEST;
                        end
                    end
                    A_REQUEST:if(request_take)begin
                        pending_tag<=request_sequence;pending_keep<=a_req_keep;
                        request_sequence<=request_sequence+1'b1;state<=A_RESPONSE;
                    end
                    A_RESPONSE:if(response_take)begin
                        if(a_rsp_error)begin pending_error<=8'h07;state<=ABORT;tile_abort_q<=1;end
                        else if(response_owner_bad)begin pending_error<=8'h0b;state<=ABORT;tile_abort_q<=1;end
                        else if(a_word_index==a_words-1'b1)begin
                            a_word_index<=0;a_row_start<=a_row_start+k_q;
                            out_next_block<=out_next_block+n_q;rq_next_block<=rq_next_block+nc_q;
                            if(a_load_row==active_rows-1'b1)begin a_load_row<=0;state<=TILE_PREP;end
                            else begin
                                a_load_row<=a_load_row+1'b1;a_request_addr<=a_row_start+k_q;state<=A_REQUEST;
                            end
                        end else begin
                            a_word_index<=a_word_index+1'b1;a_request_addr<=a_request_addr+16;state<=A_REQUEST;
                        end
                    end
                    TILE_PREP:begin
                        fill_k<=0;fill_loaded<=0;b_word_cursor<={10'd0,col_panel};
                        out_row_cursor<=out_block_base+col_byte;
                        rq_parameter_cursor<=rq_block_base+col_panel;output_lb_cursor<=rq_block_base+col_panel;
                        expected_row<=0;tile_done_seen<=0;state<=FILL;
                    end
                    FILL:begin
                        if(fill_k==k_q-1'b1)state<=FILL_DRAIN;
                        else begin fill_k<=fill_k+1'b1;b_word_cursor<=b_word_cursor+nc_q;end
                    end
                    FILL_DRAIN:if(tile_load&&fill_loaded==k_q-1'b1)state<=BIAS_REQ;
                    BIAS_REQ:state<=BIAS_CAPTURE;
                    BIAS_CAPTURE:begin bias_shift<=bias_en_q?bias_rdata:512'd0;bias_column<=0;state<=BIAS_WRITE;end
                    BIAS_WRITE:begin
                        bias_shift<=bias_shift>>32;
                        if(bias_column==15)begin parameter_row<=0;state<=RQ_REQ;end
                        else bias_column<=bias_column+1'b1;
                    end
                    RQ_REQ:state<=RQ_CAPTURE;
                    RQ_CAPTURE:begin
                        rq_parameter_cursor<=rq_parameter_cursor+nc_q;
                        if(parameter_row==7)state<=START_TILE;
                        else begin parameter_row<=parameter_row+1'b1;state<=RQ_REQ;end
                    end
                    START_TILE:if(tile_start_ready)state<=WAIT_ROW;
                    WAIT_ROW:if(tile_out_fire)begin
                        // Capture the checks beside this exact payload. A
                        // wide head-TAG comparison never feeds the state/CE
                        // cone on this capture edge. No WB is visible yet.
                        for(check_chunk=0;check_chunk<8;check_chunk=check_chunk+1)
                            row_checks[check_chunk]<=tile_out_tag[16*check_chunk+:16]==wanted_tag[16*check_chunk+:16];
                        row_checks[8]<=tile_out_keep==wanted_keep;
                        row_checks[9]<=(expected_row<8)&&(tile_out_last==(expected_row==7));
                        for(check_lane=0;check_lane<16;check_lane=check_lane+1)
                            row_checks[10+check_lane]<=wanted_keep[check_lane]||tile_out_data[8*check_lane+:8]==0;
                        wb_raw_q<=tile_out_raw;wb_addr_q<=out_row_cursor;wb_data_q<=tile_out_data;wb_keep_q<=tile_out_keep;wb_tag_q<=tile_out_tag;
                        wb_last_q<=(expected_row==7)&&(rows_left<=active_rows)&&(col_panel==nc_q-1'b1);
                        wb_tile_last<=tile_out_last;wb_pack_addr_q<=expected_global_row;wb_lb_addr_q<=output_lb_cursor;
                        out_row_cursor<=out_row_cursor+n_q;output_lb_cursor<=output_lb_cursor+nc_q;
                        expected_row<=expected_row+1'b1;state<=CHECK_ROW;
                    end
                    CHECK_ROW:begin
                        if(&row_checks)state<=WB_HOLD;
                        else begin pending_error<=8'h0a;state<=ABORT;tile_abort_q<=1;end
                    end
                    WB_HOLD:if(wb_fire)begin
                        if(wb_tile_last)state<=FINISH_TILE;else state<=WAIT_ROW;
                    end
                    FINISH_TILE:if(tile_done_seen||tile_done)begin
                        if(col_panel==nc_q-1'b1)begin
                            if(rows_left<=active_rows)begin done<=1;state<=IDLE;end
                            else begin
                                rows_left<=rows_left-active_rows;m_base<=m_base+active_rows;
                                active_rows<=single_row_q?4'd1:((rows_left-active_rows<8)?rows_left-active_rows:4'd8);
                                active_cols<=(n_q<16)?n_q:5'd16;col_panel<=0;col_byte<=0;
                                out_block_base<=out_next_block;rq_block_base<=rq_next_block;
                                a_load_row<=0;a_word_index<=0;a_request_addr<=a_row_start;state<=A_REQUEST;
                            end
                        end else begin
                            col_panel<=col_panel+1'b1;col_byte<=col_byte+16;
                            active_cols<=(n_q-col_byte-16<16)?n_q-col_byte-16:5'd16;state<=TILE_PREP;
                        end
                    end
                    ABORT:begin done<=1;error_valid<=1;error_code<=pending_error;state<=IDLE;end
                    default:begin pending_error<=8'h12;state<=ABORT;tile_abort_q<=1;end
                endcase
            end
        end
    end

`ifndef SYNTHESIS
    // Observation windows overlap. They are not an additive cycle partition.
    reg [63:0] debug_total_cycles,debug_load_cycles,debug_compute_cycles,debug_rq_cycles;
    reg [63:0] debug_writeback_cycles,debug_write_bytes,debug_tiles;
    reg [63:0] debug_a_requests,debug_a_response_wait,debug_wb_stall;
    reg [63:0] debug_cfg_cycles,debug_a_cycles,debug_fill_cycles,debug_bias_cycles,debug_parameter_cycles;
    reg [63:0] debug_tile_control_cycles,debug_abort_cycles;
    function [4:0] count_keep(input [15:0] mask);
        integer lane;
        begin
            count_keep=0;
            for(lane=0;lane<16;lane=lane+1)count_keep=count_keep+mask[lane];
        end
    endfunction
    always @(posedge clk) begin
        if(clear||(start_ready&&start))begin
            debug_total_cycles<=0;debug_load_cycles<=0;debug_compute_cycles<=0;debug_rq_cycles<=0;
            debug_writeback_cycles<=0;debug_write_bytes<=0;debug_tiles<=0;
            debug_a_requests<=0;debug_a_response_wait<=0;debug_wb_stall<=0;
            debug_cfg_cycles<=0;debug_a_cycles<=0;debug_fill_cycles<=0;
            debug_bias_cycles<=0;debug_parameter_cycles<=0;debug_tile_control_cycles<=0;debug_abort_cycles<=0;
        end else if(busy)begin
            debug_total_cycles<=debug_total_cycles+1;
            if(state==A_REQUEST||state==A_RESPONSE||state==FILL||state==FILL_DRAIN||
               state==BIAS_REQ||state==BIAS_CAPTURE||state==BIAS_WRITE||state==RQ_REQ||state==RQ_CAPTURE)
                debug_load_cycles<=debug_load_cycles+1;
            if(tile.state==tile.RUN||tile.state==tile.WAIT_CORE)debug_compute_cycles<=debug_compute_cycles+1;
            if(tile.state==tile.COLLECT||tile.state==tile.DRAIN)debug_rq_cycles<=debug_rq_cycles+1;
            if(state==WB_HOLD)debug_writeback_cycles<=debug_writeback_cycles+1;
            if(wb_fire)debug_write_bytes<=debug_write_bytes+count_keep(wb_keep);
            if(state==START_TILE&&tile_start_ready)debug_tiles<=debug_tiles+1;
            if(request_take)debug_a_requests<=debug_a_requests+1;
            if(state==A_RESPONSE&&!a_rsp_valid)debug_a_response_wait<=debug_a_response_wait+1;
            if(wb_valid&&!wb_ready)debug_wb_stall<=debug_wb_stall+1;
            case(state)
                CFG_INIT,CFG_MUL,CFG_SUM,CFG_CHECK:debug_cfg_cycles<=debug_cfg_cycles+1;
                A_REQUEST,A_RESPONSE:debug_a_cycles<=debug_a_cycles+1;
                FILL,FILL_DRAIN:debug_fill_cycles<=debug_fill_cycles+1;
                BIAS_REQ,BIAS_CAPTURE,BIAS_WRITE:debug_bias_cycles<=debug_bias_cycles+1;
                RQ_REQ,RQ_CAPTURE:debug_parameter_cycles<=debug_parameter_cycles+1;
                TILE_PREP,START_TILE,WAIT_ROW,CHECK_ROW,FINISH_TILE:debug_tile_control_cycles<=debug_tile_control_cycles+1;
                ABORT:debug_abort_cycles<=debug_abort_cycles+1;
                // WB_HOLD is counted by debug_writeback_cycles above.
                default:begin end
            endcase
        end
    end
`endif
`ifndef SYNTHESIS
    always @(negedge clk)if(!clear&&tile_abort_q!==(state==ABORT))$fatal(1,"GEMM_ABORT_AGE_MISMATCH");
`endif
endmodule
