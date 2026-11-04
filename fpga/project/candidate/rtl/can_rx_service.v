`timescale 1ns / 1ps
// PG096 v5.1 RX service, using the existing shared AXI command executor.
// Error bits: 0 HW overflow,1 underflow,2 AXI,3 invalid DLC,4 queue drop,
//             5 CAN ERROR,6 BSOFF; all sticky until the common PL reset.
module can_rx_service #(
    parameter integer POLL_CYCLES=2500,
    parameter integer FRAME_FIFO_DEPTH=16
)(
    input wire clk,rst_n,enable,
    input wire [63:0] time_now,
    output reg cmd_valid,cmd_write,
    output reg [31:0] cmd_addr,cmd_data,
    input wire cmd_ready,
    input wire response_valid,response_error,response_timeout,
    input wire [31:0] response_data,
    // Lock covers IDR, DLCR, DW1, DW2, and RX event acknowledgement.
    output wire group_lock,
    output reg fault,
    output reg [3:0] state,
    output wire rx_valid,
    input wire rx_ready,
    output wire [28:0] rx_can_id,
    output wire rx_ide,rx_rtr,
    output wire [3:0] rx_dlc,
    output wire [63:0] rx_data,rx_timestamp,
    output wire [7:0] rx_frame_error,
    output reg [7:0] rx_error_flags,
    output wire rx_integrity_lost,
    output reg [31:0] rx_frame_count,rx_overflow_count,rx_underflow_count,
    output reg [31:0] rx_axi_error_count,rx_invalid_frame_count,rx_sw_drop_count,
    output wire [31:0] rx_fifo_level,
    output reg [28:0] rx_last_id,
    output reg [3:0] rx_last_dlc,
    output reg [31:0] rx_last_isr,
    output reg [31:0] snapshot_isr,snapshot_esr,snapshot_ecr,snapshot_sr,
    // bit0 seen, bit1 pending, bit2 done, bit3 failed,
    // bits6:4 ESR/ECR/SR valid, bit7 diagnostic AXI request in flight.
    output wire [7:0] snapshot_status
);
    localparam [3:0] POLL_REQ=0,POLL_WAIT=1,ID_REQ=2,ID_WAIT=3,
        DLC_REQ=4,DLC_WAIT=5,DW1_REQ=6,DW1_WAIT=7,DW2_REQ=8,DW2_WAIT=9,
        ACK_REQ=10,ACK_WAIT=11,PUBLISH=12,GAP=13,FAILED=14;
    reg [31:0] timer,idr,dlcr,dw1,dw2,ack_mask;
    reg [63:0] stamp;
    reg frame_pending;
    reg [1:0] reported_events;
    reg snapshot_seen,snapshot_pending,snapshot_done,snapshot_failed;
    reg [2:0] snapshot_valid_mask;
    reg [1:0] snapshot_phase;
    reg diag_ready,diag_inflight;
    wire queue_drop,push;
    wire [28:0] decoded_id;
    wire decoded_rtr;
    wire [63:0] decoded_data;
    assign group_lock=(state>=ID_REQ && state<=ACK_WAIT);
    assign rx_integrity_lost=(rx_error_flags!=0);
    assign snapshot_status={diag_inflight,snapshot_valid_mask,snapshot_failed,
                            snapshot_done,snapshot_pending,snapshot_seen};
    assign decoded_id=idr[19]?{idr[31:21],idr[18:1]}:{18'd0,idr[31:21]};
    assign decoded_rtr=idr[19]?idr[0]:idr[20];
    // AXI words put the first CAN byte in bits31:24. Unified data puts it
    // in bits7:0. Preserve all eight physical bytes; DLC determines validity.
    assign decoded_data={dw2[7:0],dw2[15:8],dw2[23:16],dw2[31:24],
                         dw1[7:0],dw1[15:8],dw1[23:16],dw1[31:24]};
    assign push=enable && state==PUBLISH && frame_pending && dlcr[31:28]<=8;
    can_rx_frame_fifo #(.DEPTH(FRAME_FIFO_DEPTH)) frames(
        .clk(clk),.rst_n(rst_n),.push(push),.in_id(decoded_id),.in_ide(idr[19]),
        .in_rtr(decoded_rtr),.in_dlc(dlcr[31:28]),.in_data(decoded_data),
        .in_timestamp(stamp),.in_error(rx_error_flags),.valid(rx_valid),.ready(rx_ready),
        .out_id(rx_can_id),.out_ide(rx_ide),.out_rtr(rx_rtr),.out_dlc(rx_dlc),
        .out_data(rx_data),.out_timestamp(rx_timestamp),.out_error(rx_frame_error),
        .level(rx_fifo_level),.drop(queue_drop));
    always @* begin
        cmd_valid=0;cmd_write=0;cmd_addr=32'h43C0001C;cmd_data=0;
        if(enable && !fault) case(state)
            POLL_REQ: begin
                cmd_valid=1;
                if(diag_ready) case(snapshot_phase)
                    0: cmd_addr=32'h43C00014; // ESR: read does not clear
                    1: cmd_addr=32'h43C00010; // ECR
                    2: cmd_addr=32'h43C00018; // SR
                    default: cmd_addr=32'h43C0001C;
                endcase
            end
            ID_REQ: begin cmd_valid=1;cmd_addr=32'h43C00050;end
            DLC_REQ: begin cmd_valid=1;cmd_addr=32'h43C00054;end
            DW1_REQ: begin cmd_valid=1;cmd_addr=32'h43C00058;end
            DW2_REQ: begin cmd_valid=1;cmd_addr=32'h43C0005C;end
            ACK_REQ: begin cmd_valid=1;cmd_write=1;cmd_addr=32'h43C00024;cmd_data=ack_mask;end
            default: begin end
        endcase
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=POLL_REQ;fault<=0;timer<=0;idr<=0;dlcr<=0;dw1<=0;dw2<=0;stamp<=0;
            ack_mask<=0;frame_pending<=0;reported_events<=0;rx_error_flags<=0;
            rx_frame_count<=0;rx_overflow_count<=0;rx_underflow_count<=0;
            rx_axi_error_count<=0;rx_invalid_frame_count<=0;rx_sw_drop_count<=0;
            rx_last_id<=0;rx_last_dlc<=0;rx_last_isr<=0;
            snapshot_isr<=0;snapshot_esr<=0;snapshot_ecr<=0;snapshot_sr<=0;
            snapshot_seen<=0;snapshot_pending<=0;snapshot_done<=0;snapshot_failed<=0;
            snapshot_valid_mask<=0;snapshot_phase<=0;diag_ready<=0;diag_inflight<=0;
        end else if(enable) begin
            if(queue_drop) begin
                rx_sw_drop_count<=rx_sw_drop_count+1'b1;rx_error_flags[4]<=1;
            end
            // A late completion after a timeout cannot create a second event.
            // Stop, rather than retry a possibly side-effecting partial read.
            if(!fault && (response_timeout || (response_valid && response_error))) begin
                fault<=1;state<=FAILED;frame_pending<=0;
                rx_axi_error_count<=rx_axi_error_count+1'b1;rx_error_flags[2]<=1;
                if(snapshot_pending || diag_inflight || diag_ready) begin
                    snapshot_failed<=1;snapshot_pending<=0;diag_ready<=0;diag_inflight<=0;
                end
            end else if(!fault) case(state)
                POLL_REQ: if(cmd_valid && cmd_ready) begin
                    diag_inflight<=diag_ready;
                    diag_ready<=0;
                    state<=POLL_WAIT;
                end
                POLL_WAIT: if(response_valid) begin
                    if(diag_inflight) begin
                        diag_inflight<=0;
                        case(snapshot_phase)
                            0: begin snapshot_esr<=response_data;snapshot_valid_mask[0]<=1;end
                            1: begin snapshot_ecr<=response_data;snapshot_valid_mask[1]<=1;end
                            2: begin
                                snapshot_sr<=response_data;snapshot_valid_mask[2]<=1;
                                snapshot_done<=1;snapshot_pending<=0;
                            end
                        endcase
                        if(snapshot_phase<2) snapshot_phase<=snapshot_phase+1'b1;
                        // Repoll ISR before another diagnostic read so RX traffic
                        // can preempt the next snapshot step.
                        state<=POLL_REQ;
                    end else begin
                        rx_last_isr<=response_data;
                        if(response_data[6]) begin
                            rx_error_flags[0]<=1;
                            if(!reported_events[0]) rx_overflow_count<=rx_overflow_count+1'b1;
                        end
                        if(response_data[5]) begin
                            rx_error_flags[1]<=1;
                            if(!reported_events[1]) rx_underflow_count<=rx_underflow_count+1'b1;
                        end
                        reported_events<={response_data[5],response_data[6]};
                        if(response_data[8]) begin
                            rx_error_flags[5]<=1;
                            if(!snapshot_seen) begin
                                snapshot_seen<=1;snapshot_pending<=1;
                                snapshot_isr<=response_data;
                            end
                        end
                        if(response_data[9]) rx_error_flags[6]<=1;
                        // Clear only RX events; NEVER clear TXOK, ERROR, or BSOFF.
                        ack_mask<=response_data & 32'hF0;
                        frame_pending<=0;
                        if(response_data[7]) state<=ID_REQ;
                        else if((response_data & 32'h70)!=0) state<=ACK_REQ;
                        else begin
                            // First ERROR is latched above; schedule one diagnostic
                            // read only after this ISR response shows RX empty.
                            if(snapshot_pending || (response_data[8] && !snapshot_seen))
                                diag_ready<=1;
                            timer<=0;state<=GAP;
                        end
                    end
                end
                ID_REQ: if(cmd_valid && cmd_ready) begin stamp<=time_now;state<=ID_WAIT;end
                ID_WAIT: if(response_valid) begin idr<=response_data;state<=DLC_REQ;end
                DLC_REQ: if(cmd_valid && cmd_ready) state<=DLC_WAIT;
                DLC_WAIT: if(response_valid) begin dlcr<=response_data;state<=DW1_REQ;end
                DW1_REQ: if(cmd_valid && cmd_ready) state<=DW1_WAIT;
                DW1_WAIT: if(response_valid) begin dw1<=response_data;state<=DW2_REQ;end
                DW2_REQ: if(cmd_valid && cmd_ready) state<=DW2_WAIT;
                DW2_WAIT: if(response_valid) begin
                    dw2<=response_data;frame_pending<=1;state<=ACK_REQ;
                    rx_frame_count<=rx_frame_count+1'b1;
                    rx_last_id<=decoded_id;rx_last_dlc<=dlcr[31:28];
                    if(dlcr[31:28]>8) begin
                        rx_invalid_frame_count<=rx_invalid_frame_count+1'b1;rx_error_flags[3]<=1;
                    end
                end
                ACK_REQ: if(cmd_valid && cmd_ready) state<=ACK_WAIT;
                ACK_WAIT: if(response_valid) begin
                    if(ack_mask[6]) reported_events[0]<=0;
                    if(ack_mask[5]) reported_events[1]<=0;
                    state<=PUBLISH;
                end
                PUBLISH: begin frame_pending<=0;state<=POLL_REQ;end
                GAP: if(timer==POLL_CYCLES-1) state<=POLL_REQ;else timer<=timer+1'b1;
                default: begin end
            endcase
        end
    end
endmodule
