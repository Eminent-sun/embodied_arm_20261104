`timescale 1ns / 1ps
// Digital phase/reset tests, not a metastability model. Clocks never gated in RTL.
module tb_pl_clock_reset_cdc;
    reg axi_clk=0,can_clk=0,can_clock_run=1;
    reg rst_n=0,raw_locked=0,start_req=0,hold_b=0;
    reg [31:0] ack_delay=3;
    wire locked_axi,axi_resetn,can_resetn,ready,released,initialized;
    wire [31:0] awaddr,wdata,araddr,rdata,attempted,enqueued,successes;
    wire awvalid,wvalid,bready,arvalid,rready,awready,wready,bvalid,arready,rvalid;
    wire [3:0] wstrb;
    wire [1:0] bresp,rresp;
    wire [31:0] model_enqueues,model_errors,model_writes;
    wire [4:0] init_state;
    integer checks=0,failures=0,axi_release_edges=0,can_release_edges=0;
    real last_axi=0,last_can=0,axi_release_time=0,can_release_time=0;
    always #10 axi_clk=~axi_clk;
    // Fault stimulus only: deliberately withhold CAN clock to test release gating.
    always #25 if(can_clock_run) can_clk=~can_clk;else can_clk=0;
    pl_clock_reset reset_controller(.clk_axi_50m(axi_clk),.clk_can_20m(can_clk),
        .rst_n(rst_n),.clock_locked(raw_locked),.axi_aresetn(axi_resetn),
        .can_aresetn(can_resetn),.clock_ready(ready),.reset_released(released),
        .clock_locked_axi(locked_axi));
    can_axi_lite_master #(.ENABLE_PL_INIT(1),.ENABLE_PERIODIC(1),
        .INIT_TIMEOUT_CYCLES(1000),.INIT_POLL_CYCLES(3),.TIMEOUT_CYCLES(100),
        .POLL_INTERVAL_CYCLES(16),.PERIOD_10HZ_CYCLES(4096),
        .PERIOD_100HZ_CYCLES(1024),.PERIOD_200HZ_CYCLES(512),
        .TXOK_POLL_CYCLES(8),.TXOK_TIMEOUT_CYCLES(1024),.SEND_TIMEOUT_CYCLES(2048)) master(
        .aclk(axi_clk),.aresetn(axi_resetn),.clock_locked(locked_axi),.reset_released(released),
        .send_req(start_req),.stop_req(1'b0),.period_sel(2'b10),.limit_sel(2'b00),
        .m_axi_awaddr(awaddr),.m_axi_awprot(),.m_axi_awvalid(awvalid),.m_axi_awready(awready),
        .m_axi_wdata(wdata),.m_axi_wstrb(wstrb),.m_axi_wvalid(wvalid),.m_axi_wready(wready),
        .m_axi_bresp(bresp),.m_axi_bvalid(bvalid),.m_axi_bready(bready),
        .m_axi_araddr(araddr),.m_axi_arprot(),.m_axi_arvalid(arvalid),.m_axi_arready(arready),
        .m_axi_rdata(rdata),.m_axi_rresp(rresp),.m_axi_rvalid(rvalid),.m_axi_rready(rready),
        .can_initialized(initialized),.can_init_state(init_state),
        .attempted_count(attempted),.enqueued_count(enqueued),.tx_success_count(successes));
    can_axi_slave_model slave(.clk(axi_clk),.rst_n(axi_resetn),
        .awaddr(awaddr),.wdata(wdata),.araddr(araddr),.wstrb(wstrb),
        .awvalid(awvalid),.wvalid(wvalid),.bready(bready),.arvalid(arvalid),.rready(rready),
        .awready(awready),.wready(wready),.bvalid(bvalid),.arready(arready),.rvalid(rvalid),
        .bresp(bresp),.rresp(rresp),.rdata(rdata),
        .hold_aw(1'b0),.hold_w(1'b0),.hold_b(hold_b),.hold_ar(1'b0),.hold_r(1'b0),
        .config_stuck(1'b0),.normal_stuck(1'b0),.fifo_full(1'b0),
        .no_txok(1'b0),.can_error(1'b0),.txok_delay_cycles(ack_delay),
        .fail_write_index(32'hFFFFFFFF),.fail_read_index(32'hFFFFFFFF),
        .write_count(model_writes),.enqueued_count(model_enqueues),.protocol_errors(model_errors));
    task check;
        input ok;
        input [8*120-1:0] message;
        begin
            checks=checks+1;
            if(ok!==1'b1) begin failures=failures+1;$display("FAIL: %0s",message);end
            else $display("PASS: %0s",message);
        end
    endtask
    task assert_unlocked;
        begin
            #0.001;
            check(!axi_resetn&&!can_resetn&&!locked_axi&&!released&&!initialized,
                  "loss/reset asynchronously clears both domains and synchronized status");
            repeat(6) @(negedge axi_clk);
            check(!(arvalid||awvalid||wvalid||rready||bready)&&attempted==0&&enqueued==0,
                  "unlocked system cannot issue AXI or enqueue CAN frames");
        end
    endtask
    task recover_held_high;
        begin
            hold_b=0;raw_locked=1;wait(initialized);repeat(120) @(negedge axi_clk);
            check(attempted==0&&model_enqueues==0&&model_errors==0,
                  "lock recovery reinitializes but held-high start cannot automatically transmit");
        end
    endtask
    task fresh_start;
        begin
            start_req=0;repeat(5) @(negedge axi_clk);start_req=1;
        end
    endtask
    always @(posedge axi_clk) begin
        last_axi=$realtime;
        if(reset_controller.qualified_reset_n) axi_release_edges=axi_release_edges+1;
        else axi_release_edges=0;
        #0.001;
        if(!axi_resetn&&(awvalid||wvalid||arvalid||bready||rready)) begin
            failures=failures+1;$display("FAIL: AXI activity during common reset");
        end
        if(awvalid&&awready&&awaddr>=32'h43C00030&&awaddr<=32'h43C0003C &&
           (!initialized||!released||!locked_axi)) begin
            failures=failures+1;$display("FAIL: FIFO write without initialization/clock/reset qualification");
        end
    end
    always @(posedge can_clk) begin
        last_can=$realtime;
        if(reset_controller.qualified_reset_n) can_release_edges=can_release_edges+1;
        else can_release_edges=0;
    end
    always @(negedge reset_controller.qualified_reset_n) begin
        axi_release_edges=0;can_release_edges=0;
    end
    always @(posedge axi_resetn) begin
        axi_release_time=$realtime;
        check($realtime==last_axi&&axi_release_edges==3,
              "50 MHz reset releases only on its own third clock edge");
    end
    always @(posedge can_resetn) begin
        can_release_time=$realtime;
        check($realtime==last_can&&can_release_edges==3,
              "20 MHz reset independently releases on its own third clock edge");
    end
    always @(posedge locked_axi)
        check($realtime==last_axi,"synchronized LOCKED rises only on a 50 MHz edge");
    initial begin
        #73;rst_n=1;repeat(8) @(negedge axi_clk);
        check(!ready&&!axi_resetn&&!can_resetn&&model_writes==0,
              "initial raw LOCKED=0 keeps initialization and transmission inhibited");
        // 1 ps before an AXI rising edge, then wait for the real synchronizer.
        @(negedge axi_clk);#9.999;raw_locked=1;
        #0.002;check(!locked_axi&&!ready&&!axi_resetn,
                     "near-edge raw LOCKED cannot bypass the two-stage synchronizer");
        wait(initialized);check(can_release_time>axi_release_time,
              "CAN domain release is independent; Init waits for returned CAN-ready status");
        check(model_errors==0&&model_enqueues==0,"normal initialization works without automatic sending");
        // 1 ps after an AXI rising edge: asynchronous assertion must not wait a clock.
        @(posedge axi_clk);#0.001;raw_locked=0;start_req=1;assert_unlocked;
        @(posedge axi_clk);#0.001;recover_held_high;
        // A second loss 1 ps before a rising edge exercises the opposite phase.
        @(negedge axi_clk);#9.999;raw_locked=0;assert_unlocked;
        recover_held_high;
        // Short false-lock interval cannot finish the qualification sequence.
        raw_locked=0;#7;raw_locked=1;repeat(3) @(negedge axi_clk);
        raw_locked=0;#0.001;check(!axi_resetn&&!can_resetn,"short LOCKED pulse cannot release either domain");
        recover_held_high;
        // Lose lock with an initialization write awaiting its B response.
        #7;rst_n=0;raw_locked=0;start_req=1;hold_b=1;#43;rst_n=1;raw_locked=1;
        wait(init_state==3);@(negedge axi_clk);#3;raw_locked=0;assert_unlocked;
        check(!initialized,"loss during CAN initialization cancels initialized status");
        recover_held_high;
        // Exercise a periodic job, then lose lock during a partial FIFO frame.
        fresh_start;wait(master.fifo_started&&master.fifo_word==1);
        #3;raw_locked=0;assert_unlocked;
        recover_held_high;
        // Lose lock after enqueue while TXOK is still delayed.
        ack_delay=900;fresh_start;wait(model_enqueues==1);
        check(successes==0,"periodic frame is genuinely in flight before injected lock loss");
        #3;raw_locked=0;assert_unlocked;
        ack_delay=3;recover_held_high;
        // External active-low reset close to an edge is independent of LOCKED.
        @(negedge axi_clk);#9.999;rst_n=0;assert_unlocked;
        #47;rst_n=1;recover_held_high;
        // Withhold only CAN-domain edges: AXI reset may release, Init may not start.
        #3;rst_n=0;raw_locked=0;can_clock_run=0;
        #100;rst_n=1;raw_locked=1;repeat(40) @(negedge axi_clk);
        check(axi_resetn&&!can_resetn&&!released&&!initialized&&model_writes==0,
              "missing CAN clock cannot be replaced by AXI-domain LOCKED for release");
        can_clock_run=1;wait(initialized);repeat(20) @(negedge axi_clk);
        check(model_enqueues==0&&attempted==0,"restoring CAN clock does not automatically start a job");
        fresh_start;wait(successes==1);
        check(model_errors==0&&attempted==1&&enqueued==1,
              "fresh low-to-high request still transmits correctly after all recovery cases");
        if(failures==0) $display("RESULT: PASS CLOCK_RESET_CDC (%0d checks)",checks);
        else $display("RESULT: FAIL CLOCK_RESET_CDC (%0d failures)",failures);
        $finish;
    end
    initial begin #2000000;$display("FAIL: CDC/reset simulation guard timeout");$finish;end
endmodule
