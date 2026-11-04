`timescale 1ns / 1ps
module tb_can_periodic_tx #(
    parameter integer LONG_TEST=0,
    parameter integer POLL_CHECK_ONLY=0
);
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
    can_axi_lite_master #(.ENABLE_PL_INIT(1),.ENABLE_PERIODIC(1),
        .INIT_TIMEOUT_CYCLES(500),.INIT_POLL_CYCLES(3),.TIMEOUT_CYCLES(24),
        .POLL_INTERVAL_CYCLES(73),.PERIOD_10HZ_CYCLES(2560),.PERIOD_100HZ_CYCLES(256),
        .PERIOD_200HZ_CYCLES(128),.TXOK_POLL_CYCLES(POLL_CHECK_ONLY?5000:20),
        .TXOK_TIMEOUT_CYCLES(POLL_CHECK_ONLY?30000:800),
        .SEND_TIMEOUT_CYCLES(POLL_CHECK_ONLY?60000:2000)) dut(
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
        .last_attempt_cycle(last_attempt_cycle),.tx_completed_cycle(last_complete_cycle));
    can_axi_slave_model slave(.clk(clk),.rst_n(rst_n),
        .awaddr(awaddr),.wdata(wdata),.araddr(araddr),.wstrb(wstrb),
        .awvalid(awvalid),.wvalid(wvalid),.bready(bready),.arvalid(arvalid),.rready(rready),
        .awready(awready),.wready(wready),.bvalid(bvalid),.arready(arready),.rvalid(rvalid),
        .bresp(bresp),.rresp(rresp),.rdata(rdata),
        .hold_aw(hold_aw),.hold_w(hold_w),.hold_b(hold_b),.hold_ar(hold_ar),.hold_r(hold_r),
        .config_stuck(1'b0),.normal_stuck(1'b0),.fifo_full(fifo_full),.no_txok(no_txok),
        .can_error(can_error),.txok_delay_cycles(ack_delay),.fail_write_index(fail_write),.fail_read_index(fail_read),
        .write_count(writes),.read_count(reads),.enqueued_count(model_enqueued),.protocol_errors(model_errors),
        .reset_count(reset_count),.last_sequence(model_sequence));
    task check;
        input ok;input [8*130-1:0] label;
        begin checks=checks+1;if(ok!==1'b1) begin failures=failures+1;$display("FAIL: %0s",label);end
        else $display("PASS: %0s",label);end
    endtask
    task expect;
        input ok;input [8*130-1:0] label;
        begin if(ok!==1'b1) begin failures=failures+1;if(failures<30)$display("FAIL: %0s",label);end end
    endtask
    task reset_all;
        begin
            @(negedge clk);rst_n=0;locked=0;released=0;start_req=0;stop_req=0;
            hold_aw=0;hold_w=0;hold_b=0;hold_ar=0;hold_r=0;fifo_full=0;no_txok=0;can_error=0;
            fail_write=-1;fail_read=-1;ack_delay=5;period_sel=1;limit_sel=0;
            repeat(4) @(negedge clk);rst_n=1;locked=1;released=1;
            wait(initialized||init_error);expect(!init_error,"real CAN initialization must succeed before each TX case");
            repeat(4) @(negedge clk);
        end
    endtask
    task trigger;
        begin @(negedge clk);start_req=1;repeat(3) @(negedge clk);end
    endtask
    task wait_terminal;
        input integer max_cycles;
        integer k;
        begin k=0;while(!done&&!stopped&&scheduler_state!=5&&k<max_cycles) begin @(negedge clk);k=k+1;end
            expect(k<max_cycles,"bounded periodic terminal state");end
    endtask
    task nominal;
        input [1:0] period,limit;
        input integer count;
        integer period_cycles;
        begin
            reset_all;period_sel=period;limit_sel=limit;
            period_cycles=(period==0)?2560:(period==1)?256:128;
            trigger;
            wait_terminal(count*period_cycles+3000);
            check(done&&!tx_error&&successes==count,"normal completion reaches requested success limit");
            check(scheduled==count&&attempted==count&&enqueued==count&&missed==0,"all four successful-run counters agree, no missed deadline");
            check(sequence==count-1&&model_enqueued==count&&model_errors==0,"SEQ begins at zero and every emitted frame is checked");
            check(selected_period==period_cycles&&frame_limit==count,"period and frame limit decode correctly");
            saved_count=successes;start_req=0;repeat(5) @(negedge clk);start_req=1;
            repeat(400) @(negedge clk);
            check(successes==saved_count&&attempted==count&&round_used,"no second round without common reset; counters retained");
            $display("NOMINAL COMPLETE: period_sel=%0d count=%0d",period,count);
        end
    endtask
    always @(posedge clk) begin
        if(rst_n) begin
            expect(!((arvalid||rready)&&(awvalid||wvalid||bready)),"Reader/Sender/Init share one non-overlapping AXI transaction");
            if(awvalid&&awaddr>=32'h43C00030&&awaddr<=32'h43C0003C) expect(initialized,"no FIFO writes before initialization");
            if(previous_ar_stall) expect(arvalid&&araddr==held_ar,"ARVALID/address stable across wait");
            if(previous_aw_stall) expect(awvalid&&awaddr==held_aw,"AWVALID/address stable across wait");
            if(previous_w_stall) expect(wvalid&&wdata==held_w,"WVALID/data stable across wait");
            if(arvalid&&arready&&araddr==32'h43C0001C) begin
                if(POLL_CHECK_ONLY&&previous_isr_cycle>=0)
                    expect(cycle-previous_isr_cycle==5000,"ISR AR handshakes exactly 5000 cycles apart without backpressure");
                previous_isr_cycle=cycle;isr_reads=isr_reads+1;
            end
        end
        previous_ar_stall=rst_n&&arvalid&&!arready;held_ar=araddr;
        previous_aw_stall=rst_n&&awvalid&&!awready;held_aw=awaddr;
        previous_w_stall=rst_n&&wvalid&&!wready;held_w=wdata;
    end
    always @(negedge clk) begin
        if(!rst_n) begin
            previous_enqueues=0;previous_scheduled=0;cycle=0;previous_tick=0;
            previous_isr_cycle=-1;isr_reads=0;previous_attempts=0;first_attempt_cycle=-1;second_attempt_cycle=-1;
        end else begin
            cycle=cycle+1;
            if(scheduled!=previous_scheduled) begin
                if(previous_scheduled!=0) expect(cycle-previous_tick==selected_period,"fixed time base has no completion-time drift");
                previous_scheduled=scheduled;previous_tick=cycle;
            end
            if(attempted!=previous_attempts) begin
                if(previous_attempts==0) first_attempt_cycle=last_attempt_cycle;
                if(previous_attempts==1) second_attempt_cycle=last_attempt_cycle;
                previous_attempts=attempted;
            end
            if(model_enqueued!=previous_enqueues) begin
                expect(model_sequence==previous_enqueues,"unique monotonic sequence allocation per actual attempt");
                expect(slave.data_bytes[0]==((previous_enqueues>>24)&255)&&slave.data_bytes[1]==((previous_enqueues>>16)&255)&&
                    slave.data_bytes[2]==((previous_enqueues>>8)&255)&&slave.data_bytes[3]==(previous_enqueues&255),"CAN DATA[0..3] are SEQ big endian");
                expect(slave.data_bytes[4]==8'h11&&slave.data_bytes[5]==8'h22&&slave.data_bytes[6]==8'h33&&slave.data_bytes[7]==8'h44,"CAN DATA[4..7] fixed bytes");
                expect((((slave.id_word>>21)<<18)|((slave.id_word>>1)&32'h3FFFF))==32'h1B345678&&
                    slave.id_word[20:19]==2'b11&&!slave.id_word[0],"independent IDR decode: extended data ID 0x1B345678");
                previous_enqueues=model_enqueued;
            end
        end
    end
    initial begin
        if(LONG_TEST) begin
            nominal(1,3,360000);
        end else if(POLL_CHECK_ONLY) begin
            reset_all;no_txok=1;trigger;wait(isr_reads>=3);@(negedge clk);
            check(successes==0&&isr_reads==3,"100 us TXOK poll spacing verified across three physical AXI reads");
            stop_req=1;no_txok=0;wait_terminal(12000);
            check(stopped&&successes==1&&enqueued==1,"STOP drains pending frame with spaced TXOK polling");
        end else begin
            nominal(0,0,100);
            nominal(1,1,1000);
            nominal(2,2,2000);
            reset_all;period_sel=3;trigger;repeat(100) @(negedge clk);
            check(rejected&&attempted==0&&enqueued==0&&!round_used,"reserved period rejects start without fallback");
            period_sel=1;repeat(50) @(negedge clk);check(attempted==0,"changing configuration while start high cannot trigger");
            start_req=0;repeat(4) @(negedge clk);trigger;wait(model_enqueued==2);@(negedge clk);stop_req=1;
            wait_terminal(2000);check(stopped&&successes==2,"fresh edge starts after invalid selection; one round only");

            reset_all;trigger;period_sel=2;limit_sel=3;
            wait_terminal(30000);
            check(done&&successes==100&&selected_period==256&&frame_limit==100,"run-time configuration changes do not alter latched job");
            check(status_count>0,"background Reader progresses between Sender jobs");

            reset_all;ack_delay=600;trigger;
            wait(successes==2);@(negedge clk);stop_req=1;wait_terminal(2000);
            check(stopped&&missed>=2&&violation&&!tx_error,"busy periods are skipped and reported, not queued");
            check(scheduled==attempted+missed,"scheduled equals attempts plus missed when no request is pending");
            check((second_attempt_cycle-first_attempt_cycle)%256==0,"post-busy request stays on original time grid");

            reset_all;ack_delay=300;trigger;wait_terminal(60000);
            check(done&&successes==100&&attempted==100&&missed>0&&violation,"missed slots extend elapsed time until success limit; completion retains deadline violation");
            check(scheduled==attempted+missed,"extended run does not burst catch up or reuse skipped sequences");

            reset_all;trigger;wait(dut.tx_state==3);@(negedge clk);stop_req=1;wait_terminal(2000);
            check(stopped&&attempted==1&&enqueued==0&&errors==0,"STOP before FIFO cancels new enqueue without resetting CAN");
            check(reset_count==1,"STOP does not reinitialize or reset CAN");

            reset_all;trigger;wait(writes==8);@(negedge clk);stop_req=1;wait_terminal(2000);
            check(stopped&&enqueued==1&&successes==1&&slave.fifo_phase==0,"STOP after FIFO ID finishes atomic four-word frame");
            saved_count=writes;repeat(400) @(negedge clk);check(writes==saved_count,"STOP leaves no additional frame writes");

            reset_all;ack_delay=100;trigger;wait(model_enqueued==1);@(negedge clk);stop_req=1;
            check(successes==0,"STOP while awaiting TXOK keeps in-flight frame pending");
            wait_terminal(2000);check(stopped&&successes==1&&enqueued==1,"pending frame may finish after STOP");

            reset_all;no_txok=1;trigger;wait(model_enqueued==1);@(negedge clk);stop_req=1;wait_terminal(2000);
            check(scheduler_state==5&&errors==1&&error_code==6&&may_pending,"TXOK timeout faults once and preserves may-be-pending status");
            saved_count=writes;repeat(500) @(negedge clk);
            check(writes==saved_count&&errors==1&&sequence==0&&reset_count==1,"fault preserves sequence and never retries/reinitializes");

            reset_all;slave.isr=2;ack_delay=100;trigger;wait(model_enqueued==1);repeat(10) @(negedge clk);
            check(successes==0&&!slave.isr[1],"stale TXOK is cleared before enqueue and cannot signal early success");
            stop_req=1;wait_terminal(2000);check(successes==1,"only new TXOK completes the frame");

            reset_all;fifo_full=1;trigger;wait_terminal(2000);
            check(tx_error&&error_code==2&&enqueued==0&&errors==1,"TX FIFO full rejects attempt and enters FAULT");
            for(i=6;i<=10;i=i+1) begin
                reset_all;fail_write=i;trigger;wait_terminal(2000);
                check(tx_error&&error_code==4&&errors==1,"each ICR/FIFO BRESP error stops later commands");
            end
            reset_all;hold_ar=1;trigger;wait_terminal(2500);
            check(tx_error&&quarantined&&errors==1&&enqueued==0,"AXI AR timeout quarantines outstanding transaction");
            hold_ar=0;repeat(200) @(negedge clk);check(errors==1&&enqueued==0,"late response drains without retry after fault");
            reset_all;can_error=1;trigger;wait_terminal(2000);
            check(tx_error&&errors==1&&error_code==8&&last_isr[8],"CAN ERROR event takes priority over TXOK and stops job");

            reset_all;trigger;wait(dut.tx_state==8);@(negedge clk);fail_read=reads;
            // Force the next ISR access to report RRESP without altering RX data.
            wait_terminal(2000);check(tx_error&&errors==1&&error_code==3,"ISR RRESP failure faults periodic job");

            @(negedge clk);rst_n=0;start_req=1;stop_req=0;can_error=0;repeat(4) @(negedge clk);
            rst_n=1;locked=1;released=1;wait(initialized);repeat(150) @(negedge clk);
            check(attempted==0&&enqueued==0,"start high across reset/init cannot auto-run");
            start_req=0;repeat(4) @(negedge clk);trigger;wait(model_enqueued==1);@(negedge clk);stop_req=1;
            wait_terminal(2000);check(stopped&&successes==1,"fresh low then edge works after full reset and initialization");
        end
        if(failures==0) $display("RESULT: PASS PERIODIC_TX long=%0d poll_only=%0d (%0d checks)",LONG_TEST,POLL_CHECK_ONLY,checks);
        else $display("RESULT: FAIL PERIODIC_TX (%0d failures)",failures);
        $finish;
    end
    initial begin #(64'd3000000000);$display("FAIL: periodic simulation guard timeout");$finish;end
endmodule

module tb_can_periodic_tx_long;
    tb_can_periodic_tx #(.LONG_TEST(1)) test();
endmodule
module tb_can_periodic_tx_poll;
    tb_can_periodic_tx #(.POLL_CHECK_ONLY(1)) test();
endmodule
