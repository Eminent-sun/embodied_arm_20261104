`timescale 1ns / 1ps
// One-entry elastic stage: invalid frames are events for accounting, never data updates.
// kind:0 status,1 parameter response,2 fault/warning,3 optional UID,4 invalid.
// reason:1 config,2 IDE,3 RTR,4 DLC,5 host,6 motor,7 type,8 transport,
//        9 reserved/status; later bank adds10 timestamp,11 stale,12 transaction.
module robstride_rx_dispatch #(
    parameter integer CONFIG_ENABLE=0,
    parameter [7:0] HOST_ID=0,
    parameter [47:0] MOTOR_IDS=0,
    parameter integer ALLOW_IDENTITY=0
)(
    input wire clk,rst_n,frame_valid,
    output wire frame_ready,
    input wire [28:0] can_id,
    input wire can_ide,can_rtr,
    input wire [3:0] can_dlc,
    input wire [63:0] can_data,frame_timestamp,
    input wire [7:0] frame_error,
    input wire stream_integrity_lost,
    output wire mapping_valid,
    output reg event_valid,
    input wire event_ready,
    output reg [2:0] event_kind,event_axis,
    output reg event_axis_known,
    output reg [3:0] event_reason,
    output reg [28:0] event_id,
    output reg [63:0] event_data,event_timestamp
);
    wire mapped;
    wire [2:0] axis;
    wire [4:0] communication_type;
    reg [2:0] kind;
    reg [3:0] reason;
    assign communication_type=can_id[28:24];
    robstride_axis_map #(.CONFIG_ENABLE(CONFIG_ENABLE),.HOST_ID(HOST_ID),.MOTOR_IDS(MOTOR_IDS)) addresses(
        .motor_id(can_id[15:8]),.config_valid(mapping_valid),.mapped(mapped),.axis(axis));
    assign frame_ready=rst_n && (!event_valid || event_ready);
    always @* begin
        kind=4;reason=0;
        case(communication_type)
            5'h02: begin kind=0;if(can_id[23:22]==3) reason=9;end
            5'h11: begin
                kind=1;
                if(can_id[23:16]>1 || can_data[31:16]!=0) reason=9;
            end
            5'h15: kind=2;
            5'h00: begin
                kind=3;
                if(ALLOW_IDENTITY==0) reason=7;
                else if(can_id[23:16]!=0) reason=9;
            end
            default: reason=7;
        endcase
        if((communication_type==0 && ALLOW_IDENTITY!=0)?can_id[7:0]!=8'hFE:can_id[7:0]!=HOST_ID) reason=5;
        if(!mapped) reason=6;
        if(can_dlc!=8) reason=4;
        if(can_rtr) reason=3;
        if(!can_ide) reason=2;
        if(frame_error!=0 || stream_integrity_lost) reason=8;
        if(!mapping_valid) reason=1;
        if(reason!=0) kind=4;
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            event_valid<=0;event_kind<=4;event_axis<=0;event_axis_known<=0;
            event_reason<=0;event_id<=0;event_data<=0;event_timestamp<=0;
        end else if(frame_ready) begin
            event_valid<=frame_valid;
            if(frame_valid) begin
                event_kind<=kind;event_axis<=axis;event_axis_known<=mapped;
                event_reason<=reason;event_id<=can_id;event_data<=can_data;event_timestamp<=frame_timestamp;
            end
        end
    end
endmodule
