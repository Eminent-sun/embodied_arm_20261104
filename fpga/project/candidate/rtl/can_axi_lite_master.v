`timescale 1ns / 1ps

// Shared AXI executor: PL initialization, periodic Reader and scheduled Sender.
// ENABLE_PL_INIT/ENABLE_PERIODIC=0 retain Stage 2C regression compatibility.
// At 50 MHz, 5,000,000 clocks = 100 ms; default per-phase timeout = 1 ms.
module can_axi_lite_master #(
    parameter integer POLL_INTERVAL_CYCLES = 5000000,
    parameter integer TIMEOUT_CYCLES = 50000,
    parameter integer TXOK_TIMEOUT_CYCLES = 500000,
    parameter integer SEND_TIMEOUT_CYCLES = 1000000,
    // Legacy test configurations retain their original behavior. BD enables PL init.
    parameter integer ENABLE_PL_INIT = 0,
    parameter integer INIT_TIMEOUT_CYCLES = 50000000,
    parameter integer INIT_POLL_CYCLES = 5000,
    parameter integer ENABLE_PERIODIC = 0,
    parameter integer PERIOD_10HZ_CYCLES = 5000000,
    parameter integer PERIOD_100HZ_CYCLES = 500000,
    parameter integer PERIOD_200HZ_CYCLES = 250000,
    parameter integer TXOK_POLL_CYCLES = 5000,
    // Static build mode: 0 preserves Stage 2D; 1 selects virtual six-axis traffic.
    parameter integer ENABLE_SIX_AXIS = 0,
    parameter integer ENABLE_RX = 0,
    parameter integer RX_POLL_CYCLES = 2500,
    parameter integer RX_FIFO_DEPTH = 16,
    // Static alternative to periodic traffic. Default leaves the proven path intact.
    parameter integer ENABLE_SINGLE_TX = 0
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF M_AXI, ASSOCIATED_RESET aresetn, FREQ_HZ 50000000" *)
    input wire aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW" *)
    input wire aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWADDR" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI, PROTOCOL AXI4LITE, ADDR_WIDTH 32, DATA_WIDTH 32, READ_WRITE_MODE READ_WRITE, HAS_PROT 1, HAS_WSTRB 1, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1" *)
    output wire [31:0] m_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWPROT" *)
    output wire [2:0] m_axi_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWVALID" *)
    output wire m_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWREADY" *)
    input wire m_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WDATA" *)
    output wire [31:0] m_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WSTRB" *)
    output wire [3:0] m_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WVALID" *)
    output wire m_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WREADY" *)
    input wire m_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BRESP" *)
    input wire [1:0] m_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BVALID" *)
    input wire m_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BREADY" *)
    output wire m_axi_bready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARADDR" *)
    output wire [31:0] m_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARPROT" *)
    output wire [2:0] m_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARVALID" *)
    output wire m_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARREADY" *)
    input wire m_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RDATA" *)
    input wire [31:0] m_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RRESP" *)
    input wire [1:0] m_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RVALID" *)
    input wire m_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RREADY" *)
    output wire m_axi_rready,

    output reg [31:0] status_value,
    output reg [31:0] success_count,
    output reg [31:0] completed_count,
    output reg [31:0] timeout_count,
    // Sticky until reset: bit0=non-OKAY RRESP, bit1=AR timeout, bit2=R timeout.
    output reg [2:0] error_flags,
    output reg [1:0] last_rresp,
    output reg rresp_valid,
    output reg read_done,
    output wire busy,
    output wire [1:0] debug_state,
    output reg transaction_timeout,
    input wire send_req,
    (* X_INTERFACE_IGNORE = "true" *) input wire single_tx_req_valid,
    (* X_INTERFACE_IGNORE = "true" *) output wire single_tx_req_ready,
    (* X_INTERFACE_IGNORE = "true" *) input wire [28:0] single_tx_can_id,
    (* X_INTERFACE_IGNORE = "true" *) input wire [7:0] single_tx_can_dlc,
    (* X_INTERFACE_IGNORE = "true" *) input wire [63:0] single_tx_can_data,
    (* X_INTERFACE_IGNORE = "true" *) output reg single_tx_done,
    // Sticky result qualifier for VIO. Unlike single_tx_done, this remains
    // asserted until the next accepted request or the common PL reset.
    (* X_INTERFACE_IGNORE = "true" *) output reg single_tx_result_valid,
    (* X_INTERFACE_IGNORE = "true" *) output reg single_tx_success,
    (* X_INTERFACE_IGNORE = "true" *) output reg single_tx_error,
    (* X_INTERFACE_IGNORE = "true" *) output reg single_tx_timeout,
    (* X_INTERFACE_IGNORE = "true" *) output reg single_tx_may_have_submitted,
    (* X_INTERFACE_IGNORE = "true" *) output reg [7:0] single_tx_error_code,
    output reg [3:0] tx_state,
    output wire tx_busy,
    output reg tx_fifo_write_done,
    output reg tx_success,
    output reg tx_error,
    output reg tx_timeout,
    output reg [31:0] tx_success_count,
    output reg [31:0] tx_error_count,
    output reg [1:0] last_bresp,
    output reg [31:0] last_isr,
    output reg [31:0] last_sr,
    output reg [3:0] tx_error_code,
    output reg [3:0] write_error_flags,
    output wire bus_quarantined,
    output reg tx_may_be_pending,
    output reg send_used,
    // AXI-domain status input: BD must connect pl_reset_ctrl/clock_locked_axi.
    // Raw MMCM LOCKED is reserved for the reset controller's async assertion.
    (* X_INTERFACE_IGNORE = "true" *) input wire clock_locked,
    (* X_INTERFACE_IGNORE = "true" *) input wire reset_released,
    output wire can_initialized,
    output wire can_init_error,
    output wire [4:0] can_init_state,
    output wire [4:0] can_init_failed_state,
    output wire [3:0] can_init_error_code,
    output wire [31:0] can_init_last_status,
    input wire stop_req,
    input wire [1:0] period_sel,
    input wire [1:0] limit_sel,
    output wire [2:0] scheduler_state,
    output wire [31:0] scheduled_count,
    output wire [31:0] attempted_count,
    output reg [31:0] enqueued_count,
    output wire [31:0] missed_deadline_count,
    output wire [31:0] last_sequence,
    output wire [31:0] selected_period,
    output wire [31:0] frame_limit,
    output wire round_used,
    output wire start_rejected,
    output wire periodic_completed,
    output wire periodic_stopped,
    output wire deadline_violation,
    output reg [31:0] tx_completed_cycle,
    output reg [31:0] last_attempt_cycle,
    output wire [31:0] cycle_seq,
    output wire [2:0] axis_index,
    output wire [31:0] cycle_started_count,cycle_completed_count,
    output wire [31:0] missed_cycle_count,max_cycle_span_cycles,cycle_limit,
    output wire scheduler_fault,
    (* X_INTERFACE_IGNORE = "true" *) input wire rx_ready,
    (* X_INTERFACE_IGNORE = "true" *) output wire rx_valid,
    (* X_INTERFACE_IGNORE = "true" *) output wire [28:0] rx_can_id,
    (* X_INTERFACE_IGNORE = "true" *) output wire rx_ide,rx_rtr,
    (* X_INTERFACE_IGNORE = "true" *) output wire [3:0] rx_dlc,
    (* X_INTERFACE_IGNORE = "true" *) output wire [63:0] rx_data,rx_timestamp,
    (* X_INTERFACE_IGNORE = "true" *) output wire [7:0] rx_frame_error,rx_error_flags,
    (* X_INTERFACE_IGNORE = "true" *) output wire rx_integrity_lost,rx_service_fault,
    (* X_INTERFACE_IGNORE = "true" *) output wire [3:0] rx_service_state,
    (* X_INTERFACE_IGNORE = "true" *) output wire [31:0] rx_frame_count,rx_overflow_count,
    (* X_INTERFACE_IGNORE = "true" *) output wire [31:0] rx_underflow_count,rx_axi_error_count,
    (* X_INTERFACE_IGNORE = "true" *) output wire [31:0] rx_invalid_frame_count,rx_sw_drop_count,
    (* X_INTERFACE_IGNORE = "true" *) output wire [31:0] rx_fifo_level,rx_last_isr,
    (* X_INTERFACE_IGNORE = "true" *) output wire [28:0] rx_last_id,
    (* X_INTERFACE_IGNORE = "true" *) output wire [3:0] rx_last_dlc,
    (* X_INTERFACE_IGNORE = "true" *) output wire [31:0] rx_snapshot_isr,rx_snapshot_esr,
    (* X_INTERFACE_IGNORE = "true" *) output wire [31:0] rx_snapshot_ecr,rx_snapshot_sr,
    (* X_INTERFACE_IGNORE = "true" *) output wire [7:0] rx_snapshot_status
);
    // AXI executor owns all five channels. No read/write overlap is possible.
    localparam [2:0] X_IDLE=0, X_AR=1, X_R=2, X_AW_W=3, X_B=4;
    localparam [3:0] T_WAIT=0, T_SR_REQ=1, T_SR_WAIT=2, T_CLEAR_REQ=3,
        T_CLEAR_WAIT=4, T_FIFO_REQ=5, T_FIFO_WAIT=6, T_ISR_REQ=7,
        T_ISR_WAIT=8, T_SUCCESS=9, T_ERROR=10, T_CANCELLED=11, T_ISR_DELAY=12;
    localparam [31:0] SR=32'h43C00018, ISR=32'h43C0001C, ICR=32'h43C00024;
    localparam [28:0] TEST_CAN_ID=29'h1B345678;
    localparam [31:0] TEST_IDR={TEST_CAN_ID[28:18],1'b1,1'b1,TEST_CAN_ID[17:0],1'b0};
    localparam [31:0] POLL_LAST=POLL_INTERVAL_CYCLES-1;
    localparam [31:0] TIMEOUT_LAST=TIMEOUT_CYCLES-1;
    localparam [31:0] TXOK_LAST=TXOK_TIMEOUT_CYCLES-1;
    localparam [31:0] SEND_LAST=SEND_TIMEOUT_CYCLES-1;
    reg [2:0] x_state;
    reg [31:0] x_addr, x_data, wait_counter, aw_counter, w_counter;
    reg x_write, aw_pending, w_pending;
    reg [1:0] x_owner;
    reg x_done, x_bad, x_timeout_event;
    reg [31:0] x_result;
    reg req_valid, req_write;
    reg [1:0] req_owner;
    reg [31:0] req_addr, req_data;
    reg [31:0] poll_counter, send_counter, txok_counter;
    reg reader_waiting, reader_pending, req_previous, req_armed;
    reg [1:0] fifo_word;
    wire tx_active, poll_tick, send_trigger, req_ready;
    wire aw_fire, w_fire, aw_expired, w_expired;
    wire rx_group_lock;
    wire init_cmd_valid,init_cmd_write,init_cmd_ready,init_done_raw,init_ready;
    wire [31:0] init_cmd_addr,init_cmd_data;
    wire scheduler_request,scheduler_ready,scheduler_sender_busy,periodic_stop,isr_poll_tick;
    wire [31:0] scheduler_sequence;
    wire legacy_request,legacy_round,legacy_rejected,legacy_completed,legacy_stopped,legacy_violation;
    wire [2:0] legacy_state,six_state;
    wire [31:0] legacy_sequence,legacy_last,legacy_scheduled,legacy_attempted,legacy_missed,legacy_period,legacy_limit;
    wire six_request,six_round,six_rejected,six_completed,six_stopped,six_halt;
    wire [31:0] six_attempted,six_period;
    reg [28:0] active_can_id;
    reg [7:0] active_dlc;
    reg [63:0] active_data;
    reg single_tx_inflight;
    reg [31:0] active_sequence;
    reg [7:0] active_axis;
    wire [31:0] active_idr;
    assign active_idr={active_can_id[28:18],1'b1,1'b1,active_can_id[17:0],1'b0};
    reg [31:0] isr_poll_counter,cycle_counter;
    reg fifo_started;
    assign tx_active=(tx_state>=T_SR_REQ && tx_state<=T_ISR_WAIT)||(tx_state==T_ISR_DELAY);
    assign poll_tick=(poll_counter==POLL_LAST);
    assign single_tx_req_ready=(ENABLE_SINGLE_TX!=0) && aresetn &&
        single_tx_req_valid && !single_tx_inflight && !tx_active && !tx_error &&
        !transaction_timeout && init_ready && clock_locked && reset_released &&
        !can_init_error && !rx_group_lock && (x_state==X_IDLE) && !reader_waiting;
    assign send_trigger=(ENABLE_SINGLE_TX!=0)?single_tx_req_ready:
        (ENABLE_PERIODIC!=0)?
        (scheduler_request && !tx_active && !tx_error && init_ready && !stop_req &&
         !(ENABLE_SIX_AXIS!=0 && six_halt)):
        (req_armed && send_req && !req_previous && !send_used && init_ready);
    assign periodic_stop=(ENABLE_SINGLE_TX==0 && ENABLE_PERIODIC!=0)&&
        (stop_req || (ENABLE_SIX_AXIS!=0 && six_halt));
    assign scheduler_ready=init_ready && clock_locked && reset_released && !can_init_error;
    assign scheduler_sender_busy=tx_active || (busy && x_owner==1);
    assign isr_poll_tick=(isr_poll_counter==TXOK_POLL_CYCLES-1);
    assign req_ready=(x_state==X_IDLE);
    assign aw_fire=m_axi_awvalid && m_axi_awready;
    assign w_fire=m_axi_wvalid && m_axi_wready;
    assign aw_expired=aw_pending && !m_axi_awready && (aw_counter==TIMEOUT_LAST);
    assign w_expired=w_pending && !m_axi_wready && (w_counter==TIMEOUT_LAST);
    assign busy=(x_state!=X_IDLE);
    assign debug_state=(x_state==X_AR)?2'd1:(x_state==X_R)?2'd2:
                       (x_state==X_IDLE)?2'd0:2'd3;
    assign tx_busy=tx_active;
    assign bus_quarantined=busy && transaction_timeout;
    assign m_axi_araddr=x_addr;
    assign m_axi_arprot=3'b000;
    assign m_axi_arvalid=(x_state==X_AR) && aresetn;
    assign m_axi_rready=(x_state==X_R) && aresetn;
    assign m_axi_awaddr=x_write?x_addr:32'd0;
    assign m_axi_awprot=3'b000;
    assign m_axi_awvalid=(x_state==X_AW_W) && aw_pending && aresetn;
    assign m_axi_wdata=x_write?x_data:32'd0;
    assign m_axi_wstrb=x_write?4'b1111:4'b0000;
    assign m_axi_wvalid=(x_state==X_AW_W) && w_pending && aresetn;
    assign m_axi_bready=(x_state==X_B) && aresetn;

    pl_can_scheduler #(.PERIOD_10HZ_CYCLES(PERIOD_10HZ_CYCLES),
        .PERIOD_100HZ_CYCLES(PERIOD_100HZ_CYCLES),.PERIOD_200HZ_CYCLES(PERIOD_200HZ_CYCLES))
    scheduler(.clk(aclk),.rst_n(aresetn),.enable(ENABLE_SINGLE_TX==0 && ENABLE_PERIODIC!=0 && ENABLE_SIX_AXIS==0),.ready(scheduler_ready),
        .start_req(send_req),.stop_req(stop_req),.period_sel(period_sel),.limit_sel(limit_sel),
        .sender_busy(scheduler_sender_busy),.sender_fault(tx_error||can_init_error),.send_accept(send_trigger),
        .tx_success_count(tx_success_count),.send_request(legacy_request),.request_sequence(legacy_sequence),
        .last_sequence(legacy_last),.scheduled_count(legacy_scheduled),.attempted_count(legacy_attempted),
        .missed_deadline_count(legacy_missed),.latched_period(legacy_period),.frame_limit(legacy_limit),
        .state(legacy_state),.round_used(legacy_round),.start_rejected(legacy_rejected),
        .completed(legacy_completed),.stopped(legacy_stopped),.deadline_violation(legacy_violation));
    generate if(ENABLE_SIX_AXIS!=0) begin: six_axis_mode
        pl_six_axis_scheduler #(.PERIOD_CYCLES(PERIOD_100HZ_CYCLES)) scheduler(
            .clk(aclk),.rst_n(aresetn),.enable(ENABLE_SINGLE_TX==0 && ENABLE_PERIODIC!=0),.ready(scheduler_ready),
            .start_req(send_req),.stop_req(stop_req),.period_sel(period_sel),.limit_sel(limit_sel),
            .sender_busy(scheduler_sender_busy),.sender_fault(tx_error||can_init_error),.send_accept(send_trigger),
            .tx_success_count(tx_success_count),.time_now(cycle_counter),.tx_completed_cycle(tx_completed_cycle),
            .send_request(six_request),.cycle_seq(cycle_seq),.axis_index(axis_index),
            .cycle_started_count(cycle_started_count),.cycle_completed_count(cycle_completed_count),
            .attempted_count(six_attempted),.missed_cycle_count(missed_cycle_count),
            .max_cycle_span_cycles(max_cycle_span_cycles),.cycle_limit(cycle_limit),.selected_period(six_period),
            .state(six_state),.round_used(six_round),.start_rejected(six_rejected),.scheduler_fault(scheduler_fault),
            .completed(six_completed),.stopped(six_stopped),.halt_new_frames(six_halt));
    end else begin: legacy_mode
        assign six_request=0;assign six_halt=0;assign six_state=0;
        assign six_round=0;assign six_rejected=0;assign six_completed=0;assign six_stopped=0;
        assign six_attempted=0;assign six_period=0;assign cycle_seq=0;assign axis_index=0;
        assign cycle_started_count=0;assign cycle_completed_count=0;assign missed_cycle_count=0;
        assign max_cycle_span_cycles=0;assign cycle_limit=0;assign scheduler_fault=0;
    end endgenerate
    assign scheduler_request=(ENABLE_SIX_AXIS!=0)?six_request:legacy_request;
    assign scheduler_sequence=(ENABLE_SIX_AXIS!=0)?cycle_seq:legacy_sequence;
    assign last_sequence=(ENABLE_SIX_AXIS!=0)?cycle_seq:legacy_last;
    assign scheduled_count=(ENABLE_SIX_AXIS!=0)?cycle_started_count:legacy_scheduled;
    assign attempted_count=(ENABLE_SIX_AXIS!=0)?six_attempted:legacy_attempted;
    assign missed_deadline_count=(ENABLE_SIX_AXIS!=0)?missed_cycle_count:legacy_missed;
    assign selected_period=(ENABLE_SIX_AXIS!=0)?six_period:legacy_period;
    // In Stage 3-A only, the legacy debug alias frame_limit means control cycles.
    assign frame_limit=(ENABLE_SIX_AXIS!=0)?cycle_limit:legacy_limit;
    assign scheduler_state=(ENABLE_SIX_AXIS!=0)?six_state:legacy_state;
    assign round_used=(ENABLE_SIX_AXIS!=0)?six_round:legacy_round;
    assign start_rejected=(ENABLE_SIX_AXIS!=0)?six_rejected:legacy_rejected;
    assign periodic_completed=(ENABLE_SIX_AXIS!=0)?six_completed:legacy_completed;
    assign periodic_stopped=(ENABLE_SIX_AXIS!=0)?six_stopped:legacy_stopped;
    assign deadline_violation=(ENABLE_SIX_AXIS!=0)?(missed_cycle_count!=0):legacy_violation;

    assign init_ready=(ENABLE_PL_INIT==0)||can_initialized;
    assign can_initialized=(ENABLE_PL_INIT==0)?1'b1:
        (init_done_raw && aresetn && clock_locked && reset_released);
    assign init_cmd_ready=req_ready && req_valid && req_owner==2;
    pl_can_init #(.INIT_TIMEOUT_CYCLES(INIT_TIMEOUT_CYCLES),.POLL_CYCLES(INIT_POLL_CYCLES))
    initializer(.clk(aclk),.rst_n(aresetn),.enable(ENABLE_PL_INIT!=0),
        .clock_locked(clock_locked),.reset_released(reset_released),
        .cmd_valid(init_cmd_valid),.cmd_write(init_cmd_write),.cmd_addr(init_cmd_addr),
        .cmd_data(init_cmd_data),.cmd_ready(init_cmd_ready),
        .response_valid(x_done && x_owner==2),.response_error(x_bad),
        .response_timeout(x_timeout_event && x_owner==2),.response_data(x_result),
        .can_initialized(init_done_raw),.can_init_error(can_init_error),
        .state(can_init_state),.failed_state(can_init_failed_state),
        .error_code(can_init_error_code),.last_status(can_init_last_status));

    // Owner 0=Status Reader, 1=Sender, 2=Init, 3=RX. The executor below is unchanged.
    wire rx_cmd_valid,rx_cmd_write,rx_cmd_ready,tx_response;
    wire [31:0] rx_cmd_addr,rx_cmd_data;
    reg rx_yield;
    reg [63:0] rx_time_counter;
    assign tx_response=x_done && x_owner==1;
    assign rx_cmd_ready=req_ready && req_valid && req_owner==3;
    always @(posedge aclk) begin
        if(!aresetn) begin rx_yield<=0;rx_time_counter<=0;end
        else begin
            rx_time_counter<=rx_time_counter+1'b1;
            if(req_valid && req_ready) rx_yield<=(req_owner==3);
        end
    end
    can_rx_service #(.POLL_CYCLES(RX_POLL_CYCLES),.FRAME_FIFO_DEPTH(RX_FIFO_DEPTH)) receiver(
        .clk(aclk),.rst_n(aresetn),.enable(ENABLE_RX!=0 && scheduler_ready),.time_now(rx_time_counter),
        .cmd_valid(rx_cmd_valid),.cmd_write(rx_cmd_write),.cmd_addr(rx_cmd_addr),.cmd_data(rx_cmd_data),
        .cmd_ready(rx_cmd_ready),.response_valid(x_done && x_owner==3),
        .response_error(x_bad),.response_timeout(x_timeout_event && x_owner==3),.response_data(x_result),
        .group_lock(rx_group_lock),.fault(rx_service_fault),.state(rx_service_state),
        .rx_valid(rx_valid),.rx_ready(rx_ready),.rx_can_id(rx_can_id),.rx_ide(rx_ide),.rx_rtr(rx_rtr),
        .rx_dlc(rx_dlc),.rx_data(rx_data),.rx_timestamp(rx_timestamp),.rx_frame_error(rx_frame_error),
        .rx_error_flags(rx_error_flags),.rx_integrity_lost(rx_integrity_lost),
        .rx_frame_count(rx_frame_count),.rx_overflow_count(rx_overflow_count),
        .rx_underflow_count(rx_underflow_count),.rx_axi_error_count(rx_axi_error_count),
        .rx_invalid_frame_count(rx_invalid_frame_count),.rx_sw_drop_count(rx_sw_drop_count),
        .rx_fifo_level(rx_fifo_level),.rx_last_id(rx_last_id),.rx_last_dlc(rx_last_dlc),.rx_last_isr(rx_last_isr),
        .snapshot_isr(rx_snapshot_isr),.snapshot_esr(rx_snapshot_esr),
        .snapshot_ecr(rx_snapshot_ecr),.snapshot_sr(rx_snapshot_sr),
        .snapshot_status(rx_snapshot_status));

    // Scheduler issues one command; executor latches address/data/ownership.
    always @* begin
        req_valid=0; req_write=0; req_owner=0; req_addr=SR; req_data=0;
        if (req_ready && !reader_waiting && ENABLE_PL_INIT!=0 && !init_ready) begin
            req_valid=init_cmd_valid;req_write=init_cmd_write;req_owner=2;
            req_addr=init_cmd_addr;req_data=init_cmd_data;
        end else if (req_ready && !reader_waiting && init_ready &&
            !(periodic_stop && !fifo_started && tx_active)) begin
            case (tx_state)
                T_SR_REQ: begin req_valid=1; req_owner=1; end
                T_CLEAR_REQ: begin
                    req_valid=1; req_owner=1; req_write=1;
                    req_addr=ICR; req_data=32'h00000002;
                end
                T_FIFO_REQ: begin
                    req_valid=1; req_owner=1; req_write=1;
                    case (fifo_word)
                        0: begin req_addr=32'h43C00030; req_data=(ENABLE_SINGLE_TX!=0)?active_idr:
                            (ENABLE_SIX_AXIS!=0)?active_idr:TEST_IDR; end
                        1: begin req_addr=32'h43C00034; req_data=(ENABLE_SINGLE_TX!=0)?
                            {active_dlc[3:0],28'd0}:32'h80000000; end
                        2: begin req_addr=32'h43C00038; req_data=(ENABLE_SINGLE_TX!=0)?
                            {active_data[7:0],active_data[15:8],active_data[23:16],active_data[31:24]}:
                            (ENABLE_SIX_AXIS!=0)?active_sequence:
                            (ENABLE_PERIODIC!=0)?last_sequence:32'h11223344; end
                        3: begin req_addr=32'h43C0003C; req_data=(ENABLE_SINGLE_TX!=0)?
                            {active_data[39:32],active_data[47:40],active_data[55:48],active_data[63:56]}:
                            (ENABLE_SIX_AXIS!=0)?{active_axis,24'hA55AC3}:
                            (ENABLE_PERIODIC!=0)?32'h11223344:32'h55667788; end
                    endcase
                end
                T_ISR_REQ: begin req_valid=1; req_owner=1; req_addr=ISR; end
                default: if (!tx_active && !send_trigger && (poll_tick || reader_pending))
                    req_valid=1;
            endcase
        end
        if(ENABLE_RX!=0 && init_ready) begin
            // A completion must be consumed by its owner before another owner
            // changes the request context. Hold the entire RX frame group.
            if(x_done || reader_waiting || !req_ready) req_valid=0;
            else if(rx_group_lock) begin
                req_valid=rx_cmd_valid;req_write=rx_cmd_write;req_owner=3;
                req_addr=rx_cmd_addr;req_data=rx_cmd_data;
            end else if(rx_cmd_valid && (!req_valid || !rx_yield)) begin
                req_valid=1;req_write=rx_cmd_write;req_owner=3;
                req_addr=rx_cmd_addr;req_data=rx_cmd_data;
            end
        end
    end

    // Result is emitted only for the accepted single-frame request. Terminal
    // TX states are sticky, so in-flight ownership turns them into one pulse.
    always @(posedge aclk) begin
        if(!aresetn) begin
            single_tx_inflight<=0;
            single_tx_done<=0;single_tx_result_valid<=0;
            single_tx_success<=0;single_tx_error<=0;
            single_tx_timeout<=0;single_tx_may_have_submitted<=0;
            single_tx_error_code<=0;
        end else begin
            single_tx_done<=0;
            if(single_tx_req_ready) begin
                single_tx_inflight<=1;
                single_tx_result_valid<=0;
                single_tx_success<=0;single_tx_error<=0;single_tx_timeout<=0;
                single_tx_may_have_submitted<=0;single_tx_error_code<=0;
            end
            else if(single_tx_inflight && (tx_state==T_SUCCESS || tx_state==T_ERROR ||
                    tx_state==T_CANCELLED)) begin
                single_tx_inflight<=0;
                single_tx_done<=1;
                single_tx_result_valid<=1;
                single_tx_success<=tx_state==T_SUCCESS;
                single_tx_error<=tx_state!=T_SUCCESS;
                single_tx_timeout<=tx_timeout;
                single_tx_may_have_submitted<=fifo_started || tx_may_be_pending;
                single_tx_error_code<={4'd0,tx_error_code};
            end
        end
    end

    // Transport engine. Timeouts notify the scheduler once, then drain the
    // old transaction without withdrawing VALID or issuing a new command.
    always @(posedge aclk) begin
        if (!aresetn) begin
            x_state<=X_IDLE; x_addr<=SR; x_data<=0; x_write<=0; x_owner<=0;
            aw_pending<=0; w_pending<=0; wait_counter<=0; aw_counter<=0; w_counter<=0;
            x_done<=0; x_bad<=0; x_result<=0; x_timeout_event<=0;
            status_value<=0; success_count<=0; completed_count<=0; timeout_count<=0;
            error_flags<=0; write_error_flags<=0; last_rresp<=0; last_bresp<=0;
            rresp_valid<=0; read_done<=0; transaction_timeout<=0;
        end else begin
            x_done<=0; x_timeout_event<=0; read_done<=0;
            case (x_state)
                X_IDLE: if (req_valid) begin
                    x_addr<=req_addr; x_data<=req_data; x_write<=req_write; x_owner<=req_owner;
                    transaction_timeout<=0; x_bad<=0; wait_counter<=0;
                    aw_counter<=0; w_counter<=0; aw_pending<=req_write; w_pending<=req_write;
                    if (req_write) x_state<=X_AW_W; else x_state<=X_AR;
                end
                X_AR: begin
                    if (m_axi_arready) begin wait_counter<=0; x_state<=X_R; end
                    else if (!transaction_timeout) begin
                        if (wait_counter==TIMEOUT_LAST) begin
                            transaction_timeout<=1; x_timeout_event<=1;
                            timeout_count<=timeout_count+1; error_flags[1]<=1;
                        end else wait_counter<=wait_counter+1;
                    end
                end
                X_R: begin
                    if (m_axi_rvalid) begin
                        x_result<=m_axi_rdata;
                        x_bad<=(m_axi_rresp!=0)||transaction_timeout;
                        x_done<=1; x_state<=X_IDLE;
                        last_rresp<=m_axi_rresp; rresp_valid<=1;
                        if (m_axi_rresp!=0) error_flags[0]<=1;
                        if (x_owner==0) begin
                            read_done<=1; completed_count<=completed_count+1;
                            if (m_axi_rresp==0 && !transaction_timeout) begin
                                status_value<=m_axi_rdata; success_count<=success_count+1;
                            end
                        end
                    end else if (!transaction_timeout) begin
                        if (wait_counter==TIMEOUT_LAST) begin
                            transaction_timeout<=1; x_timeout_event<=1;
                            timeout_count<=timeout_count+1; error_flags[2]<=1;
                        end else wait_counter<=wait_counter+1;
                    end
                end
                X_AW_W: begin
                    if (aw_fire) aw_pending<=0;
                    if (w_fire) w_pending<=0;
                    if ((!aw_pending || aw_fire) && (!w_pending || w_fire)) begin
                        wait_counter<=0; x_state<=X_B;
                    end
                    if (!transaction_timeout) begin
                        if (aw_expired || w_expired) begin
                            transaction_timeout<=1; x_timeout_event<=1; timeout_count<=timeout_count+1;
                            if (aw_expired) write_error_flags[1]<=1;
                            if (w_expired) write_error_flags[2]<=1;
                        end else begin
                            if (aw_pending && !aw_fire) aw_counter<=aw_counter+1;
                            if (w_pending && !w_fire) w_counter<=w_counter+1;
                        end
                    end
                end
                X_B: begin
                    if (m_axi_bvalid) begin
                        last_bresp<=m_axi_bresp;
                        x_bad<=(m_axi_bresp!=0)||transaction_timeout;
                        x_done<=1; x_state<=X_IDLE;
                        if (m_axi_bresp!=0) write_error_flags[0]<=1;
                    end else if (!transaction_timeout) begin
                        if (wait_counter==TIMEOUT_LAST) begin
                            transaction_timeout<=1; x_timeout_event<=1;
                            timeout_count<=timeout_count+1; write_error_flags[3]<=1;
                        end else wait_counter<=wait_counter+1;
                    end
                end
                default: x_state<=X_IDLE;
            endcase
        end
    end

    // Upper scheduler remains responsive even if transport is quarantined.
    // No TX retry/requeue is possible before a shared reset and a fresh low->high.
    always @(posedge aclk) begin
        if (!aresetn) begin
            poll_counter<=0; reader_waiting<=0; reader_pending<=0;
            req_previous<=0; req_armed<=0; send_used<=0;
            tx_state<=T_WAIT; fifo_word<=0; send_counter<=0; txok_counter<=0;
            tx_fifo_write_done<=0; tx_success<=0; tx_error<=0; tx_timeout<=0;
            tx_success_count<=0; tx_error_count<=0; tx_error_code<=0;
            tx_may_be_pending<=0; last_isr<=0; last_sr<=0;
            fifo_started<=0;enqueued_count<=0;isr_poll_counter<=0;cycle_counter<=0;
            tx_completed_cycle<=0;last_attempt_cycle<=0;
            active_can_id<=TEST_CAN_ID;active_dlc<=0;active_data<=0;
            active_sequence<=0;active_axis<=0;
        end else begin
            cycle_counter<=cycle_counter+1;
            req_previous<=send_req;
            if (!send_req) req_armed<=1;
            if (poll_tick) poll_counter<=0; else poll_counter<=poll_counter+1;
            if (poll_tick && (tx_active || send_trigger || (ENABLE_RX!=0 && (busy || rx_group_lock || rx_cmd_valid)))) reader_pending<=1;
            if (req_valid && req_ready && req_owner==0) begin
                reader_waiting<=1; reader_pending<=0;
            end
            if (x_done && x_owner==0) reader_waiting<=0;
            if (send_trigger) begin
                active_can_id<=(ENABLE_SINGLE_TX!=0)?single_tx_can_id:
                    29'h1B345670+axis_index;
                active_dlc<=single_tx_can_dlc;
                active_data<=single_tx_can_data;
                active_sequence<=scheduler_sequence;active_axis<={5'd0,axis_index};
                send_used<=1; tx_state<=T_SR_REQ; send_counter<=0;
                fifo_word<=0;fifo_started<=0;tx_fifo_write_done<=0;tx_success<=0;
                txok_counter<=0;isr_poll_counter<=0;last_attempt_cycle<=cycle_counter;
            end
            if(req_valid && req_ready && req_owner==1 && tx_state==T_FIFO_REQ) fifo_started<=1;
            if (req_valid && req_ready && req_owner==1 && req_write && req_addr==32'h43C0003C)
                tx_may_be_pending<=1; // DW2 may commit even if B later fails.

            if (tx_active) begin
                send_counter<=send_counter+1;
                if (tx_fifo_write_done) txok_counter<=txok_counter+1;
                if(tx_fifo_write_done) begin
                    if(isr_poll_tick) isr_poll_counter<=0;else isr_poll_counter<=isr_poll_counter+1;
                end
                if (x_timeout_event && x_owner==1) begin
                    tx_state<=T_ERROR; tx_error<=1; tx_timeout<=1;
                    tx_error_code<=4'd5; tx_error_count<=tx_error_count+1;
                end else if (ENABLE_PERIODIC!=0 && tx_state==T_ISR_WAIT && tx_response && !x_bad && (x_result & 32'h300)!=0) begin
                    last_isr<=x_result;tx_state<=T_ERROR;tx_error<=1;tx_error_code<=8;
                    tx_error_count<=tx_error_count+1;
                end else if (tx_state==T_ISR_WAIT && tx_response && !x_bad && x_result[1]) begin
                    last_isr<=x_result; tx_state<=T_SUCCESS; tx_success<=1;
                    tx_success_count<=tx_success_count+1; tx_may_be_pending<=0;
                    tx_completed_cycle<=cycle_counter;
                end else if (tx_fifo_write_done && txok_counter==TXOK_LAST) begin
                    tx_state<=T_ERROR; tx_error<=1; tx_timeout<=1;
                    tx_error_code<=4'd6; tx_error_count<=tx_error_count+1;
                end else if (send_counter==SEND_LAST) begin
                    tx_state<=T_ERROR; tx_error<=1; tx_timeout<=1;
                    tx_error_code<=4'd7; tx_error_count<=tx_error_count+1;
                end else if(periodic_stop && !fifo_started && req_ready && !(tx_response&&x_bad)) begin
                    tx_state<=T_CANCELLED;
                end else begin
                    case (tx_state)
                        T_SR_REQ: if (req_valid && req_ready && req_owner==1) tx_state<=T_SR_WAIT;
                        T_SR_WAIT: if (tx_response) begin
                            last_sr<=x_result;
                            if (x_bad || !x_result[3] || x_result[10]) begin
                                tx_state<=T_ERROR; tx_error<=1; tx_error_count<=tx_error_count+1;
                                if (x_bad) tx_error_code<=3;
                                else if (!x_result[3]) tx_error_code<=1;
                                else tx_error_code<=2;
                            end else tx_state<=T_CLEAR_REQ;
                        end
                        T_CLEAR_REQ: if (req_valid && req_ready && req_owner==1) tx_state<=T_CLEAR_WAIT;
                        T_CLEAR_WAIT: if (tx_response) begin
                            if (x_bad) begin
                                tx_state<=T_ERROR; tx_error<=1; tx_error_code<=4;
                                tx_error_count<=tx_error_count+1;
                            end else begin fifo_word<=0; tx_state<=T_FIFO_REQ; end
                        end
                        T_FIFO_REQ: if (req_valid && req_ready && req_owner==1) tx_state<=T_FIFO_WAIT;
                        T_FIFO_WAIT: if (tx_response) begin
                            if (x_bad) begin
                                tx_state<=T_ERROR; tx_error<=1; tx_error_code<=4;
                                tx_error_count<=tx_error_count+1;
                            end else if (fifo_word==3) begin
                                tx_fifo_write_done<=1; txok_counter<=0; isr_poll_counter<=0;
                                enqueued_count<=enqueued_count+1;
                                tx_state<=(ENABLE_PERIODIC!=0)?T_ISR_DELAY:T_ISR_REQ;
                            end else begin fifo_word<=fifo_word+1; tx_state<=T_FIFO_REQ; end
                        end
                        T_ISR_REQ: if (req_valid && req_ready && req_owner==1) tx_state<=T_ISR_WAIT;
                        T_ISR_WAIT: if (tx_response) begin
                            last_isr<=x_result;
                            if (x_bad) begin
                                tx_state<=T_ERROR; tx_error<=1; tx_error_code<=3;
                                tx_error_count<=tx_error_count+1;
                            end else tx_state<=(ENABLE_PERIODIC!=0)?T_ISR_DELAY:T_ISR_REQ;
                        end
                        T_ISR_DELAY: if(isr_poll_tick) tx_state<=T_ISR_REQ;
                    endcase
                end
            end
        end
    end
endmodule
