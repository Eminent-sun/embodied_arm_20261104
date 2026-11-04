`timescale 1ns / 1ps
// Receive-only protocol state. Explicit address/timeout configuration is mandatory.
// The timebase shares the B1 AXI clock/reset; timestamps are service times, not CAN SOF.
module robstride_protocol #(
    parameter integer CONFIG_ENABLE=0,
    parameter [7:0] HOST_ID=0,
    // Sized hex default makes Vivado Module Reference infer a 48-bit bitString,
    // rather than emit an overflowing unsized decimal parameter in its wrapper.
    // Byte i maps Axis i; zero retains the existing invalid/unconfigured default.
    parameter [47:0] MOTOR_IDS=48'h000000000000,
    parameter integer ALLOW_IDENTITY=0,
    parameter integer FEEDBACK_TIMEOUT_CYCLES=0,
    parameter integer PARAM_TIMEOUT_CYCLES=0
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_RESET rst_n, FREQ_HZ 50000000" *)
    input wire clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW" *)
    input wire rst_n,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire consume_enable,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire frame_valid,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire frame_ready,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire [28:0] can_id,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire can_ide,can_rtr,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire [3:0] can_dlc,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire [63:0] can_data,frame_timestamp,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire [7:0] frame_error,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire stream_integrity_lost,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire param_req_valid,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire param_req_ready,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire [7:0] param_req_host,param_req_motor,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire [15:0] param_req_index,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire [31:0] param_req_token,
    (* X_INTERFACE_IGNORE = "true" *)
    // Lifecycle control: valid/ready request; result pulses on the next cycle.
    input wire param_cancel_valid,
    output wire param_cancel_ready,
    input wire [7:0] param_cancel_motor,
    input wire [15:0] param_cancel_index,
    input wire [31:0] param_cancel_token,
    input wire param_cancel_poison,
    output wire param_cancel_done,param_cancel_matched,
    // Live query uses param_req fields, including token; expiry gates TX combinationally.
    output wire param_req_active,
    output wire param_req_rejected,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire param_reply_valid,param_reply_failed,
    output wire status_event_valid,
    output wire [7:0] status_event_motor,
    output wire [5:0] status_event_error,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [2:0] param_reply_axis,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [15:0] param_reply_index,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [31:0] param_reply_bits,param_reply_token,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [5:0] param_pending,param_poisoned,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire [2:0] query_axis,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire query_valid,query_status_valid,query_fault_valid,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [7:0] query_motor_id,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [15:0] query_position_raw,query_velocity_raw,query_torque_raw,query_temperature_raw,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [1:0] query_pattern,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [5:0] query_error_code,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [31:0] query_fault,query_warning,query_fault_latched,query_warning_latched,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [63:0] query_feedback_timestamp,query_last_frame_timestamp,query_fault_timestamp,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [31:0] query_frame_count,query_status_count,query_invalid_count,query_timeout_count,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [15:0] query_parameter_index,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [31:0] query_parameter_bits,query_parameter_token,query_parameter_count,query_parameter_failed_count,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [63:0] query_parameter_timestamp,query_uid_raw,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [28:0] query_last_id,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [5:0] feedback_timeout,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire mapping_valid,watchdog_config_valid,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire integrity_lost,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [31:0] accepted_frame_count,invalid_frame_count,stale_frame_count,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [31:0] parameter_unmatched_count,parameter_timeout_count,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [3:0] last_reject_reason,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire [4:0] debug_page,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire [31:0] rx_snapshot_isr,rx_snapshot_esr,rx_snapshot_ecr,rx_snapshot_sr,
    (* X_INTERFACE_IGNORE = "true" *)
    input wire [7:0] rx_snapshot_status,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [31:0] debug_data,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [15:0] diag_event_info,
    (* X_INTERFACE_IGNORE = "true" *)
    output wire [5:0] diag_timeout_seen
);
    reg [63:0] time_now;
    wire event_valid,event_ready,event_axis_known,dispatch_mapping_valid;
    wire [2:0] event_kind,event_axis;
    wire [3:0] event_reason;
    wire [28:0] event_id;
    wire [63:0] event_data,event_timestamp;
    wire [31:0] id_mismatch_count;
    always @(posedge clk) begin
        if(!rst_n) time_now<=0;
        else time_now<=time_now+1'b1;
    end
    robstride_rx_dispatch #(.CONFIG_ENABLE(CONFIG_ENABLE),.HOST_ID(HOST_ID),
        .MOTOR_IDS(MOTOR_IDS),.ALLOW_IDENTITY(ALLOW_IDENTITY)) dispatch(
        .clk(clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_ready(frame_ready),
        .can_id(can_id),.can_ide(can_ide),.can_rtr(can_rtr),.can_dlc(can_dlc),
        .can_data(can_data),.frame_timestamp(frame_timestamp),.frame_error(frame_error),
        .stream_integrity_lost(stream_integrity_lost),.mapping_valid(dispatch_mapping_valid),
        .event_valid(event_valid),.event_ready(event_ready),.event_kind(event_kind),
        .event_axis(event_axis),.event_axis_known(event_axis_known),.event_reason(event_reason),
        .event_id(event_id),.event_data(event_data),.event_timestamp(event_timestamp));
    robstride_feedback_bank #(.CONFIG_ENABLE(CONFIG_ENABLE),.HOST_ID(HOST_ID),
        .MOTOR_IDS(MOTOR_IDS),.FEEDBACK_TIMEOUT_CYCLES(FEEDBACK_TIMEOUT_CYCLES),
        .PARAM_TIMEOUT_CYCLES(PARAM_TIMEOUT_CYCLES)) bank(
        .clk(clk),.rst_n(rst_n),.consume_enable(consume_enable),.time_now(time_now),
        .stream_integrity_lost(stream_integrity_lost),.event_valid(event_valid),.event_ready(event_ready),
        .event_kind(event_kind),.event_axis(event_axis),.event_axis_known(event_axis_known),
        .event_reason(event_reason),.event_id(event_id),.event_data(event_data),.event_timestamp(event_timestamp),
        .param_cancel_valid(param_cancel_valid),.param_cancel_ready(param_cancel_ready),
        .param_cancel_motor(param_cancel_motor),.param_cancel_index(param_cancel_index),
        .param_cancel_token(param_cancel_token),.param_cancel_poison(param_cancel_poison),
        .param_cancel_done(param_cancel_done),.param_cancel_matched(param_cancel_matched),
        .param_req_active(param_req_active),
        .param_req_valid(param_req_valid),
        .param_req_ready(param_req_ready),
        .param_req_host(param_req_host),
        .param_req_motor(param_req_motor),
        .param_req_index(param_req_index),
        .param_req_token(param_req_token),
        .param_req_rejected(param_req_rejected),
        .param_reply_valid(param_reply_valid),
        .param_reply_failed(param_reply_failed),
        .status_event_valid(status_event_valid),
        .status_event_motor(status_event_motor),
        .status_event_error(status_event_error),
        .param_reply_axis(param_reply_axis),
        .param_reply_index(param_reply_index),
        .param_reply_bits(param_reply_bits),
        .param_reply_token(param_reply_token),
        .param_pending(param_pending),
        .param_poisoned(param_poisoned),
        .query_axis(query_axis),
        .query_valid(query_valid),
        .query_status_valid(query_status_valid),
        .query_fault_valid(query_fault_valid),
        .query_motor_id(query_motor_id),
        .query_position_raw(query_position_raw),
        .query_velocity_raw(query_velocity_raw),
        .query_torque_raw(query_torque_raw),
        .query_temperature_raw(query_temperature_raw),
        .query_pattern(query_pattern),
        .query_error_code(query_error_code),
        .query_fault(query_fault),
        .query_warning(query_warning),
        .query_fault_latched(query_fault_latched),
        .query_warning_latched(query_warning_latched),
        .query_feedback_timestamp(query_feedback_timestamp),
        .query_last_frame_timestamp(query_last_frame_timestamp),
        .query_fault_timestamp(query_fault_timestamp),
        .query_frame_count(query_frame_count),
        .query_status_count(query_status_count),
        .query_invalid_count(query_invalid_count),
        .query_timeout_count(query_timeout_count),
        .query_parameter_index(query_parameter_index),
        .query_parameter_bits(query_parameter_bits),
        .query_parameter_token(query_parameter_token),
        .query_parameter_count(query_parameter_count),
        .query_parameter_failed_count(query_parameter_failed_count),
        .query_parameter_timestamp(query_parameter_timestamp),
        .query_uid_raw(query_uid_raw),
        .query_last_id(query_last_id),
        .feedback_timeout(feedback_timeout),
        .mapping_valid(mapping_valid),
        .watchdog_config_valid(watchdog_config_valid),
        .integrity_lost(integrity_lost),
        .accepted_frame_count(accepted_frame_count),
        .invalid_frame_count(invalid_frame_count),
        .stale_frame_count(stale_frame_count),
        .parameter_unmatched_count(parameter_unmatched_count),
        .parameter_timeout_count(parameter_timeout_count),
        .last_reject_reason(last_reject_reason),.diag_event_info(diag_event_info),
        .id_mismatch_count(id_mismatch_count),.diag_timeout_seen(diag_timeout_seen));
    robstride_feedback_debug debug_view(
        .page(debug_page),.axis(query_axis),.query_valid(query_valid),
        .status_valid(query_status_valid),.fault_valid(query_fault_valid),
        .motor_id(query_motor_id),.position_raw(query_position_raw),.velocity_raw(query_velocity_raw),
        .torque_raw(query_torque_raw),.temperature_raw(query_temperature_raw),
        .pattern(query_pattern),.error_code(query_error_code),.feedback_timeout(feedback_timeout),
        .integrity_lost(integrity_lost),.mapping_valid(mapping_valid),.watchdog_config_valid(watchdog_config_valid),
        .last_reject_reason(last_reject_reason),.status_count(query_status_count),.frame_count(query_frame_count),
        .invalid_count(query_invalid_count),.timeout_count(query_timeout_count),
        .fault(query_fault),.warning(query_warning),.fault_latched(query_fault_latched),.warning_latched(query_warning_latched),
        .time_now(time_now),.last_frame_timestamp(query_last_frame_timestamp),.fault_timestamp(query_fault_timestamp),
        .id_mismatch_count(id_mismatch_count),.stale_count(stale_frame_count),
        .parameter_unmatched_count(parameter_unmatched_count),.last_id(query_last_id),
        .diag_isr_snapshot(rx_snapshot_isr),.diag_esr_snapshot(rx_snapshot_esr),
        .diag_ecr_snapshot(rx_snapshot_ecr),.diag_sr_snapshot(rx_snapshot_sr),
        .diag_snapshot_status(rx_snapshot_status),.data(debug_data));
endmodule
