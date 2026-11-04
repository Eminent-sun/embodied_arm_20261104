`timescale 1ns / 1ps
module tb_pl_clock_reset;
    reg osc=0, rst_n=0, inject_unlock=0, send_req=0;
    wire axi_clk,can_clk,wizard_locked,axi_resetn,can_resetn,clock_ready,released;
    wire locked;
    integer checks=0, failures=0, read_count=0;
    real last_axi=0,last_can=0,t0;
    wire [31:0] araddr,awaddr,wdata;
    wire arvalid,rready,awvalid,wvalid,bready;
    wire rvalid,arready,awready,wready,bvalid,initialized;
    wire [31:0] rdata,reader_successes,model_writes,model_reads,model_enqueues,model_errors,model_resets,model_seq;
    wire [1:0] bresp,rresp;
    wire [3:0] wstrb;
    wire effective_locked;
    assign effective_locked=wizard_locked & ~inject_unlock;
    always #10 osc=~osc;
    can_test_clk_pl_0 clock_wizard(.clk_in1(osc),.resetn(rst_n),
        .clk_out1(axi_clk),.clk_out2(can_clk),.locked(wizard_locked));
    pl_clock_reset #(.LOCK_STABLE_CYCLES(16)) reset_controller(
        .clk_axi_50m(axi_clk),.clk_can_20m(can_clk),.rst_n(rst_n),
        .clock_locked(effective_locked),.axi_aresetn(axi_resetn),
        .can_aresetn(can_resetn),.clock_ready(clock_ready),.reset_released(released),
        .clock_locked_axi(locked));
    can_axi_lite_master #(.POLL_INTERVAL_CYCLES(8),.TIMEOUT_CYCLES(50),
        .ENABLE_PL_INIT(1),.ENABLE_PERIODIC(1),.INIT_TIMEOUT_CYCLES(1000),.INIT_POLL_CYCLES(3)) master(
        .aclk(axi_clk),.aresetn(axi_resetn),.send_req(send_req),
        .clock_locked(locked),.reset_released(released),.stop_req(1'b0),.period_sel(2'b01),.limit_sel(2'b00),
        .m_axi_araddr(araddr),.m_axi_arprot(),.m_axi_arvalid(arvalid),.m_axi_arready(arready),
        .m_axi_rdata(rdata),.m_axi_rresp(rresp),.m_axi_rvalid(rvalid),.m_axi_rready(rready),
        .m_axi_awaddr(awaddr),.m_axi_awprot(),.m_axi_awvalid(awvalid),.m_axi_awready(awready),
        .m_axi_wdata(wdata),.m_axi_wstrb(wstrb),.m_axi_wvalid(wvalid),.m_axi_wready(wready),
        .m_axi_bresp(bresp),.m_axi_bvalid(bvalid),.m_axi_bready(bready),
        .can_initialized(initialized),.success_count(reader_successes));
    can_axi_slave_model slave(.clk(axi_clk),.rst_n(axi_resetn),
        .awaddr(awaddr),.wdata(wdata),.araddr(araddr),.wstrb(wstrb),
        .awvalid(awvalid),.wvalid(wvalid),.bready(bready),.arvalid(arvalid),.rready(rready),
        .awready(awready),.wready(wready),.bvalid(bvalid),.arready(arready),.rvalid(rvalid),
        .bresp(bresp),.rresp(rresp),.rdata(rdata),
        .hold_aw(1'b0),.hold_w(1'b0),.hold_b(1'b0),.hold_ar(1'b0),.hold_r(1'b0),
        .config_stuck(1'b0),.normal_stuck(1'b0),.fifo_full(1'b0),.no_txok(1'b0),.can_error(1'b0),
        .txok_delay_cycles(32'd3),.fail_write_index(32'hFFFFFFFF),.fail_read_index(32'hFFFFFFFF),
        .write_count(model_writes),.read_count(model_reads),.enqueued_count(model_enqueues),
        .protocol_errors(model_errors),.reset_count(model_resets),.last_sequence(model_seq));
    task check;
        input ok;
        input [8*110-1:0] description;
        begin
            checks=checks+1;
            if(ok!==1'b1) begin failures=failures+1;$display("FAIL: %0s",description);end
            else $display("PASS: %0s",description);
        end
    endtask
    always @(posedge axi_clk) begin
        last_axi=$realtime;
        if(axi_resetn&&arvalid&&arready) read_count=read_count+1;
        #1;
        if(!axi_resetn && (arvalid||awvalid||wvalid||rready||bready)) begin
            failures=failures+1;$display("FAIL: AXI activity during reset");
        end
        if(awvalid&&awaddr>=32'h43C00030&&awaddr<=32'h43C0003C) begin
            failures=failures+1;$display("FAIL: high start spanning reset triggered send");
        end
    end
    always @(posedge can_clk) last_can=$realtime;
    always @(posedge axi_resetn) check($realtime==last_axi,"AXI reset releases on AXI rising edge");
    always @(posedge can_resetn) check($realtime==last_can,"CAN reset releases on CAN rising edge");
    initial begin
        #100;check(!axi_resetn&&!can_resetn&&!released,"external reset asserts both domains");
        rst_n=1;
        #100;check(!wizard_locked&&!axi_resetn,"real Clocking Wizard has lock acquisition latency");
        wait(wizard_locked);#1;check(!clock_ready&&!axi_resetn,"LOCKED alone cannot release reset");
        wait(released);#1;check(clock_ready&&axi_resetn&&can_resetn,"both domains release after qualified lock");
        @(posedge axi_clk);t0=$realtime;@(posedge axi_clk);check($realtime-t0==20.0,"AXI clock period is 20 ns");
        @(posedge can_clk);t0=$realtime;@(posedge can_clk);check($realtime-t0==50.0,"CAN clock period is 50 ns");
        wait(initialized);repeat(30) @(posedge axi_clk);
        check(reader_successes>0&&model_resets==1,"CAN init and Reader run from actual PL clock without PS");
        #7;rst_n=0;send_req=1;#1;
        check(!axi_resetn&&!can_resetn&&!arvalid&&!awvalid&&!wvalid,"external reset asserts asynchronously and inhibits AXI");
        #100;rst_n=1;wait(released);wait(initialized);repeat(30) @(posedge axi_clk);
        check(model_enqueues==0&&reader_successes>0,"held-high request across reset cannot start TX; init recovers");
        #7;inject_unlock=1;#1;
        check(!axi_resetn&&!can_resetn&&!released,"loss of LOCKED immediately asserts both resets");
        repeat(10) @(posedge axi_clk);check(!arvalid&&!awvalid&&!wvalid,"no AXI traffic while unlocked");
        inject_unlock=0;repeat(5) @(posedge axi_clk);#1;
        check(!axi_resetn&&!can_resetn,"lock must be stable before reset release");
        inject_unlock=1;#31;inject_unlock=0;
        repeat(5) @(posedge axi_clk);#1;check(!axi_resetn,"lock glitch restarts the qualification timer");
        wait(released);wait(initialized);repeat(40) @(posedge axi_clk);
        check(reader_successes>1&&model_enqueues==0&&model_errors==0,"Init/Scheduler/Reader recover after lock loss without automatic TX");
        if(failures==0) $display("RESULT: PASS CLOCK_RESET (%0d checks)",checks);
        else $display("RESULT: FAIL CLOCK_RESET (%0d failures)",failures);
        $finish;
    end
    initial begin #2000000;$display("FAIL: clock/reset simulation guard timeout");$finish;end
endmodule
