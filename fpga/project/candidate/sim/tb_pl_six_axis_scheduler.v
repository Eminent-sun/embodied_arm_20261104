`timescale 1ns / 1ps
// Exact deadline-edge tests independent of CAN/AXI transport latency.
module tb_pl_six_axis_scheduler;
    localparam integer PERIOD=64;
    reg clk=0,rst_n=0,ready=0,start_req=0,stop_req=0;
    reg busy=0,sender_fault=0,accept=0;
    reg [1:0] period_sel=1,limit_sel=0;
    reg [31:0] successes=0,now=0,ack_tick=0;
    wire request,completed,stopped,fault,halt,used,rejected;
    wire [31:0] seq,started,finished,attempts,missed,maxspan,limit,period;
    wire [2:0] axis,state;
    integer checks=0,failures=0,i,saved;
    always #10 clk=~clk;
    always @(posedge clk) if(!rst_n) now<=0;else now<=now+1;
    pl_six_axis_scheduler #(.PERIOD_CYCLES(PERIOD)) dut(
        .clk(clk),.rst_n(rst_n),.enable(1'b1),.ready(ready),.start_req(start_req),.stop_req(stop_req),
        .period_sel(period_sel),.limit_sel(limit_sel),.sender_busy(busy),.sender_fault(sender_fault),
        .send_accept(accept),.tx_success_count(successes),.time_now(now),.tx_completed_cycle(ack_tick),
        .send_request(request),.cycle_seq(seq),.axis_index(axis),.cycle_started_count(started),
        .cycle_completed_count(finished),.attempted_count(attempts),.missed_cycle_count(missed),
        .max_cycle_span_cycles(maxspan),.cycle_limit(limit),.selected_period(period),.state(state),
        .round_used(used),.start_rejected(rejected),.scheduler_fault(fault),.completed(completed),.stopped(stopped),.halt_new_frames(halt));
    task check;
        input ok;input [8*130-1:0] label;
        begin checks=checks+1;if(ok!==1'b1) begin failures=failures+1;$display("FAIL: %0s",label);end
        else $display("PASS: %0s",label);end
    endtask
    task reset_start;
        begin
            @(negedge clk);rst_n=0;ready=0;start_req=0;stop_req=0;busy=0;sender_fault=0;accept=0;successes=0;
            period_sel=1;limit_sel=0;repeat(3) @(negedge clk);rst_n=1;ready=1;
            repeat(3) @(negedge clk);start_req=1;@(negedge clk);
            check(used&&started==1&&seq==0&&axis==0,"first cycle at t0; one-shot armed by low then rising edge");
        end
    endtask
    task accept_frame;
        begin
            while(!request) @(negedge clk);
            accept=1;busy=1;@(negedge clk);accept=0;
        end
    endtask
    task ack_frame;
        begin successes=successes+1;ack_tick=now-1;busy=0;@(negedge clk);end
    endtask
    initial begin
        reset_start;
        for(i=0;i<5;i=i+1) begin accept_frame;ack_frame;end
        accept_frame;
        while(dut.period_counter<PERIOD-2) @(negedge clk);
        ack_frame;
        check(finished==1&&!fault,"sixth TXOK observed one edge before next period completes current cycle");
        @(negedge clk);
        check(started==2&&seq==1&&axis==0&&!fault,"next cycle starts on original fixed grid, no completion-time drift");

        reset_start;
        for(i=0;i<5;i=i+1) begin accept_frame;ack_frame;end
        accept_frame;
        while(dut.period_counter<PERIOD-1) @(negedge clk);
        ack_frame;
        check(finished==1&&started==2&&seq==1&&!fault&&missed==0,
            "previous-edge TXOK observed on boundary completes old cycle and starts next fixed slot");

        reset_start;
        for(i=0;i<5;i=i+1) begin accept_frame;ack_frame;end
        accept_frame;
        while(dut.period_counter<PERIOD-1) @(negedge clk);
        check(halt&&!fault,"deadline combinational gate active before boundary acceptance edge");
        @(posedge clk);#1;successes=successes+1;ack_tick=now-1;busy=0;
        @(negedge clk);
        check(fault&&missed==1&&finished==0&&started==1,"TXOK on deadline edge is too late; strict before-deadline requirement");
        repeat(PERIOD*2) @(negedge clk);
        check(fault&&missed==1&&seq==0&&!request,"late TXOK cannot clear FAULT or advance cycle sequence");

        reset_start;
        for(i=0;i<5;i=i+1) begin accept_frame;ack_frame;end
        while(dut.period_counter<PERIOD-1) @(negedge clk);
        check(request&&halt,"pending sixth-frame request is blocked on unfinished-cycle boundary");
        @(negedge clk);check(fault&&!request&&attempts==5,"deadline cancels unsent request and does not create another attempt");

        reset_start;accept_frame;stop_req=1;repeat(3) @(negedge clk);
        check(state==3&&!request&&!stopped,"STOP waits for already accepted Sender work");
        ack_frame;repeat(2) @(negedge clk);
        check(stopped&&started==1&&finished==0&&attempts==1,"STOP preserves partial-cycle counts");
        saved=attempts;start_req=0;repeat(3) @(negedge clk);start_req=1;
        repeat(PERIOD*2) @(negedge clk);check(stopped&&attempts==saved,"STOP is terminal until reset");

        reset_start;accept_frame;sender_fault=1;@(negedge clk);
        check(fault&&missed==0&&!request,"Sender fault stops requests without miscounting a missed period");
        sender_fault=0;ready=1;repeat(PERIOD) @(negedge clk);
        check(fault&&!request&&started==1,"Sender recovery cannot automatically resume a failed round");

        reset_start;ready=0;@(negedge clk);
        check(fault&&!request,"loss of initialization readiness during job faults scheduling");
        if(failures==0)$display("RESULT: PASS SIX_AXIS_BOUNDARY (%0d checks)",checks);
        else $display("RESULT: FAIL SIX_AXIS_BOUNDARY failures=%0d",failures);
        $finish;
    end
    initial begin #1000000;$display("RESULT: FAIL SIX_AXIS_BOUNDARY watchdog");$finish;end
endmodule
