// (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// (c) Copyright 2022-2026 Advanced Micro Devices, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and international copyright
// and other intellectual property laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: xilinx.com:module_ref:robstride_protocol:1.0
// IP Revision: 1

(* X_CORE_INFO = "robstride_protocol,Vivado 2023.1" *)
(* CHECK_LICENSE_TYPE = "can_test_pl_robstride_feedback_0,robstride_protocol,{}" *)
(* CORE_GENERATION_INFO = "can_test_pl_robstride_feedback_0,robstride_protocol,{x_ipProduct=Vivado 2023.1,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=robstride_protocol,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,CONFIG_ENABLE=1,HOST_ID=253,MOTOR_IDS=0x060504030201,ALLOW_IDENTITY=0,FEEDBACK_TIMEOUT_CYCLES=5000000,PARAM_TIMEOUT_CYCLES=5000000}" *)
(* IP_DEFINITION_SOURCE = "module_ref" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module can_test_pl_robstride_feedback_0 (
  clk,
  rst_n,
  consume_enable,
  frame_valid,
  frame_ready,
  can_id,
  can_ide,
  can_rtr,
  can_dlc,
  can_data,
  frame_timestamp,
  frame_error,
  stream_integrity_lost,
  param_req_valid,
  param_req_ready,
  param_req_host,
  param_req_motor,
  param_req_index,
  param_req_token,
  param_cancel_valid,
  param_cancel_ready,
  param_cancel_motor,
  param_cancel_index,
  param_cancel_token,
  param_cancel_poison,
  param_cancel_done,
  param_cancel_matched,
  param_req_active,
  param_req_rejected,
  param_reply_valid,
  param_reply_failed,
  status_event_valid,
  status_event_motor,
  status_event_error,
  param_reply_axis,
  param_reply_index,
  param_reply_bits,
  param_reply_token,
  param_pending,
  param_poisoned,
  query_axis,
  query_valid,
  query_status_valid,
  query_fault_valid,
  query_motor_id,
  query_position_raw,
  query_velocity_raw,
  query_torque_raw,
  query_temperature_raw,
  query_pattern,
  query_error_code,
  query_fault,
  query_warning,
  query_fault_latched,
  query_warning_latched,
  query_feedback_timestamp,
  query_last_frame_timestamp,
  query_fault_timestamp,
  query_frame_count,
  query_status_count,
  query_invalid_count,
  query_timeout_count,
  query_parameter_index,
  query_parameter_bits,
  query_parameter_token,
  query_parameter_count,
  query_parameter_failed_count,
  query_parameter_timestamp,
  query_uid_raw,
  query_last_id,
  feedback_timeout,
  mapping_valid,
  watchdog_config_valid,
  integrity_lost,
  accepted_frame_count,
  invalid_frame_count,
  stale_frame_count,
  parameter_unmatched_count,
  parameter_timeout_count,
  last_reject_reason,
  debug_page,
  rx_snapshot_isr,
  rx_snapshot_esr,
  rx_snapshot_ecr,
  rx_snapshot_sr,
  rx_snapshot_status,
  debug_data,
  diag_event_info,
  diag_timeout_seen
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_RESET rst_n, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_pl_clk_out1, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
input wire clk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
input wire rst_n;
input wire consume_enable;
input wire frame_valid;
output wire frame_ready;
input wire [28 : 0] can_id;
input wire can_ide;
input wire can_rtr;
input wire [3 : 0] can_dlc;
input wire [63 : 0] can_data;
input wire [63 : 0] frame_timestamp;
input wire [7 : 0] frame_error;
input wire stream_integrity_lost;
input wire param_req_valid;
output wire param_req_ready;
input wire [7 : 0] param_req_host;
input wire [7 : 0] param_req_motor;
input wire [15 : 0] param_req_index;
input wire [31 : 0] param_req_token;
input wire param_cancel_valid;
output wire param_cancel_ready;
input wire [7 : 0] param_cancel_motor;
input wire [15 : 0] param_cancel_index;
input wire [31 : 0] param_cancel_token;
input wire param_cancel_poison;
output wire param_cancel_done;
output wire param_cancel_matched;
output wire param_req_active;
output wire param_req_rejected;
output wire param_reply_valid;
output wire param_reply_failed;
output wire status_event_valid;
output wire [7 : 0] status_event_motor;
output wire [5 : 0] status_event_error;
output wire [2 : 0] param_reply_axis;
output wire [15 : 0] param_reply_index;
output wire [31 : 0] param_reply_bits;
output wire [31 : 0] param_reply_token;
output wire [5 : 0] param_pending;
output wire [5 : 0] param_poisoned;
input wire [2 : 0] query_axis;
output wire query_valid;
output wire query_status_valid;
output wire query_fault_valid;
output wire [7 : 0] query_motor_id;
output wire [15 : 0] query_position_raw;
output wire [15 : 0] query_velocity_raw;
output wire [15 : 0] query_torque_raw;
output wire [15 : 0] query_temperature_raw;
output wire [1 : 0] query_pattern;
output wire [5 : 0] query_error_code;
output wire [31 : 0] query_fault;
output wire [31 : 0] query_warning;
output wire [31 : 0] query_fault_latched;
output wire [31 : 0] query_warning_latched;
output wire [63 : 0] query_feedback_timestamp;
output wire [63 : 0] query_last_frame_timestamp;
output wire [63 : 0] query_fault_timestamp;
output wire [31 : 0] query_frame_count;
output wire [31 : 0] query_status_count;
output wire [31 : 0] query_invalid_count;
output wire [31 : 0] query_timeout_count;
output wire [15 : 0] query_parameter_index;
output wire [31 : 0] query_parameter_bits;
output wire [31 : 0] query_parameter_token;
output wire [31 : 0] query_parameter_count;
output wire [31 : 0] query_parameter_failed_count;
output wire [63 : 0] query_parameter_timestamp;
output wire [63 : 0] query_uid_raw;
output wire [28 : 0] query_last_id;
output wire [5 : 0] feedback_timeout;
output wire mapping_valid;
output wire watchdog_config_valid;
output wire integrity_lost;
output wire [31 : 0] accepted_frame_count;
output wire [31 : 0] invalid_frame_count;
output wire [31 : 0] stale_frame_count;
output wire [31 : 0] parameter_unmatched_count;
output wire [31 : 0] parameter_timeout_count;
output wire [3 : 0] last_reject_reason;
input wire [4 : 0] debug_page;
input wire [31 : 0] rx_snapshot_isr;
input wire [31 : 0] rx_snapshot_esr;
input wire [31 : 0] rx_snapshot_ecr;
input wire [31 : 0] rx_snapshot_sr;
input wire [7 : 0] rx_snapshot_status;
output wire [31 : 0] debug_data;
output wire [15 : 0] diag_event_info;
output wire [5 : 0] diag_timeout_seen;

  robstride_protocol #(
    .CONFIG_ENABLE(1),
    .HOST_ID(253),
    .MOTOR_IDS(48'H060504030201),
    .ALLOW_IDENTITY(0),
    .FEEDBACK_TIMEOUT_CYCLES(5000000),
    .PARAM_TIMEOUT_CYCLES(5000000)
  ) inst (
    .clk(clk),
    .rst_n(rst_n),
    .consume_enable(consume_enable),
    .frame_valid(frame_valid),
    .frame_ready(frame_ready),
    .can_id(can_id),
    .can_ide(can_ide),
    .can_rtr(can_rtr),
    .can_dlc(can_dlc),
    .can_data(can_data),
    .frame_timestamp(frame_timestamp),
    .frame_error(frame_error),
    .stream_integrity_lost(stream_integrity_lost),
    .param_req_valid(param_req_valid),
    .param_req_ready(param_req_ready),
    .param_req_host(param_req_host),
    .param_req_motor(param_req_motor),
    .param_req_index(param_req_index),
    .param_req_token(param_req_token),
    .param_cancel_valid(param_cancel_valid),
    .param_cancel_ready(param_cancel_ready),
    .param_cancel_motor(param_cancel_motor),
    .param_cancel_index(param_cancel_index),
    .param_cancel_token(param_cancel_token),
    .param_cancel_poison(param_cancel_poison),
    .param_cancel_done(param_cancel_done),
    .param_cancel_matched(param_cancel_matched),
    .param_req_active(param_req_active),
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
    .last_reject_reason(last_reject_reason),
    .debug_page(debug_page),
    .rx_snapshot_isr(rx_snapshot_isr),
    .rx_snapshot_esr(rx_snapshot_esr),
    .rx_snapshot_ecr(rx_snapshot_ecr),
    .rx_snapshot_sr(rx_snapshot_sr),
    .rx_snapshot_status(rx_snapshot_status),
    .debug_data(debug_data),
    .diag_event_info(diag_event_info),
    .diag_timeout_seen(diag_timeout_seen)
  );
endmodule
