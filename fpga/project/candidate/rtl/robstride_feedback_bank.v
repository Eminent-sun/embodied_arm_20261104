`timescale 1ns / 1ps
// Raw six-axis state and one outstanding parameter transaction per axis.
// No model ranges, floating-point conversions, CAN writes, or automatic recovery.
module robstride_feedback_bank #(
    parameter integer CONFIG_ENABLE=0,
    parameter [7:0] HOST_ID=0,
    parameter [47:0] MOTOR_IDS=0,
    parameter integer FEEDBACK_TIMEOUT_CYCLES=0,
    parameter integer PARAM_TIMEOUT_CYCLES=0
)(
    input wire clk,rst_n,consume_enable,
    input wire [63:0] time_now,
    input wire stream_integrity_lost,
    input wire event_valid,
    output wire event_ready,
    input wire [2:0] event_kind,event_axis,
    input wire event_axis_known,
    input wire [3:0] event_reason,
    input wire [28:0] event_id,
    input wire [63:0] event_data,event_timestamp,
    // Register only a real admitted read attempt in a future command path.
    // A local token is NOT transmitted on CAN and cannot solve wire ambiguity.
    input wire param_req_valid,
    output wire param_req_ready,
    input wire [7:0] param_req_host,param_req_motor,
    input wire [15:0] param_req_index,
    input wire [31:0] param_req_token,
    // Lifecycle control: valid/ready request; result pulses on the next cycle.
    input wire param_cancel_valid,
    output wire param_cancel_ready,
    input wire [7:0] param_cancel_motor,
    input wire [15:0] param_cancel_index,
    input wire [31:0] param_cancel_token,
    input wire param_cancel_poison,
    output reg param_cancel_done,param_cancel_matched,
    // Live query uses param_req fields, including token; expiry gates TX combinationally.
    output wire param_req_active,
    output reg param_req_rejected,
    output reg param_reply_valid,param_reply_failed,
    // Accepted type-2 status event for write acknowledgement observation.
    output wire status_event_valid,
    output wire [7:0] status_event_motor,
    output wire [5:0] status_event_error,
    output reg [2:0] param_reply_axis,
    output reg [15:0] param_reply_index,
    output reg [31:0] param_reply_bits,param_reply_token,
    output reg [5:0] param_pending,param_poisoned,
    input wire [2:0] query_axis,
    output reg query_valid,query_status_valid,query_fault_valid,
    output reg [7:0] query_motor_id,
    output reg [15:0] query_position_raw,query_velocity_raw,query_torque_raw,query_temperature_raw,
    output reg [1:0] query_pattern,
    output reg [5:0] query_error_code,
    output reg [31:0] query_fault,query_warning,query_fault_latched,query_warning_latched,
    output reg [63:0] query_feedback_timestamp,query_last_frame_timestamp,query_fault_timestamp,
    output reg [31:0] query_frame_count,query_status_count,query_invalid_count,query_timeout_count,
    output reg [15:0] query_parameter_index,
    output reg [31:0] query_parameter_bits,query_parameter_token,query_parameter_count,query_parameter_failed_count,
    output reg [63:0] query_parameter_timestamp,query_uid_raw,
    output reg [28:0] query_last_id,
    output reg [5:0] feedback_timeout,
    output wire mapping_valid,watchdog_config_valid,
    output reg integrity_lost,
    output reg [31:0] accepted_frame_count,invalid_frame_count,stale_frame_count,
    output reg [31:0] parameter_unmatched_count,parameter_timeout_count,
    output reg [3:0] last_reject_reason,
    // Passive diagnostics only; none of these outputs gates protocol or CAN.
    output wire [15:0] diag_event_info,
    output reg [31:0] id_mismatch_count,
    output reg [5:0] diag_timeout_seen
);
    reg [15:0] position_raw[0:5],velocity_raw[0:5],torque_raw[0:5],temperature_raw[0:5];
    reg [1:0] pattern[0:5];
    reg [5:0] errors[0:5];
    reg [31:0] faults[0:5],warnings[0:5],sticky_fault[0:5],sticky_warning[0:5];
    reg [63:0] feedback_stamp[0:5],frame_stamp[0:5],fault_stamp[0:5],uid_stamp[0:5],uid_raw[0:5];
    reg [31:0] frames[0:5],statuses[0:5],invalids[0:5],timeouts[0:5];
    reg [15:0] expected_index[0:5],last_index[0:5];
    reg [31:0] expected_token[0:5],last_bits[0:5],last_token[0:5],parameter_count[0:5],parameter_failures[0:5];
    reg [63:0] request_stamp[0:5],parameter_stamp[0:5];
    reg [28:0] last_id[0:5];
    reg [5:0] have_status,have_fault,have_uid,previous_timeout;
    wire req_mapped;
    wire [2:0] req_axis;
    wire req_ok;
    wire cancel_mapped;
    wire [2:0] cancel_axis;
    reg [5:0] transaction_seen,uncertain;
    wire cancel_match;
    reg accept_event;
    reg [3:0] reason;
    robstride_axis_map #(.CONFIG_ENABLE(CONFIG_ENABLE),.HOST_ID(HOST_ID),.MOTOR_IDS(MOTOR_IDS)) cancel_addresses(
        .motor_id(param_cancel_motor),.config_valid(),.mapped(cancel_mapped),.axis(cancel_axis));
    assign param_cancel_ready=rst_n;
    assign status_event_valid=event_valid && event_ready && accept_event && event_kind==0;
    assign status_event_motor=event_id[15:8];
    assign status_event_error=event_id[21:16];
    assign cancel_match=cancel_mapped && transaction_seen[cancel_axis] &&
        expected_index[cancel_axis]==param_cancel_index && expected_token[cancel_axis]==param_cancel_token &&
        (param_cancel_poison || !uncertain[cancel_axis]);
    assign param_req_active=req_ok && param_pending[req_axis] && !param_poisoned[req_axis] &&
        expected_index[req_axis]==param_req_index && expected_token[req_axis]==param_req_token &&
        time_now-request_stamp[req_axis]<PARAM_TIMEOUT_CYCLES;
    integer i,expired_count;
    robstride_axis_map #(.CONFIG_ENABLE(CONFIG_ENABLE),.HOST_ID(HOST_ID),.MOTOR_IDS(MOTOR_IDS)) addresses(
        .motor_id(param_req_motor),.config_valid(mapping_valid),.mapped(req_mapped),.axis(req_axis));
    assign watchdog_config_valid=mapping_valid && FEEDBACK_TIMEOUT_CYCLES>0;
    assign event_ready=rst_n && consume_enable;
    assign req_ok=mapping_valid && req_mapped && param_req_host==HOST_ID && PARAM_TIMEOUT_CYCLES>0
        && !stream_integrity_lost && !integrity_lost;
    // Invalid requests are consumed and explicitly rejected; busy valid axes backpressure.
    assign param_req_ready=rst_n && !(param_cancel_valid === 1'b1) && (!req_ok || !param_pending[req_axis]);
    // On each event handshake: [0] valid, [1] accepted, [2] rejected,
    // [7:3] wire communication type, [10:8] axis (7 if unmapped),
    // [11] axis known, [15:12] effective rejection reason (0 if accepted).
    // Adjacent events may keep valid high: each clock is a distinct event.
    assign diag_event_info=(event_valid && event_ready)?
        {(accept_event?4'd0:reason),event_axis_known,
         (event_axis_known?event_axis:3'd7),event_id[28:24],
         !accept_event,accept_event,1'b1}:16'd0;
    // Array watchdogs operate even when parsing is backpressured or CAN TX is idle.
    integer w;
    always @* begin
        feedback_timeout=6'h3F;
        if(watchdog_config_valid)
            for(w=0;w<6;w=w+1)
                feedback_timeout[w]=!have_status[w] || (time_now-feedback_stamp[w]>=FEEDBACK_TIMEOUT_CYCLES);
        reason=event_reason;accept_event=(event_kind!=4);
        if(!event_axis_known || event_axis>=6 || !mapping_valid) begin accept_event=0;if(event_kind!=4) reason=6;end
        else if(event_kind!=4) begin
            if(event_timestamp>time_now) begin accept_event=0;reason=10;end
            else case(event_kind)
                0: if(have_status[event_axis] && event_timestamp<=feedback_stamp[event_axis]) begin accept_event=0;reason=11;end
                1: if(!param_pending[event_axis] || param_poisoned[event_axis] ||
                      expected_index[event_axis]!=event_data[15:0] ||
                      time_now-request_stamp[event_axis]>=PARAM_TIMEOUT_CYCLES ||
                      event_timestamp<request_stamp[event_axis] ||
                      event_timestamp-request_stamp[event_axis]>=PARAM_TIMEOUT_CYCLES) begin accept_event=0;reason=12;end
                2: if(have_fault[event_axis] && event_timestamp<=fault_stamp[event_axis]) begin accept_event=0;reason=11;end
                3: if(have_uid[event_axis] && event_timestamp<=uid_stamp[event_axis]) begin accept_event=0;reason=11;end
                default: begin accept_event=0;reason=7;end
            endcase
        end
        if(param_cancel_valid && param_cancel_ready && cancel_match && event_kind==1 && event_axis==cancel_axis) begin
            accept_event=0;reason=12;
        end
        if(stream_integrity_lost || integrity_lost) begin accept_event=0;reason=8;end
    end
    // Current payloads have one addressed write and one asynchronous addressed read.
    // Valid bits below preserve the externally visible reset-to-zero behavior;
    // the storage itself has no array reset, allowing distributed RAM inference.
    always @(posedge clk) begin
        if(rst_n && event_valid && event_ready && accept_event) begin
            if(event_kind==0) begin
                position_raw[event_axis]<={event_data[7:0],event_data[15:8]};
                velocity_raw[event_axis]<={event_data[23:16],event_data[31:24]};
                torque_raw[event_axis]<={event_data[39:32],event_data[47:40]};
                temperature_raw[event_axis]<={event_data[55:48],event_data[63:56]};
            end
            if(event_kind==2) begin
                faults[event_axis]<=event_data[31:0];
                warnings[event_axis]<=event_data[63:32];
            end
        end
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            transaction_seen<=0;uncertain<=0;param_cancel_done<=0;param_cancel_matched<=0;
            have_status<=0;have_fault<=0;have_uid<=0;previous_timeout<=6'h3F;
            param_pending<=0;param_poisoned<=0;param_req_rejected<=0;
            param_reply_valid<=0;param_reply_failed<=0;param_reply_axis<=0;
            param_reply_index<=0;param_reply_bits<=0;param_reply_token<=0;
            integrity_lost<=0;accepted_frame_count<=0;invalid_frame_count<=0;
            stale_frame_count<=0;parameter_unmatched_count<=0;parameter_timeout_count<=0;last_reject_reason<=0;
            id_mismatch_count<=0;diag_timeout_seen<=0;
            for(i=0;i<6;i=i+1) begin
                pattern[i]<=0;errors[i]<=0;
                sticky_fault[i]<=0;sticky_warning[i]<=0;
                feedback_stamp[i]<=0;frame_stamp[i]<=0;fault_stamp[i]<=0;uid_stamp[i]<=0;uid_raw[i]<=0;
                frames[i]<=0;statuses[i]<=0;invalids[i]<=0;timeouts[i]<=0;
                expected_index[i]<=0;expected_token[i]<=0;request_stamp[i]<=0;
                last_index[i]<=0;last_bits[i]<=0;last_token[i]<=0;parameter_stamp[i]<=0;
                parameter_count[i]<=0;parameter_failures[i]<=0;last_id[i]<=0;
            end
        end else begin
            param_cancel_done<=0;param_cancel_matched<=0;
            param_req_rejected<=0;param_reply_valid<=0;param_reply_failed<=0;
            if(stream_integrity_lost) integrity_lost<=1;
            previous_timeout<=feedback_timeout;
            expired_count=0;
            for(i=0;i<6;i=i+1) begin
                if(feedback_timeout[i] && !previous_timeout[i]) begin
                    timeouts[i]<=timeouts[i]+1'b1;
                    diag_timeout_seen[i]<=1;
                end
                if(param_pending[i] && time_now-request_stamp[i]>=PARAM_TIMEOUT_CYCLES) begin
                    param_pending[i]<=0;param_poisoned[i]<=1;expired_count=expired_count+1;
                end
            end
            if(expired_count!=0) parameter_timeout_count<=parameter_timeout_count+expired_count;
            if(param_req_valid && param_req_ready) begin
                if(!req_ok || param_poisoned[req_axis]) param_req_rejected<=1;
                else begin
                    transaction_seen[req_axis]<=1;
                    param_pending[req_axis]<=1;expected_index[req_axis]<=param_req_index;
                    expected_token[req_axis]<=param_req_token;request_stamp[req_axis]<=time_now;
                end
            end
            if(event_valid && event_ready) begin
                if(!accept_event) begin
                    invalid_frame_count<=invalid_frame_count+1'b1;last_reject_reason<=reason;
                    if(event_axis_known && event_axis<6) invalids[event_axis]<=invalids[event_axis]+1'b1;
                    if(reason==11) stale_frame_count<=stale_frame_count+1'b1;
                    if(reason==12) parameter_unmatched_count<=parameter_unmatched_count+1'b1;
                    if(reason==5 || reason==6) id_mismatch_count<=id_mismatch_count+1'b1;
                    if(reason==8) integrity_lost<=1;
                end else begin
                    accepted_frame_count<=accepted_frame_count+1'b1;frames[event_axis]<=frames[event_axis]+1'b1;
                    if(event_timestamp>frame_stamp[event_axis]) frame_stamp[event_axis]<=event_timestamp;
                    last_id[event_axis]<=event_id;
                    case(event_kind)
                        0: begin
                            have_status[event_axis]<=1;feedback_stamp[event_axis]<=event_timestamp;
                            statuses[event_axis]<=statuses[event_axis]+1'b1;
                            pattern[event_axis]<=event_id[23:22];errors[event_axis]<=event_id[21:16];
                        end
                        1: begin
                            param_pending[event_axis]<=0;param_reply_valid<=1;
                            param_reply_failed<=(event_id[23:16]!=0);param_reply_axis<=event_axis;
                            param_reply_index<=event_data[15:0];param_reply_bits<=event_data[63:32];
                            param_reply_token<=expected_token[event_axis];
                            parameter_count[event_axis]<=parameter_count[event_axis]+1'b1;
                            if(event_id[23:16]!=0) parameter_failures[event_axis]<=parameter_failures[event_axis]+1'b1;
                            else begin
                                last_index[event_axis]<=event_data[15:0];last_bits[event_axis]<=event_data[63:32];
                                last_token[event_axis]<=expected_token[event_axis];parameter_stamp[event_axis]<=event_timestamp;
                            end
                        end
                        2: begin
                            have_fault[event_axis]<=1;fault_stamp[event_axis]<=event_timestamp;
                            sticky_fault[event_axis]<=sticky_fault[event_axis]|event_data[31:0];
                            sticky_warning[event_axis]<=sticky_warning[event_axis]|event_data[63:32];
                        end
                        3: begin have_uid[event_axis]<=1;uid_stamp[event_axis]<=event_timestamp;uid_raw[event_axis]<=event_data;end
                    endcase
                end
            end
            // Last assignment wins over timeout/event on the same edge.
            // poison is irreversible until common reset; normal cancel is proof of no CAN submission.
            if(param_cancel_valid && param_cancel_ready) begin
                param_cancel_done<=1;param_cancel_matched<=cancel_match;
                if(cancel_match) begin
                    param_pending[cancel_axis]<=0;
                    if(param_cancel_poison) begin
                        param_poisoned[cancel_axis]<=1;uncertain[cancel_axis]<=1;
                    end else begin
                        param_poisoned[cancel_axis]<=0;transaction_seen[cancel_axis]<=0;
                    end
                end
            end
        end
    end
    always @* begin
        query_valid=0;query_status_valid=0;query_fault_valid=0;query_motor_id=0;
        query_position_raw=0;query_velocity_raw=0;query_torque_raw=0;query_temperature_raw=0;
        query_pattern=0;query_error_code=0;query_fault=0;query_warning=0;query_fault_latched=0;query_warning_latched=0;
        query_feedback_timestamp=0;query_last_frame_timestamp=0;query_fault_timestamp=0;
        query_frame_count=0;query_status_count=0;query_invalid_count=0;query_timeout_count=0;
        query_parameter_index=0;query_parameter_bits=0;query_parameter_token=0;query_parameter_count=0;
        query_parameter_failed_count=0;query_parameter_timestamp=0;query_uid_raw=0;query_last_id=0;
        if(query_axis<6 && mapping_valid) begin
            query_valid=1;query_motor_id=MOTOR_IDS[query_axis*8 +: 8];
            query_status_valid=have_status[query_axis];query_fault_valid=have_fault[query_axis];
            if(have_status[query_axis]) begin
                query_position_raw=position_raw[query_axis];query_velocity_raw=velocity_raw[query_axis];
                query_torque_raw=torque_raw[query_axis];query_temperature_raw=temperature_raw[query_axis];
            end
            query_pattern=pattern[query_axis];query_error_code=errors[query_axis];
            if(have_fault[query_axis]) begin
                query_fault=faults[query_axis];query_warning=warnings[query_axis];
            end
            query_fault_latched=sticky_fault[query_axis];query_warning_latched=sticky_warning[query_axis];
            query_feedback_timestamp=feedback_stamp[query_axis];query_last_frame_timestamp=frame_stamp[query_axis];
            query_fault_timestamp=fault_stamp[query_axis];query_frame_count=frames[query_axis];
            query_status_count=statuses[query_axis];query_invalid_count=invalids[query_axis];query_timeout_count=timeouts[query_axis];
            query_parameter_index=last_index[query_axis];query_parameter_bits=last_bits[query_axis];
            query_parameter_token=last_token[query_axis];query_parameter_count=parameter_count[query_axis];
            query_parameter_failed_count=parameter_failures[query_axis];query_parameter_timestamp=parameter_stamp[query_axis];
            query_uid_raw=uid_raw[query_axis];query_last_id=last_id[query_axis];
        end
    end
endmodule
