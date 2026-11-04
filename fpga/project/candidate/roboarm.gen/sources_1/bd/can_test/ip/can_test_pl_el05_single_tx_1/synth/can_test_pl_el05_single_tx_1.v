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


// IP VLNV: xilinx.com:module_ref:pl_robstride_command_engine:1.0
// IP Revision: 1

(* X_CORE_INFO = "pl_robstride_command_engine,Vivado 2023.1" *)
(* CHECK_LICENSE_TYPE = "can_test_pl_el05_single_tx_1,pl_robstride_command_engine,{}" *)
(* CORE_GENERATION_INFO = "can_test_pl_el05_single_tx_1,pl_robstride_command_engine,{x_ipProduct=Vivado 2023.1,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=pl_robstride_command_engine,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,HOST_ID=11111101,MOTOR_IDS=0x060504030201,REG_TIMEOUT_CYCLES=1024,TX_ACCEPT_TIMEOUT_CYCLES=1024,TX_RESULT_TIMEOUT_CYCLES=1000000,REPLY_TIMEOUT_CYCLES=1000000,CANCEL_TIMEOUT_CYCLES=1024,ENABLE_PP_TEST=1,ENABLE_MULTI_PP=1,ENABLE_PATH_PP=1,ENABLE_HOLD_PP=1,PA\
TH_WINDOW_CYCLES=10110010110100000101111000000000,PATH_LEASE_CYCLES=00000001011111010111100001000000,PATH_POSITION_AGE_CYCLES=00000001011111010111100001000000,PATH_MAX_STEP_Q16=6554,PP_MAX_DELTA_Q16=824442,PP_MAX_SPEED_BITS=0x404CCCCD,PP_MAX_ACCEL_BITS=0x404CCCCD,PP_WINDOW_CYCLES=500000000,PP_POSITION_AGE_CYCLES=1500000000}" *)
(* IP_DEFINITION_SOURCE = "module_ref" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module can_test_pl_el05_single_tx_1 (
  clk,
  rst_n,
  start,
  command_word,
  byte_reserved,
  command_value_word,
  mapping_valid,
  stream_integrity_lost,
  param_pending,
  param_poisoned,
  param_req_valid,
  param_req_ready,
  param_req_rejected,
  param_req_active,
  param_req_host,
  param_req_motor,
  param_req_index,
  param_req_token,
  param_cancel_valid,
  param_cancel_ready,
  param_cancel_done,
  param_cancel_matched,
  param_cancel_motor,
  param_cancel_index,
  param_cancel_token,
  param_cancel_poison,
  param_reply_valid,
  param_reply_failed,
  param_reply_axis,
  param_reply_index,
  param_reply_bits,
  param_reply_token,
  status_event_valid,
  status_event_motor,
  status_event_error,
  tx_req_valid,
  tx_req_ready,
  tx_can_id,
  tx_can_dlc,
  tx_can_data,
  tx_done,
  tx_success,
  tx_may_have_submitted,
  tx_error_code,
  command_busy,
  fault_locked,
  command_done,
  command_success,
  command_error,
  command_error_code,
  result_value,
  command_state,
  command_start_accepted,
  command_param_registered,
  command_rejected
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_pl_clk_out1, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
input wire clk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
input wire rst_n;
input wire start;
input wire [28 : 0] command_word;
input wire [7 : 0] byte_reserved;
input wire [63 : 0] command_value_word;
input wire mapping_valid;
input wire stream_integrity_lost;
input wire [5 : 0] param_pending;
input wire [5 : 0] param_poisoned;
output wire param_req_valid;
input wire param_req_ready;
input wire param_req_rejected;
input wire param_req_active;
output wire [7 : 0] param_req_host;
output wire [7 : 0] param_req_motor;
output wire [15 : 0] param_req_index;
output wire [31 : 0] param_req_token;
output wire param_cancel_valid;
input wire param_cancel_ready;
input wire param_cancel_done;
input wire param_cancel_matched;
output wire [7 : 0] param_cancel_motor;
output wire [15 : 0] param_cancel_index;
output wire [31 : 0] param_cancel_token;
output wire param_cancel_poison;
input wire param_reply_valid;
input wire param_reply_failed;
input wire [2 : 0] param_reply_axis;
input wire [15 : 0] param_reply_index;
input wire [31 : 0] param_reply_bits;
input wire [31 : 0] param_reply_token;
input wire status_event_valid;
input wire [7 : 0] status_event_motor;
input wire [5 : 0] status_event_error;
output wire tx_req_valid;
input wire tx_req_ready;
output wire [28 : 0] tx_can_id;
output wire [7 : 0] tx_can_dlc;
output wire [63 : 0] tx_can_data;
input wire tx_done;
input wire tx_success;
input wire tx_may_have_submitted;
input wire [7 : 0] tx_error_code;
output wire command_busy;
output wire fault_locked;
output wire command_done;
output wire command_success;
output wire command_error;
output wire [7 : 0] command_error_code;
output wire [31 : 0] result_value;
output wire [3 : 0] command_state;
output wire command_start_accepted;
output wire command_param_registered;
output wire command_rejected;

  pl_robstride_command_engine #(
    .HOST_ID(8'B11111101),
    .MOTOR_IDS(48'H060504030201),
    .REG_TIMEOUT_CYCLES(1024),
    .TX_ACCEPT_TIMEOUT_CYCLES(1024),
    .TX_RESULT_TIMEOUT_CYCLES(1000000),
    .REPLY_TIMEOUT_CYCLES(1000000),
    .CANCEL_TIMEOUT_CYCLES(1024),
    .ENABLE_PP_TEST(1),
    .ENABLE_MULTI_PP(1),
    .ENABLE_PATH_PP(1),
    .ENABLE_HOLD_PP(1),
    .PATH_WINDOW_CYCLES(32'B10110010110100000101111000000000),
    .PATH_LEASE_CYCLES(32'B00000001011111010111100001000000),
    .PATH_POSITION_AGE_CYCLES(32'B00000001011111010111100001000000),
    .PATH_MAX_STEP_Q16(6554),
    .PP_MAX_DELTA_Q16(824442),
    .PP_MAX_SPEED_BITS(32'H404CCCCD),
    .PP_MAX_ACCEL_BITS(32'H404CCCCD),
    .PP_WINDOW_CYCLES(500000000),
    .PP_POSITION_AGE_CYCLES(1500000000)
  ) inst (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .command_word(command_word),
    .byte_reserved(byte_reserved),
    .command_value_word(command_value_word),
    .mapping_valid(mapping_valid),
    .stream_integrity_lost(stream_integrity_lost),
    .param_pending(param_pending),
    .param_poisoned(param_poisoned),
    .param_req_valid(param_req_valid),
    .param_req_ready(param_req_ready),
    .param_req_rejected(param_req_rejected),
    .param_req_active(param_req_active),
    .param_req_host(param_req_host),
    .param_req_motor(param_req_motor),
    .param_req_index(param_req_index),
    .param_req_token(param_req_token),
    .param_cancel_valid(param_cancel_valid),
    .param_cancel_ready(param_cancel_ready),
    .param_cancel_done(param_cancel_done),
    .param_cancel_matched(param_cancel_matched),
    .param_cancel_motor(param_cancel_motor),
    .param_cancel_index(param_cancel_index),
    .param_cancel_token(param_cancel_token),
    .param_cancel_poison(param_cancel_poison),
    .param_reply_valid(param_reply_valid),
    .param_reply_failed(param_reply_failed),
    .param_reply_axis(param_reply_axis),
    .param_reply_index(param_reply_index),
    .param_reply_bits(param_reply_bits),
    .param_reply_token(param_reply_token),
    .status_event_valid(status_event_valid),
    .status_event_motor(status_event_motor),
    .status_event_error(status_event_error),
    .tx_req_valid(tx_req_valid),
    .tx_req_ready(tx_req_ready),
    .tx_can_id(tx_can_id),
    .tx_can_dlc(tx_can_dlc),
    .tx_can_data(tx_can_data),
    .tx_done(tx_done),
    .tx_success(tx_success),
    .tx_may_have_submitted(tx_may_have_submitted),
    .tx_error_code(tx_error_code),
    .command_busy(command_busy),
    .fault_locked(fault_locked),
    .command_done(command_done),
    .command_success(command_success),
    .command_error(command_error),
    .command_error_code(command_error_code),
    .result_value(result_value),
    .command_state(command_state),
    .command_start_accepted(command_start_accepted),
    .command_param_registered(command_param_registered),
    .command_rejected(command_rejected)
  );
endmodule
