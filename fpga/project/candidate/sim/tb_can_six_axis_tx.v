`timescale 1ns / 1ps
module tb_can_six_axis_tx #(parameter integer REAL_TIMING=0);
    localparam integer PERIOD=REAL_TIMING?500000:2000;
    reg clk=0,rst_n=0,locked=0,released=0,start_req=0,stop_req=0;
    reg [1:0] period_sel=0,limit_sel=0;
    reg hold_aw=0,hold_w=0,hold_b=0,hold_ar=0,hold_r=0,fifo_full=0,no_txok=0,can_error=0;
    reg [31:0] ack_delay=5;
    integer fail_write=-1,fail_read=-1,checks=0,failures=0,i,n,saved_count;
    wire [31:0] awaddr,wdata,araddr,rdata,scheduled,attempted,enqueued,successes,errors,missed,sequence;
    wire [31:0] selected_period,frame_limit,status_count,last_isr,last_attempt_cycle,last_complete_cycle;
    wire [3:0] wstrb,error_code;
    wire [1:0] bresp,rresp;
    wire awvalid,wvalid,bready,arvalid,rready,awready,wready,bvalid,arready,rvalid;
    wire initialized,init_error,done,stopped,tx_busy,tx_error,quarantined,may_pending,round_used,rejected,violation;
    wire [2:0] scheduler_state;
    wire [31:0] writes,reads,model_enqueued,model_errors,reset_count,model_sequence;
    integer previous_enqueues=0,previous_scheduled=0,cycle=0,previous_tick=0,previous_isr_cycle=-1,isr_reads=0;
    integer first_attempt_cycle=-1,second_attempt_cycle=-1,previous_attempts=0;
    reg previous_ar_stall=0,previous_aw_stall=0,previous_w_stall=0;
    reg [31:0] held_ar=0,held_aw=0,held_w=0;
    always #10 clk=~clk;
    wire [31:0] seq3,started3,completed3,missed3,maxspan3,limit3;
    wire [2:0] axis3;
    wire fault3;
    can_axi_lite_master #(.ENABLE_PL_INIT(1),.ENABLE_PERIODIC(1),.ENABLE_SIX_AXIS(1),
        .INIT_TIMEOUT_CYCLES(500),.INIT_POLL_CYCLES(3),.TIMEOUT_CYCLES(24),
        .POLL_INTERVAL_CYCLES(73),.PERIOD_100HZ_CYCLES(PERIOD),
        .TXOK_POLL_CYCLES(REAL_TIMING?5000:20),
        .TXOK_TIMEOUT_CYCLES(REAL_TIMING?500000:500),
        .SEND_TIMEOUT_CYCLES(REAL_TIMING?1000000:1200)) dut(
        .aclk(clk),.aresetn(rst_n),.clock_locked(locked),.reset_released(released),
        .send_req(start_req),.stop_req(stop_req),.period_sel(period_sel),.limit_sel(limit_sel),
        .m_axi_awaddr(awaddr),.m_axi_awprot(),.m_axi_awvalid(awvalid),.m_axi_awready(awready),
        .m_axi_wdata(wdata),.m_axi_wstrb(wstrb),.m_axi_wvalid(wvalid),.m_axi_wready(wready),
        .m_axi_bresp(bresp),.m_axi_bvalid(bvalid),.m_axi_bready(bready),
        .m_axi_araddr(araddr),.m_axi_arprot(),.m_axi_arvalid(arvalid),.m_axi_arready(arready),
        .m_axi_rdata(rdata),.m_axi_rresp(rresp),.m_axi_rvalid(rvalid),.m_axi_rready(rready),
        .can_initialized(initialized),.can_init_error(init_error),.success_count(status_count),
        .scheduled_count(scheduled),.attempted_count(attempted),.enqueued_count(enqueued),
        .tx_success_count(successes),.tx_error_count(errors),.missed_deadline_count(missed),
        .last_sequence(sequence),.selected_period(selected_period),.frame_limit(frame_limit),
        .periodic_completed(done),.periodic_stopped(stopped),.scheduler_state(scheduler_state),
        .tx_busy(tx_busy),.tx_error(tx_error),.tx_error_code(error_code),.last_isr(last_isr),
        .bus_quarantined(quarantined),.tx_may_be_pending(may_pending),.round_used(round_used),
        .start_rejected(rejected),.deadline_violation(violation),
        .last_attempt_cycle(last_attempt_cycle),.tx_completed_cycle(last_complete_cycle),
        .cycle_seq(seq3),.axis_index(axis3),.cycle_started_count(started3),.cycle_completed_count(completed3),
        .missed_cycle_count(missed3),.max_cycle_span_cycles(maxspan3),.cycle_limit(limit3),.scheduler_fault(fault3));
    can_axi_slave_model #(.SIX_AXIS_TEST(1)) slave(.clk(clk),.rst_n(rst_n),
        .awaddr(awaddr),.wdata(wdata),.araddr(araddr),.wstrb(wstrb),
        .awvalid(awvalid),.wvalid(wvalid),.bready(bready),.arvalid(arvalid),.rready(rready),
        .awready(awready),.wready(wready),.bvalid(bvalid),.arready(arready),.rvalid(rvalid),
        .bresp(bresp),.rresp(rresp),.rdata(rdata),
        .hold_aw(hold_aw),.hold_w(hold_w),.hold_b(hold_b),.hold_ar(hold_ar),.hold_r(hold_r),
        .config_stuck(1'b0),.normal_stuck(1'b0),.fifo_full(fifo_full),.no_txok(no_txok),
        .can_error(can_error),.txok_delay_cycles(ack_delay),.fail_write_index(fail_write),.fail_read_index(fail_read),
        .write_count(writes),.read_count(reads),.enqueued_count(model_enqueued),.protocol_errors(model_errors),
        .reset_count(reset_count),.last_sequence(model_sequence));
    integer slot_clock=0,last_slot=0,old_started=0,old_enqueued=0,old_successes=0;
    integer first_tick=0,expected_max=0,accepted=0,span_value=0;
    task check;
        input ok;input [8*140-1:0] label;
        begin checks=checks+1;
            if(ok!==1'b1) begin failures=failures+1;$display("FAIL: %0s",label);end
            else $display("PASS: %0s",label);
        end
    endtask
    task expect;
        input ok;input [8*140-1:0] label;
        begin if(ok!==1'b1) begin failures=failures+1;if(failures<25)$display("FAIL: %0s",label);end end
    endtask
    task reset_all;
        begin
            @(negedge clk);rst_n=0;locked=0;released=0;start_req=0;stop_req=0;
            hold_aw=0;hold_w=0;hold_b=0;hold_ar=0;hold_r=0;fifo_full=0;no_txok=0;can_error=0;
            fail_write=-1;fail_read=-1;ack_delay=5;period_sel=1;limit_sel=0;
            repeat(4) @(negedge clk);rst_n=1;locked=1;released=1;
            wait(initialized||init_error);expect(!init_error,"PL init completes without software");
            repeat(4) @(negedge clk);
        end
    endtask
    task trigger;
        begin @(negedge clk);start_req=1;repeat(3) @(negedge clk);end
    endtask
    task wait_terminal;
        input integer bound;
        integer k;
        begin
            k=0;
            while(!done&&!stopped&&!fault3&&k<bound) begin @(negedge clk);k=k+1;end
            expect(k<bound,"terminal state reached within bound");
        end
    endtask
    task nominal;
        input [1:0] limit;
        input integer count;
        begin
            reset_all;limit_sel=limit;trigger;
            // Both selectors must be latched at the accepted start.
            period_sel=3;limit_sel=3;
            wait_terminal(PERIOD*(count+1));
            check(done&&!fault3&&errors==0,"nominal six-axis job completes without fault");
            check(started3==count&&completed3==count&&successes==6*count&&enqueued==6*count,
                "cycle limit counts 100/1000 control cycles, exactly 600/6000 frames");
            check(seq3==count-1&&axis3==5&&limit3==count&&frame_limit==count,
                "sequence starts at zero; final axis and cycle-limit debug alias retained");
            check(missed3==0&&maxspan3==expected_max&&maxspan3<PERIOD,
                "all six fresh TXOKs before next slot; exact measured maximum span");
            check(selected_period==PERIOD&&model_errors==0&&reset_count==1,
                "configuration latched; model protocol checks and autonomous initialization pass");
            check(status_count>0,"existing AXI Reader continues in inter-cycle gaps");
            saved_count=enqueued;start_req=0;repeat(5) @(negedge clk);start_req=1;
            repeat(PERIOD+50) @(negedge clk);
            check(done&&enqueued==saved_count&&round_used,"one round per reset; terminal counters retained");
            $display("NOMINAL: cycles=%0d frames=%0d max_span=%0d",count,successes,maxspan3);
        end
    endtask
    always @(posedge clk) begin
        if(rst_n) begin
            expect(!((arvalid||rready)&&(awvalid||wvalid||bready)),"single shared AXI executor; no read/write overlap");
            if(dut.send_trigger) begin
                expect(successes==accepted,"each next frame attempt requires preceding new TXOK");
                if(axis3==0) first_tick=dut.cycle_counter;
                accepted=accepted+1;
            end
            if(awvalid&&awaddr>=32'h43C00030&&awaddr<=32'h43C0003C)
                expect(initialized,"no FIFO write before PL CAN initialization");
            if(previous_ar_stall) expect(arvalid&&araddr==held_ar,"AR held stable across waits/timeouts");
            if(previous_aw_stall) expect(awvalid&&awaddr==held_aw,"AW held stable across waits/timeouts");
            if(previous_w_stall) expect(wvalid&&wdata==held_w,"W held stable across waits/timeouts");
        end else accepted=0;
        previous_ar_stall=rst_n&&arvalid&&!arready;held_ar=araddr;
        previous_aw_stall=rst_n&&awvalid&&!awready;held_aw=awaddr;
        previous_w_stall=rst_n&&wvalid&&!wready;held_w=wdata;
    end
    always @(negedge clk) begin
        if(!rst_n) begin
            slot_clock=0;old_started=0;last_slot=0;old_enqueued=0;old_successes=0;expected_max=0;
        end else begin
            slot_clock=slot_clock+1;
            if(started3!=old_started) begin
                if(old_started!=0) expect(slot_clock-last_slot==PERIOD,"control slots use fixed period with no cumulative drift");
                expect(seq3==started3-1&&axis3==0,"new cycle uses next sequence and Axis0");
                last_slot=slot_clock;old_started=started3;
            end
            if(model_enqueued!=old_enqueued) begin
                expect((((slave.id_word>>21)<<18)|((slave.id_word>>1)&32'h3FFFF))==32'h1B345670+(old_enqueued%6),
                    "six independent decoded extended IDs are in Axis0..5 order");
                expect(slave.id_word[20:19]==2'b11&&!slave.id_word[0]&&slave.dlc_word==32'h80000000,
                    "extended data frame, RTR=0, DLC=8");
                expect(slave.dw1_word==old_enqueued/6,"six frames share one cycle_seq and next cycle increments");
                expect({slave.data_bytes[0],slave.data_bytes[1],slave.data_bytes[2],slave.data_bytes[3]}==old_enqueued/6,
                    "physical CAN byte mapping preserves 32-bit big-endian cycle_seq");
                expect(slave.data_bytes[4]==old_enqueued%6&&slave.data_bytes[5]==8'hA5&&
                    slave.data_bytes[6]==8'h5A&&slave.data_bytes[7]==8'hC3,"axis byte and A5 5A C3 payload match");
                old_enqueued=model_enqueued;
            end
            if(successes!=old_successes) begin
                if(successes%6==0) begin
                    span_value=dut.tx_completed_cycle-first_tick;
                    if(span_value>expected_max) expected_max=span_value;
                end
                old_successes=successes;
            end
        end
    end
    initial begin
        if(REAL_TIMING) begin
            reset_all;trigger;wait(completed3==2);@(negedge clk);stop_req=1;
            wait_terminal(30000);
            check(stopped&&successes==12&&completed3==2&&missed3==0,"unscaled 50 MHz / 500000 clocks: two exact 10 ms control cycles");
            check(maxspan3==expected_max&&maxspan3<500000,"unscaled six-frame spans measured with real 100 us TXOK polling");
            $display("REAL_TIMING: period_cycles=%0d max_cycle_span_cycles=%0d frames=%0d",PERIOD,maxspan3,successes);
        end else begin
            nominal(0,100);nominal(1,1000);
            for(i=0;i<4;i=i+1) if(i!=1) begin
                reset_all;period_sel=i;trigger;repeat(80) @(negedge clk);
                check(rejected&&!round_used&&enqueued==0,"non-100Hz selector rejected without fallback or consumption");
            end
            for(i=2;i<4;i=i+1) begin
                reset_all;limit_sel=i;trigger;repeat(80) @(negedge clk);
                check(rejected&&!round_used&&enqueued==0,"unsupported cycle limit selector rejected");
            end
            reset_all;stop_req=1;trigger;repeat(80) @(negedge clk);
            check(rejected&&enqueued==0&&!round_used,"STOP high forbids launch");
            reset_all;trigger;wait(dut.tx_state==3);@(negedge clk);stop_req=1;wait_terminal(2000);
            check(stopped&&enqueued==0&&errors==0,"STOP before FIFO admission cancels pending frame");
            reset_all;trigger;wait(slave.fifo_phase==1);@(negedge clk);stop_req=1;wait_terminal(2000);
            check(stopped&&successes==1&&enqueued==1&&completed3==0&&slave.fifo_phase==0,
                "STOP after first FIFO word drains atomic frame, no next axis");
            check(reset_count==1,"STOP does not reset or reinitialize CAN");
            reset_all;ack_delay=100;trigger;wait(model_enqueued==1);@(negedge clk);stop_req=1;
            check(successes==0,"STOP cannot cancel a queued CAN frame");wait_terminal(2000);
            check(stopped&&successes==1&&started3==1&&completed3==0,"queued frame may finish; partial cycle stays incomplete");
            saved_count=writes;repeat(PERIOD+50) @(negedge clk);
            check(writes==saved_count&&stopped,"STOP sticky and no later period/axis enqueue");
            reset_all;ack_delay=100;trigger;wait(model_enqueued==6);@(negedge clk);stop_req=1;wait_terminal(2000);
            check(stopped&&successes==6&&completed3==1&&maxspan3==expected_max,"STOP while waiting sixth TXOK preserves completed-cycle accounting");
            reset_all;no_txok=1;trigger;wait_terminal(2500);
            check(fault3&&tx_error&&errors==1&&error_code==6&&may_pending&&completed3==0,
                "no ACK model causes bounded TXOK timeout, FAULT, may-be-pending status");
            saved_count=enqueued;no_txok=0;repeat(PERIOD+700) @(negedge clk);
            check(enqueued==saved_count&&errors==1&&fault3&&reset_count==1,"late ACK cannot restart, retry, or reinitialize after timeout");
            reset_all;ack_delay=400;trigger;wait_terminal(PERIOD+100);
            check(fault3&&missed3==1&&started3==1&&completed3==0,"unfinished six-axis cycle faults at deadline instead of skipping or queueing");
            saved_count=enqueued;repeat(PERIOD+800) @(negedge clk);
            check(enqueued==saved_count&&missed3==1&&seq3==0,"deadline FAULT forbids next cycle, catch-up burst and sequence advance");
            reset_all;fifo_full=1;trigger;wait_terminal(2000);
            check(fault3&&errors==1&&error_code==2&&enqueued==0,"FIFO full faults with no automatic retry");
            for(i=6;i<=10;i=i+1) begin
                reset_all;fail_write=i;trigger;wait_terminal(2000);
                check(fault3&&errors==1&&error_code==4,"AXI BRESP error at each ICR/FIFO word faults once");
            end
            reset_all;hold_ar=1;trigger;wait_terminal(2000);
            check(fault3&&errors==1&&quarantined,"AXI address timeout retains transaction quarantine");
            hold_ar=0;repeat(150) @(negedge clk);check(enqueued==0&&errors==1,"late AXI drain does not enqueue after fault");
            reset_all;fail_read=reads;trigger;wait_terminal(2000);
            check(fault3&&errors==1&&error_code==3,"AXI RRESP error stops the cycle without a FIFO enqueue");
            reset_all;ack_delay=100;trigger;wait(model_enqueued==1);@(negedge clk);stop_req=1;
            @(negedge clk);stop_req=0;wait_terminal(2000);
            check(stopped&&successes==1&&enqueued==1,"one-clock STOP pulse is latched; no later axis is admitted");
            reset_all;can_error=1;trigger;wait_terminal(2000);
            check(fault3&&errors==1&&error_code==8,"CAN error response stops six-axis scheduler");
            reset_all;slave.isr=2;ack_delay=100;trigger;wait(model_enqueued==1);repeat(10) @(negedge clk);
            check(successes==0&&!slave.isr[1],"old TXOK cannot acknowledge the new first frame");
            stop_req=1;wait_terminal(2000);
            @(negedge clk);rst_n=0;start_req=1;stop_req=0;repeat(4) @(negedge clk);
            rst_n=1;wait(initialized);repeat(150) @(negedge clk);
            check(enqueued==0&&!round_used,"start held high across reset/init never auto-sends");
            start_req=0;repeat(4) @(negedge clk);trigger;wait(model_enqueued==1);@(negedge clk);stop_req=1;wait_terminal(2000);
            check(stopped&&successes==1,"fresh low and rising edge required after reset");
        end
        if(failures==0)$display("RESULT: PASS SIX_AXIS real_timing=%0d (%0d checks)",REAL_TIMING,checks);
        else $display("RESULT: FAIL SIX_AXIS failures=%0d checks=%0d",failures,checks);
        $finish;
    end
    initial begin #2000000000;$display("RESULT: FAIL SIX_AXIS watchdog");$finish;end
endmodule
module tb_can_six_axis_real_timing;
    tb_can_six_axis_tx #(.REAL_TIMING(1)) test();
endmodule
