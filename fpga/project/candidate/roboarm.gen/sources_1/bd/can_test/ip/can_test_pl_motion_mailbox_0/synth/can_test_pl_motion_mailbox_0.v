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


// IP VLNV: xilinx.com:module_ref:pl_motion_mailbox:1.0
// IP Revision: 1

(* X_CORE_INFO = "pl_motion_mailbox,Vivado 2023.1" *)
(* CHECK_LICENSE_TYPE = "can_test_pl_motion_mailbox_0,pl_motion_mailbox,{}" *)
(* CORE_GENERATION_INFO = "can_test_pl_motion_mailbox_0,pl_motion_mailbox,{x_ipProduct=Vivado 2023.1,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=pl_motion_mailbox,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,ABI_VERSION=0x00020009}" *)
(* IP_DEFINITION_SOURCE = "module_ref" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module can_test_pl_motion_mailbox_0 (
  clk,
  rst_n,
  s_axi_awaddr,
  s_axi_awvalid,
  s_axi_awready,
  s_axi_wdata,
  s_axi_wstrb,
  s_axi_wvalid,
  s_axi_wready,
  s_axi_bresp,
  s_axi_bvalid,
  s_axi_bready,
  s_axi_araddr,
  s_axi_arvalid,
  s_axi_arready,
  s_axi_rdata,
  s_axi_rresp,
  s_axi_rvalid,
  s_axi_rready,
  engine_start,
  engine_word,
  engine_reserved,
  engine_value,
  query_axis,
  query_page,
  command_busy,
  command_done,
  command_success,
  command_error,
  fault_locked,
  command_state,
  command_error_code,
  result_value,
  command_accepted,
  command_rejected,
  clock_locked,
  can_initialized,
  can_init_error,
  mapping_valid,
  integrity_lost,
  feedback_timeout,
  param_pending,
  param_poisoned,
  feedback_data,
  rx_frame_count,
  rx_last_isr,
  rx_overflow_count,
  rx_error_flags,
  tx_error_code,
  tx_may_be_pending
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET rst_n, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN /clk_pl_clk_out1, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
input wire clk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
input wire rst_n;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
input wire [11 : 0] s_axi_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
input wire s_axi_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
output wire s_axi_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
input wire [31 : 0] s_axi_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
input wire [3 : 0] s_axi_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
input wire s_axi_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
output wire s_axi_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
output wire [1 : 0] s_axi_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
output wire s_axi_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
input wire s_axi_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
input wire [11 : 0] s_axi_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
input wire s_axi_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
output wire s_axi_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
output wire [31 : 0] s_axi_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
output wire [1 : 0] s_axi_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
output wire s_axi_rvalid;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI, PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 12, FREQ_HZ 50000000, READ_WRITE_MODE READ_WRITE, ID_WIDTH 0, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN /clk_pl_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RU\
SER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
input wire s_axi_rready;
output wire engine_start;
output wire [28 : 0] engine_word;
output wire [7 : 0] engine_reserved;
output wire [63 : 0] engine_value;
output wire [2 : 0] query_axis;
output wire [4 : 0] query_page;
input wire command_busy;
input wire command_done;
input wire command_success;
input wire command_error;
input wire fault_locked;
input wire [3 : 0] command_state;
input wire [7 : 0] command_error_code;
input wire [31 : 0] result_value;
input wire command_accepted;
input wire command_rejected;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clock_locked, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clock_locked CLK" *)
input wire clock_locked;
input wire can_initialized;
input wire can_init_error;
input wire mapping_valid;
input wire integrity_lost;
input wire [5 : 0] feedback_timeout;
input wire [5 : 0] param_pending;
input wire [5 : 0] param_poisoned;
input wire [31 : 0] feedback_data;
input wire [31 : 0] rx_frame_count;
input wire [31 : 0] rx_last_isr;
input wire [31 : 0] rx_overflow_count;
input wire [7 : 0] rx_error_flags;
input wire [3 : 0] tx_error_code;
input wire tx_may_be_pending;

  pl_motion_mailbox #(
    .ABI_VERSION(32'H00020009)
  ) inst (
    .clk(clk),
    .rst_n(rst_n),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .engine_start(engine_start),
    .engine_word(engine_word),
    .engine_reserved(engine_reserved),
    .engine_value(engine_value),
    .query_axis(query_axis),
    .query_page(query_page),
    .command_busy(command_busy),
    .command_done(command_done),
    .command_success(command_success),
    .command_error(command_error),
    .fault_locked(fault_locked),
    .command_state(command_state),
    .command_error_code(command_error_code),
    .result_value(result_value),
    .command_accepted(command_accepted),
    .command_rejected(command_rejected),
    .clock_locked(clock_locked),
    .can_initialized(can_initialized),
    .can_init_error(can_init_error),
    .mapping_valid(mapping_valid),
    .integrity_lost(integrity_lost),
    .feedback_timeout(feedback_timeout),
    .param_pending(param_pending),
    .param_poisoned(param_poisoned),
    .feedback_data(feedback_data),
    .rx_frame_count(rx_frame_count),
    .rx_last_isr(rx_last_isr),
    .rx_overflow_count(rx_overflow_count),
    .rx_error_flags(rx_error_flags),
    .tx_error_code(tx_error_code),
    .tx_may_be_pending(tx_may_be_pending)
  );
endmodule
