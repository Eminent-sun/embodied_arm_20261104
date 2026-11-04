//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2023.1 (win64) Build 3865809 Sun May  7 15:05:29 MDT 2023
//Date        : Wed Nov  4 11:07:46 2026
//Host        : YouShuTing running 64-bit major release  (build 9200)
//Command     : generate_target can_test.bd
//Design      : can_test
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "can_test,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=can_test,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=27,numReposBlks=21,numNonXlnxBlks=0,numHierBlks=6,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=6,numPkgbdBlks=0,bdsource=USER,synth_mode=Global}" *) (* HW_HANDOFF = "can_test.hwdef" *) 
module can_test
   (CAN_RX,
    CAN_TX,
    DDR_addr,
    DDR_ba,
    DDR_cas_n,
    DDR_ck_n,
    DDR_ck_p,
    DDR_cke,
    DDR_cs_n,
    DDR_dm,
    DDR_dq,
    DDR_dqs_n,
    DDR_dqs_p,
    DDR_odt,
    DDR_ras_n,
    DDR_reset_n,
    DDR_we_n,
    FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp,
    FIXED_IO_mio,
    FIXED_IO_ps_clk,
    FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb,
    rst_n,
    servo_pwm,
    sys_clk_50m);
  input CAN_RX;
  output CAN_TX;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR ADDR" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME DDR, AXI_ARBITRATION_SCHEME TDM, BURST_LENGTH 8, CAN_DEBUG false, CAS_LATENCY 11, CAS_WRITE_LATENCY 11, CS_ENABLED true, DATA_MASK_ENABLED true, DATA_WIDTH 8, MEMORY_TYPE COMPONENTS, MEM_ADDR_MAP ROW_COLUMN_BANK, SLOT Single, TIMEPERIOD_PS 1250" *) inout [14:0]DDR_addr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR BA" *) inout [2:0]DDR_ba;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR CAS_N" *) inout DDR_cas_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR CK_N" *) inout DDR_ck_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR CK_P" *) inout DDR_ck_p;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR CKE" *) inout DDR_cke;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR CS_N" *) inout DDR_cs_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR DM" *) inout [3:0]DDR_dm;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR DQ" *) inout [31:0]DDR_dq;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR DQS_N" *) inout [3:0]DDR_dqs_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR DQS_P" *) inout [3:0]DDR_dqs_p;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR ODT" *) inout DDR_odt;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR RAS_N" *) inout DDR_ras_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR RESET_N" *) inout DDR_reset_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx:1.0 DDR WE_N" *) inout DDR_we_n;
  (* X_INTERFACE_INFO = "xilinx.com:display_processing_system7:fixedio:1.0 FIXED_IO DDR_VRN" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME FIXED_IO, CAN_DEBUG false" *) inout FIXED_IO_ddr_vrn;
  (* X_INTERFACE_INFO = "xilinx.com:display_processing_system7:fixedio:1.0 FIXED_IO DDR_VRP" *) inout FIXED_IO_ddr_vrp;
  (* X_INTERFACE_INFO = "xilinx.com:display_processing_system7:fixedio:1.0 FIXED_IO MIO" *) inout [53:0]FIXED_IO_mio;
  (* X_INTERFACE_INFO = "xilinx.com:display_processing_system7:fixedio:1.0 FIXED_IO PS_CLK" *) inout FIXED_IO_ps_clk;
  (* X_INTERFACE_INFO = "xilinx.com:display_processing_system7:fixedio:1.0 FIXED_IO PS_PORB" *) inout FIXED_IO_ps_porb;
  (* X_INTERFACE_INFO = "xilinx.com:display_processing_system7:fixedio:1.0 FIXED_IO PS_SRSTB" *) inout FIXED_IO_ps_srstb;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RST_N RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RST_N, INSERT_VIP 0, POLARITY ACTIVE_LOW" *) input rst_n;
  output servo_pwm;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.SYS_CLK_50M CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.SYS_CLK_50M, CLK_DOMAIN can_test_sys_clk_50m, FREQ_HZ 50000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) input sys_clk_50m;

  wire CAN_RX_1;
  wire axi_can_0_can_phy_tx;
  wire axi_can_0_ip2bus_intrevent;
  wire [31:0]axi_periph_M00_AXI_ARADDR;
  wire axi_periph_M00_AXI_ARREADY;
  wire axi_periph_M00_AXI_ARVALID;
  wire [31:0]axi_periph_M00_AXI_AWADDR;
  wire axi_periph_M00_AXI_AWREADY;
  wire axi_periph_M00_AXI_AWVALID;
  wire axi_periph_M00_AXI_BREADY;
  wire [1:0]axi_periph_M00_AXI_BRESP;
  wire axi_periph_M00_AXI_BVALID;
  wire [31:0]axi_periph_M00_AXI_RDATA;
  wire axi_periph_M00_AXI_RREADY;
  wire [1:0]axi_periph_M00_AXI_RRESP;
  wire axi_periph_M00_AXI_RVALID;
  wire [31:0]axi_periph_M00_AXI_WDATA;
  wire axi_periph_M00_AXI_WREADY;
  wire [3:0]axi_periph_M00_AXI_WSTRB;
  wire axi_periph_M00_AXI_WVALID;
  wire [31:0]axi_periph_M01_AXI_ARADDR;
  wire axi_periph_M01_AXI_ARREADY;
  wire axi_periph_M01_AXI_ARVALID;
  wire [31:0]axi_periph_M01_AXI_AWADDR;
  wire axi_periph_M01_AXI_AWREADY;
  wire axi_periph_M01_AXI_AWVALID;
  wire axi_periph_M01_AXI_BREADY;
  wire [1:0]axi_periph_M01_AXI_BRESP;
  wire axi_periph_M01_AXI_BVALID;
  wire [31:0]axi_periph_M01_AXI_RDATA;
  wire axi_periph_M01_AXI_RREADY;
  wire [1:0]axi_periph_M01_AXI_RRESP;
  wire axi_periph_M01_AXI_RVALID;
  wire [31:0]axi_periph_M01_AXI_WDATA;
  wire axi_periph_M01_AXI_WREADY;
  wire [3:0]axi_periph_M01_AXI_WSTRB;
  wire axi_periph_M01_AXI_WVALID;
  wire [31:0]axi_periph_M02_AXI_ARADDR;
  wire axi_periph_M02_AXI_ARREADY;
  wire axi_periph_M02_AXI_ARVALID;
  wire [31:0]axi_periph_M02_AXI_AWADDR;
  wire axi_periph_M02_AXI_AWREADY;
  wire axi_periph_M02_AXI_AWVALID;
  wire axi_periph_M02_AXI_BREADY;
  wire [1:0]axi_periph_M02_AXI_BRESP;
  wire axi_periph_M02_AXI_BVALID;
  wire [31:0]axi_periph_M02_AXI_RDATA;
  wire axi_periph_M02_AXI_RREADY;
  wire [1:0]axi_periph_M02_AXI_RRESP;
  wire axi_periph_M02_AXI_RVALID;
  wire [31:0]axi_periph_M02_AXI_WDATA;
  wire axi_periph_M02_AXI_WREADY;
  wire [3:0]axi_periph_M02_AXI_WSTRB;
  wire axi_periph_M02_AXI_WVALID;
  wire [15:0]b2_zero16_dout;
  wire [0:0]b2_zero1_dout;
  wire [31:0]b2_zero32_dout;
  wire [7:0]b2_zero8_dout;
  wire clk_pl_clk_out1;
  wire clk_pl_clk_out2;
  wire clk_pl_locked;
  wire [0:0]const_one_dout;
  wire [0:0]const_zero_dout;
  wire [1:0]legacy_idle2_dout;
  wire [31:0]pl_can_reader_M_AXI_ARADDR;
  wire [2:0]pl_can_reader_M_AXI_ARPROT;
  wire pl_can_reader_M_AXI_ARREADY;
  wire pl_can_reader_M_AXI_ARVALID;
  wire [31:0]pl_can_reader_M_AXI_AWADDR;
  wire [2:0]pl_can_reader_M_AXI_AWPROT;
  wire pl_can_reader_M_AXI_AWREADY;
  wire pl_can_reader_M_AXI_AWVALID;
  wire pl_can_reader_M_AXI_BREADY;
  wire [1:0]pl_can_reader_M_AXI_BRESP;
  wire pl_can_reader_M_AXI_BVALID;
  wire [31:0]pl_can_reader_M_AXI_RDATA;
  wire pl_can_reader_M_AXI_RREADY;
  wire [1:0]pl_can_reader_M_AXI_RRESP;
  wire pl_can_reader_M_AXI_RVALID;
  wire [31:0]pl_can_reader_M_AXI_WDATA;
  wire pl_can_reader_M_AXI_WREADY;
  wire [3:0]pl_can_reader_M_AXI_WSTRB;
  wire pl_can_reader_M_AXI_WVALID;
  wire [31:0]pl_can_reader_attempted_count;
  wire [2:0]pl_can_reader_axis_index;
  wire pl_can_reader_bus_quarantined;
  wire pl_can_reader_busy;
  wire pl_can_reader_can_init_error;
  wire [3:0]pl_can_reader_can_init_error_code;
  wire [4:0]pl_can_reader_can_init_failed_state;
  wire [31:0]pl_can_reader_can_init_last_status;
  wire [4:0]pl_can_reader_can_init_state;
  wire pl_can_reader_can_initialized;
  wire [31:0]pl_can_reader_completed_count;
  wire [31:0]pl_can_reader_cycle_completed_count;
  wire [31:0]pl_can_reader_cycle_limit;
  wire [31:0]pl_can_reader_cycle_seq;
  wire [31:0]pl_can_reader_cycle_started_count;
  wire pl_can_reader_deadline_violation;
  wire [1:0]pl_can_reader_debug_state;
  wire [31:0]pl_can_reader_enqueued_count;
  wire [2:0]pl_can_reader_error_flags;
  wire [31:0]pl_can_reader_frame_limit;
  wire [31:0]pl_can_reader_last_attempt_cycle;
  wire [1:0]pl_can_reader_last_bresp;
  wire [31:0]pl_can_reader_last_isr;
  wire [1:0]pl_can_reader_last_rresp;
  wire [31:0]pl_can_reader_last_sequence;
  wire [31:0]pl_can_reader_last_sr;
  wire [31:0]pl_can_reader_max_cycle_span_cycles;
  wire [31:0]pl_can_reader_missed_cycle_count;
  wire [31:0]pl_can_reader_missed_deadline_count;
  wire pl_can_reader_periodic_completed;
  wire pl_can_reader_periodic_stopped;
  wire pl_can_reader_read_done;
  wire pl_can_reader_round_used;
  wire pl_can_reader_rresp_valid;
  wire [31:0]pl_can_reader_rx_axi_error_count;
  wire [28:0]pl_can_reader_rx_can_id;
  wire [63:0]pl_can_reader_rx_data;
  wire [3:0]pl_can_reader_rx_dlc;
  wire [7:0]pl_can_reader_rx_error_flags;
  wire [31:0]pl_can_reader_rx_fifo_level;
  wire [31:0]pl_can_reader_rx_frame_count;
  wire [7:0]pl_can_reader_rx_frame_error;
  wire pl_can_reader_rx_ide;
  wire pl_can_reader_rx_integrity_lost;
  wire [31:0]pl_can_reader_rx_invalid_frame_count;
  wire [3:0]pl_can_reader_rx_last_dlc;
  wire [28:0]pl_can_reader_rx_last_id;
  wire [31:0]pl_can_reader_rx_last_isr;
  wire [31:0]pl_can_reader_rx_overflow_count;
  wire pl_can_reader_rx_rtr;
  wire pl_can_reader_rx_service_fault;
  wire [3:0]pl_can_reader_rx_service_state;
  wire [31:0]pl_can_reader_rx_snapshot_ecr;
  wire [31:0]pl_can_reader_rx_snapshot_esr;
  wire [31:0]pl_can_reader_rx_snapshot_isr;
  wire [31:0]pl_can_reader_rx_snapshot_sr;
  wire [7:0]pl_can_reader_rx_snapshot_status;
  wire [31:0]pl_can_reader_rx_sw_drop_count;
  wire [63:0]pl_can_reader_rx_timestamp;
  wire [31:0]pl_can_reader_rx_underflow_count;
  wire pl_can_reader_rx_valid;
  wire [31:0]pl_can_reader_scheduled_count;
  wire pl_can_reader_scheduler_fault;
  wire [2:0]pl_can_reader_scheduler_state;
  wire [31:0]pl_can_reader_selected_period;
  wire pl_can_reader_send_used;
  wire pl_can_reader_single_tx_done;
  wire pl_can_reader_single_tx_error;
  wire [7:0]pl_can_reader_single_tx_error_code;
  wire pl_can_reader_single_tx_may_have_submitted;
  wire pl_can_reader_single_tx_req_ready;
  wire pl_can_reader_single_tx_result_valid;
  wire pl_can_reader_single_tx_success;
  wire pl_can_reader_single_tx_timeout;
  wire pl_can_reader_start_rejected;
  wire [31:0]pl_can_reader_status_value;
  wire [31:0]pl_can_reader_success_count;
  wire [31:0]pl_can_reader_timeout_count;
  wire pl_can_reader_transaction_timeout;
  wire pl_can_reader_tx_busy;
  wire [31:0]pl_can_reader_tx_completed_cycle;
  wire pl_can_reader_tx_error;
  wire [3:0]pl_can_reader_tx_error_code;
  wire [31:0]pl_can_reader_tx_error_count;
  wire pl_can_reader_tx_fifo_write_done;
  wire pl_can_reader_tx_may_be_pending;
  wire [3:0]pl_can_reader_tx_state;
  wire pl_can_reader_tx_success;
  wire [31:0]pl_can_reader_tx_success_count;
  wire pl_can_reader_tx_timeout;
  wire [3:0]pl_can_reader_write_error_flags;
  wire pl_el05_single_tx_command_busy;
  wire pl_el05_single_tx_command_done;
  wire pl_el05_single_tx_command_error;
  wire [7:0]pl_el05_single_tx_command_error_code;
  wire pl_el05_single_tx_command_rejected;
  wire pl_el05_single_tx_command_start_accepted;
  wire [3:0]pl_el05_single_tx_command_state;
  wire pl_el05_single_tx_command_success;
  wire pl_el05_single_tx_fault_locked1;
  wire [15:0]pl_el05_single_tx_param_cancel_index1;
  wire [7:0]pl_el05_single_tx_param_cancel_motor1;
  wire pl_el05_single_tx_param_cancel_poison1;
  wire [31:0]pl_el05_single_tx_param_cancel_token1;
  wire pl_el05_single_tx_param_cancel_valid1;
  wire [7:0]pl_el05_single_tx_param_req_host1;
  wire [15:0]pl_el05_single_tx_param_req_index1;
  wire [7:0]pl_el05_single_tx_param_req_motor1;
  wire [31:0]pl_el05_single_tx_param_req_token1;
  wire pl_el05_single_tx_param_req_valid1;
  wire [31:0]pl_el05_single_tx_result_value;
  wire [63:0]pl_el05_single_tx_tx_can_data1;
  wire [7:0]pl_el05_single_tx_tx_can_dlc1;
  wire [28:0]pl_el05_single_tx_tx_can_id1;
  wire pl_el05_single_tx_tx_req_valid1;
  wire pl_reset_ctrl_axi_aresetn;
  wire pl_reset_ctrl_can_aresetn;
  wire pl_reset_ctrl_can_reset_released_axi;
  wire pl_reset_ctrl_clock_locked_axi;
  wire pl_reset_ctrl_clock_ready;
  wire pl_reset_ctrl_reset_released;
  wire [31:0]pl_robstride_feedback_accepted_frame_count;
  wire [31:0]pl_robstride_feedback_debug_data;
  wire [15:0]pl_robstride_feedback_diag_event_info;
  wire [5:0]pl_robstride_feedback_diag_timeout_seen;
  wire [5:0]pl_robstride_feedback_feedback_timeout;
  wire pl_robstride_feedback_frame_ready;
  wire pl_robstride_feedback_integrity_lost;
  wire [31:0]pl_robstride_feedback_invalid_frame_count;
  wire pl_robstride_feedback_mapping_valid;
  wire pl_robstride_feedback_param_cancel_done;
  wire pl_robstride_feedback_param_cancel_matched;
  wire pl_robstride_feedback_param_cancel_ready;
  wire [5:0]pl_robstride_feedback_param_pending;
  wire [5:0]pl_robstride_feedback_param_poisoned;
  wire [2:0]pl_robstride_feedback_param_reply_axis;
  wire [31:0]pl_robstride_feedback_param_reply_bits;
  wire pl_robstride_feedback_param_reply_failed;
  wire [15:0]pl_robstride_feedback_param_reply_index;
  wire [31:0]pl_robstride_feedback_param_reply_token;
  wire pl_robstride_feedback_param_reply_valid;
  wire pl_robstride_feedback_param_req_active;
  wire pl_robstride_feedback_param_req_ready;
  wire pl_robstride_feedback_param_req_rejected;
  wire [31:0]pl_robstride_feedback_parameter_timeout_count;
  wire [5:0]pl_robstride_feedback_query_error_code;
  wire [31:0]pl_robstride_feedback_query_fault;
  wire [63:0]pl_robstride_feedback_query_feedback_timestamp;
  wire [15:0]pl_robstride_feedback_query_position_raw;
  wire [31:0]pl_robstride_feedback_query_warning;
  wire [5:0]pl_robstride_feedback_status_event_error;
  wire [7:0]pl_robstride_feedback_status_event_motor;
  wire pl_robstride_feedback_status_event_valid;
  wire pl_robstride_feedback_watchdog_config_valid;
  wire pl_servo_axi_servo_pwm;
  wire [14:0]processing_system7_0_DDR_ADDR;
  wire [2:0]processing_system7_0_DDR_BA;
  wire processing_system7_0_DDR_CAS_N;
  wire processing_system7_0_DDR_CKE;
  wire processing_system7_0_DDR_CK_N;
  wire processing_system7_0_DDR_CK_P;
  wire processing_system7_0_DDR_CS_N;
  wire [3:0]processing_system7_0_DDR_DM;
  wire [31:0]processing_system7_0_DDR_DQ;
  wire [3:0]processing_system7_0_DDR_DQS_N;
  wire [3:0]processing_system7_0_DDR_DQS_P;
  wire processing_system7_0_DDR_ODT;
  wire processing_system7_0_DDR_RAS_N;
  wire processing_system7_0_DDR_RESET_N;
  wire processing_system7_0_DDR_WE_N;
  wire processing_system7_0_FIXED_IO_DDR_VRN;
  wire processing_system7_0_FIXED_IO_DDR_VRP;
  wire [53:0]processing_system7_0_FIXED_IO_MIO;
  wire processing_system7_0_FIXED_IO_PS_CLK;
  wire processing_system7_0_FIXED_IO_PS_PORB;
  wire processing_system7_0_FIXED_IO_PS_SRSTB;
  wire [31:0]processing_system7_0_M_AXI_GP0_ARADDR;
  wire [1:0]processing_system7_0_M_AXI_GP0_ARBURST;
  wire [3:0]processing_system7_0_M_AXI_GP0_ARCACHE;
  wire [11:0]processing_system7_0_M_AXI_GP0_ARID;
  wire [3:0]processing_system7_0_M_AXI_GP0_ARLEN;
  wire [1:0]processing_system7_0_M_AXI_GP0_ARLOCK;
  wire [2:0]processing_system7_0_M_AXI_GP0_ARPROT;
  wire [3:0]processing_system7_0_M_AXI_GP0_ARQOS;
  wire processing_system7_0_M_AXI_GP0_ARREADY;
  wire [2:0]processing_system7_0_M_AXI_GP0_ARSIZE;
  wire processing_system7_0_M_AXI_GP0_ARVALID;
  wire [31:0]processing_system7_0_M_AXI_GP0_AWADDR;
  wire [1:0]processing_system7_0_M_AXI_GP0_AWBURST;
  wire [3:0]processing_system7_0_M_AXI_GP0_AWCACHE;
  wire [11:0]processing_system7_0_M_AXI_GP0_AWID;
  wire [3:0]processing_system7_0_M_AXI_GP0_AWLEN;
  wire [1:0]processing_system7_0_M_AXI_GP0_AWLOCK;
  wire [2:0]processing_system7_0_M_AXI_GP0_AWPROT;
  wire [3:0]processing_system7_0_M_AXI_GP0_AWQOS;
  wire processing_system7_0_M_AXI_GP0_AWREADY;
  wire [2:0]processing_system7_0_M_AXI_GP0_AWSIZE;
  wire processing_system7_0_M_AXI_GP0_AWVALID;
  wire [11:0]processing_system7_0_M_AXI_GP0_BID;
  wire processing_system7_0_M_AXI_GP0_BREADY;
  wire [1:0]processing_system7_0_M_AXI_GP0_BRESP;
  wire processing_system7_0_M_AXI_GP0_BVALID;
  wire [31:0]processing_system7_0_M_AXI_GP0_RDATA;
  wire [11:0]processing_system7_0_M_AXI_GP0_RID;
  wire processing_system7_0_M_AXI_GP0_RLAST;
  wire processing_system7_0_M_AXI_GP0_RREADY;
  wire [1:0]processing_system7_0_M_AXI_GP0_RRESP;
  wire processing_system7_0_M_AXI_GP0_RVALID;
  wire [31:0]processing_system7_0_M_AXI_GP0_WDATA;
  wire [11:0]processing_system7_0_M_AXI_GP0_WID;
  wire processing_system7_0_M_AXI_GP0_WLAST;
  wire processing_system7_0_M_AXI_GP0_WREADY;
  wire [3:0]processing_system7_0_M_AXI_GP0_WSTRB;
  wire processing_system7_0_M_AXI_GP0_WVALID;
  wire rst_n_1;
  wire [31:0]rx_last_id_dbg_concat_dout;
  wire [2:0]rx_last_id_dbg_zero3_dout;
  wire [0:0]rx_ready_one_dout;
  wire sys_clk_50m_1;
  wire vio_el05_single_tx_probe_out0;
  wire [28:0]vio_el05_single_tx_probe_out1;
  wire [7:0]vio_el05_single_tx_probe_out2;
  wire [63:0]vio_el05_single_tx_probe_out3;
  wire [2:0]vio_feedback_debug_probe_out0;
  wire [4:0]vio_feedback_debug_probe_out1;

  assign CAN_RX_1 = CAN_RX;
  assign CAN_TX = axi_can_0_can_phy_tx;
  assign rst_n_1 = rst_n;
  assign servo_pwm = pl_servo_axi_servo_pwm;
  assign sys_clk_50m_1 = sys_clk_50m;
  can_test_axi_can_0_0 axi_can_0
       (.can_clk(clk_pl_clk_out2),
        .can_phy_rx(CAN_RX_1),
        .can_phy_tx(axi_can_0_can_phy_tx),
        .ip2bus_intrevent(axi_can_0_ip2bus_intrevent),
        .s_axi_aclk(clk_pl_clk_out1),
        .s_axi_araddr(axi_periph_M00_AXI_ARADDR[7:0]),
        .s_axi_aresetn(pl_reset_ctrl_axi_aresetn),
        .s_axi_arready(axi_periph_M00_AXI_ARREADY),
        .s_axi_arvalid(axi_periph_M00_AXI_ARVALID),
        .s_axi_awaddr(axi_periph_M00_AXI_AWADDR[7:0]),
        .s_axi_awready(axi_periph_M00_AXI_AWREADY),
        .s_axi_awvalid(axi_periph_M00_AXI_AWVALID),
        .s_axi_bready(axi_periph_M00_AXI_BREADY),
        .s_axi_bresp(axi_periph_M00_AXI_BRESP),
        .s_axi_bvalid(axi_periph_M00_AXI_BVALID),
        .s_axi_rdata(axi_periph_M00_AXI_RDATA),
        .s_axi_rready(axi_periph_M00_AXI_RREADY),
        .s_axi_rresp(axi_periph_M00_AXI_RRESP),
        .s_axi_rvalid(axi_periph_M00_AXI_RVALID),
        .s_axi_wdata(axi_periph_M00_AXI_WDATA),
        .s_axi_wready(axi_periph_M00_AXI_WREADY),
        .s_axi_wstrb(axi_periph_M00_AXI_WSTRB),
        .s_axi_wvalid(axi_periph_M00_AXI_WVALID));
  can_test_axi_periph_0 axi_periph
       (.ACLK(clk_pl_clk_out1),
        .ARESETN(pl_reset_ctrl_axi_aresetn),
        .M00_ACLK(clk_pl_clk_out1),
        .M00_ARESETN(pl_reset_ctrl_axi_aresetn),
        .M00_AXI_araddr(axi_periph_M00_AXI_ARADDR),
        .M00_AXI_arready(axi_periph_M00_AXI_ARREADY),
        .M00_AXI_arvalid(axi_periph_M00_AXI_ARVALID),
        .M00_AXI_awaddr(axi_periph_M00_AXI_AWADDR),
        .M00_AXI_awready(axi_periph_M00_AXI_AWREADY),
        .M00_AXI_awvalid(axi_periph_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_periph_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_periph_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_periph_M00_AXI_BVALID),
        .M00_AXI_rdata(axi_periph_M00_AXI_RDATA),
        .M00_AXI_rready(axi_periph_M00_AXI_RREADY),
        .M00_AXI_rresp(axi_periph_M00_AXI_RRESP),
        .M00_AXI_rvalid(axi_periph_M00_AXI_RVALID),
        .M00_AXI_wdata(axi_periph_M00_AXI_WDATA),
        .M00_AXI_wready(axi_periph_M00_AXI_WREADY),
        .M00_AXI_wstrb(axi_periph_M00_AXI_WSTRB),
        .M00_AXI_wvalid(axi_periph_M00_AXI_WVALID),
        .M01_ACLK(clk_pl_clk_out1),
        .M01_ARESETN(pl_reset_ctrl_axi_aresetn),
        .M01_AXI_araddr(axi_periph_M01_AXI_ARADDR),
        .M01_AXI_arready(axi_periph_M01_AXI_ARREADY),
        .M01_AXI_arvalid(axi_periph_M01_AXI_ARVALID),
        .M01_AXI_awaddr(axi_periph_M01_AXI_AWADDR),
        .M01_AXI_awready(axi_periph_M01_AXI_AWREADY),
        .M01_AXI_awvalid(axi_periph_M01_AXI_AWVALID),
        .M01_AXI_bready(axi_periph_M01_AXI_BREADY),
        .M01_AXI_bresp(axi_periph_M01_AXI_BRESP),
        .M01_AXI_bvalid(axi_periph_M01_AXI_BVALID),
        .M01_AXI_rdata(axi_periph_M01_AXI_RDATA),
        .M01_AXI_rready(axi_periph_M01_AXI_RREADY),
        .M01_AXI_rresp(axi_periph_M01_AXI_RRESP),
        .M01_AXI_rvalid(axi_periph_M01_AXI_RVALID),
        .M01_AXI_wdata(axi_periph_M01_AXI_WDATA),
        .M01_AXI_wready(axi_periph_M01_AXI_WREADY),
        .M01_AXI_wstrb(axi_periph_M01_AXI_WSTRB),
        .M01_AXI_wvalid(axi_periph_M01_AXI_WVALID),
        .M02_ACLK(clk_pl_clk_out1),
        .M02_ARESETN(pl_reset_ctrl_axi_aresetn),
        .M02_AXI_araddr(axi_periph_M02_AXI_ARADDR),
        .M02_AXI_arready(axi_periph_M02_AXI_ARREADY),
        .M02_AXI_arvalid(axi_periph_M02_AXI_ARVALID),
        .M02_AXI_awaddr(axi_periph_M02_AXI_AWADDR),
        .M02_AXI_awready(axi_periph_M02_AXI_AWREADY),
        .M02_AXI_awvalid(axi_periph_M02_AXI_AWVALID),
        .M02_AXI_bready(axi_periph_M02_AXI_BREADY),
        .M02_AXI_bresp(axi_periph_M02_AXI_BRESP),
        .M02_AXI_bvalid(axi_periph_M02_AXI_BVALID),
        .M02_AXI_rdata(axi_periph_M02_AXI_RDATA),
        .M02_AXI_rready(axi_periph_M02_AXI_RREADY),
        .M02_AXI_rresp(axi_periph_M02_AXI_RRESP),
        .M02_AXI_rvalid(axi_periph_M02_AXI_RVALID),
        .M02_AXI_wdata(axi_periph_M02_AXI_WDATA),
        .M02_AXI_wready(axi_periph_M02_AXI_WREADY),
        .M02_AXI_wstrb(axi_periph_M02_AXI_WSTRB),
        .M02_AXI_wvalid(axi_periph_M02_AXI_WVALID),
        .S00_ACLK(clk_pl_clk_out1),
        .S00_ARESETN(pl_reset_ctrl_axi_aresetn),
        .S00_AXI_araddr(processing_system7_0_M_AXI_GP0_ARADDR),
        .S00_AXI_arburst(processing_system7_0_M_AXI_GP0_ARBURST),
        .S00_AXI_arcache(processing_system7_0_M_AXI_GP0_ARCACHE),
        .S00_AXI_arid(processing_system7_0_M_AXI_GP0_ARID),
        .S00_AXI_arlen(processing_system7_0_M_AXI_GP0_ARLEN),
        .S00_AXI_arlock(processing_system7_0_M_AXI_GP0_ARLOCK),
        .S00_AXI_arprot(processing_system7_0_M_AXI_GP0_ARPROT),
        .S00_AXI_arqos(processing_system7_0_M_AXI_GP0_ARQOS),
        .S00_AXI_arready(processing_system7_0_M_AXI_GP0_ARREADY),
        .S00_AXI_arsize(processing_system7_0_M_AXI_GP0_ARSIZE),
        .S00_AXI_arvalid(processing_system7_0_M_AXI_GP0_ARVALID),
        .S00_AXI_awaddr(processing_system7_0_M_AXI_GP0_AWADDR),
        .S00_AXI_awburst(processing_system7_0_M_AXI_GP0_AWBURST),
        .S00_AXI_awcache(processing_system7_0_M_AXI_GP0_AWCACHE),
        .S00_AXI_awid(processing_system7_0_M_AXI_GP0_AWID),
        .S00_AXI_awlen(processing_system7_0_M_AXI_GP0_AWLEN),
        .S00_AXI_awlock(processing_system7_0_M_AXI_GP0_AWLOCK),
        .S00_AXI_awprot(processing_system7_0_M_AXI_GP0_AWPROT),
        .S00_AXI_awqos(processing_system7_0_M_AXI_GP0_AWQOS),
        .S00_AXI_awready(processing_system7_0_M_AXI_GP0_AWREADY),
        .S00_AXI_awsize(processing_system7_0_M_AXI_GP0_AWSIZE),
        .S00_AXI_awvalid(processing_system7_0_M_AXI_GP0_AWVALID),
        .S00_AXI_bid(processing_system7_0_M_AXI_GP0_BID),
        .S00_AXI_bready(processing_system7_0_M_AXI_GP0_BREADY),
        .S00_AXI_bresp(processing_system7_0_M_AXI_GP0_BRESP),
        .S00_AXI_bvalid(processing_system7_0_M_AXI_GP0_BVALID),
        .S00_AXI_rdata(processing_system7_0_M_AXI_GP0_RDATA),
        .S00_AXI_rid(processing_system7_0_M_AXI_GP0_RID),
        .S00_AXI_rlast(processing_system7_0_M_AXI_GP0_RLAST),
        .S00_AXI_rready(processing_system7_0_M_AXI_GP0_RREADY),
        .S00_AXI_rresp(processing_system7_0_M_AXI_GP0_RRESP),
        .S00_AXI_rvalid(processing_system7_0_M_AXI_GP0_RVALID),
        .S00_AXI_wdata(processing_system7_0_M_AXI_GP0_WDATA),
        .S00_AXI_wid(processing_system7_0_M_AXI_GP0_WID),
        .S00_AXI_wlast(processing_system7_0_M_AXI_GP0_WLAST),
        .S00_AXI_wready(processing_system7_0_M_AXI_GP0_WREADY),
        .S00_AXI_wstrb(processing_system7_0_M_AXI_GP0_WSTRB),
        .S00_AXI_wvalid(processing_system7_0_M_AXI_GP0_WVALID),
        .S01_ACLK(clk_pl_clk_out1),
        .S01_ARESETN(pl_reset_ctrl_axi_aresetn),
        .S01_AXI_araddr(pl_can_reader_M_AXI_ARADDR),
        .S01_AXI_arprot(pl_can_reader_M_AXI_ARPROT),
        .S01_AXI_arready(pl_can_reader_M_AXI_ARREADY),
        .S01_AXI_arvalid(pl_can_reader_M_AXI_ARVALID),
        .S01_AXI_awaddr(pl_can_reader_M_AXI_AWADDR),
        .S01_AXI_awprot(pl_can_reader_M_AXI_AWPROT),
        .S01_AXI_awready(pl_can_reader_M_AXI_AWREADY),
        .S01_AXI_awvalid(pl_can_reader_M_AXI_AWVALID),
        .S01_AXI_bready(pl_can_reader_M_AXI_BREADY),
        .S01_AXI_bresp(pl_can_reader_M_AXI_BRESP),
        .S01_AXI_bvalid(pl_can_reader_M_AXI_BVALID),
        .S01_AXI_rdata(pl_can_reader_M_AXI_RDATA),
        .S01_AXI_rready(pl_can_reader_M_AXI_RREADY),
        .S01_AXI_rresp(pl_can_reader_M_AXI_RRESP),
        .S01_AXI_rvalid(pl_can_reader_M_AXI_RVALID),
        .S01_AXI_wdata(pl_can_reader_M_AXI_WDATA),
        .S01_AXI_wready(pl_can_reader_M_AXI_WREADY),
        .S01_AXI_wstrb(pl_can_reader_M_AXI_WSTRB),
        .S01_AXI_wvalid(pl_can_reader_M_AXI_WVALID));
  can_test_b2_zero1_0 b2_zero1
       (.dout(b2_zero1_dout));
  can_test_b2_zero16_0 b2_zero16
       (.dout(b2_zero16_dout));
  can_test_b2_zero32_0 b2_zero32
       (.dout(b2_zero32_dout));
  can_test_b2_zero8_0 b2_zero8
       (.dout(b2_zero8_dout));
  can_test_clk_pl_0 clk_pl
       (.clk_in1(sys_clk_50m_1),
        .clk_out1(clk_pl_clk_out1),
        .clk_out2(clk_pl_clk_out2),
        .locked(clk_pl_locked),
        .resetn(rst_n_1));
  can_test_const_one_0 const_one
       (.dout(const_one_dout));
  can_test_const_zero_0 const_zero
       (.dout(const_zero_dout));
  can_test_legacy_idle2_0 legacy_idle2
       (.dout(legacy_idle2_dout));
  can_test_pl_can_reader_0 pl_can_reader
       (.aclk(clk_pl_clk_out1),
        .aresetn(pl_reset_ctrl_axi_aresetn),
        .attempted_count(pl_can_reader_attempted_count),
        .axis_index(pl_can_reader_axis_index),
        .bus_quarantined(pl_can_reader_bus_quarantined),
        .busy(pl_can_reader_busy),
        .can_init_error(pl_can_reader_can_init_error),
        .can_init_error_code(pl_can_reader_can_init_error_code),
        .can_init_failed_state(pl_can_reader_can_init_failed_state),
        .can_init_last_status(pl_can_reader_can_init_last_status),
        .can_init_state(pl_can_reader_can_init_state),
        .can_initialized(pl_can_reader_can_initialized),
        .clock_locked(pl_reset_ctrl_clock_locked_axi),
        .completed_count(pl_can_reader_completed_count),
        .cycle_completed_count(pl_can_reader_cycle_completed_count),
        .cycle_limit(pl_can_reader_cycle_limit),
        .cycle_seq(pl_can_reader_cycle_seq),
        .cycle_started_count(pl_can_reader_cycle_started_count),
        .deadline_violation(pl_can_reader_deadline_violation),
        .debug_state(pl_can_reader_debug_state),
        .enqueued_count(pl_can_reader_enqueued_count),
        .error_flags(pl_can_reader_error_flags),
        .frame_limit(pl_can_reader_frame_limit),
        .last_attempt_cycle(pl_can_reader_last_attempt_cycle),
        .last_bresp(pl_can_reader_last_bresp),
        .last_isr(pl_can_reader_last_isr),
        .last_rresp(pl_can_reader_last_rresp),
        .last_sequence(pl_can_reader_last_sequence),
        .last_sr(pl_can_reader_last_sr),
        .limit_sel(legacy_idle2_dout),
        .m_axi_araddr(pl_can_reader_M_AXI_ARADDR),
        .m_axi_arprot(pl_can_reader_M_AXI_ARPROT),
        .m_axi_arready(pl_can_reader_M_AXI_ARREADY),
        .m_axi_arvalid(pl_can_reader_M_AXI_ARVALID),
        .m_axi_awaddr(pl_can_reader_M_AXI_AWADDR),
        .m_axi_awprot(pl_can_reader_M_AXI_AWPROT),
        .m_axi_awready(pl_can_reader_M_AXI_AWREADY),
        .m_axi_awvalid(pl_can_reader_M_AXI_AWVALID),
        .m_axi_bready(pl_can_reader_M_AXI_BREADY),
        .m_axi_bresp(pl_can_reader_M_AXI_BRESP),
        .m_axi_bvalid(pl_can_reader_M_AXI_BVALID),
        .m_axi_rdata(pl_can_reader_M_AXI_RDATA),
        .m_axi_rready(pl_can_reader_M_AXI_RREADY),
        .m_axi_rresp(pl_can_reader_M_AXI_RRESP),
        .m_axi_rvalid(pl_can_reader_M_AXI_RVALID),
        .m_axi_wdata(pl_can_reader_M_AXI_WDATA),
        .m_axi_wready(pl_can_reader_M_AXI_WREADY),
        .m_axi_wstrb(pl_can_reader_M_AXI_WSTRB),
        .m_axi_wvalid(pl_can_reader_M_AXI_WVALID),
        .max_cycle_span_cycles(pl_can_reader_max_cycle_span_cycles),
        .missed_cycle_count(pl_can_reader_missed_cycle_count),
        .missed_deadline_count(pl_can_reader_missed_deadline_count),
        .period_sel(legacy_idle2_dout),
        .periodic_completed(pl_can_reader_periodic_completed),
        .periodic_stopped(pl_can_reader_periodic_stopped),
        .read_done(pl_can_reader_read_done),
        .reset_released(pl_reset_ctrl_reset_released),
        .round_used(pl_can_reader_round_used),
        .rresp_valid(pl_can_reader_rresp_valid),
        .rx_axi_error_count(pl_can_reader_rx_axi_error_count),
        .rx_can_id(pl_can_reader_rx_can_id),
        .rx_data(pl_can_reader_rx_data),
        .rx_dlc(pl_can_reader_rx_dlc),
        .rx_error_flags(pl_can_reader_rx_error_flags),
        .rx_fifo_level(pl_can_reader_rx_fifo_level),
        .rx_frame_count(pl_can_reader_rx_frame_count),
        .rx_frame_error(pl_can_reader_rx_frame_error),
        .rx_ide(pl_can_reader_rx_ide),
        .rx_integrity_lost(pl_can_reader_rx_integrity_lost),
        .rx_invalid_frame_count(pl_can_reader_rx_invalid_frame_count),
        .rx_last_dlc(pl_can_reader_rx_last_dlc),
        .rx_last_id(pl_can_reader_rx_last_id),
        .rx_last_isr(pl_can_reader_rx_last_isr),
        .rx_overflow_count(pl_can_reader_rx_overflow_count),
        .rx_ready(pl_robstride_feedback_frame_ready),
        .rx_rtr(pl_can_reader_rx_rtr),
        .rx_service_fault(pl_can_reader_rx_service_fault),
        .rx_service_state(pl_can_reader_rx_service_state),
        .rx_snapshot_ecr(pl_can_reader_rx_snapshot_ecr),
        .rx_snapshot_esr(pl_can_reader_rx_snapshot_esr),
        .rx_snapshot_isr(pl_can_reader_rx_snapshot_isr),
        .rx_snapshot_sr(pl_can_reader_rx_snapshot_sr),
        .rx_snapshot_status(pl_can_reader_rx_snapshot_status),
        .rx_sw_drop_count(pl_can_reader_rx_sw_drop_count),
        .rx_timestamp(pl_can_reader_rx_timestamp),
        .rx_underflow_count(pl_can_reader_rx_underflow_count),
        .rx_valid(pl_can_reader_rx_valid),
        .scheduled_count(pl_can_reader_scheduled_count),
        .scheduler_fault(pl_can_reader_scheduler_fault),
        .scheduler_state(pl_can_reader_scheduler_state),
        .selected_period(pl_can_reader_selected_period),
        .send_req(const_zero_dout),
        .send_used(pl_can_reader_send_used),
        .single_tx_can_data(pl_el05_single_tx_tx_can_data1),
        .single_tx_can_dlc(pl_el05_single_tx_tx_can_dlc1),
        .single_tx_can_id(pl_el05_single_tx_tx_can_id1),
        .single_tx_done(pl_can_reader_single_tx_done),
        .single_tx_error(pl_can_reader_single_tx_error),
        .single_tx_error_code(pl_can_reader_single_tx_error_code),
        .single_tx_may_have_submitted(pl_can_reader_single_tx_may_have_submitted),
        .single_tx_req_ready(pl_can_reader_single_tx_req_ready),
        .single_tx_req_valid(pl_el05_single_tx_tx_req_valid1),
        .single_tx_result_valid(pl_can_reader_single_tx_result_valid),
        .single_tx_success(pl_can_reader_single_tx_success),
        .single_tx_timeout(pl_can_reader_single_tx_timeout),
        .start_rejected(pl_can_reader_start_rejected),
        .status_value(pl_can_reader_status_value),
        .stop_req(const_zero_dout),
        .success_count(pl_can_reader_success_count),
        .timeout_count(pl_can_reader_timeout_count),
        .transaction_timeout(pl_can_reader_transaction_timeout),
        .tx_busy(pl_can_reader_tx_busy),
        .tx_completed_cycle(pl_can_reader_tx_completed_cycle),
        .tx_error(pl_can_reader_tx_error),
        .tx_error_code(pl_can_reader_tx_error_code),
        .tx_error_count(pl_can_reader_tx_error_count),
        .tx_fifo_write_done(pl_can_reader_tx_fifo_write_done),
        .tx_may_be_pending(pl_can_reader_tx_may_be_pending),
        .tx_state(pl_can_reader_tx_state),
        .tx_success(pl_can_reader_tx_success),
        .tx_success_count(pl_can_reader_tx_success_count),
        .tx_timeout(pl_can_reader_tx_timeout),
        .write_error_flags(pl_can_reader_write_error_flags));
  can_test_pl_el05_single_tx_1 pl_el05_single_tx
       (.byte_reserved(vio_el05_single_tx_probe_out2),
        .clk(clk_pl_clk_out1),
        .command_busy(pl_el05_single_tx_command_busy),
        .command_done(pl_el05_single_tx_command_done),
        .command_error(pl_el05_single_tx_command_error),
        .command_error_code(pl_el05_single_tx_command_error_code),
        .command_rejected(pl_el05_single_tx_command_rejected),
        .command_start_accepted(pl_el05_single_tx_command_start_accepted),
        .command_state(pl_el05_single_tx_command_state),
        .command_success(pl_el05_single_tx_command_success),
        .command_value_word(vio_el05_single_tx_probe_out3),
        .command_word(vio_el05_single_tx_probe_out1),
        .fault_locked(pl_el05_single_tx_fault_locked1),
        .mapping_valid(pl_robstride_feedback_mapping_valid),
        .param_cancel_done(pl_robstride_feedback_param_cancel_done),
        .param_cancel_index(pl_el05_single_tx_param_cancel_index1),
        .param_cancel_matched(pl_robstride_feedback_param_cancel_matched),
        .param_cancel_motor(pl_el05_single_tx_param_cancel_motor1),
        .param_cancel_poison(pl_el05_single_tx_param_cancel_poison1),
        .param_cancel_ready(pl_robstride_feedback_param_cancel_ready),
        .param_cancel_token(pl_el05_single_tx_param_cancel_token1),
        .param_cancel_valid(pl_el05_single_tx_param_cancel_valid1),
        .param_pending(pl_robstride_feedback_param_pending),
        .param_poisoned(pl_robstride_feedback_param_poisoned),
        .param_reply_axis(pl_robstride_feedback_param_reply_axis),
        .param_reply_bits(pl_robstride_feedback_param_reply_bits),
        .param_reply_failed(pl_robstride_feedback_param_reply_failed),
        .param_reply_index(pl_robstride_feedback_param_reply_index),
        .param_reply_token(pl_robstride_feedback_param_reply_token),
        .param_reply_valid(pl_robstride_feedback_param_reply_valid),
        .param_req_active(pl_robstride_feedback_param_req_active),
        .param_req_host(pl_el05_single_tx_param_req_host1),
        .param_req_index(pl_el05_single_tx_param_req_index1),
        .param_req_motor(pl_el05_single_tx_param_req_motor1),
        .param_req_ready(pl_robstride_feedback_param_req_ready),
        .param_req_rejected(pl_robstride_feedback_param_req_rejected),
        .param_req_token(pl_el05_single_tx_param_req_token1),
        .param_req_valid(pl_el05_single_tx_param_req_valid1),
        .result_value(pl_el05_single_tx_result_value),
        .rst_n(pl_reset_ctrl_axi_aresetn),
        .start(vio_el05_single_tx_probe_out0),
        .status_event_error(pl_robstride_feedback_status_event_error),
        .status_event_motor(pl_robstride_feedback_status_event_motor),
        .status_event_valid(pl_robstride_feedback_status_event_valid),
        .stream_integrity_lost(pl_can_reader_rx_integrity_lost),
        .tx_can_data(pl_el05_single_tx_tx_can_data1),
        .tx_can_dlc(pl_el05_single_tx_tx_can_dlc1),
        .tx_can_id(pl_el05_single_tx_tx_can_id1),
        .tx_done(pl_can_reader_single_tx_done),
        .tx_error_code(pl_can_reader_single_tx_error_code),
        .tx_may_have_submitted(pl_can_reader_single_tx_may_have_submitted),
        .tx_req_ready(pl_can_reader_single_tx_req_ready),
        .tx_req_valid(pl_el05_single_tx_tx_req_valid1),
        .tx_success(pl_can_reader_single_tx_success));
  can_test_pl_motion_mailbox_0 pl_motion_mailbox
       (.can_init_error(pl_can_reader_can_init_error),
        .can_initialized(pl_can_reader_can_initialized),
        .clk(clk_pl_clk_out1),
        .clock_locked(pl_reset_ctrl_clock_locked_axi),
        .command_accepted(pl_el05_single_tx_command_start_accepted),
        .command_busy(pl_el05_single_tx_command_busy),
        .command_done(pl_el05_single_tx_command_done),
        .command_error(pl_el05_single_tx_command_error),
        .command_error_code(pl_el05_single_tx_command_error_code),
        .command_rejected(pl_el05_single_tx_command_rejected),
        .command_state(pl_el05_single_tx_command_state),
        .command_success(pl_el05_single_tx_command_success),
        .engine_reserved(vio_el05_single_tx_probe_out2),
        .engine_start(vio_el05_single_tx_probe_out0),
        .engine_value(vio_el05_single_tx_probe_out3),
        .engine_word(vio_el05_single_tx_probe_out1),
        .fault_locked(pl_el05_single_tx_fault_locked1),
        .feedback_data(pl_robstride_feedback_debug_data),
        .feedback_timeout(pl_robstride_feedback_feedback_timeout),
        .integrity_lost(pl_robstride_feedback_integrity_lost),
        .mapping_valid(pl_robstride_feedback_mapping_valid),
        .param_pending(pl_robstride_feedback_param_pending),
        .param_poisoned(pl_robstride_feedback_param_poisoned),
        .query_axis(vio_feedback_debug_probe_out0),
        .query_page(vio_feedback_debug_probe_out1),
        .result_value(pl_el05_single_tx_result_value),
        .rst_n(pl_reset_ctrl_axi_aresetn),
        .rx_error_flags(pl_can_reader_rx_error_flags),
        .rx_frame_count(pl_can_reader_rx_frame_count),
        .rx_last_isr(pl_can_reader_rx_last_isr),
        .rx_overflow_count(pl_can_reader_rx_overflow_count),
        .s_axi_araddr(axi_periph_M01_AXI_ARADDR[11:0]),
        .s_axi_arready(axi_periph_M01_AXI_ARREADY),
        .s_axi_arvalid(axi_periph_M01_AXI_ARVALID),
        .s_axi_awaddr(axi_periph_M01_AXI_AWADDR[11:0]),
        .s_axi_awready(axi_periph_M01_AXI_AWREADY),
        .s_axi_awvalid(axi_periph_M01_AXI_AWVALID),
        .s_axi_bready(axi_periph_M01_AXI_BREADY),
        .s_axi_bresp(axi_periph_M01_AXI_BRESP),
        .s_axi_bvalid(axi_periph_M01_AXI_BVALID),
        .s_axi_rdata(axi_periph_M01_AXI_RDATA),
        .s_axi_rready(axi_periph_M01_AXI_RREADY),
        .s_axi_rresp(axi_periph_M01_AXI_RRESP),
        .s_axi_rvalid(axi_periph_M01_AXI_RVALID),
        .s_axi_wdata(axi_periph_M01_AXI_WDATA),
        .s_axi_wready(axi_periph_M01_AXI_WREADY),
        .s_axi_wstrb(axi_periph_M01_AXI_WSTRB),
        .s_axi_wvalid(axi_periph_M01_AXI_WVALID),
        .tx_error_code(pl_can_reader_tx_error_code),
        .tx_may_be_pending(pl_can_reader_tx_may_be_pending));
  can_test_pl_reset_ctrl_0 pl_reset_ctrl
       (.axi_aresetn(pl_reset_ctrl_axi_aresetn),
        .can_aresetn(pl_reset_ctrl_can_aresetn),
        .can_reset_released_axi(pl_reset_ctrl_can_reset_released_axi),
        .clk_axi_50m(clk_pl_clk_out1),
        .clk_can_20m(clk_pl_clk_out2),
        .clock_locked(clk_pl_locked),
        .clock_locked_axi(pl_reset_ctrl_clock_locked_axi),
        .clock_ready(pl_reset_ctrl_clock_ready),
        .reset_released(pl_reset_ctrl_reset_released),
        .rst_n(rst_n_1));
  can_test_pl_robstride_feedback_0 pl_robstride_feedback
       (.accepted_frame_count(pl_robstride_feedback_accepted_frame_count),
        .can_data(pl_can_reader_rx_data),
        .can_dlc(pl_can_reader_rx_dlc),
        .can_id(pl_can_reader_rx_can_id),
        .can_ide(pl_can_reader_rx_ide),
        .can_rtr(pl_can_reader_rx_rtr),
        .clk(clk_pl_clk_out1),
        .consume_enable(rx_ready_one_dout),
        .debug_data(pl_robstride_feedback_debug_data),
        .debug_page(vio_feedback_debug_probe_out1),
        .diag_event_info(pl_robstride_feedback_diag_event_info),
        .diag_timeout_seen(pl_robstride_feedback_diag_timeout_seen),
        .feedback_timeout(pl_robstride_feedback_feedback_timeout),
        .frame_error(pl_can_reader_rx_frame_error),
        .frame_ready(pl_robstride_feedback_frame_ready),
        .frame_timestamp(pl_can_reader_rx_timestamp),
        .frame_valid(pl_can_reader_rx_valid),
        .integrity_lost(pl_robstride_feedback_integrity_lost),
        .invalid_frame_count(pl_robstride_feedback_invalid_frame_count),
        .mapping_valid(pl_robstride_feedback_mapping_valid),
        .param_cancel_done(pl_robstride_feedback_param_cancel_done),
        .param_cancel_index(pl_el05_single_tx_param_cancel_index1),
        .param_cancel_matched(pl_robstride_feedback_param_cancel_matched),
        .param_cancel_motor(pl_el05_single_tx_param_cancel_motor1),
        .param_cancel_poison(pl_el05_single_tx_param_cancel_poison1),
        .param_cancel_ready(pl_robstride_feedback_param_cancel_ready),
        .param_cancel_token(pl_el05_single_tx_param_cancel_token1),
        .param_cancel_valid(pl_el05_single_tx_param_cancel_valid1),
        .param_pending(pl_robstride_feedback_param_pending),
        .param_poisoned(pl_robstride_feedback_param_poisoned),
        .param_reply_axis(pl_robstride_feedback_param_reply_axis),
        .param_reply_bits(pl_robstride_feedback_param_reply_bits),
        .param_reply_failed(pl_robstride_feedback_param_reply_failed),
        .param_reply_index(pl_robstride_feedback_param_reply_index),
        .param_reply_token(pl_robstride_feedback_param_reply_token),
        .param_reply_valid(pl_robstride_feedback_param_reply_valid),
        .param_req_active(pl_robstride_feedback_param_req_active),
        .param_req_host(pl_el05_single_tx_param_req_host1),
        .param_req_index(pl_el05_single_tx_param_req_index1),
        .param_req_motor(pl_el05_single_tx_param_req_motor1),
        .param_req_ready(pl_robstride_feedback_param_req_ready),
        .param_req_rejected(pl_robstride_feedback_param_req_rejected),
        .param_req_token(pl_el05_single_tx_param_req_token1),
        .param_req_valid(pl_el05_single_tx_param_req_valid1),
        .parameter_timeout_count(pl_robstride_feedback_parameter_timeout_count),
        .query_axis(vio_feedback_debug_probe_out0),
        .query_error_code(pl_robstride_feedback_query_error_code),
        .query_fault(pl_robstride_feedback_query_fault),
        .query_feedback_timestamp(pl_robstride_feedback_query_feedback_timestamp),
        .query_position_raw(pl_robstride_feedback_query_position_raw),
        .query_warning(pl_robstride_feedback_query_warning),
        .rst_n(pl_reset_ctrl_axi_aresetn),
        .rx_snapshot_ecr(pl_can_reader_rx_snapshot_ecr),
        .rx_snapshot_esr(pl_can_reader_rx_snapshot_esr),
        .rx_snapshot_isr(pl_can_reader_rx_snapshot_isr),
        .rx_snapshot_sr(pl_can_reader_rx_snapshot_sr),
        .rx_snapshot_status(pl_can_reader_rx_snapshot_status),
        .status_event_error(pl_robstride_feedback_status_event_error),
        .status_event_motor(pl_robstride_feedback_status_event_motor),
        .status_event_valid(pl_robstride_feedback_status_event_valid),
        .stream_integrity_lost(pl_can_reader_rx_integrity_lost),
        .watchdog_config_valid(pl_robstride_feedback_watchdog_config_valid));
  can_test_pl_servo_axi_0 pl_servo_axi
       (.clk(clk_pl_clk_out1),
        .rst_n(pl_reset_ctrl_axi_aresetn),
        .s_axi_araddr(axi_periph_M02_AXI_ARADDR[11:0]),
        .s_axi_arready(axi_periph_M02_AXI_ARREADY),
        .s_axi_arvalid(axi_periph_M02_AXI_ARVALID),
        .s_axi_awaddr(axi_periph_M02_AXI_AWADDR[11:0]),
        .s_axi_awready(axi_periph_M02_AXI_AWREADY),
        .s_axi_awvalid(axi_periph_M02_AXI_AWVALID),
        .s_axi_bready(axi_periph_M02_AXI_BREADY),
        .s_axi_bresp(axi_periph_M02_AXI_BRESP),
        .s_axi_bvalid(axi_periph_M02_AXI_BVALID),
        .s_axi_rdata(axi_periph_M02_AXI_RDATA),
        .s_axi_rready(axi_periph_M02_AXI_RREADY),
        .s_axi_rresp(axi_periph_M02_AXI_RRESP),
        .s_axi_rvalid(axi_periph_M02_AXI_RVALID),
        .s_axi_wdata(axi_periph_M02_AXI_WDATA),
        .s_axi_wready(axi_periph_M02_AXI_WREADY),
        .s_axi_wstrb(axi_periph_M02_AXI_WSTRB),
        .s_axi_wvalid(axi_periph_M02_AXI_WVALID),
        .servo_pwm(pl_servo_axi_servo_pwm));
  can_test_processing_system7_0_0 processing_system7_0
       (.DDR_Addr(DDR_addr[14:0]),
        .DDR_BankAddr(DDR_ba[2:0]),
        .DDR_CAS_n(DDR_cas_n),
        .DDR_CKE(DDR_cke),
        .DDR_CS_n(DDR_cs_n),
        .DDR_Clk(DDR_ck_p),
        .DDR_Clk_n(DDR_ck_n),
        .DDR_DM(DDR_dm[3:0]),
        .DDR_DQ(DDR_dq[31:0]),
        .DDR_DQS(DDR_dqs_p[3:0]),
        .DDR_DQS_n(DDR_dqs_n[3:0]),
        .DDR_DRSTB(DDR_reset_n),
        .DDR_ODT(DDR_odt),
        .DDR_RAS_n(DDR_ras_n),
        .DDR_VRN(FIXED_IO_ddr_vrn),
        .DDR_VRP(FIXED_IO_ddr_vrp),
        .DDR_WEB(DDR_we_n),
        .IRQ_F2P(axi_can_0_ip2bus_intrevent),
        .MIO(FIXED_IO_mio[53:0]),
        .M_AXI_GP0_ACLK(clk_pl_clk_out1),
        .M_AXI_GP0_ARADDR(processing_system7_0_M_AXI_GP0_ARADDR),
        .M_AXI_GP0_ARBURST(processing_system7_0_M_AXI_GP0_ARBURST),
        .M_AXI_GP0_ARCACHE(processing_system7_0_M_AXI_GP0_ARCACHE),
        .M_AXI_GP0_ARID(processing_system7_0_M_AXI_GP0_ARID),
        .M_AXI_GP0_ARLEN(processing_system7_0_M_AXI_GP0_ARLEN),
        .M_AXI_GP0_ARLOCK(processing_system7_0_M_AXI_GP0_ARLOCK),
        .M_AXI_GP0_ARPROT(processing_system7_0_M_AXI_GP0_ARPROT),
        .M_AXI_GP0_ARQOS(processing_system7_0_M_AXI_GP0_ARQOS),
        .M_AXI_GP0_ARREADY(processing_system7_0_M_AXI_GP0_ARREADY),
        .M_AXI_GP0_ARSIZE(processing_system7_0_M_AXI_GP0_ARSIZE),
        .M_AXI_GP0_ARVALID(processing_system7_0_M_AXI_GP0_ARVALID),
        .M_AXI_GP0_AWADDR(processing_system7_0_M_AXI_GP0_AWADDR),
        .M_AXI_GP0_AWBURST(processing_system7_0_M_AXI_GP0_AWBURST),
        .M_AXI_GP0_AWCACHE(processing_system7_0_M_AXI_GP0_AWCACHE),
        .M_AXI_GP0_AWID(processing_system7_0_M_AXI_GP0_AWID),
        .M_AXI_GP0_AWLEN(processing_system7_0_M_AXI_GP0_AWLEN),
        .M_AXI_GP0_AWLOCK(processing_system7_0_M_AXI_GP0_AWLOCK),
        .M_AXI_GP0_AWPROT(processing_system7_0_M_AXI_GP0_AWPROT),
        .M_AXI_GP0_AWQOS(processing_system7_0_M_AXI_GP0_AWQOS),
        .M_AXI_GP0_AWREADY(processing_system7_0_M_AXI_GP0_AWREADY),
        .M_AXI_GP0_AWSIZE(processing_system7_0_M_AXI_GP0_AWSIZE),
        .M_AXI_GP0_AWVALID(processing_system7_0_M_AXI_GP0_AWVALID),
        .M_AXI_GP0_BID(processing_system7_0_M_AXI_GP0_BID),
        .M_AXI_GP0_BREADY(processing_system7_0_M_AXI_GP0_BREADY),
        .M_AXI_GP0_BRESP(processing_system7_0_M_AXI_GP0_BRESP),
        .M_AXI_GP0_BVALID(processing_system7_0_M_AXI_GP0_BVALID),
        .M_AXI_GP0_RDATA(processing_system7_0_M_AXI_GP0_RDATA),
        .M_AXI_GP0_RID(processing_system7_0_M_AXI_GP0_RID),
        .M_AXI_GP0_RLAST(processing_system7_0_M_AXI_GP0_RLAST),
        .M_AXI_GP0_RREADY(processing_system7_0_M_AXI_GP0_RREADY),
        .M_AXI_GP0_RRESP(processing_system7_0_M_AXI_GP0_RRESP),
        .M_AXI_GP0_RVALID(processing_system7_0_M_AXI_GP0_RVALID),
        .M_AXI_GP0_WDATA(processing_system7_0_M_AXI_GP0_WDATA),
        .M_AXI_GP0_WID(processing_system7_0_M_AXI_GP0_WID),
        .M_AXI_GP0_WLAST(processing_system7_0_M_AXI_GP0_WLAST),
        .M_AXI_GP0_WREADY(processing_system7_0_M_AXI_GP0_WREADY),
        .M_AXI_GP0_WSTRB(processing_system7_0_M_AXI_GP0_WSTRB),
        .M_AXI_GP0_WVALID(processing_system7_0_M_AXI_GP0_WVALID),
        .PS_CLK(FIXED_IO_ps_clk),
        .PS_PORB(FIXED_IO_ps_porb),
        .PS_SRSTB(FIXED_IO_ps_srstb),
        .USB0_VBUS_PWRFAULT(1'b0));
  can_test_rx_last_id_dbg_concat_0 rx_last_id_dbg_concat
       (.In0(pl_can_reader_rx_last_id),
        .In1(rx_last_id_dbg_zero3_dout),
        .dout(rx_last_id_dbg_concat_dout));
  can_test_rx_last_id_dbg_zero3_0 rx_last_id_dbg_zero3
       (.dout(rx_last_id_dbg_zero3_dout));
  can_test_rx_ready_one_0 rx_ready_one
       (.dout(rx_ready_one_dout));
endmodule

module can_test_axi_periph_0
   (ACLK,
    ARESETN,
    M00_ACLK,
    M00_ARESETN,
    M00_AXI_araddr,
    M00_AXI_arready,
    M00_AXI_arvalid,
    M00_AXI_awaddr,
    M00_AXI_awready,
    M00_AXI_awvalid,
    M00_AXI_bready,
    M00_AXI_bresp,
    M00_AXI_bvalid,
    M00_AXI_rdata,
    M00_AXI_rready,
    M00_AXI_rresp,
    M00_AXI_rvalid,
    M00_AXI_wdata,
    M00_AXI_wready,
    M00_AXI_wstrb,
    M00_AXI_wvalid,
    M01_ACLK,
    M01_ARESETN,
    M01_AXI_araddr,
    M01_AXI_arready,
    M01_AXI_arvalid,
    M01_AXI_awaddr,
    M01_AXI_awready,
    M01_AXI_awvalid,
    M01_AXI_bready,
    M01_AXI_bresp,
    M01_AXI_bvalid,
    M01_AXI_rdata,
    M01_AXI_rready,
    M01_AXI_rresp,
    M01_AXI_rvalid,
    M01_AXI_wdata,
    M01_AXI_wready,
    M01_AXI_wstrb,
    M01_AXI_wvalid,
    M02_ACLK,
    M02_ARESETN,
    M02_AXI_araddr,
    M02_AXI_arready,
    M02_AXI_arvalid,
    M02_AXI_awaddr,
    M02_AXI_awready,
    M02_AXI_awvalid,
    M02_AXI_bready,
    M02_AXI_bresp,
    M02_AXI_bvalid,
    M02_AXI_rdata,
    M02_AXI_rready,
    M02_AXI_rresp,
    M02_AXI_rvalid,
    M02_AXI_wdata,
    M02_AXI_wready,
    M02_AXI_wstrb,
    M02_AXI_wvalid,
    S00_ACLK,
    S00_ARESETN,
    S00_AXI_araddr,
    S00_AXI_arburst,
    S00_AXI_arcache,
    S00_AXI_arid,
    S00_AXI_arlen,
    S00_AXI_arlock,
    S00_AXI_arprot,
    S00_AXI_arqos,
    S00_AXI_arready,
    S00_AXI_arsize,
    S00_AXI_arvalid,
    S00_AXI_awaddr,
    S00_AXI_awburst,
    S00_AXI_awcache,
    S00_AXI_awid,
    S00_AXI_awlen,
    S00_AXI_awlock,
    S00_AXI_awprot,
    S00_AXI_awqos,
    S00_AXI_awready,
    S00_AXI_awsize,
    S00_AXI_awvalid,
    S00_AXI_bid,
    S00_AXI_bready,
    S00_AXI_bresp,
    S00_AXI_bvalid,
    S00_AXI_rdata,
    S00_AXI_rid,
    S00_AXI_rlast,
    S00_AXI_rready,
    S00_AXI_rresp,
    S00_AXI_rvalid,
    S00_AXI_wdata,
    S00_AXI_wid,
    S00_AXI_wlast,
    S00_AXI_wready,
    S00_AXI_wstrb,
    S00_AXI_wvalid,
    S01_ACLK,
    S01_ARESETN,
    S01_AXI_araddr,
    S01_AXI_arprot,
    S01_AXI_arready,
    S01_AXI_arvalid,
    S01_AXI_awaddr,
    S01_AXI_awprot,
    S01_AXI_awready,
    S01_AXI_awvalid,
    S01_AXI_bready,
    S01_AXI_bresp,
    S01_AXI_bvalid,
    S01_AXI_rdata,
    S01_AXI_rready,
    S01_AXI_rresp,
    S01_AXI_rvalid,
    S01_AXI_wdata,
    S01_AXI_wready,
    S01_AXI_wstrb,
    S01_AXI_wvalid);
  input ACLK;
  input ARESETN;
  input M00_ACLK;
  input M00_ARESETN;
  output [31:0]M00_AXI_araddr;
  input M00_AXI_arready;
  output M00_AXI_arvalid;
  output [31:0]M00_AXI_awaddr;
  input M00_AXI_awready;
  output M00_AXI_awvalid;
  output M00_AXI_bready;
  input [1:0]M00_AXI_bresp;
  input M00_AXI_bvalid;
  input [31:0]M00_AXI_rdata;
  output M00_AXI_rready;
  input [1:0]M00_AXI_rresp;
  input M00_AXI_rvalid;
  output [31:0]M00_AXI_wdata;
  input M00_AXI_wready;
  output [3:0]M00_AXI_wstrb;
  output M00_AXI_wvalid;
  input M01_ACLK;
  input M01_ARESETN;
  output [31:0]M01_AXI_araddr;
  input M01_AXI_arready;
  output M01_AXI_arvalid;
  output [31:0]M01_AXI_awaddr;
  input M01_AXI_awready;
  output M01_AXI_awvalid;
  output M01_AXI_bready;
  input [1:0]M01_AXI_bresp;
  input M01_AXI_bvalid;
  input [31:0]M01_AXI_rdata;
  output M01_AXI_rready;
  input [1:0]M01_AXI_rresp;
  input M01_AXI_rvalid;
  output [31:0]M01_AXI_wdata;
  input M01_AXI_wready;
  output [3:0]M01_AXI_wstrb;
  output M01_AXI_wvalid;
  input M02_ACLK;
  input M02_ARESETN;
  output [31:0]M02_AXI_araddr;
  input M02_AXI_arready;
  output M02_AXI_arvalid;
  output [31:0]M02_AXI_awaddr;
  input M02_AXI_awready;
  output M02_AXI_awvalid;
  output M02_AXI_bready;
  input [1:0]M02_AXI_bresp;
  input M02_AXI_bvalid;
  input [31:0]M02_AXI_rdata;
  output M02_AXI_rready;
  input [1:0]M02_AXI_rresp;
  input M02_AXI_rvalid;
  output [31:0]M02_AXI_wdata;
  input M02_AXI_wready;
  output [3:0]M02_AXI_wstrb;
  output M02_AXI_wvalid;
  input S00_ACLK;
  input S00_ARESETN;
  input [31:0]S00_AXI_araddr;
  input [1:0]S00_AXI_arburst;
  input [3:0]S00_AXI_arcache;
  input [11:0]S00_AXI_arid;
  input [3:0]S00_AXI_arlen;
  input [1:0]S00_AXI_arlock;
  input [2:0]S00_AXI_arprot;
  input [3:0]S00_AXI_arqos;
  output S00_AXI_arready;
  input [2:0]S00_AXI_arsize;
  input S00_AXI_arvalid;
  input [31:0]S00_AXI_awaddr;
  input [1:0]S00_AXI_awburst;
  input [3:0]S00_AXI_awcache;
  input [11:0]S00_AXI_awid;
  input [3:0]S00_AXI_awlen;
  input [1:0]S00_AXI_awlock;
  input [2:0]S00_AXI_awprot;
  input [3:0]S00_AXI_awqos;
  output S00_AXI_awready;
  input [2:0]S00_AXI_awsize;
  input S00_AXI_awvalid;
  output [11:0]S00_AXI_bid;
  input S00_AXI_bready;
  output [1:0]S00_AXI_bresp;
  output S00_AXI_bvalid;
  output [31:0]S00_AXI_rdata;
  output [11:0]S00_AXI_rid;
  output S00_AXI_rlast;
  input S00_AXI_rready;
  output [1:0]S00_AXI_rresp;
  output S00_AXI_rvalid;
  input [31:0]S00_AXI_wdata;
  input [11:0]S00_AXI_wid;
  input S00_AXI_wlast;
  output S00_AXI_wready;
  input [3:0]S00_AXI_wstrb;
  input S00_AXI_wvalid;
  input S01_ACLK;
  input S01_ARESETN;
  input [31:0]S01_AXI_araddr;
  input [2:0]S01_AXI_arprot;
  output S01_AXI_arready;
  input S01_AXI_arvalid;
  input [31:0]S01_AXI_awaddr;
  input [2:0]S01_AXI_awprot;
  output S01_AXI_awready;
  input S01_AXI_awvalid;
  input S01_AXI_bready;
  output [1:0]S01_AXI_bresp;
  output S01_AXI_bvalid;
  output [31:0]S01_AXI_rdata;
  input S01_AXI_rready;
  output [1:0]S01_AXI_rresp;
  output S01_AXI_rvalid;
  input [31:0]S01_AXI_wdata;
  output S01_AXI_wready;
  input [3:0]S01_AXI_wstrb;
  input S01_AXI_wvalid;

  wire axi_periph_ACLK_net;
  wire axi_periph_ARESETN_net;
  wire [31:0]axi_periph_to_s00_couplers_ARADDR;
  wire [1:0]axi_periph_to_s00_couplers_ARBURST;
  wire [3:0]axi_periph_to_s00_couplers_ARCACHE;
  wire [11:0]axi_periph_to_s00_couplers_ARID;
  wire [3:0]axi_periph_to_s00_couplers_ARLEN;
  wire [1:0]axi_periph_to_s00_couplers_ARLOCK;
  wire [2:0]axi_periph_to_s00_couplers_ARPROT;
  wire [3:0]axi_periph_to_s00_couplers_ARQOS;
  wire axi_periph_to_s00_couplers_ARREADY;
  wire [2:0]axi_periph_to_s00_couplers_ARSIZE;
  wire axi_periph_to_s00_couplers_ARVALID;
  wire [31:0]axi_periph_to_s00_couplers_AWADDR;
  wire [1:0]axi_periph_to_s00_couplers_AWBURST;
  wire [3:0]axi_periph_to_s00_couplers_AWCACHE;
  wire [11:0]axi_periph_to_s00_couplers_AWID;
  wire [3:0]axi_periph_to_s00_couplers_AWLEN;
  wire [1:0]axi_periph_to_s00_couplers_AWLOCK;
  wire [2:0]axi_periph_to_s00_couplers_AWPROT;
  wire [3:0]axi_periph_to_s00_couplers_AWQOS;
  wire axi_periph_to_s00_couplers_AWREADY;
  wire [2:0]axi_periph_to_s00_couplers_AWSIZE;
  wire axi_periph_to_s00_couplers_AWVALID;
  wire [11:0]axi_periph_to_s00_couplers_BID;
  wire axi_periph_to_s00_couplers_BREADY;
  wire [1:0]axi_periph_to_s00_couplers_BRESP;
  wire axi_periph_to_s00_couplers_BVALID;
  wire [31:0]axi_periph_to_s00_couplers_RDATA;
  wire [11:0]axi_periph_to_s00_couplers_RID;
  wire axi_periph_to_s00_couplers_RLAST;
  wire axi_periph_to_s00_couplers_RREADY;
  wire [1:0]axi_periph_to_s00_couplers_RRESP;
  wire axi_periph_to_s00_couplers_RVALID;
  wire [31:0]axi_periph_to_s00_couplers_WDATA;
  wire [11:0]axi_periph_to_s00_couplers_WID;
  wire axi_periph_to_s00_couplers_WLAST;
  wire axi_periph_to_s00_couplers_WREADY;
  wire [3:0]axi_periph_to_s00_couplers_WSTRB;
  wire axi_periph_to_s00_couplers_WVALID;
  wire [31:0]axi_periph_to_s01_couplers_ARADDR;
  wire [2:0]axi_periph_to_s01_couplers_ARPROT;
  wire axi_periph_to_s01_couplers_ARREADY;
  wire axi_periph_to_s01_couplers_ARVALID;
  wire [31:0]axi_periph_to_s01_couplers_AWADDR;
  wire [2:0]axi_periph_to_s01_couplers_AWPROT;
  wire axi_periph_to_s01_couplers_AWREADY;
  wire axi_periph_to_s01_couplers_AWVALID;
  wire axi_periph_to_s01_couplers_BREADY;
  wire [1:0]axi_periph_to_s01_couplers_BRESP;
  wire axi_periph_to_s01_couplers_BVALID;
  wire [31:0]axi_periph_to_s01_couplers_RDATA;
  wire axi_periph_to_s01_couplers_RREADY;
  wire [1:0]axi_periph_to_s01_couplers_RRESP;
  wire axi_periph_to_s01_couplers_RVALID;
  wire [31:0]axi_periph_to_s01_couplers_WDATA;
  wire axi_periph_to_s01_couplers_WREADY;
  wire [3:0]axi_periph_to_s01_couplers_WSTRB;
  wire axi_periph_to_s01_couplers_WVALID;
  wire [31:0]m00_couplers_to_axi_periph_ARADDR;
  wire m00_couplers_to_axi_periph_ARREADY;
  wire m00_couplers_to_axi_periph_ARVALID;
  wire [31:0]m00_couplers_to_axi_periph_AWADDR;
  wire m00_couplers_to_axi_periph_AWREADY;
  wire m00_couplers_to_axi_periph_AWVALID;
  wire m00_couplers_to_axi_periph_BREADY;
  wire [1:0]m00_couplers_to_axi_periph_BRESP;
  wire m00_couplers_to_axi_periph_BVALID;
  wire [31:0]m00_couplers_to_axi_periph_RDATA;
  wire m00_couplers_to_axi_periph_RREADY;
  wire [1:0]m00_couplers_to_axi_periph_RRESP;
  wire m00_couplers_to_axi_periph_RVALID;
  wire [31:0]m00_couplers_to_axi_periph_WDATA;
  wire m00_couplers_to_axi_periph_WREADY;
  wire [3:0]m00_couplers_to_axi_periph_WSTRB;
  wire m00_couplers_to_axi_periph_WVALID;
  wire [31:0]m01_couplers_to_axi_periph_ARADDR;
  wire m01_couplers_to_axi_periph_ARREADY;
  wire m01_couplers_to_axi_periph_ARVALID;
  wire [31:0]m01_couplers_to_axi_periph_AWADDR;
  wire m01_couplers_to_axi_periph_AWREADY;
  wire m01_couplers_to_axi_periph_AWVALID;
  wire m01_couplers_to_axi_periph_BREADY;
  wire [1:0]m01_couplers_to_axi_periph_BRESP;
  wire m01_couplers_to_axi_periph_BVALID;
  wire [31:0]m01_couplers_to_axi_periph_RDATA;
  wire m01_couplers_to_axi_periph_RREADY;
  wire [1:0]m01_couplers_to_axi_periph_RRESP;
  wire m01_couplers_to_axi_periph_RVALID;
  wire [31:0]m01_couplers_to_axi_periph_WDATA;
  wire m01_couplers_to_axi_periph_WREADY;
  wire [3:0]m01_couplers_to_axi_periph_WSTRB;
  wire m01_couplers_to_axi_periph_WVALID;
  wire [31:0]m02_couplers_to_axi_periph_ARADDR;
  wire m02_couplers_to_axi_periph_ARREADY;
  wire m02_couplers_to_axi_periph_ARVALID;
  wire [31:0]m02_couplers_to_axi_periph_AWADDR;
  wire m02_couplers_to_axi_periph_AWREADY;
  wire m02_couplers_to_axi_periph_AWVALID;
  wire m02_couplers_to_axi_periph_BREADY;
  wire [1:0]m02_couplers_to_axi_periph_BRESP;
  wire m02_couplers_to_axi_periph_BVALID;
  wire [31:0]m02_couplers_to_axi_periph_RDATA;
  wire m02_couplers_to_axi_periph_RREADY;
  wire [1:0]m02_couplers_to_axi_periph_RRESP;
  wire m02_couplers_to_axi_periph_RVALID;
  wire [31:0]m02_couplers_to_axi_periph_WDATA;
  wire m02_couplers_to_axi_periph_WREADY;
  wire [3:0]m02_couplers_to_axi_periph_WSTRB;
  wire m02_couplers_to_axi_periph_WVALID;
  wire [31:0]s00_couplers_to_xbar_ARADDR;
  wire [2:0]s00_couplers_to_xbar_ARPROT;
  wire [0:0]s00_couplers_to_xbar_ARREADY;
  wire s00_couplers_to_xbar_ARVALID;
  wire [31:0]s00_couplers_to_xbar_AWADDR;
  wire [2:0]s00_couplers_to_xbar_AWPROT;
  wire [0:0]s00_couplers_to_xbar_AWREADY;
  wire s00_couplers_to_xbar_AWVALID;
  wire s00_couplers_to_xbar_BREADY;
  wire [1:0]s00_couplers_to_xbar_BRESP;
  wire [0:0]s00_couplers_to_xbar_BVALID;
  wire [31:0]s00_couplers_to_xbar_RDATA;
  wire s00_couplers_to_xbar_RREADY;
  wire [1:0]s00_couplers_to_xbar_RRESP;
  wire [0:0]s00_couplers_to_xbar_RVALID;
  wire [31:0]s00_couplers_to_xbar_WDATA;
  wire [0:0]s00_couplers_to_xbar_WREADY;
  wire [3:0]s00_couplers_to_xbar_WSTRB;
  wire s00_couplers_to_xbar_WVALID;
  wire [31:0]s01_couplers_to_xbar_ARADDR;
  wire [2:0]s01_couplers_to_xbar_ARPROT;
  wire [1:1]s01_couplers_to_xbar_ARREADY;
  wire s01_couplers_to_xbar_ARVALID;
  wire [31:0]s01_couplers_to_xbar_AWADDR;
  wire [2:0]s01_couplers_to_xbar_AWPROT;
  wire [1:1]s01_couplers_to_xbar_AWREADY;
  wire s01_couplers_to_xbar_AWVALID;
  wire s01_couplers_to_xbar_BREADY;
  wire [3:2]s01_couplers_to_xbar_BRESP;
  wire [1:1]s01_couplers_to_xbar_BVALID;
  wire [63:32]s01_couplers_to_xbar_RDATA;
  wire s01_couplers_to_xbar_RREADY;
  wire [3:2]s01_couplers_to_xbar_RRESP;
  wire [1:1]s01_couplers_to_xbar_RVALID;
  wire [31:0]s01_couplers_to_xbar_WDATA;
  wire [1:1]s01_couplers_to_xbar_WREADY;
  wire [3:0]s01_couplers_to_xbar_WSTRB;
  wire s01_couplers_to_xbar_WVALID;
  wire [31:0]xbar_to_m00_couplers_ARADDR;
  wire xbar_to_m00_couplers_ARREADY;
  wire [0:0]xbar_to_m00_couplers_ARVALID;
  wire [31:0]xbar_to_m00_couplers_AWADDR;
  wire xbar_to_m00_couplers_AWREADY;
  wire [0:0]xbar_to_m00_couplers_AWVALID;
  wire [0:0]xbar_to_m00_couplers_BREADY;
  wire [1:0]xbar_to_m00_couplers_BRESP;
  wire xbar_to_m00_couplers_BVALID;
  wire [31:0]xbar_to_m00_couplers_RDATA;
  wire [0:0]xbar_to_m00_couplers_RREADY;
  wire [1:0]xbar_to_m00_couplers_RRESP;
  wire xbar_to_m00_couplers_RVALID;
  wire [31:0]xbar_to_m00_couplers_WDATA;
  wire xbar_to_m00_couplers_WREADY;
  wire [3:0]xbar_to_m00_couplers_WSTRB;
  wire [0:0]xbar_to_m00_couplers_WVALID;
  wire [63:32]xbar_to_m01_couplers_ARADDR;
  wire xbar_to_m01_couplers_ARREADY;
  wire [1:1]xbar_to_m01_couplers_ARVALID;
  wire [63:32]xbar_to_m01_couplers_AWADDR;
  wire xbar_to_m01_couplers_AWREADY;
  wire [1:1]xbar_to_m01_couplers_AWVALID;
  wire [1:1]xbar_to_m01_couplers_BREADY;
  wire [1:0]xbar_to_m01_couplers_BRESP;
  wire xbar_to_m01_couplers_BVALID;
  wire [31:0]xbar_to_m01_couplers_RDATA;
  wire [1:1]xbar_to_m01_couplers_RREADY;
  wire [1:0]xbar_to_m01_couplers_RRESP;
  wire xbar_to_m01_couplers_RVALID;
  wire [63:32]xbar_to_m01_couplers_WDATA;
  wire xbar_to_m01_couplers_WREADY;
  wire [7:4]xbar_to_m01_couplers_WSTRB;
  wire [1:1]xbar_to_m01_couplers_WVALID;
  wire [95:64]xbar_to_m02_couplers_ARADDR;
  wire xbar_to_m02_couplers_ARREADY;
  wire [2:2]xbar_to_m02_couplers_ARVALID;
  wire [95:64]xbar_to_m02_couplers_AWADDR;
  wire xbar_to_m02_couplers_AWREADY;
  wire [2:2]xbar_to_m02_couplers_AWVALID;
  wire [2:2]xbar_to_m02_couplers_BREADY;
  wire [1:0]xbar_to_m02_couplers_BRESP;
  wire xbar_to_m02_couplers_BVALID;
  wire [31:0]xbar_to_m02_couplers_RDATA;
  wire [2:2]xbar_to_m02_couplers_RREADY;
  wire [1:0]xbar_to_m02_couplers_RRESP;
  wire xbar_to_m02_couplers_RVALID;
  wire [95:64]xbar_to_m02_couplers_WDATA;
  wire xbar_to_m02_couplers_WREADY;
  wire [11:8]xbar_to_m02_couplers_WSTRB;
  wire [2:2]xbar_to_m02_couplers_WVALID;

  assign M00_AXI_araddr[31:0] = m00_couplers_to_axi_periph_ARADDR;
  assign M00_AXI_arvalid = m00_couplers_to_axi_periph_ARVALID;
  assign M00_AXI_awaddr[31:0] = m00_couplers_to_axi_periph_AWADDR;
  assign M00_AXI_awvalid = m00_couplers_to_axi_periph_AWVALID;
  assign M00_AXI_bready = m00_couplers_to_axi_periph_BREADY;
  assign M00_AXI_rready = m00_couplers_to_axi_periph_RREADY;
  assign M00_AXI_wdata[31:0] = m00_couplers_to_axi_periph_WDATA;
  assign M00_AXI_wstrb[3:0] = m00_couplers_to_axi_periph_WSTRB;
  assign M00_AXI_wvalid = m00_couplers_to_axi_periph_WVALID;
  assign M01_AXI_araddr[31:0] = m01_couplers_to_axi_periph_ARADDR;
  assign M01_AXI_arvalid = m01_couplers_to_axi_periph_ARVALID;
  assign M01_AXI_awaddr[31:0] = m01_couplers_to_axi_periph_AWADDR;
  assign M01_AXI_awvalid = m01_couplers_to_axi_periph_AWVALID;
  assign M01_AXI_bready = m01_couplers_to_axi_periph_BREADY;
  assign M01_AXI_rready = m01_couplers_to_axi_periph_RREADY;
  assign M01_AXI_wdata[31:0] = m01_couplers_to_axi_periph_WDATA;
  assign M01_AXI_wstrb[3:0] = m01_couplers_to_axi_periph_WSTRB;
  assign M01_AXI_wvalid = m01_couplers_to_axi_periph_WVALID;
  assign M02_AXI_araddr[31:0] = m02_couplers_to_axi_periph_ARADDR;
  assign M02_AXI_arvalid = m02_couplers_to_axi_periph_ARVALID;
  assign M02_AXI_awaddr[31:0] = m02_couplers_to_axi_periph_AWADDR;
  assign M02_AXI_awvalid = m02_couplers_to_axi_periph_AWVALID;
  assign M02_AXI_bready = m02_couplers_to_axi_periph_BREADY;
  assign M02_AXI_rready = m02_couplers_to_axi_periph_RREADY;
  assign M02_AXI_wdata[31:0] = m02_couplers_to_axi_periph_WDATA;
  assign M02_AXI_wstrb[3:0] = m02_couplers_to_axi_periph_WSTRB;
  assign M02_AXI_wvalid = m02_couplers_to_axi_periph_WVALID;
  assign S00_AXI_arready = axi_periph_to_s00_couplers_ARREADY;
  assign S00_AXI_awready = axi_periph_to_s00_couplers_AWREADY;
  assign S00_AXI_bid[11:0] = axi_periph_to_s00_couplers_BID;
  assign S00_AXI_bresp[1:0] = axi_periph_to_s00_couplers_BRESP;
  assign S00_AXI_bvalid = axi_periph_to_s00_couplers_BVALID;
  assign S00_AXI_rdata[31:0] = axi_periph_to_s00_couplers_RDATA;
  assign S00_AXI_rid[11:0] = axi_periph_to_s00_couplers_RID;
  assign S00_AXI_rlast = axi_periph_to_s00_couplers_RLAST;
  assign S00_AXI_rresp[1:0] = axi_periph_to_s00_couplers_RRESP;
  assign S00_AXI_rvalid = axi_periph_to_s00_couplers_RVALID;
  assign S00_AXI_wready = axi_periph_to_s00_couplers_WREADY;
  assign S01_AXI_arready = axi_periph_to_s01_couplers_ARREADY;
  assign S01_AXI_awready = axi_periph_to_s01_couplers_AWREADY;
  assign S01_AXI_bresp[1:0] = axi_periph_to_s01_couplers_BRESP;
  assign S01_AXI_bvalid = axi_periph_to_s01_couplers_BVALID;
  assign S01_AXI_rdata[31:0] = axi_periph_to_s01_couplers_RDATA;
  assign S01_AXI_rresp[1:0] = axi_periph_to_s01_couplers_RRESP;
  assign S01_AXI_rvalid = axi_periph_to_s01_couplers_RVALID;
  assign S01_AXI_wready = axi_periph_to_s01_couplers_WREADY;
  assign axi_periph_ACLK_net = ACLK;
  assign axi_periph_ARESETN_net = ARESETN;
  assign axi_periph_to_s00_couplers_ARADDR = S00_AXI_araddr[31:0];
  assign axi_periph_to_s00_couplers_ARBURST = S00_AXI_arburst[1:0];
  assign axi_periph_to_s00_couplers_ARCACHE = S00_AXI_arcache[3:0];
  assign axi_periph_to_s00_couplers_ARID = S00_AXI_arid[11:0];
  assign axi_periph_to_s00_couplers_ARLEN = S00_AXI_arlen[3:0];
  assign axi_periph_to_s00_couplers_ARLOCK = S00_AXI_arlock[1:0];
  assign axi_periph_to_s00_couplers_ARPROT = S00_AXI_arprot[2:0];
  assign axi_periph_to_s00_couplers_ARQOS = S00_AXI_arqos[3:0];
  assign axi_periph_to_s00_couplers_ARSIZE = S00_AXI_arsize[2:0];
  assign axi_periph_to_s00_couplers_ARVALID = S00_AXI_arvalid;
  assign axi_periph_to_s00_couplers_AWADDR = S00_AXI_awaddr[31:0];
  assign axi_periph_to_s00_couplers_AWBURST = S00_AXI_awburst[1:0];
  assign axi_periph_to_s00_couplers_AWCACHE = S00_AXI_awcache[3:0];
  assign axi_periph_to_s00_couplers_AWID = S00_AXI_awid[11:0];
  assign axi_periph_to_s00_couplers_AWLEN = S00_AXI_awlen[3:0];
  assign axi_periph_to_s00_couplers_AWLOCK = S00_AXI_awlock[1:0];
  assign axi_periph_to_s00_couplers_AWPROT = S00_AXI_awprot[2:0];
  assign axi_periph_to_s00_couplers_AWQOS = S00_AXI_awqos[3:0];
  assign axi_periph_to_s00_couplers_AWSIZE = S00_AXI_awsize[2:0];
  assign axi_periph_to_s00_couplers_AWVALID = S00_AXI_awvalid;
  assign axi_periph_to_s00_couplers_BREADY = S00_AXI_bready;
  assign axi_periph_to_s00_couplers_RREADY = S00_AXI_rready;
  assign axi_periph_to_s00_couplers_WDATA = S00_AXI_wdata[31:0];
  assign axi_periph_to_s00_couplers_WID = S00_AXI_wid[11:0];
  assign axi_periph_to_s00_couplers_WLAST = S00_AXI_wlast;
  assign axi_periph_to_s00_couplers_WSTRB = S00_AXI_wstrb[3:0];
  assign axi_periph_to_s00_couplers_WVALID = S00_AXI_wvalid;
  assign axi_periph_to_s01_couplers_ARADDR = S01_AXI_araddr[31:0];
  assign axi_periph_to_s01_couplers_ARPROT = S01_AXI_arprot[2:0];
  assign axi_periph_to_s01_couplers_ARVALID = S01_AXI_arvalid;
  assign axi_periph_to_s01_couplers_AWADDR = S01_AXI_awaddr[31:0];
  assign axi_periph_to_s01_couplers_AWPROT = S01_AXI_awprot[2:0];
  assign axi_periph_to_s01_couplers_AWVALID = S01_AXI_awvalid;
  assign axi_periph_to_s01_couplers_BREADY = S01_AXI_bready;
  assign axi_periph_to_s01_couplers_RREADY = S01_AXI_rready;
  assign axi_periph_to_s01_couplers_WDATA = S01_AXI_wdata[31:0];
  assign axi_periph_to_s01_couplers_WSTRB = S01_AXI_wstrb[3:0];
  assign axi_periph_to_s01_couplers_WVALID = S01_AXI_wvalid;
  assign m00_couplers_to_axi_periph_ARREADY = M00_AXI_arready;
  assign m00_couplers_to_axi_periph_AWREADY = M00_AXI_awready;
  assign m00_couplers_to_axi_periph_BRESP = M00_AXI_bresp[1:0];
  assign m00_couplers_to_axi_periph_BVALID = M00_AXI_bvalid;
  assign m00_couplers_to_axi_periph_RDATA = M00_AXI_rdata[31:0];
  assign m00_couplers_to_axi_periph_RRESP = M00_AXI_rresp[1:0];
  assign m00_couplers_to_axi_periph_RVALID = M00_AXI_rvalid;
  assign m00_couplers_to_axi_periph_WREADY = M00_AXI_wready;
  assign m01_couplers_to_axi_periph_ARREADY = M01_AXI_arready;
  assign m01_couplers_to_axi_periph_AWREADY = M01_AXI_awready;
  assign m01_couplers_to_axi_periph_BRESP = M01_AXI_bresp[1:0];
  assign m01_couplers_to_axi_periph_BVALID = M01_AXI_bvalid;
  assign m01_couplers_to_axi_periph_RDATA = M01_AXI_rdata[31:0];
  assign m01_couplers_to_axi_periph_RRESP = M01_AXI_rresp[1:0];
  assign m01_couplers_to_axi_periph_RVALID = M01_AXI_rvalid;
  assign m01_couplers_to_axi_periph_WREADY = M01_AXI_wready;
  assign m02_couplers_to_axi_periph_ARREADY = M02_AXI_arready;
  assign m02_couplers_to_axi_periph_AWREADY = M02_AXI_awready;
  assign m02_couplers_to_axi_periph_BRESP = M02_AXI_bresp[1:0];
  assign m02_couplers_to_axi_periph_BVALID = M02_AXI_bvalid;
  assign m02_couplers_to_axi_periph_RDATA = M02_AXI_rdata[31:0];
  assign m02_couplers_to_axi_periph_RRESP = M02_AXI_rresp[1:0];
  assign m02_couplers_to_axi_periph_RVALID = M02_AXI_rvalid;
  assign m02_couplers_to_axi_periph_WREADY = M02_AXI_wready;
  m00_couplers_imp_1HQR5QE m00_couplers
       (.M_ACLK(axi_periph_ACLK_net),
        .M_ARESETN(axi_periph_ARESETN_net),
        .M_AXI_araddr(m00_couplers_to_axi_periph_ARADDR),
        .M_AXI_arready(m00_couplers_to_axi_periph_ARREADY),
        .M_AXI_arvalid(m00_couplers_to_axi_periph_ARVALID),
        .M_AXI_awaddr(m00_couplers_to_axi_periph_AWADDR),
        .M_AXI_awready(m00_couplers_to_axi_periph_AWREADY),
        .M_AXI_awvalid(m00_couplers_to_axi_periph_AWVALID),
        .M_AXI_bready(m00_couplers_to_axi_periph_BREADY),
        .M_AXI_bresp(m00_couplers_to_axi_periph_BRESP),
        .M_AXI_bvalid(m00_couplers_to_axi_periph_BVALID),
        .M_AXI_rdata(m00_couplers_to_axi_periph_RDATA),
        .M_AXI_rready(m00_couplers_to_axi_periph_RREADY),
        .M_AXI_rresp(m00_couplers_to_axi_periph_RRESP),
        .M_AXI_rvalid(m00_couplers_to_axi_periph_RVALID),
        .M_AXI_wdata(m00_couplers_to_axi_periph_WDATA),
        .M_AXI_wready(m00_couplers_to_axi_periph_WREADY),
        .M_AXI_wstrb(m00_couplers_to_axi_periph_WSTRB),
        .M_AXI_wvalid(m00_couplers_to_axi_periph_WVALID),
        .S_ACLK(axi_periph_ACLK_net),
        .S_ARESETN(axi_periph_ARESETN_net),
        .S_AXI_araddr(xbar_to_m00_couplers_ARADDR),
        .S_AXI_arready(xbar_to_m00_couplers_ARREADY),
        .S_AXI_arvalid(xbar_to_m00_couplers_ARVALID),
        .S_AXI_awaddr(xbar_to_m00_couplers_AWADDR),
        .S_AXI_awready(xbar_to_m00_couplers_AWREADY),
        .S_AXI_awvalid(xbar_to_m00_couplers_AWVALID),
        .S_AXI_bready(xbar_to_m00_couplers_BREADY),
        .S_AXI_bresp(xbar_to_m00_couplers_BRESP),
        .S_AXI_bvalid(xbar_to_m00_couplers_BVALID),
        .S_AXI_rdata(xbar_to_m00_couplers_RDATA),
        .S_AXI_rready(xbar_to_m00_couplers_RREADY),
        .S_AXI_rresp(xbar_to_m00_couplers_RRESP),
        .S_AXI_rvalid(xbar_to_m00_couplers_RVALID),
        .S_AXI_wdata(xbar_to_m00_couplers_WDATA),
        .S_AXI_wready(xbar_to_m00_couplers_WREADY),
        .S_AXI_wstrb(xbar_to_m00_couplers_WSTRB),
        .S_AXI_wvalid(xbar_to_m00_couplers_WVALID));
  m01_couplers_imp_D0CAP3 m01_couplers
       (.M_ACLK(axi_periph_ACLK_net),
        .M_ARESETN(axi_periph_ARESETN_net),
        .M_AXI_araddr(m01_couplers_to_axi_periph_ARADDR),
        .M_AXI_arready(m01_couplers_to_axi_periph_ARREADY),
        .M_AXI_arvalid(m01_couplers_to_axi_periph_ARVALID),
        .M_AXI_awaddr(m01_couplers_to_axi_periph_AWADDR),
        .M_AXI_awready(m01_couplers_to_axi_periph_AWREADY),
        .M_AXI_awvalid(m01_couplers_to_axi_periph_AWVALID),
        .M_AXI_bready(m01_couplers_to_axi_periph_BREADY),
        .M_AXI_bresp(m01_couplers_to_axi_periph_BRESP),
        .M_AXI_bvalid(m01_couplers_to_axi_periph_BVALID),
        .M_AXI_rdata(m01_couplers_to_axi_periph_RDATA),
        .M_AXI_rready(m01_couplers_to_axi_periph_RREADY),
        .M_AXI_rresp(m01_couplers_to_axi_periph_RRESP),
        .M_AXI_rvalid(m01_couplers_to_axi_periph_RVALID),
        .M_AXI_wdata(m01_couplers_to_axi_periph_WDATA),
        .M_AXI_wready(m01_couplers_to_axi_periph_WREADY),
        .M_AXI_wstrb(m01_couplers_to_axi_periph_WSTRB),
        .M_AXI_wvalid(m01_couplers_to_axi_periph_WVALID),
        .S_ACLK(axi_periph_ACLK_net),
        .S_ARESETN(axi_periph_ARESETN_net),
        .S_AXI_araddr(xbar_to_m01_couplers_ARADDR),
        .S_AXI_arready(xbar_to_m01_couplers_ARREADY),
        .S_AXI_arvalid(xbar_to_m01_couplers_ARVALID),
        .S_AXI_awaddr(xbar_to_m01_couplers_AWADDR),
        .S_AXI_awready(xbar_to_m01_couplers_AWREADY),
        .S_AXI_awvalid(xbar_to_m01_couplers_AWVALID),
        .S_AXI_bready(xbar_to_m01_couplers_BREADY),
        .S_AXI_bresp(xbar_to_m01_couplers_BRESP),
        .S_AXI_bvalid(xbar_to_m01_couplers_BVALID),
        .S_AXI_rdata(xbar_to_m01_couplers_RDATA),
        .S_AXI_rready(xbar_to_m01_couplers_RREADY),
        .S_AXI_rresp(xbar_to_m01_couplers_RRESP),
        .S_AXI_rvalid(xbar_to_m01_couplers_RVALID),
        .S_AXI_wdata(xbar_to_m01_couplers_WDATA),
        .S_AXI_wready(xbar_to_m01_couplers_WREADY),
        .S_AXI_wstrb(xbar_to_m01_couplers_WSTRB),
        .S_AXI_wvalid(xbar_to_m01_couplers_WVALID));
  m02_couplers_imp_1IHRDXH m02_couplers
       (.M_ACLK(axi_periph_ACLK_net),
        .M_ARESETN(axi_periph_ARESETN_net),
        .M_AXI_araddr(m02_couplers_to_axi_periph_ARADDR),
        .M_AXI_arready(m02_couplers_to_axi_periph_ARREADY),
        .M_AXI_arvalid(m02_couplers_to_axi_periph_ARVALID),
        .M_AXI_awaddr(m02_couplers_to_axi_periph_AWADDR),
        .M_AXI_awready(m02_couplers_to_axi_periph_AWREADY),
        .M_AXI_awvalid(m02_couplers_to_axi_periph_AWVALID),
        .M_AXI_bready(m02_couplers_to_axi_periph_BREADY),
        .M_AXI_bresp(m02_couplers_to_axi_periph_BRESP),
        .M_AXI_bvalid(m02_couplers_to_axi_periph_BVALID),
        .M_AXI_rdata(m02_couplers_to_axi_periph_RDATA),
        .M_AXI_rready(m02_couplers_to_axi_periph_RREADY),
        .M_AXI_rresp(m02_couplers_to_axi_periph_RRESP),
        .M_AXI_rvalid(m02_couplers_to_axi_periph_RVALID),
        .M_AXI_wdata(m02_couplers_to_axi_periph_WDATA),
        .M_AXI_wready(m02_couplers_to_axi_periph_WREADY),
        .M_AXI_wstrb(m02_couplers_to_axi_periph_WSTRB),
        .M_AXI_wvalid(m02_couplers_to_axi_periph_WVALID),
        .S_ACLK(axi_periph_ACLK_net),
        .S_ARESETN(axi_periph_ARESETN_net),
        .S_AXI_araddr(xbar_to_m02_couplers_ARADDR),
        .S_AXI_arready(xbar_to_m02_couplers_ARREADY),
        .S_AXI_arvalid(xbar_to_m02_couplers_ARVALID),
        .S_AXI_awaddr(xbar_to_m02_couplers_AWADDR),
        .S_AXI_awready(xbar_to_m02_couplers_AWREADY),
        .S_AXI_awvalid(xbar_to_m02_couplers_AWVALID),
        .S_AXI_bready(xbar_to_m02_couplers_BREADY),
        .S_AXI_bresp(xbar_to_m02_couplers_BRESP),
        .S_AXI_bvalid(xbar_to_m02_couplers_BVALID),
        .S_AXI_rdata(xbar_to_m02_couplers_RDATA),
        .S_AXI_rready(xbar_to_m02_couplers_RREADY),
        .S_AXI_rresp(xbar_to_m02_couplers_RRESP),
        .S_AXI_rvalid(xbar_to_m02_couplers_RVALID),
        .S_AXI_wdata(xbar_to_m02_couplers_WDATA),
        .S_AXI_wready(xbar_to_m02_couplers_WREADY),
        .S_AXI_wstrb(xbar_to_m02_couplers_WSTRB),
        .S_AXI_wvalid(xbar_to_m02_couplers_WVALID));
  s00_couplers_imp_FOYHZ8 s00_couplers
       (.M_ACLK(axi_periph_ACLK_net),
        .M_ARESETN(axi_periph_ARESETN_net),
        .M_AXI_araddr(s00_couplers_to_xbar_ARADDR),
        .M_AXI_arprot(s00_couplers_to_xbar_ARPROT),
        .M_AXI_arready(s00_couplers_to_xbar_ARREADY),
        .M_AXI_arvalid(s00_couplers_to_xbar_ARVALID),
        .M_AXI_awaddr(s00_couplers_to_xbar_AWADDR),
        .M_AXI_awprot(s00_couplers_to_xbar_AWPROT),
        .M_AXI_awready(s00_couplers_to_xbar_AWREADY),
        .M_AXI_awvalid(s00_couplers_to_xbar_AWVALID),
        .M_AXI_bready(s00_couplers_to_xbar_BREADY),
        .M_AXI_bresp(s00_couplers_to_xbar_BRESP),
        .M_AXI_bvalid(s00_couplers_to_xbar_BVALID),
        .M_AXI_rdata(s00_couplers_to_xbar_RDATA),
        .M_AXI_rready(s00_couplers_to_xbar_RREADY),
        .M_AXI_rresp(s00_couplers_to_xbar_RRESP),
        .M_AXI_rvalid(s00_couplers_to_xbar_RVALID),
        .M_AXI_wdata(s00_couplers_to_xbar_WDATA),
        .M_AXI_wready(s00_couplers_to_xbar_WREADY),
        .M_AXI_wstrb(s00_couplers_to_xbar_WSTRB),
        .M_AXI_wvalid(s00_couplers_to_xbar_WVALID),
        .S_ACLK(axi_periph_ACLK_net),
        .S_ARESETN(axi_periph_ARESETN_net),
        .S_AXI_araddr(axi_periph_to_s00_couplers_ARADDR),
        .S_AXI_arburst(axi_periph_to_s00_couplers_ARBURST),
        .S_AXI_arcache(axi_periph_to_s00_couplers_ARCACHE),
        .S_AXI_arid(axi_periph_to_s00_couplers_ARID),
        .S_AXI_arlen(axi_periph_to_s00_couplers_ARLEN),
        .S_AXI_arlock(axi_periph_to_s00_couplers_ARLOCK),
        .S_AXI_arprot(axi_periph_to_s00_couplers_ARPROT),
        .S_AXI_arqos(axi_periph_to_s00_couplers_ARQOS),
        .S_AXI_arready(axi_periph_to_s00_couplers_ARREADY),
        .S_AXI_arsize(axi_periph_to_s00_couplers_ARSIZE),
        .S_AXI_arvalid(axi_periph_to_s00_couplers_ARVALID),
        .S_AXI_awaddr(axi_periph_to_s00_couplers_AWADDR),
        .S_AXI_awburst(axi_periph_to_s00_couplers_AWBURST),
        .S_AXI_awcache(axi_periph_to_s00_couplers_AWCACHE),
        .S_AXI_awid(axi_periph_to_s00_couplers_AWID),
        .S_AXI_awlen(axi_periph_to_s00_couplers_AWLEN),
        .S_AXI_awlock(axi_periph_to_s00_couplers_AWLOCK),
        .S_AXI_awprot(axi_periph_to_s00_couplers_AWPROT),
        .S_AXI_awqos(axi_periph_to_s00_couplers_AWQOS),
        .S_AXI_awready(axi_periph_to_s00_couplers_AWREADY),
        .S_AXI_awsize(axi_periph_to_s00_couplers_AWSIZE),
        .S_AXI_awvalid(axi_periph_to_s00_couplers_AWVALID),
        .S_AXI_bid(axi_periph_to_s00_couplers_BID),
        .S_AXI_bready(axi_periph_to_s00_couplers_BREADY),
        .S_AXI_bresp(axi_periph_to_s00_couplers_BRESP),
        .S_AXI_bvalid(axi_periph_to_s00_couplers_BVALID),
        .S_AXI_rdata(axi_periph_to_s00_couplers_RDATA),
        .S_AXI_rid(axi_periph_to_s00_couplers_RID),
        .S_AXI_rlast(axi_periph_to_s00_couplers_RLAST),
        .S_AXI_rready(axi_periph_to_s00_couplers_RREADY),
        .S_AXI_rresp(axi_periph_to_s00_couplers_RRESP),
        .S_AXI_rvalid(axi_periph_to_s00_couplers_RVALID),
        .S_AXI_wdata(axi_periph_to_s00_couplers_WDATA),
        .S_AXI_wid(axi_periph_to_s00_couplers_WID),
        .S_AXI_wlast(axi_periph_to_s00_couplers_WLAST),
        .S_AXI_wready(axi_periph_to_s00_couplers_WREADY),
        .S_AXI_wstrb(axi_periph_to_s00_couplers_WSTRB),
        .S_AXI_wvalid(axi_periph_to_s00_couplers_WVALID));
  s01_couplers_imp_1NW8H9H s01_couplers
       (.M_ACLK(axi_periph_ACLK_net),
        .M_ARESETN(axi_periph_ARESETN_net),
        .M_AXI_araddr(s01_couplers_to_xbar_ARADDR),
        .M_AXI_arprot(s01_couplers_to_xbar_ARPROT),
        .M_AXI_arready(s01_couplers_to_xbar_ARREADY),
        .M_AXI_arvalid(s01_couplers_to_xbar_ARVALID),
        .M_AXI_awaddr(s01_couplers_to_xbar_AWADDR),
        .M_AXI_awprot(s01_couplers_to_xbar_AWPROT),
        .M_AXI_awready(s01_couplers_to_xbar_AWREADY),
        .M_AXI_awvalid(s01_couplers_to_xbar_AWVALID),
        .M_AXI_bready(s01_couplers_to_xbar_BREADY),
        .M_AXI_bresp(s01_couplers_to_xbar_BRESP),
        .M_AXI_bvalid(s01_couplers_to_xbar_BVALID),
        .M_AXI_rdata(s01_couplers_to_xbar_RDATA),
        .M_AXI_rready(s01_couplers_to_xbar_RREADY),
        .M_AXI_rresp(s01_couplers_to_xbar_RRESP),
        .M_AXI_rvalid(s01_couplers_to_xbar_RVALID),
        .M_AXI_wdata(s01_couplers_to_xbar_WDATA),
        .M_AXI_wready(s01_couplers_to_xbar_WREADY),
        .M_AXI_wstrb(s01_couplers_to_xbar_WSTRB),
        .M_AXI_wvalid(s01_couplers_to_xbar_WVALID),
        .S_ACLK(axi_periph_ACLK_net),
        .S_ARESETN(axi_periph_ARESETN_net),
        .S_AXI_araddr(axi_periph_to_s01_couplers_ARADDR),
        .S_AXI_arprot(axi_periph_to_s01_couplers_ARPROT),
        .S_AXI_arready(axi_periph_to_s01_couplers_ARREADY),
        .S_AXI_arvalid(axi_periph_to_s01_couplers_ARVALID),
        .S_AXI_awaddr(axi_periph_to_s01_couplers_AWADDR),
        .S_AXI_awprot(axi_periph_to_s01_couplers_AWPROT),
        .S_AXI_awready(axi_periph_to_s01_couplers_AWREADY),
        .S_AXI_awvalid(axi_periph_to_s01_couplers_AWVALID),
        .S_AXI_bready(axi_periph_to_s01_couplers_BREADY),
        .S_AXI_bresp(axi_periph_to_s01_couplers_BRESP),
        .S_AXI_bvalid(axi_periph_to_s01_couplers_BVALID),
        .S_AXI_rdata(axi_periph_to_s01_couplers_RDATA),
        .S_AXI_rready(axi_periph_to_s01_couplers_RREADY),
        .S_AXI_rresp(axi_periph_to_s01_couplers_RRESP),
        .S_AXI_rvalid(axi_periph_to_s01_couplers_RVALID),
        .S_AXI_wdata(axi_periph_to_s01_couplers_WDATA),
        .S_AXI_wready(axi_periph_to_s01_couplers_WREADY),
        .S_AXI_wstrb(axi_periph_to_s01_couplers_WSTRB),
        .S_AXI_wvalid(axi_periph_to_s01_couplers_WVALID));
  can_test_xbar_0 xbar
       (.aclk(axi_periph_ACLK_net),
        .aresetn(axi_periph_ARESETN_net),
        .m_axi_araddr({xbar_to_m02_couplers_ARADDR,xbar_to_m01_couplers_ARADDR,xbar_to_m00_couplers_ARADDR}),
        .m_axi_arready({xbar_to_m02_couplers_ARREADY,xbar_to_m01_couplers_ARREADY,xbar_to_m00_couplers_ARREADY}),
        .m_axi_arvalid({xbar_to_m02_couplers_ARVALID,xbar_to_m01_couplers_ARVALID,xbar_to_m00_couplers_ARVALID}),
        .m_axi_awaddr({xbar_to_m02_couplers_AWADDR,xbar_to_m01_couplers_AWADDR,xbar_to_m00_couplers_AWADDR}),
        .m_axi_awready({xbar_to_m02_couplers_AWREADY,xbar_to_m01_couplers_AWREADY,xbar_to_m00_couplers_AWREADY}),
        .m_axi_awvalid({xbar_to_m02_couplers_AWVALID,xbar_to_m01_couplers_AWVALID,xbar_to_m00_couplers_AWVALID}),
        .m_axi_bready({xbar_to_m02_couplers_BREADY,xbar_to_m01_couplers_BREADY,xbar_to_m00_couplers_BREADY}),
        .m_axi_bresp({xbar_to_m02_couplers_BRESP,xbar_to_m01_couplers_BRESP,xbar_to_m00_couplers_BRESP}),
        .m_axi_bvalid({xbar_to_m02_couplers_BVALID,xbar_to_m01_couplers_BVALID,xbar_to_m00_couplers_BVALID}),
        .m_axi_rdata({xbar_to_m02_couplers_RDATA,xbar_to_m01_couplers_RDATA,xbar_to_m00_couplers_RDATA}),
        .m_axi_rready({xbar_to_m02_couplers_RREADY,xbar_to_m01_couplers_RREADY,xbar_to_m00_couplers_RREADY}),
        .m_axi_rresp({xbar_to_m02_couplers_RRESP,xbar_to_m01_couplers_RRESP,xbar_to_m00_couplers_RRESP}),
        .m_axi_rvalid({xbar_to_m02_couplers_RVALID,xbar_to_m01_couplers_RVALID,xbar_to_m00_couplers_RVALID}),
        .m_axi_wdata({xbar_to_m02_couplers_WDATA,xbar_to_m01_couplers_WDATA,xbar_to_m00_couplers_WDATA}),
        .m_axi_wready({xbar_to_m02_couplers_WREADY,xbar_to_m01_couplers_WREADY,xbar_to_m00_couplers_WREADY}),
        .m_axi_wstrb({xbar_to_m02_couplers_WSTRB,xbar_to_m01_couplers_WSTRB,xbar_to_m00_couplers_WSTRB}),
        .m_axi_wvalid({xbar_to_m02_couplers_WVALID,xbar_to_m01_couplers_WVALID,xbar_to_m00_couplers_WVALID}),
        .s_axi_araddr({s01_couplers_to_xbar_ARADDR,s00_couplers_to_xbar_ARADDR}),
        .s_axi_arprot({s01_couplers_to_xbar_ARPROT,s00_couplers_to_xbar_ARPROT}),
        .s_axi_arready({s01_couplers_to_xbar_ARREADY,s00_couplers_to_xbar_ARREADY}),
        .s_axi_arvalid({s01_couplers_to_xbar_ARVALID,s00_couplers_to_xbar_ARVALID}),
        .s_axi_awaddr({s01_couplers_to_xbar_AWADDR,s00_couplers_to_xbar_AWADDR}),
        .s_axi_awprot({s01_couplers_to_xbar_AWPROT,s00_couplers_to_xbar_AWPROT}),
        .s_axi_awready({s01_couplers_to_xbar_AWREADY,s00_couplers_to_xbar_AWREADY}),
        .s_axi_awvalid({s01_couplers_to_xbar_AWVALID,s00_couplers_to_xbar_AWVALID}),
        .s_axi_bready({s01_couplers_to_xbar_BREADY,s00_couplers_to_xbar_BREADY}),
        .s_axi_bresp({s01_couplers_to_xbar_BRESP,s00_couplers_to_xbar_BRESP}),
        .s_axi_bvalid({s01_couplers_to_xbar_BVALID,s00_couplers_to_xbar_BVALID}),
        .s_axi_rdata({s01_couplers_to_xbar_RDATA,s00_couplers_to_xbar_RDATA}),
        .s_axi_rready({s01_couplers_to_xbar_RREADY,s00_couplers_to_xbar_RREADY}),
        .s_axi_rresp({s01_couplers_to_xbar_RRESP,s00_couplers_to_xbar_RRESP}),
        .s_axi_rvalid({s01_couplers_to_xbar_RVALID,s00_couplers_to_xbar_RVALID}),
        .s_axi_wdata({s01_couplers_to_xbar_WDATA,s00_couplers_to_xbar_WDATA}),
        .s_axi_wready({s01_couplers_to_xbar_WREADY,s00_couplers_to_xbar_WREADY}),
        .s_axi_wstrb({s01_couplers_to_xbar_WSTRB,s00_couplers_to_xbar_WSTRB}),
        .s_axi_wvalid({s01_couplers_to_xbar_WVALID,s00_couplers_to_xbar_WVALID}));
endmodule

module m00_couplers_imp_1HQR5QE
   (M_ACLK,
    M_ARESETN,
    M_AXI_araddr,
    M_AXI_arready,
    M_AXI_arvalid,
    M_AXI_awaddr,
    M_AXI_awready,
    M_AXI_awvalid,
    M_AXI_bready,
    M_AXI_bresp,
    M_AXI_bvalid,
    M_AXI_rdata,
    M_AXI_rready,
    M_AXI_rresp,
    M_AXI_rvalid,
    M_AXI_wdata,
    M_AXI_wready,
    M_AXI_wstrb,
    M_AXI_wvalid,
    S_ACLK,
    S_ARESETN,
    S_AXI_araddr,
    S_AXI_arready,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awready,
    S_AXI_awvalid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid);
  input M_ACLK;
  input M_ARESETN;
  output [31:0]M_AXI_araddr;
  input M_AXI_arready;
  output M_AXI_arvalid;
  output [31:0]M_AXI_awaddr;
  input M_AXI_awready;
  output M_AXI_awvalid;
  output M_AXI_bready;
  input [1:0]M_AXI_bresp;
  input M_AXI_bvalid;
  input [31:0]M_AXI_rdata;
  output M_AXI_rready;
  input [1:0]M_AXI_rresp;
  input M_AXI_rvalid;
  output [31:0]M_AXI_wdata;
  input M_AXI_wready;
  output [3:0]M_AXI_wstrb;
  output M_AXI_wvalid;
  input S_ACLK;
  input S_ARESETN;
  input [31:0]S_AXI_araddr;
  output S_AXI_arready;
  input S_AXI_arvalid;
  input [31:0]S_AXI_awaddr;
  output S_AXI_awready;
  input S_AXI_awvalid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;

  wire [31:0]m00_couplers_to_m00_couplers_ARADDR;
  wire m00_couplers_to_m00_couplers_ARREADY;
  wire m00_couplers_to_m00_couplers_ARVALID;
  wire [31:0]m00_couplers_to_m00_couplers_AWADDR;
  wire m00_couplers_to_m00_couplers_AWREADY;
  wire m00_couplers_to_m00_couplers_AWVALID;
  wire m00_couplers_to_m00_couplers_BREADY;
  wire [1:0]m00_couplers_to_m00_couplers_BRESP;
  wire m00_couplers_to_m00_couplers_BVALID;
  wire [31:0]m00_couplers_to_m00_couplers_RDATA;
  wire m00_couplers_to_m00_couplers_RREADY;
  wire [1:0]m00_couplers_to_m00_couplers_RRESP;
  wire m00_couplers_to_m00_couplers_RVALID;
  wire [31:0]m00_couplers_to_m00_couplers_WDATA;
  wire m00_couplers_to_m00_couplers_WREADY;
  wire [3:0]m00_couplers_to_m00_couplers_WSTRB;
  wire m00_couplers_to_m00_couplers_WVALID;

  assign M_AXI_araddr[31:0] = m00_couplers_to_m00_couplers_ARADDR;
  assign M_AXI_arvalid = m00_couplers_to_m00_couplers_ARVALID;
  assign M_AXI_awaddr[31:0] = m00_couplers_to_m00_couplers_AWADDR;
  assign M_AXI_awvalid = m00_couplers_to_m00_couplers_AWVALID;
  assign M_AXI_bready = m00_couplers_to_m00_couplers_BREADY;
  assign M_AXI_rready = m00_couplers_to_m00_couplers_RREADY;
  assign M_AXI_wdata[31:0] = m00_couplers_to_m00_couplers_WDATA;
  assign M_AXI_wstrb[3:0] = m00_couplers_to_m00_couplers_WSTRB;
  assign M_AXI_wvalid = m00_couplers_to_m00_couplers_WVALID;
  assign S_AXI_arready = m00_couplers_to_m00_couplers_ARREADY;
  assign S_AXI_awready = m00_couplers_to_m00_couplers_AWREADY;
  assign S_AXI_bresp[1:0] = m00_couplers_to_m00_couplers_BRESP;
  assign S_AXI_bvalid = m00_couplers_to_m00_couplers_BVALID;
  assign S_AXI_rdata[31:0] = m00_couplers_to_m00_couplers_RDATA;
  assign S_AXI_rresp[1:0] = m00_couplers_to_m00_couplers_RRESP;
  assign S_AXI_rvalid = m00_couplers_to_m00_couplers_RVALID;
  assign S_AXI_wready = m00_couplers_to_m00_couplers_WREADY;
  assign m00_couplers_to_m00_couplers_ARADDR = S_AXI_araddr[31:0];
  assign m00_couplers_to_m00_couplers_ARREADY = M_AXI_arready;
  assign m00_couplers_to_m00_couplers_ARVALID = S_AXI_arvalid;
  assign m00_couplers_to_m00_couplers_AWADDR = S_AXI_awaddr[31:0];
  assign m00_couplers_to_m00_couplers_AWREADY = M_AXI_awready;
  assign m00_couplers_to_m00_couplers_AWVALID = S_AXI_awvalid;
  assign m00_couplers_to_m00_couplers_BREADY = S_AXI_bready;
  assign m00_couplers_to_m00_couplers_BRESP = M_AXI_bresp[1:0];
  assign m00_couplers_to_m00_couplers_BVALID = M_AXI_bvalid;
  assign m00_couplers_to_m00_couplers_RDATA = M_AXI_rdata[31:0];
  assign m00_couplers_to_m00_couplers_RREADY = S_AXI_rready;
  assign m00_couplers_to_m00_couplers_RRESP = M_AXI_rresp[1:0];
  assign m00_couplers_to_m00_couplers_RVALID = M_AXI_rvalid;
  assign m00_couplers_to_m00_couplers_WDATA = S_AXI_wdata[31:0];
  assign m00_couplers_to_m00_couplers_WREADY = M_AXI_wready;
  assign m00_couplers_to_m00_couplers_WSTRB = S_AXI_wstrb[3:0];
  assign m00_couplers_to_m00_couplers_WVALID = S_AXI_wvalid;
endmodule

module m01_couplers_imp_D0CAP3
   (M_ACLK,
    M_ARESETN,
    M_AXI_araddr,
    M_AXI_arready,
    M_AXI_arvalid,
    M_AXI_awaddr,
    M_AXI_awready,
    M_AXI_awvalid,
    M_AXI_bready,
    M_AXI_bresp,
    M_AXI_bvalid,
    M_AXI_rdata,
    M_AXI_rready,
    M_AXI_rresp,
    M_AXI_rvalid,
    M_AXI_wdata,
    M_AXI_wready,
    M_AXI_wstrb,
    M_AXI_wvalid,
    S_ACLK,
    S_ARESETN,
    S_AXI_araddr,
    S_AXI_arready,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awready,
    S_AXI_awvalid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid);
  input M_ACLK;
  input M_ARESETN;
  output [31:0]M_AXI_araddr;
  input M_AXI_arready;
  output M_AXI_arvalid;
  output [31:0]M_AXI_awaddr;
  input M_AXI_awready;
  output M_AXI_awvalid;
  output M_AXI_bready;
  input [1:0]M_AXI_bresp;
  input M_AXI_bvalid;
  input [31:0]M_AXI_rdata;
  output M_AXI_rready;
  input [1:0]M_AXI_rresp;
  input M_AXI_rvalid;
  output [31:0]M_AXI_wdata;
  input M_AXI_wready;
  output [3:0]M_AXI_wstrb;
  output M_AXI_wvalid;
  input S_ACLK;
  input S_ARESETN;
  input [31:0]S_AXI_araddr;
  output S_AXI_arready;
  input S_AXI_arvalid;
  input [31:0]S_AXI_awaddr;
  output S_AXI_awready;
  input S_AXI_awvalid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;

  wire [31:0]m01_couplers_to_m01_couplers_ARADDR;
  wire m01_couplers_to_m01_couplers_ARREADY;
  wire m01_couplers_to_m01_couplers_ARVALID;
  wire [31:0]m01_couplers_to_m01_couplers_AWADDR;
  wire m01_couplers_to_m01_couplers_AWREADY;
  wire m01_couplers_to_m01_couplers_AWVALID;
  wire m01_couplers_to_m01_couplers_BREADY;
  wire [1:0]m01_couplers_to_m01_couplers_BRESP;
  wire m01_couplers_to_m01_couplers_BVALID;
  wire [31:0]m01_couplers_to_m01_couplers_RDATA;
  wire m01_couplers_to_m01_couplers_RREADY;
  wire [1:0]m01_couplers_to_m01_couplers_RRESP;
  wire m01_couplers_to_m01_couplers_RVALID;
  wire [31:0]m01_couplers_to_m01_couplers_WDATA;
  wire m01_couplers_to_m01_couplers_WREADY;
  wire [3:0]m01_couplers_to_m01_couplers_WSTRB;
  wire m01_couplers_to_m01_couplers_WVALID;

  assign M_AXI_araddr[31:0] = m01_couplers_to_m01_couplers_ARADDR;
  assign M_AXI_arvalid = m01_couplers_to_m01_couplers_ARVALID;
  assign M_AXI_awaddr[31:0] = m01_couplers_to_m01_couplers_AWADDR;
  assign M_AXI_awvalid = m01_couplers_to_m01_couplers_AWVALID;
  assign M_AXI_bready = m01_couplers_to_m01_couplers_BREADY;
  assign M_AXI_rready = m01_couplers_to_m01_couplers_RREADY;
  assign M_AXI_wdata[31:0] = m01_couplers_to_m01_couplers_WDATA;
  assign M_AXI_wstrb[3:0] = m01_couplers_to_m01_couplers_WSTRB;
  assign M_AXI_wvalid = m01_couplers_to_m01_couplers_WVALID;
  assign S_AXI_arready = m01_couplers_to_m01_couplers_ARREADY;
  assign S_AXI_awready = m01_couplers_to_m01_couplers_AWREADY;
  assign S_AXI_bresp[1:0] = m01_couplers_to_m01_couplers_BRESP;
  assign S_AXI_bvalid = m01_couplers_to_m01_couplers_BVALID;
  assign S_AXI_rdata[31:0] = m01_couplers_to_m01_couplers_RDATA;
  assign S_AXI_rresp[1:0] = m01_couplers_to_m01_couplers_RRESP;
  assign S_AXI_rvalid = m01_couplers_to_m01_couplers_RVALID;
  assign S_AXI_wready = m01_couplers_to_m01_couplers_WREADY;
  assign m01_couplers_to_m01_couplers_ARADDR = S_AXI_araddr[31:0];
  assign m01_couplers_to_m01_couplers_ARREADY = M_AXI_arready;
  assign m01_couplers_to_m01_couplers_ARVALID = S_AXI_arvalid;
  assign m01_couplers_to_m01_couplers_AWADDR = S_AXI_awaddr[31:0];
  assign m01_couplers_to_m01_couplers_AWREADY = M_AXI_awready;
  assign m01_couplers_to_m01_couplers_AWVALID = S_AXI_awvalid;
  assign m01_couplers_to_m01_couplers_BREADY = S_AXI_bready;
  assign m01_couplers_to_m01_couplers_BRESP = M_AXI_bresp[1:0];
  assign m01_couplers_to_m01_couplers_BVALID = M_AXI_bvalid;
  assign m01_couplers_to_m01_couplers_RDATA = M_AXI_rdata[31:0];
  assign m01_couplers_to_m01_couplers_RREADY = S_AXI_rready;
  assign m01_couplers_to_m01_couplers_RRESP = M_AXI_rresp[1:0];
  assign m01_couplers_to_m01_couplers_RVALID = M_AXI_rvalid;
  assign m01_couplers_to_m01_couplers_WDATA = S_AXI_wdata[31:0];
  assign m01_couplers_to_m01_couplers_WREADY = M_AXI_wready;
  assign m01_couplers_to_m01_couplers_WSTRB = S_AXI_wstrb[3:0];
  assign m01_couplers_to_m01_couplers_WVALID = S_AXI_wvalid;
endmodule

module m02_couplers_imp_1IHRDXH
   (M_ACLK,
    M_ARESETN,
    M_AXI_araddr,
    M_AXI_arready,
    M_AXI_arvalid,
    M_AXI_awaddr,
    M_AXI_awready,
    M_AXI_awvalid,
    M_AXI_bready,
    M_AXI_bresp,
    M_AXI_bvalid,
    M_AXI_rdata,
    M_AXI_rready,
    M_AXI_rresp,
    M_AXI_rvalid,
    M_AXI_wdata,
    M_AXI_wready,
    M_AXI_wstrb,
    M_AXI_wvalid,
    S_ACLK,
    S_ARESETN,
    S_AXI_araddr,
    S_AXI_arready,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awready,
    S_AXI_awvalid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid);
  input M_ACLK;
  input M_ARESETN;
  output [31:0]M_AXI_araddr;
  input M_AXI_arready;
  output M_AXI_arvalid;
  output [31:0]M_AXI_awaddr;
  input M_AXI_awready;
  output M_AXI_awvalid;
  output M_AXI_bready;
  input [1:0]M_AXI_bresp;
  input M_AXI_bvalid;
  input [31:0]M_AXI_rdata;
  output M_AXI_rready;
  input [1:0]M_AXI_rresp;
  input M_AXI_rvalid;
  output [31:0]M_AXI_wdata;
  input M_AXI_wready;
  output [3:0]M_AXI_wstrb;
  output M_AXI_wvalid;
  input S_ACLK;
  input S_ARESETN;
  input [31:0]S_AXI_araddr;
  output S_AXI_arready;
  input S_AXI_arvalid;
  input [31:0]S_AXI_awaddr;
  output S_AXI_awready;
  input S_AXI_awvalid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;

  wire [31:0]m02_couplers_to_m02_couplers_ARADDR;
  wire m02_couplers_to_m02_couplers_ARREADY;
  wire m02_couplers_to_m02_couplers_ARVALID;
  wire [31:0]m02_couplers_to_m02_couplers_AWADDR;
  wire m02_couplers_to_m02_couplers_AWREADY;
  wire m02_couplers_to_m02_couplers_AWVALID;
  wire m02_couplers_to_m02_couplers_BREADY;
  wire [1:0]m02_couplers_to_m02_couplers_BRESP;
  wire m02_couplers_to_m02_couplers_BVALID;
  wire [31:0]m02_couplers_to_m02_couplers_RDATA;
  wire m02_couplers_to_m02_couplers_RREADY;
  wire [1:0]m02_couplers_to_m02_couplers_RRESP;
  wire m02_couplers_to_m02_couplers_RVALID;
  wire [31:0]m02_couplers_to_m02_couplers_WDATA;
  wire m02_couplers_to_m02_couplers_WREADY;
  wire [3:0]m02_couplers_to_m02_couplers_WSTRB;
  wire m02_couplers_to_m02_couplers_WVALID;

  assign M_AXI_araddr[31:0] = m02_couplers_to_m02_couplers_ARADDR;
  assign M_AXI_arvalid = m02_couplers_to_m02_couplers_ARVALID;
  assign M_AXI_awaddr[31:0] = m02_couplers_to_m02_couplers_AWADDR;
  assign M_AXI_awvalid = m02_couplers_to_m02_couplers_AWVALID;
  assign M_AXI_bready = m02_couplers_to_m02_couplers_BREADY;
  assign M_AXI_rready = m02_couplers_to_m02_couplers_RREADY;
  assign M_AXI_wdata[31:0] = m02_couplers_to_m02_couplers_WDATA;
  assign M_AXI_wstrb[3:0] = m02_couplers_to_m02_couplers_WSTRB;
  assign M_AXI_wvalid = m02_couplers_to_m02_couplers_WVALID;
  assign S_AXI_arready = m02_couplers_to_m02_couplers_ARREADY;
  assign S_AXI_awready = m02_couplers_to_m02_couplers_AWREADY;
  assign S_AXI_bresp[1:0] = m02_couplers_to_m02_couplers_BRESP;
  assign S_AXI_bvalid = m02_couplers_to_m02_couplers_BVALID;
  assign S_AXI_rdata[31:0] = m02_couplers_to_m02_couplers_RDATA;
  assign S_AXI_rresp[1:0] = m02_couplers_to_m02_couplers_RRESP;
  assign S_AXI_rvalid = m02_couplers_to_m02_couplers_RVALID;
  assign S_AXI_wready = m02_couplers_to_m02_couplers_WREADY;
  assign m02_couplers_to_m02_couplers_ARADDR = S_AXI_araddr[31:0];
  assign m02_couplers_to_m02_couplers_ARREADY = M_AXI_arready;
  assign m02_couplers_to_m02_couplers_ARVALID = S_AXI_arvalid;
  assign m02_couplers_to_m02_couplers_AWADDR = S_AXI_awaddr[31:0];
  assign m02_couplers_to_m02_couplers_AWREADY = M_AXI_awready;
  assign m02_couplers_to_m02_couplers_AWVALID = S_AXI_awvalid;
  assign m02_couplers_to_m02_couplers_BREADY = S_AXI_bready;
  assign m02_couplers_to_m02_couplers_BRESP = M_AXI_bresp[1:0];
  assign m02_couplers_to_m02_couplers_BVALID = M_AXI_bvalid;
  assign m02_couplers_to_m02_couplers_RDATA = M_AXI_rdata[31:0];
  assign m02_couplers_to_m02_couplers_RREADY = S_AXI_rready;
  assign m02_couplers_to_m02_couplers_RRESP = M_AXI_rresp[1:0];
  assign m02_couplers_to_m02_couplers_RVALID = M_AXI_rvalid;
  assign m02_couplers_to_m02_couplers_WDATA = S_AXI_wdata[31:0];
  assign m02_couplers_to_m02_couplers_WREADY = M_AXI_wready;
  assign m02_couplers_to_m02_couplers_WSTRB = S_AXI_wstrb[3:0];
  assign m02_couplers_to_m02_couplers_WVALID = S_AXI_wvalid;
endmodule

module s00_couplers_imp_FOYHZ8
   (M_ACLK,
    M_ARESETN,
    M_AXI_araddr,
    M_AXI_arprot,
    M_AXI_arready,
    M_AXI_arvalid,
    M_AXI_awaddr,
    M_AXI_awprot,
    M_AXI_awready,
    M_AXI_awvalid,
    M_AXI_bready,
    M_AXI_bresp,
    M_AXI_bvalid,
    M_AXI_rdata,
    M_AXI_rready,
    M_AXI_rresp,
    M_AXI_rvalid,
    M_AXI_wdata,
    M_AXI_wready,
    M_AXI_wstrb,
    M_AXI_wvalid,
    S_ACLK,
    S_ARESETN,
    S_AXI_araddr,
    S_AXI_arburst,
    S_AXI_arcache,
    S_AXI_arid,
    S_AXI_arlen,
    S_AXI_arlock,
    S_AXI_arprot,
    S_AXI_arqos,
    S_AXI_arready,
    S_AXI_arsize,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awburst,
    S_AXI_awcache,
    S_AXI_awid,
    S_AXI_awlen,
    S_AXI_awlock,
    S_AXI_awprot,
    S_AXI_awqos,
    S_AXI_awready,
    S_AXI_awsize,
    S_AXI_awvalid,
    S_AXI_bid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rid,
    S_AXI_rlast,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wid,
    S_AXI_wlast,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid);
  input M_ACLK;
  input M_ARESETN;
  output [31:0]M_AXI_araddr;
  output [2:0]M_AXI_arprot;
  input M_AXI_arready;
  output M_AXI_arvalid;
  output [31:0]M_AXI_awaddr;
  output [2:0]M_AXI_awprot;
  input M_AXI_awready;
  output M_AXI_awvalid;
  output M_AXI_bready;
  input [1:0]M_AXI_bresp;
  input M_AXI_bvalid;
  input [31:0]M_AXI_rdata;
  output M_AXI_rready;
  input [1:0]M_AXI_rresp;
  input M_AXI_rvalid;
  output [31:0]M_AXI_wdata;
  input M_AXI_wready;
  output [3:0]M_AXI_wstrb;
  output M_AXI_wvalid;
  input S_ACLK;
  input S_ARESETN;
  input [31:0]S_AXI_araddr;
  input [1:0]S_AXI_arburst;
  input [3:0]S_AXI_arcache;
  input [11:0]S_AXI_arid;
  input [3:0]S_AXI_arlen;
  input [1:0]S_AXI_arlock;
  input [2:0]S_AXI_arprot;
  input [3:0]S_AXI_arqos;
  output S_AXI_arready;
  input [2:0]S_AXI_arsize;
  input S_AXI_arvalid;
  input [31:0]S_AXI_awaddr;
  input [1:0]S_AXI_awburst;
  input [3:0]S_AXI_awcache;
  input [11:0]S_AXI_awid;
  input [3:0]S_AXI_awlen;
  input [1:0]S_AXI_awlock;
  input [2:0]S_AXI_awprot;
  input [3:0]S_AXI_awqos;
  output S_AXI_awready;
  input [2:0]S_AXI_awsize;
  input S_AXI_awvalid;
  output [11:0]S_AXI_bid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  output [11:0]S_AXI_rid;
  output S_AXI_rlast;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  input [11:0]S_AXI_wid;
  input S_AXI_wlast;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;

  wire S_ACLK_1;
  wire S_ARESETN_1;
  wire [31:0]auto_pc_to_s00_couplers_ARADDR;
  wire [2:0]auto_pc_to_s00_couplers_ARPROT;
  wire auto_pc_to_s00_couplers_ARREADY;
  wire auto_pc_to_s00_couplers_ARVALID;
  wire [31:0]auto_pc_to_s00_couplers_AWADDR;
  wire [2:0]auto_pc_to_s00_couplers_AWPROT;
  wire auto_pc_to_s00_couplers_AWREADY;
  wire auto_pc_to_s00_couplers_AWVALID;
  wire auto_pc_to_s00_couplers_BREADY;
  wire [1:0]auto_pc_to_s00_couplers_BRESP;
  wire auto_pc_to_s00_couplers_BVALID;
  wire [31:0]auto_pc_to_s00_couplers_RDATA;
  wire auto_pc_to_s00_couplers_RREADY;
  wire [1:0]auto_pc_to_s00_couplers_RRESP;
  wire auto_pc_to_s00_couplers_RVALID;
  wire [31:0]auto_pc_to_s00_couplers_WDATA;
  wire auto_pc_to_s00_couplers_WREADY;
  wire [3:0]auto_pc_to_s00_couplers_WSTRB;
  wire auto_pc_to_s00_couplers_WVALID;
  wire [31:0]s00_couplers_to_auto_pc_ARADDR;
  wire [1:0]s00_couplers_to_auto_pc_ARBURST;
  wire [3:0]s00_couplers_to_auto_pc_ARCACHE;
  wire [11:0]s00_couplers_to_auto_pc_ARID;
  wire [3:0]s00_couplers_to_auto_pc_ARLEN;
  wire [1:0]s00_couplers_to_auto_pc_ARLOCK;
  wire [2:0]s00_couplers_to_auto_pc_ARPROT;
  wire [3:0]s00_couplers_to_auto_pc_ARQOS;
  wire s00_couplers_to_auto_pc_ARREADY;
  wire [2:0]s00_couplers_to_auto_pc_ARSIZE;
  wire s00_couplers_to_auto_pc_ARVALID;
  wire [31:0]s00_couplers_to_auto_pc_AWADDR;
  wire [1:0]s00_couplers_to_auto_pc_AWBURST;
  wire [3:0]s00_couplers_to_auto_pc_AWCACHE;
  wire [11:0]s00_couplers_to_auto_pc_AWID;
  wire [3:0]s00_couplers_to_auto_pc_AWLEN;
  wire [1:0]s00_couplers_to_auto_pc_AWLOCK;
  wire [2:0]s00_couplers_to_auto_pc_AWPROT;
  wire [3:0]s00_couplers_to_auto_pc_AWQOS;
  wire s00_couplers_to_auto_pc_AWREADY;
  wire [2:0]s00_couplers_to_auto_pc_AWSIZE;
  wire s00_couplers_to_auto_pc_AWVALID;
  wire [11:0]s00_couplers_to_auto_pc_BID;
  wire s00_couplers_to_auto_pc_BREADY;
  wire [1:0]s00_couplers_to_auto_pc_BRESP;
  wire s00_couplers_to_auto_pc_BVALID;
  wire [31:0]s00_couplers_to_auto_pc_RDATA;
  wire [11:0]s00_couplers_to_auto_pc_RID;
  wire s00_couplers_to_auto_pc_RLAST;
  wire s00_couplers_to_auto_pc_RREADY;
  wire [1:0]s00_couplers_to_auto_pc_RRESP;
  wire s00_couplers_to_auto_pc_RVALID;
  wire [31:0]s00_couplers_to_auto_pc_WDATA;
  wire [11:0]s00_couplers_to_auto_pc_WID;
  wire s00_couplers_to_auto_pc_WLAST;
  wire s00_couplers_to_auto_pc_WREADY;
  wire [3:0]s00_couplers_to_auto_pc_WSTRB;
  wire s00_couplers_to_auto_pc_WVALID;

  assign M_AXI_araddr[31:0] = auto_pc_to_s00_couplers_ARADDR;
  assign M_AXI_arprot[2:0] = auto_pc_to_s00_couplers_ARPROT;
  assign M_AXI_arvalid = auto_pc_to_s00_couplers_ARVALID;
  assign M_AXI_awaddr[31:0] = auto_pc_to_s00_couplers_AWADDR;
  assign M_AXI_awprot[2:0] = auto_pc_to_s00_couplers_AWPROT;
  assign M_AXI_awvalid = auto_pc_to_s00_couplers_AWVALID;
  assign M_AXI_bready = auto_pc_to_s00_couplers_BREADY;
  assign M_AXI_rready = auto_pc_to_s00_couplers_RREADY;
  assign M_AXI_wdata[31:0] = auto_pc_to_s00_couplers_WDATA;
  assign M_AXI_wstrb[3:0] = auto_pc_to_s00_couplers_WSTRB;
  assign M_AXI_wvalid = auto_pc_to_s00_couplers_WVALID;
  assign S_ACLK_1 = S_ACLK;
  assign S_ARESETN_1 = S_ARESETN;
  assign S_AXI_arready = s00_couplers_to_auto_pc_ARREADY;
  assign S_AXI_awready = s00_couplers_to_auto_pc_AWREADY;
  assign S_AXI_bid[11:0] = s00_couplers_to_auto_pc_BID;
  assign S_AXI_bresp[1:0] = s00_couplers_to_auto_pc_BRESP;
  assign S_AXI_bvalid = s00_couplers_to_auto_pc_BVALID;
  assign S_AXI_rdata[31:0] = s00_couplers_to_auto_pc_RDATA;
  assign S_AXI_rid[11:0] = s00_couplers_to_auto_pc_RID;
  assign S_AXI_rlast = s00_couplers_to_auto_pc_RLAST;
  assign S_AXI_rresp[1:0] = s00_couplers_to_auto_pc_RRESP;
  assign S_AXI_rvalid = s00_couplers_to_auto_pc_RVALID;
  assign S_AXI_wready = s00_couplers_to_auto_pc_WREADY;
  assign auto_pc_to_s00_couplers_ARREADY = M_AXI_arready;
  assign auto_pc_to_s00_couplers_AWREADY = M_AXI_awready;
  assign auto_pc_to_s00_couplers_BRESP = M_AXI_bresp[1:0];
  assign auto_pc_to_s00_couplers_BVALID = M_AXI_bvalid;
  assign auto_pc_to_s00_couplers_RDATA = M_AXI_rdata[31:0];
  assign auto_pc_to_s00_couplers_RRESP = M_AXI_rresp[1:0];
  assign auto_pc_to_s00_couplers_RVALID = M_AXI_rvalid;
  assign auto_pc_to_s00_couplers_WREADY = M_AXI_wready;
  assign s00_couplers_to_auto_pc_ARADDR = S_AXI_araddr[31:0];
  assign s00_couplers_to_auto_pc_ARBURST = S_AXI_arburst[1:0];
  assign s00_couplers_to_auto_pc_ARCACHE = S_AXI_arcache[3:0];
  assign s00_couplers_to_auto_pc_ARID = S_AXI_arid[11:0];
  assign s00_couplers_to_auto_pc_ARLEN = S_AXI_arlen[3:0];
  assign s00_couplers_to_auto_pc_ARLOCK = S_AXI_arlock[1:0];
  assign s00_couplers_to_auto_pc_ARPROT = S_AXI_arprot[2:0];
  assign s00_couplers_to_auto_pc_ARQOS = S_AXI_arqos[3:0];
  assign s00_couplers_to_auto_pc_ARSIZE = S_AXI_arsize[2:0];
  assign s00_couplers_to_auto_pc_ARVALID = S_AXI_arvalid;
  assign s00_couplers_to_auto_pc_AWADDR = S_AXI_awaddr[31:0];
  assign s00_couplers_to_auto_pc_AWBURST = S_AXI_awburst[1:0];
  assign s00_couplers_to_auto_pc_AWCACHE = S_AXI_awcache[3:0];
  assign s00_couplers_to_auto_pc_AWID = S_AXI_awid[11:0];
  assign s00_couplers_to_auto_pc_AWLEN = S_AXI_awlen[3:0];
  assign s00_couplers_to_auto_pc_AWLOCK = S_AXI_awlock[1:0];
  assign s00_couplers_to_auto_pc_AWPROT = S_AXI_awprot[2:0];
  assign s00_couplers_to_auto_pc_AWQOS = S_AXI_awqos[3:0];
  assign s00_couplers_to_auto_pc_AWSIZE = S_AXI_awsize[2:0];
  assign s00_couplers_to_auto_pc_AWVALID = S_AXI_awvalid;
  assign s00_couplers_to_auto_pc_BREADY = S_AXI_bready;
  assign s00_couplers_to_auto_pc_RREADY = S_AXI_rready;
  assign s00_couplers_to_auto_pc_WDATA = S_AXI_wdata[31:0];
  assign s00_couplers_to_auto_pc_WID = S_AXI_wid[11:0];
  assign s00_couplers_to_auto_pc_WLAST = S_AXI_wlast;
  assign s00_couplers_to_auto_pc_WSTRB = S_AXI_wstrb[3:0];
  assign s00_couplers_to_auto_pc_WVALID = S_AXI_wvalid;
  can_test_auto_pc_0 auto_pc
       (.aclk(S_ACLK_1),
        .aresetn(S_ARESETN_1),
        .m_axi_araddr(auto_pc_to_s00_couplers_ARADDR),
        .m_axi_arprot(auto_pc_to_s00_couplers_ARPROT),
        .m_axi_arready(auto_pc_to_s00_couplers_ARREADY),
        .m_axi_arvalid(auto_pc_to_s00_couplers_ARVALID),
        .m_axi_awaddr(auto_pc_to_s00_couplers_AWADDR),
        .m_axi_awprot(auto_pc_to_s00_couplers_AWPROT),
        .m_axi_awready(auto_pc_to_s00_couplers_AWREADY),
        .m_axi_awvalid(auto_pc_to_s00_couplers_AWVALID),
        .m_axi_bready(auto_pc_to_s00_couplers_BREADY),
        .m_axi_bresp(auto_pc_to_s00_couplers_BRESP),
        .m_axi_bvalid(auto_pc_to_s00_couplers_BVALID),
        .m_axi_rdata(auto_pc_to_s00_couplers_RDATA),
        .m_axi_rready(auto_pc_to_s00_couplers_RREADY),
        .m_axi_rresp(auto_pc_to_s00_couplers_RRESP),
        .m_axi_rvalid(auto_pc_to_s00_couplers_RVALID),
        .m_axi_wdata(auto_pc_to_s00_couplers_WDATA),
        .m_axi_wready(auto_pc_to_s00_couplers_WREADY),
        .m_axi_wstrb(auto_pc_to_s00_couplers_WSTRB),
        .m_axi_wvalid(auto_pc_to_s00_couplers_WVALID),
        .s_axi_araddr(s00_couplers_to_auto_pc_ARADDR),
        .s_axi_arburst(s00_couplers_to_auto_pc_ARBURST),
        .s_axi_arcache(s00_couplers_to_auto_pc_ARCACHE),
        .s_axi_arid(s00_couplers_to_auto_pc_ARID),
        .s_axi_arlen(s00_couplers_to_auto_pc_ARLEN),
        .s_axi_arlock(s00_couplers_to_auto_pc_ARLOCK),
        .s_axi_arprot(s00_couplers_to_auto_pc_ARPROT),
        .s_axi_arqos(s00_couplers_to_auto_pc_ARQOS),
        .s_axi_arready(s00_couplers_to_auto_pc_ARREADY),
        .s_axi_arsize(s00_couplers_to_auto_pc_ARSIZE),
        .s_axi_arvalid(s00_couplers_to_auto_pc_ARVALID),
        .s_axi_awaddr(s00_couplers_to_auto_pc_AWADDR),
        .s_axi_awburst(s00_couplers_to_auto_pc_AWBURST),
        .s_axi_awcache(s00_couplers_to_auto_pc_AWCACHE),
        .s_axi_awid(s00_couplers_to_auto_pc_AWID),
        .s_axi_awlen(s00_couplers_to_auto_pc_AWLEN),
        .s_axi_awlock(s00_couplers_to_auto_pc_AWLOCK),
        .s_axi_awprot(s00_couplers_to_auto_pc_AWPROT),
        .s_axi_awqos(s00_couplers_to_auto_pc_AWQOS),
        .s_axi_awready(s00_couplers_to_auto_pc_AWREADY),
        .s_axi_awsize(s00_couplers_to_auto_pc_AWSIZE),
        .s_axi_awvalid(s00_couplers_to_auto_pc_AWVALID),
        .s_axi_bid(s00_couplers_to_auto_pc_BID),
        .s_axi_bready(s00_couplers_to_auto_pc_BREADY),
        .s_axi_bresp(s00_couplers_to_auto_pc_BRESP),
        .s_axi_bvalid(s00_couplers_to_auto_pc_BVALID),
        .s_axi_rdata(s00_couplers_to_auto_pc_RDATA),
        .s_axi_rid(s00_couplers_to_auto_pc_RID),
        .s_axi_rlast(s00_couplers_to_auto_pc_RLAST),
        .s_axi_rready(s00_couplers_to_auto_pc_RREADY),
        .s_axi_rresp(s00_couplers_to_auto_pc_RRESP),
        .s_axi_rvalid(s00_couplers_to_auto_pc_RVALID),
        .s_axi_wdata(s00_couplers_to_auto_pc_WDATA),
        .s_axi_wid(s00_couplers_to_auto_pc_WID),
        .s_axi_wlast(s00_couplers_to_auto_pc_WLAST),
        .s_axi_wready(s00_couplers_to_auto_pc_WREADY),
        .s_axi_wstrb(s00_couplers_to_auto_pc_WSTRB),
        .s_axi_wvalid(s00_couplers_to_auto_pc_WVALID));
endmodule

module s01_couplers_imp_1NW8H9H
   (M_ACLK,
    M_ARESETN,
    M_AXI_araddr,
    M_AXI_arprot,
    M_AXI_arready,
    M_AXI_arvalid,
    M_AXI_awaddr,
    M_AXI_awprot,
    M_AXI_awready,
    M_AXI_awvalid,
    M_AXI_bready,
    M_AXI_bresp,
    M_AXI_bvalid,
    M_AXI_rdata,
    M_AXI_rready,
    M_AXI_rresp,
    M_AXI_rvalid,
    M_AXI_wdata,
    M_AXI_wready,
    M_AXI_wstrb,
    M_AXI_wvalid,
    S_ACLK,
    S_ARESETN,
    S_AXI_araddr,
    S_AXI_arprot,
    S_AXI_arready,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awprot,
    S_AXI_awready,
    S_AXI_awvalid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid);
  input M_ACLK;
  input M_ARESETN;
  output [31:0]M_AXI_araddr;
  output [2:0]M_AXI_arprot;
  input M_AXI_arready;
  output M_AXI_arvalid;
  output [31:0]M_AXI_awaddr;
  output [2:0]M_AXI_awprot;
  input M_AXI_awready;
  output M_AXI_awvalid;
  output M_AXI_bready;
  input [1:0]M_AXI_bresp;
  input M_AXI_bvalid;
  input [31:0]M_AXI_rdata;
  output M_AXI_rready;
  input [1:0]M_AXI_rresp;
  input M_AXI_rvalid;
  output [31:0]M_AXI_wdata;
  input M_AXI_wready;
  output [3:0]M_AXI_wstrb;
  output M_AXI_wvalid;
  input S_ACLK;
  input S_ARESETN;
  input [31:0]S_AXI_araddr;
  input [2:0]S_AXI_arprot;
  output S_AXI_arready;
  input S_AXI_arvalid;
  input [31:0]S_AXI_awaddr;
  input [2:0]S_AXI_awprot;
  output S_AXI_awready;
  input S_AXI_awvalid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;

  wire [31:0]s01_couplers_to_s01_couplers_ARADDR;
  wire [2:0]s01_couplers_to_s01_couplers_ARPROT;
  wire s01_couplers_to_s01_couplers_ARREADY;
  wire s01_couplers_to_s01_couplers_ARVALID;
  wire [31:0]s01_couplers_to_s01_couplers_AWADDR;
  wire [2:0]s01_couplers_to_s01_couplers_AWPROT;
  wire s01_couplers_to_s01_couplers_AWREADY;
  wire s01_couplers_to_s01_couplers_AWVALID;
  wire s01_couplers_to_s01_couplers_BREADY;
  wire [1:0]s01_couplers_to_s01_couplers_BRESP;
  wire s01_couplers_to_s01_couplers_BVALID;
  wire [31:0]s01_couplers_to_s01_couplers_RDATA;
  wire s01_couplers_to_s01_couplers_RREADY;
  wire [1:0]s01_couplers_to_s01_couplers_RRESP;
  wire s01_couplers_to_s01_couplers_RVALID;
  wire [31:0]s01_couplers_to_s01_couplers_WDATA;
  wire s01_couplers_to_s01_couplers_WREADY;
  wire [3:0]s01_couplers_to_s01_couplers_WSTRB;
  wire s01_couplers_to_s01_couplers_WVALID;

  assign M_AXI_araddr[31:0] = s01_couplers_to_s01_couplers_ARADDR;
  assign M_AXI_arprot[2:0] = s01_couplers_to_s01_couplers_ARPROT;
  assign M_AXI_arvalid = s01_couplers_to_s01_couplers_ARVALID;
  assign M_AXI_awaddr[31:0] = s01_couplers_to_s01_couplers_AWADDR;
  assign M_AXI_awprot[2:0] = s01_couplers_to_s01_couplers_AWPROT;
  assign M_AXI_awvalid = s01_couplers_to_s01_couplers_AWVALID;
  assign M_AXI_bready = s01_couplers_to_s01_couplers_BREADY;
  assign M_AXI_rready = s01_couplers_to_s01_couplers_RREADY;
  assign M_AXI_wdata[31:0] = s01_couplers_to_s01_couplers_WDATA;
  assign M_AXI_wstrb[3:0] = s01_couplers_to_s01_couplers_WSTRB;
  assign M_AXI_wvalid = s01_couplers_to_s01_couplers_WVALID;
  assign S_AXI_arready = s01_couplers_to_s01_couplers_ARREADY;
  assign S_AXI_awready = s01_couplers_to_s01_couplers_AWREADY;
  assign S_AXI_bresp[1:0] = s01_couplers_to_s01_couplers_BRESP;
  assign S_AXI_bvalid = s01_couplers_to_s01_couplers_BVALID;
  assign S_AXI_rdata[31:0] = s01_couplers_to_s01_couplers_RDATA;
  assign S_AXI_rresp[1:0] = s01_couplers_to_s01_couplers_RRESP;
  assign S_AXI_rvalid = s01_couplers_to_s01_couplers_RVALID;
  assign S_AXI_wready = s01_couplers_to_s01_couplers_WREADY;
  assign s01_couplers_to_s01_couplers_ARADDR = S_AXI_araddr[31:0];
  assign s01_couplers_to_s01_couplers_ARPROT = S_AXI_arprot[2:0];
  assign s01_couplers_to_s01_couplers_ARREADY = M_AXI_arready;
  assign s01_couplers_to_s01_couplers_ARVALID = S_AXI_arvalid;
  assign s01_couplers_to_s01_couplers_AWADDR = S_AXI_awaddr[31:0];
  assign s01_couplers_to_s01_couplers_AWPROT = S_AXI_awprot[2:0];
  assign s01_couplers_to_s01_couplers_AWREADY = M_AXI_awready;
  assign s01_couplers_to_s01_couplers_AWVALID = S_AXI_awvalid;
  assign s01_couplers_to_s01_couplers_BREADY = S_AXI_bready;
  assign s01_couplers_to_s01_couplers_BRESP = M_AXI_bresp[1:0];
  assign s01_couplers_to_s01_couplers_BVALID = M_AXI_bvalid;
  assign s01_couplers_to_s01_couplers_RDATA = M_AXI_rdata[31:0];
  assign s01_couplers_to_s01_couplers_RREADY = S_AXI_rready;
  assign s01_couplers_to_s01_couplers_RRESP = M_AXI_rresp[1:0];
  assign s01_couplers_to_s01_couplers_RVALID = M_AXI_rvalid;
  assign s01_couplers_to_s01_couplers_WDATA = S_AXI_wdata[31:0];
  assign s01_couplers_to_s01_couplers_WREADY = M_AXI_wready;
  assign s01_couplers_to_s01_couplers_WSTRB = S_AXI_wstrb[3:0];
  assign s01_couplers_to_s01_couplers_WVALID = S_AXI_wvalid;
endmodule
