`timescale 1ns / 1ps
// Actual default hardware counts, separate from accelerated frame-count tests.
module tb_can_scheduler_long;
    reg clk=0,rst_n=0,start_req=0,stop_req=0;
    reg [1:0] period_sel=0;
    reg [31:0] successes=0;
    wire send_request,done,stopped;
    wire [31:0] attempted,period_value,frame_limit;
    integer cycle=0,first_cycle=0,second_cycle=0,previous_attempted=0,i,failures=0,checks=0;
    integer expected_period;
    always #10 clk=~clk;
    pl_can_scheduler dut(.clk(clk),.rst_n(rst_n),.enable(1'b1),.ready(1'b1),
        .start_req(start_req),.stop_req(stop_req),.period_sel(period_sel),.limit_sel(2'b00),
        .sender_busy(1'b0),.sender_fault(1'b0),.send_accept(send_request),.tx_success_count(successes),
        .send_request(send_request),.attempted_count(attempted),.latched_period(period_value),
        .frame_limit(frame_limit),.completed(done),.stopped(stopped));
    always @(posedge clk) begin
        if(!rst_n) successes<=0;
        else if(send_request) successes<=successes+1;
    end
    always @(negedge clk) begin
        if(!rst_n) begin cycle=0;first_cycle=0;second_cycle=0;previous_attempted=0;end
        else begin
            cycle=cycle+1;
            if(attempted!=previous_attempted) begin
                if(previous_attempted==0) first_cycle=cycle;
                if(previous_attempted==1) second_cycle=cycle;
                previous_attempted=attempted;
            end
        end
    end
    task check;
        input ok;input [8*90-1:0] label;
        begin checks=checks+1;if(ok!==1'b1) begin failures=failures+1;$display("FAIL: %0s",label);end
        else $display("PASS: %0s",label);end
    endtask
    initial begin
        for(i=0;i<3;i=i+1) begin
            @(posedge clk);#1;rst_n=0;start_req=0;stop_req=0;period_sel=i;
            repeat(4) @(posedge clk);#1;rst_n=1;
            repeat(4) @(posedge clk);#1;start_req=1;
            wait(attempted==2);@(posedge clk);#1;
            expected_period=(i==0)?5000000:(i==1)?500000:250000;
            check(period_value==expected_period,"hardware default selection uses exact 50 MHz count");
            check(second_cycle-first_cycle==expected_period,"two actual hardware timer events have exact requested spacing");
            stop_req=1;wait(stopped);#1;
            check(attempted==2&&frame_limit==100,"STOP retains default-limit timer counters");
            $display("DEFAULT PERIOD VERIFIED: selector=%0d clocks=%0d",i,second_cycle-first_cycle);
        end
        if(!failures)$display("RESULT: PASS DEFAULT_PERIODS (%0d checks)",checks);
        else $display("RESULT: FAIL DEFAULT_PERIODS");
        $finish;
    end
    initial begin #(64'd1000000000);$display("FAIL: default period guard timeout");$finish;end
endmodule
