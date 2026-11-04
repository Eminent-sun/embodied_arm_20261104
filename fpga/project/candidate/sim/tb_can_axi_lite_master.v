`timescale 1ns / 1ps

// Standalone Verilog-2001 test. No PS or CAN IP simulation models required.
module tb_can_axi_lite_master;
    localparam integer POLL = 64;
    localparam integer LIMIT = 8;
    reg clk = 1'b0;
    always #10 clk = ~clk; // 50 MHz
    reg rst_n = 1'b0;
    integer errors = 0;
    integer cases_run = 0;
    integer case_errors;
    integer guard;
    integer outstanding = 0;
    integer ar_stalls = 0;
    integer r_stalls = 0;
    reg previous_stall = 1'b0;
    reg [31:0] previous_address;
    reg [2:0] previous_prot;
    reg expected_done;

    reg hold_ar = 1'b0, hold_r = 1'b0;
    reg [31:0] ar_delay = 0, r_delay = 0;
    reg [31:0] slave_data = 32'h00000098;
    reg [1:0] slave_resp = 2'b00;
    wire [31:0] araddr, rdata, status_value, success_count;
    wire [31:0] completed_count, timeout_count, accepted_count;
    wire [2:0] arprot, error_flags;
    wire [1:0] rresp, last_rresp, debug_state;
    wire arvalid, arready, rvalid, rready, read_done, busy;
    wire rresp_valid, transaction_timeout;
    wire [31:0] awaddr, wdata;
    wire [2:0] awprot;
    wire [3:0] wstrb;
    wire awvalid, wvalid, bready;

    can_axi_lite_master #(.POLL_INTERVAL_CYCLES(POLL), .TIMEOUT_CYCLES(LIMIT)) dut (
        .aclk(clk), .aresetn(rst_n), .send_req(1'b0), .tx_state(),
        .clock_locked(1'b1),.reset_released(1'b1),.stop_req(1'b0),.period_sel(2'b00),.limit_sel(2'b00),
        .tx_busy(), .tx_fifo_write_done(), .tx_success(), .tx_error(), .tx_timeout(),
        .tx_success_count(), .tx_error_count(), .last_bresp(), .last_isr(), .last_sr(),
        .tx_error_code(), .write_error_flags(), .bus_quarantined(), .tx_may_be_pending(), .send_used(),
        .m_axi_awaddr(awaddr), .m_axi_awprot(awprot), .m_axi_awvalid(awvalid),
        .m_axi_awready(1'b1), .m_axi_wdata(wdata), .m_axi_wstrb(wstrb),
        .m_axi_wvalid(wvalid), .m_axi_wready(1'b1), .m_axi_bresp(2'b11),
        .m_axi_bvalid(1'b1), .m_axi_bready(bready),
        .m_axi_araddr(araddr), .m_axi_arprot(arprot), .m_axi_arvalid(arvalid),
        .m_axi_arready(arready), .m_axi_rdata(rdata), .m_axi_rresp(rresp),
        .m_axi_rvalid(rvalid), .m_axi_rready(rready),
        .status_value(status_value), .success_count(success_count),
        .completed_count(completed_count), .timeout_count(timeout_count),
        .error_flags(error_flags), .last_rresp(last_rresp), .rresp_valid(rresp_valid),
        .read_done(read_done), .busy(busy), .debug_state(debug_state),
        .transaction_timeout(transaction_timeout)
    );
    axi_lite_read_slave_model slave (
        .clk(clk), .rst_n(rst_n), .hold_ar(hold_ar), .hold_r(hold_r),
        .ar_delay(ar_delay), .r_delay(r_delay), .reply_data(slave_data), .reply_resp(slave_resp),
        .arvalid(arvalid), .arready(arready), .rdata(rdata), .rresp(rresp),
        .rvalid(rvalid), .rready(rready), .accepted_count(accepted_count)
    );

    // A second DUT retains the actual hardware defaults. Verify real 100 ms
    // spacing, rather than relying only on an accelerated timer parameter.
    reg default_rst_n = 1'b0;
    wire [31:0] default_araddr, default_rdata, default_status;
    wire [31:0] default_success, default_completed, default_accepted;
    wire [1:0] default_rresp;
    wire default_arvalid, default_arready, default_rvalid, default_rready;
    wire default_awvalid, default_wvalid, default_bready;
    integer default_cycle = 0, first_default_cycle = 0, last_default_cycle = 0;
    integer default_requests = 0;
    can_axi_lite_master default_dut (
        .aclk(clk), .aresetn(default_rst_n), .send_req(1'b0), .tx_state(),
        .clock_locked(1'b1),.reset_released(1'b1),.stop_req(1'b0),.period_sel(2'b00),.limit_sel(2'b00),
        .tx_busy(), .tx_fifo_write_done(), .tx_success(), .tx_error(), .tx_timeout(),
        .tx_success_count(), .tx_error_count(), .last_bresp(), .last_isr(), .last_sr(),
        .tx_error_code(), .write_error_flags(), .bus_quarantined(), .tx_may_be_pending(), .send_used(),
        .m_axi_awaddr(), .m_axi_awprot(), .m_axi_awvalid(default_awvalid), .m_axi_awready(1'b0),
        .m_axi_wdata(), .m_axi_wstrb(), .m_axi_wvalid(default_wvalid), .m_axi_wready(1'b0),
        .m_axi_bresp(2'b00), .m_axi_bvalid(1'b0), .m_axi_bready(default_bready),
        .m_axi_araddr(default_araddr), .m_axi_arprot(), .m_axi_arvalid(default_arvalid),
        .m_axi_arready(default_arready), .m_axi_rdata(default_rdata), .m_axi_rresp(default_rresp),
        .m_axi_rvalid(default_rvalid), .m_axi_rready(default_rready),
        .status_value(default_status), .success_count(default_success), .completed_count(default_completed),
        .timeout_count(), .error_flags(), .last_rresp(), .rresp_valid(), .read_done(),
        .busy(), .debug_state(), .transaction_timeout()
    );
    axi_lite_read_slave_model default_slave (
        .clk(clk), .rst_n(default_rst_n), .hold_ar(1'b0), .hold_r(1'b0),
        .ar_delay(32'd0), .r_delay(32'd0), .reply_data(32'h00000098), .reply_resp(2'b00),
        .arvalid(default_arvalid), .arready(default_arready), .rdata(default_rdata),
        .rresp(default_rresp), .rvalid(default_rvalid), .rready(default_rready),
        .accepted_count(default_accepted)
    );

    task check;
        input condition;
        input [8*120-1:0] label;
        begin
            if (condition !== 1'b1) begin
                errors = errors + 1;
                if (errors < 30) $display("FAIL @ %0t: %0s", $time, label);
            end
        end
    endtask
    task start_case;
        begin case_errors = errors; end
    endtask
    task end_case;
        input [8*120-1:0] label;
        begin
            cases_run = cases_run + 1;
            if (errors == case_errors) $display("PASS [%0d]: %0s", cases_run, label);
            else $display("FAIL [%0d]: %0s", cases_run, label);
        end
    endtask
    task reset_fast;
        begin
            @(negedge clk);
            rst_n = 1'b0;
            hold_ar = 1'b0; hold_r = 1'b0;
            ar_delay = 0; r_delay = 0;
            slave_data = 32'h00000098; slave_resp = 2'b00;
            repeat (3) @(posedge clk);
            @(negedge clk); rst_n = 1'b1;
        end
    endtask
    task wait_done;
        integer n;
        begin
            n = 0;
            begin : done_loop
                while (n < 1000) begin
                    @(posedge clk); #2; n = n + 1;
                    if (read_done === 1'b1) disable done_loop;
                end
            end
            check(read_done === 1'b1, "read completion must arrive within TB deadline");
        end
    endtask
    task wait_timeout;
        integer n;
        begin
            n = 0;
            while ((transaction_timeout !== 1'b1) && (n < 1000)) begin
                @(posedge clk); #2; n = n + 1;
            end
            check(transaction_timeout === 1'b1, "timeout must be detected within TB deadline");
        end
    endtask

    // Continuous protocol checks, including every stall and timeout cycle.
    always @(posedge clk) begin
        if (!rst_n) begin
            outstanding = 0; ar_stalls = 0; r_stalls = 0;
            previous_stall = 1'b0; expected_done = 1'b0;
        end else begin
            check({awvalid,wvalid,bready} === 3'b000, "all write handshakes remain inactive");
            check({awaddr,awprot,wdata,wstrb} === 71'd0, "unused write address/data/protection/strobes stay zero");
            check(araddr === 32'h43C00018, "fixed CAN status address");
            check(arprot === 3'b000, "read protection attribute");
            check(!(arvalid && rready), "address and response phases must not overlap");
            if (previous_stall) begin
                check(arvalid === 1'b1, "ARVALID cannot be withdrawn before ARREADY, even after timeout");
                check(araddr === previous_address && arprot === previous_prot, "stalled address/protection stable");
            end
            if (arvalid && !arready) ar_stalls = ar_stalls + 1;
            if (rready && !rvalid) r_stalls = r_stalls + 1;
            if (arvalid && arready) outstanding = outstanding + 1;
            if (rvalid && rready) outstanding = outstanding - 1;
            check(outstanding >= 0 && outstanding <= 1, "at most one outstanding read; no duplicate/unsolicited response acceptance");
            previous_stall = arvalid && !arready;
            previous_address = araddr; previous_prot = arprot;
            expected_done = rvalid && rready;
        end
        #1;
        check(read_done === expected_done, "read_done equals exactly one accepted response pulse");
    end
    always @(posedge clk) begin
        if (!default_rst_n) begin
            default_cycle = 0; default_requests = 0;
            first_default_cycle = 0; last_default_cycle = 0;
        end else begin
            default_cycle = default_cycle + 1;
            check({default_awvalid,default_wvalid,default_bready} === 3'b000, "default DUT also never writes");
            if (default_arvalid && default_arready) begin
                check(default_araddr === 32'h43C00018, "default DUT address");
                default_requests = default_requests + 1;
                if (default_requests == 1) first_default_cycle = default_cycle;
                else check(default_cycle-last_default_cycle == 5000000, "actual default requests are exactly 100 ms apart");
                last_default_cycle = default_cycle;
            end
        end
    end

    initial begin
        start_case;
        reset_fast;
        check(status_value === 0 && success_count === 0 && completed_count === 0 &&
              timeout_count === 0 && error_flags === 0 && rresp_valid === 0, "reset clears all diagnostics");
        wait_done;
        check(status_value === 32'h98 && success_count === 1 && completed_count === 1 &&
              last_rresp === 0 && rresp_valid === 1 && error_flags === 0, "normal OKAY read saves 0x98");
        @(posedge clk); #2; check(read_done === 0, "read_done is one clock wide");
        end_case("reset and normal status read 0x00000098");

        start_case;
        reset_fast; ar_delay = 3; r_delay = 4;
        wait_done;
        check(status_value === 32'h98 && success_count === 1 && completed_count === 1 && error_flags === 0,
              "AR and R wait states preserve a successful read");
        check(ar_stalls >= 3 && r_stalls >= 4, "slave actually inserted address and response waits");
        end_case("independent ARREADY and RVALID wait states");

        start_case;
        reset_fast; slave_resp = 2'b10; slave_data = 32'hDEADBEEF;
        wait_done;
        check(success_count === 0 && completed_count === 1 && status_value === 0 &&
              error_flags === 3'b001 && last_rresp === 2'b10 && rresp_valid === 1, "SLVERR does not overwrite status or success count");
        @(negedge clk); slave_resp = 0; slave_data = 32'h98;
        wait_done;
        check(status_value === 32'h98 && success_count === 1 && completed_count === 2 &&
              last_rresp === 0 && error_flags === 3'b001, "next OKAY read works; error remains sticky");
        end_case("SLVERR, sticky error and subsequent recovery");

        start_case;
        reset_fast; slave_resp = 2'b11;
        wait_done;
        check(success_count === 0 && completed_count === 1 && error_flags === 3'b001 && last_rresp === 2'b11,
              "DECERR response handled");
        end_case("DECERR response");

        start_case;
        reset_fast; slave_resp = 2'b01;
        wait_done;
        check(success_count === 0 && error_flags === 3'b001 && last_rresp === 2'b01,
              "EXOKAY is not a valid successful AXI4-Lite response");
        end_case("unsupported EXOKAY rejected as non-OKAY");

        start_case;
        reset_fast; hold_ar = 1;
        wait_timeout;
        check(ar_stalls == LIMIT, "AR timeout fires on the configured wait-cycle count");
        check(error_flags === 3'b010 && timeout_count === 1 && busy === 1 &&
              arvalid === 1 && completed_count === 0 && rresp_valid === 0, "AR timeout reported without cancelling the address");
        repeat (POLL*3) @(posedge clk);
        #2; check(accepted_count === 0 && timeout_count === 1 && arvalid === 1 && success_count === 0,
                  "busy polling ticks cannot duplicate a timed-out address");
        @(negedge clk); hold_ar = 0;
        wait_done;
        check(completed_count === 1 && success_count === 0 && status_value === 0 && timeout_count === 1,
              "late transaction drained, not counted as success");
        wait_done;
        check(success_count === 1 && status_value === 32'h98 && error_flags === 3'b010,
              "polling resumes only after old address/response retires");
        end_case("AR timeout, stable VALID, skipped ticks, late response and recovery");

        start_case;
        reset_fast; hold_r = 1;
        wait_timeout;
        check(r_stalls == LIMIT, "R timeout fires on the configured wait-cycle count");
        check(error_flags === 3'b100 && timeout_count === 1 && rready === 1 &&
              arvalid === 0 && completed_count === 0 && accepted_count === 1, "R timeout keeps waiting for the outstanding response");
        repeat (POLL*3) @(posedge clk);
        #2; check(accepted_count === 1 && timeout_count === 1 && rready === 1,
                  "no new address while timed-out response is missing");
        @(negedge clk); hold_r = 0;
        wait_done;
        check(completed_count === 1 && success_count === 0 && status_value === 0 && last_rresp === 0,
              "late OKAY response is drained without updating good status");
        wait_done;
        check(success_count === 1 && status_value === 32'h98 && error_flags === 3'b100,
              "polling recovers after late R response");
        end_case("R timeout, single outstanding transaction, late response and recovery");

        start_case;
        reset_fast; ar_delay = LIMIT-1; r_delay = LIMIT-2;
        wait_done;
        check(status_value === 32'h98 && success_count === 1 && timeout_count === 0 && error_flags === 0,
              "handshake on the timeout deadline wins over alarm");
        end_case("AR and R handshake on exact timeout boundary");

        start_case;
        reset_fast; hold_ar = 1;
        guard = 0;
        while (!arvalid && guard < 200) begin @(posedge clk); #2; guard = guard+1; end
        check(arvalid === 1, "address pending before reset");
        reset_fast;
        check(busy === 0 && arvalid === 0 && completed_count === 0 && error_flags === 0, "reset aborts local state with slave reset too");
        wait_done; check(success_count === 1 && status_value === 32'h98, "read after AR-phase reset");
        end_case("shared reset while waiting for ARREADY");

        start_case;
        reset_fast; hold_r = 1;
        guard = 0;
        while (!rready && guard < 200) begin @(posedge clk); #2; guard = guard+1; end
        check(rready === 1, "response pending before reset");
        reset_fast;
        check(busy === 0 && rready === 0 && timeout_count === 0 && rresp_valid === 0, "reset clears response wait");
        wait_done; check(success_count === 1, "read after response-phase reset");
        end_case("shared reset while waiting for RVALID");

        start_case;
        @(negedge clk); rst_n = 0; default_rst_n = 1;
        guard = 0;
        while ((default_success < 2) && guard < 10000100) begin
            @(posedge clk); #2; guard = guard+1;
        end
        check(default_success === 2 && default_completed === 2 && default_requests == 2 &&
              default_status === 32'h98, "two real default-period reads completed");
        check(first_default_cycle == 5000001, "first address handshake follows the first 5,000,000-clock timer tick");
        end_case("actual 50 MHz / 100 ms default timer, two consecutive reads");

        if (errors == 0) $display("RESULT: PASS (%0d/%0d tests)", cases_run, cases_run);
        else $display("RESULT: FAIL (%0d errors in %0d tests)", errors, cases_run);
        $finish;
    end
    initial begin
        #210000000;
        $display("RESULT: FAIL (global simulation watchdog)");
        $finish;
    end
endmodule

// Configurable one-outstanding AXI4-Lite read slave. RDATA/RRESP are latched
// at the address handshake and RVALID is held until the response handshake.
module axi_lite_read_slave_model (
    input wire clk, input wire rst_n,
    input wire hold_ar, input wire hold_r,
    input wire [31:0] ar_delay, input wire [31:0] r_delay,
    input wire [31:0] reply_data, input wire [1:0] reply_resp,
    input wire arvalid, output wire arready,
    output reg [31:0] rdata, output reg [1:0] rresp,
    output reg rvalid, input wire rready,
    output reg [31:0] accepted_count
);
    reg pending;
    reg [31:0] ar_wait, r_wait;
    assign arready = rst_n && !hold_ar && !pending && (ar_wait >= ar_delay);
    always @(posedge clk) begin
        if (!rst_n) begin
            pending <= 0; ar_wait <= 0; r_wait <= 0;
            rdata <= 0; rresp <= 0; rvalid <= 0; accepted_count <= 0;
        end else begin
            if (!pending) begin
                if (arvalid && arready) begin
                    pending <= 1; ar_wait <= 0; r_wait <= 0;
                    rdata <= reply_data; rresp <= reply_resp;
                    accepted_count <= accepted_count+1;
                end else if (arvalid && !hold_ar) ar_wait <= ar_wait+1;
                else if (!arvalid) ar_wait <= 0;
            end else if (rvalid) begin
                if (rready) begin rvalid <= 0; pending <= 0; end
            end else if (!hold_r) begin
                if (r_wait >= r_delay) rvalid <= 1;
                else r_wait <= r_wait+1;
            end
        end
    end
endmodule
