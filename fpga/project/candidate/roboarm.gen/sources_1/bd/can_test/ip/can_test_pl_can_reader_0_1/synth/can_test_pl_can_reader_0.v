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


// IP VLNV: xilinx.com:module_ref:can_axi_lite_master:1.0
// IP Revision: 1

(* X_CORE_INFO = "can_axi_lite_master,Vivado 2023.1" *)
(* CHECK_LICENSE_TYPE = "can_test_pl_can_reader_0,can_axi_lite_master,{}" *)
(* CORE_GENERATION_INFO = "can_test_pl_can_reader_0,can_axi_lite_master,{x_ipProduct=Vivado 2023.1,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=can_axi_lite_master,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,POLL_INTERVAL_CYCLES=5000000,TIMEOUT_CYCLES=50000,TXOK_TIMEOUT_CYCLES=500000,SEND_TIMEOUT_CYCLES=1000000,ENABLE_PL_INIT=1,INIT_TIMEOUT_CYCLES=50000000,INIT_POLL_CYCLES=5000,ENABLE_PERIODIC=1,PERIOD_10HZ_CYCLES=5000000,PERIOD_100HZ_CYCLES=500000,PERIOD_200HZ_CYCLES=250000,TXOK\
_POLL_CYCLES=5000,ENABLE_SIX_AXIS=1,ENABLE_RX=1,RX_POLL_CYCLES=2500,RX_FIFO_DEPTH=16,ENABLE_SINGLE_TX=1}" *)
(* IP_DEFINITION_SOURCE = "module_ref" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module can_test_pl_can_reader_0 (
  aclk,
  aresetn,
  m_axi_awaddr,
  m_axi_awprot,
  m_axi_awvalid,
  m_axi_awready,
  m_axi_wdata,
  m_axi_wstrb,
  m_axi_wvalid,
  m_axi_wready,
  m_axi_bresp,
  m_axi_bvalid,
  m_axi_bready,
  m_axi_araddr,
  m_axi_arprot,
  m_axi_arvalid,
  m_axi_arready,
  m_axi_rdata,
  m_axi_rresp,
  m_axi_rvalid,
  m_axi_rready,
  status_value,
  success_count,
  completed_count,
  timeout_count,
  error_flags,
  last_rresp,
  rresp_valid,
  read_done,
  busy,
  debug_state,
  transaction_timeout,
  send_req,
  single_tx_req_valid,
  single_tx_req_ready,
  single_tx_can_id,
  single_tx_can_dlc,
  single_tx_can_data,
  single_tx_done,
  single_tx_result_valid,
  single_tx_success,
  single_tx_error,
  single_tx_timeout,
  single_tx_may_have_submitted,
  single_tx_error_code,
  tx_state,
  tx_busy,
  tx_fifo_write_done,
  tx_success,
  tx_error,
  tx_timeout,
  tx_success_count,
  tx_error_count,
  last_bresp,
  last_isr,
  last_sr,
  tx_error_code,
  write_error_flags,
  bus_quarantined,
  tx_may_be_pending,
  send_used,
  clock_locked,
  reset_released,
  can_initialized,
  can_init_error,
  can_init_state,
  can_init_failed_state,
  can_init_error_code,
  can_init_last_status,
  stop_req,
  period_sel,
  limit_sel,
  scheduler_state,
  scheduled_count,
  attempted_count,
  enqueued_count,
  missed_deadline_count,
  last_sequence,
  selected_period,
  frame_limit,
  round_used,
  start_rejected,
  periodic_completed,
  periodic_stopped,
  deadline_violation,
  tx_completed_cycle,
  last_attempt_cycle,
  cycle_seq,
  axis_index,
  cycle_started_count,
  cycle_completed_count,
  missed_cycle_count,
  max_cycle_span_cycles,
  cycle_limit,
  scheduler_fault,
  rx_ready,
  rx_valid,
  rx_can_id,
  rx_ide,
  rx_rtr,
  rx_dlc,
  rx_data,
  rx_timestamp,
  rx_frame_error,
  rx_error_flags,
  rx_integrity_lost,
  rx_service_fault,
  rx_service_state,
  rx_frame_count,
  rx_overflow_count,
  rx_underflow_count,
  rx_axi_error_count,
  rx_invalid_frame_count,
  rx_sw_drop_count,
  rx_fifo_level,
  rx_last_isr,
  rx_last_id,
  rx_last_dlc,
  rx_snapshot_isr,
  rx_snapshot_esr,
  rx_snapshot_ecr,
  rx_snapshot_sr,
  rx_snapshot_status
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF M_AXI, ASSOCIATED_RESET aresetn, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_pl_clk_out1, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
input wire aclk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
input wire aresetn;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWADDR" *)
output wire [31 : 0] m_axi_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWPROT" *)
output wire [2 : 0] m_axi_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWVALID" *)
output wire m_axi_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWREADY" *)
input wire m_axi_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WDATA" *)
output wire [31 : 0] m_axi_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WSTRB" *)
output wire [3 : 0] m_axi_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WVALID" *)
output wire m_axi_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WREADY" *)
input wire m_axi_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BRESP" *)
input wire [1 : 0] m_axi_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BVALID" *)
input wire m_axi_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BREADY" *)
output wire m_axi_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARADDR" *)
output wire [31 : 0] m_axi_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARPROT" *)
output wire [2 : 0] m_axi_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARVALID" *)
output wire m_axi_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARREADY" *)
input wire m_axi_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RDATA" *)
input wire [31 : 0] m_axi_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RRESP" *)
input wire [1 : 0] m_axi_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RVALID" *)
input wire m_axi_rvalid;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI, PROTOCOL AXI4LITE, ADDR_WIDTH 32, DATA_WIDTH 32, READ_WRITE_MODE READ_WRITE, HAS_PROT 1, HAS_WSTRB 1, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, FREQ_HZ 50000000, ID_WIDTH 0, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, HAS_BURST 0, HAS_LOCK 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_pl_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RU\
SER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RREADY" *)
output wire m_axi_rready;
output wire [31 : 0] status_value;
output wire [31 : 0] success_count;
output wire [31 : 0] completed_count;
output wire [31 : 0] timeout_count;
output wire [2 : 0] error_flags;
output wire [1 : 0] last_rresp;
output wire rresp_valid;
output wire read_done;
output wire busy;
output wire [1 : 0] debug_state;
output wire transaction_timeout;
input wire send_req;
input wire single_tx_req_valid;
output wire single_tx_req_ready;
input wire [28 : 0] single_tx_can_id;
input wire [7 : 0] single_tx_can_dlc;
input wire [63 : 0] single_tx_can_data;
output wire single_tx_done;
output wire single_tx_result_valid;
output wire single_tx_success;
output wire single_tx_error;
output wire single_tx_timeout;
output wire single_tx_may_have_submitted;
output wire [7 : 0] single_tx_error_code;
output wire [3 : 0] tx_state;
output wire tx_busy;
output wire tx_fifo_write_done;
output wire tx_success;
output wire tx_error;
output wire tx_timeout;
output wire [31 : 0] tx_success_count;
output wire [31 : 0] tx_error_count;
output wire [1 : 0] last_bresp;
output wire [31 : 0] last_isr;
output wire [31 : 0] last_sr;
output wire [3 : 0] tx_error_code;
output wire [3 : 0] write_error_flags;
output wire bus_quarantined;
output wire tx_may_be_pending;
output wire send_used;
input wire clock_locked;
input wire reset_released;
output wire can_initialized;
output wire can_init_error;
output wire [4 : 0] can_init_state;
output wire [4 : 0] can_init_failed_state;
output wire [3 : 0] can_init_error_code;
output wire [31 : 0] can_init_last_status;
input wire stop_req;
input wire [1 : 0] period_sel;
input wire [1 : 0] limit_sel;
output wire [2 : 0] scheduler_state;
output wire [31 : 0] scheduled_count;
output wire [31 : 0] attempted_count;
output wire [31 : 0] enqueued_count;
output wire [31 : 0] missed_deadline_count;
output wire [31 : 0] last_sequence;
output wire [31 : 0] selected_period;
output wire [31 : 0] frame_limit;
output wire round_used;
output wire start_rejected;
output wire periodic_completed;
output wire periodic_stopped;
output wire deadline_violation;
output wire [31 : 0] tx_completed_cycle;
output wire [31 : 0] last_attempt_cycle;
output wire [31 : 0] cycle_seq;
output wire [2 : 0] axis_index;
output wire [31 : 0] cycle_started_count;
output wire [31 : 0] cycle_completed_count;
output wire [31 : 0] missed_cycle_count;
output wire [31 : 0] max_cycle_span_cycles;
output wire [31 : 0] cycle_limit;
output wire scheduler_fault;
input wire rx_ready;
output wire rx_valid;
output wire [28 : 0] rx_can_id;
output wire rx_ide;
output wire rx_rtr;
output wire [3 : 0] rx_dlc;
output wire [63 : 0] rx_data;
output wire [63 : 0] rx_timestamp;
output wire [7 : 0] rx_frame_error;
output wire [7 : 0] rx_error_flags;
output wire rx_integrity_lost;
output wire rx_service_fault;
output wire [3 : 0] rx_service_state;
output wire [31 : 0] rx_frame_count;
output wire [31 : 0] rx_overflow_count;
output wire [31 : 0] rx_underflow_count;
output wire [31 : 0] rx_axi_error_count;
output wire [31 : 0] rx_invalid_frame_count;
output wire [31 : 0] rx_sw_drop_count;
output wire [31 : 0] rx_fifo_level;
output wire [31 : 0] rx_last_isr;
output wire [28 : 0] rx_last_id;
output wire [3 : 0] rx_last_dlc;
output wire [31 : 0] rx_snapshot_isr;
output wire [31 : 0] rx_snapshot_esr;
output wire [31 : 0] rx_snapshot_ecr;
output wire [31 : 0] rx_snapshot_sr;
output wire [7 : 0] rx_snapshot_status;

  can_axi_lite_master #(
    .POLL_INTERVAL_CYCLES(5000000),
    .TIMEOUT_CYCLES(50000),
    .TXOK_TIMEOUT_CYCLES(500000),
    .SEND_TIMEOUT_CYCLES(1000000),
    .ENABLE_PL_INIT(1),
    .INIT_TIMEOUT_CYCLES(50000000),
    .INIT_POLL_CYCLES(5000),
    .ENABLE_PERIODIC(1),
    .PERIOD_10HZ_CYCLES(5000000),
    .PERIOD_100HZ_CYCLES(500000),
    .PERIOD_200HZ_CYCLES(250000),
    .TXOK_POLL_CYCLES(5000),
    .ENABLE_SIX_AXIS(1),
    .ENABLE_RX(1),
    .RX_POLL_CYCLES(2500),
    .RX_FIFO_DEPTH(16),
    .ENABLE_SINGLE_TX(1)
  ) inst (
    .aclk(aclk),
    .aresetn(aresetn),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),
    .status_value(status_value),
    .success_count(success_count),
    .completed_count(completed_count),
    .timeout_count(timeout_count),
    .error_flags(error_flags),
    .last_rresp(last_rresp),
    .rresp_valid(rresp_valid),
    .read_done(read_done),
    .busy(busy),
    .debug_state(debug_state),
    .transaction_timeout(transaction_timeout),
    .send_req(send_req),
    .single_tx_req_valid(single_tx_req_valid),
    .single_tx_req_ready(single_tx_req_ready),
    .single_tx_can_id(single_tx_can_id),
    .single_tx_can_dlc(single_tx_can_dlc),
    .single_tx_can_data(single_tx_can_data),
    .single_tx_done(single_tx_done),
    .single_tx_result_valid(single_tx_result_valid),
    .single_tx_success(single_tx_success),
    .single_tx_error(single_tx_error),
    .single_tx_timeout(single_tx_timeout),
    .single_tx_may_have_submitted(single_tx_may_have_submitted),
    .single_tx_error_code(single_tx_error_code),
    .tx_state(tx_state),
    .tx_busy(tx_busy),
    .tx_fifo_write_done(tx_fifo_write_done),
    .tx_success(tx_success),
    .tx_error(tx_error),
    .tx_timeout(tx_timeout),
    .tx_success_count(tx_success_count),
    .tx_error_count(tx_error_count),
    .last_bresp(last_bresp),
    .last_isr(last_isr),
    .last_sr(last_sr),
    .tx_error_code(tx_error_code),
    .write_error_flags(write_error_flags),
    .bus_quarantined(bus_quarantined),
    .tx_may_be_pending(tx_may_be_pending),
    .send_used(send_used),
    .clock_locked(clock_locked),
    .reset_released(reset_released),
    .can_initialized(can_initialized),
    .can_init_error(can_init_error),
    .can_init_state(can_init_state),
    .can_init_failed_state(can_init_failed_state),
    .can_init_error_code(can_init_error_code),
    .can_init_last_status(can_init_last_status),
    .stop_req(stop_req),
    .period_sel(period_sel),
    .limit_sel(limit_sel),
    .scheduler_state(scheduler_state),
    .scheduled_count(scheduled_count),
    .attempted_count(attempted_count),
    .enqueued_count(enqueued_count),
    .missed_deadline_count(missed_deadline_count),
    .last_sequence(last_sequence),
    .selected_period(selected_period),
    .frame_limit(frame_limit),
    .round_used(round_used),
    .start_rejected(start_rejected),
    .periodic_completed(periodic_completed),
    .periodic_stopped(periodic_stopped),
    .deadline_violation(deadline_violation),
    .tx_completed_cycle(tx_completed_cycle),
    .last_attempt_cycle(last_attempt_cycle),
    .cycle_seq(cycle_seq),
    .axis_index(axis_index),
    .cycle_started_count(cycle_started_count),
    .cycle_completed_count(cycle_completed_count),
    .missed_cycle_count(missed_cycle_count),
    .max_cycle_span_cycles(max_cycle_span_cycles),
    .cycle_limit(cycle_limit),
    .scheduler_fault(scheduler_fault),
    .rx_ready(rx_ready),
    .rx_valid(rx_valid),
    .rx_can_id(rx_can_id),
    .rx_ide(rx_ide),
    .rx_rtr(rx_rtr),
    .rx_dlc(rx_dlc),
    .rx_data(rx_data),
    .rx_timestamp(rx_timestamp),
    .rx_frame_error(rx_frame_error),
    .rx_error_flags(rx_error_flags),
    .rx_integrity_lost(rx_integrity_lost),
    .rx_service_fault(rx_service_fault),
    .rx_service_state(rx_service_state),
    .rx_frame_count(rx_frame_count),
    .rx_overflow_count(rx_overflow_count),
    .rx_underflow_count(rx_underflow_count),
    .rx_axi_error_count(rx_axi_error_count),
    .rx_invalid_frame_count(rx_invalid_frame_count),
    .rx_sw_drop_count(rx_sw_drop_count),
    .rx_fifo_level(rx_fifo_level),
    .rx_last_isr(rx_last_isr),
    .rx_last_id(rx_last_id),
    .rx_last_dlc(rx_last_dlc),
    .rx_snapshot_isr(rx_snapshot_isr),
    .rx_snapshot_esr(rx_snapshot_esr),
    .rx_snapshot_ecr(rx_snapshot_ecr),
    .rx_snapshot_sr(rx_snapshot_sr),
    .rx_snapshot_status(rx_snapshot_status)
  );
endmodule
