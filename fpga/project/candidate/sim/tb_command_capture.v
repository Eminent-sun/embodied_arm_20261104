`timescale 1ns / 1ps
module tb_command_capture;
    reg clk=0;
    always #10 clk=~clk;
    reg rst_n=0,start=0;
    reg [7:0] motor_id=5;
    reg [2:0] cmd_op=0;
    reg [15:0] parameter_index=16'h7019;
    reg [31:0] parameter_value=32'h3F800000;
    reg [1:0] command_reserved=0;
    reg [7:0] byte_reserved=0;
    reg [31:0] value_reserved=0;
    reg mapping_valid=1,stream_integrity_lost=0;
    reg [5:0] param_pending=0,param_poisoned=0;
    wire param_req_valid,param_req_host_unused;
    reg param_req_ready=1,param_req_rejected=0,param_req_active=0;
    wire [7:0] param_req_host,param_req_motor;
    wire [15:0] param_req_index;
    wire [31:0] param_req_token;
    wire param_cancel_valid,param_cancel_poison;
    reg param_cancel_ready=1,param_cancel_done=0,param_cancel_matched=1;
    wire [7:0] param_cancel_motor;
    wire [15:0] param_cancel_index;
    wire [31:0] param_cancel_token;
    reg param_reply_valid=0,param_reply_failed=0;
    reg [2:0] param_reply_axis=4;
    reg [15:0] param_reply_index=0;
    reg [31:0] param_reply_bits=0,param_reply_token=0;
    reg status_event_valid=0;
    reg [7:0] status_event_motor=5;
    reg [5:0] status_event_error=0;
    wire tx_req_valid;
    reg tx_req_ready=1;
    wire [28:0] tx_can_id;
    wire [7:0] tx_can_dlc;
    wire [63:0] tx_can_data;
    reg tx_done=0,tx_success=0,tx_may_have_submitted=0;
    reg [7:0] tx_error_code=0;
    wire command_busy,fault_locked,command_done,command_success,command_error;
    wire [7:0] command_error_code;
    wire [31:0] result_value;
    wire [3:0] command_state;
    wire command_start_accepted,command_param_registered,command_rejected;
    reg legacy=0;
    integer checks=0, tx_count=0, register_count=0, before_tx=0;
    reg reject_next=0;
    pl_robstride_command_engine #(.REG_TIMEOUT_CYCLES(30),
        .TX_ACCEPT_TIMEOUT_CYCLES(30),.TX_RESULT_TIMEOUT_CYCLES(40),
        .REPLY_TIMEOUT_CYCLES(40),.CANCEL_TIMEOUT_CYCLES(30)) dut(
        .clk(clk),.rst_n(rst_n),.start(start),
        .command_word(legacy ? 29'h1100FD05 : {command_reserved,parameter_index,cmd_op,motor_id}),
        .byte_reserved(legacy ? 8'd8 : byte_reserved),
        .command_value_word(legacy ? 64'h7005 : {value_reserved,parameter_value}),.mapping_valid(mapping_valid),
        .stream_integrity_lost(stream_integrity_lost),.param_pending(param_pending),
        .param_poisoned(param_poisoned),.param_req_valid(param_req_valid),
        .param_req_ready(param_req_ready),.param_req_rejected(param_req_rejected),
        .param_req_active(param_req_active),.param_req_host(param_req_host),
        .param_req_motor(param_req_motor),.param_req_index(param_req_index),
        .param_req_token(param_req_token),.param_cancel_valid(param_cancel_valid),
        .param_cancel_ready(param_cancel_ready),.param_cancel_done(param_cancel_done),
        .param_cancel_matched(param_cancel_matched),.param_cancel_motor(param_cancel_motor),
        .param_cancel_index(param_cancel_index),.param_cancel_token(param_cancel_token),
        .param_cancel_poison(param_cancel_poison),.param_reply_valid(param_reply_valid),
        .param_reply_failed(param_reply_failed),.param_reply_axis(param_reply_axis),
        .param_reply_index(param_reply_index),.param_reply_bits(param_reply_bits),
        .param_reply_token(param_reply_token),.status_event_valid(status_event_valid),
        .status_event_motor(status_event_motor),.status_event_error(status_event_error),
        .tx_req_valid(tx_req_valid),.tx_req_ready(tx_req_ready),
        .tx_can_id(tx_can_id),.tx_can_dlc(tx_can_dlc),.tx_can_data(tx_can_data),
        .tx_done(tx_done),.tx_success(tx_success),
        .tx_may_have_submitted(tx_may_have_submitted),.tx_error_code(tx_error_code),
        .command_busy(command_busy),.fault_locked(fault_locked),
        .command_done(command_done),.command_success(command_success),
        .command_error(command_error),.command_error_code(command_error_code),
        .result_value(result_value),.command_state(command_state),
        .command_start_accepted(command_start_accepted),
        .command_param_registered(command_param_registered),
        .command_rejected(command_rejected));
    always @(posedge clk) begin
        param_req_rejected<=0;param_cancel_done<=0;
        if(!rst_n) begin
            param_req_active<=0;param_pending<=0;param_poisoned<=0;
            tx_count<=0;register_count<=0;
        end else begin
            if(param_req_valid && param_req_ready) begin
                register_count<=register_count+1;
                if(reject_next) param_req_rejected<=1;
                else begin param_req_active<=1;param_pending[4]<=1;end
            end
            if(param_cancel_valid && param_cancel_ready) begin
                param_cancel_done<=1;param_req_active<=0;param_pending[4]<=0;
                if(param_cancel_poison) param_poisoned[4]<=1;
            end
            if(param_reply_valid) begin param_req_active<=0;param_pending[4]<=0;end
            if(tx_req_valid && tx_req_ready) tx_count<=tx_count+1;
        end
    end
    task check;
        input condition;
        input [255:0] name;
        begin
            if(condition !== 1'b1) begin
                $display("FAIL %0s at %0t state=%0d code=%h",name,$time,command_state,command_error_code);
                $fatal(1);$finish;
            end else begin
                checks=checks+1;$display("PASS %0s",name);
            end
        end
    endtask
    task launch;
        begin
            @(negedge clk);start=0;
            repeat(2) @(negedge clk);
            start=1;
            @(negedge clk);start=0;
        end
    endtask
    task wait_state;
        input [3:0] wanted;
        integer n;
        begin
            n=0;
            while(command_state!=wanted && n<100) begin @(negedge clk);n=n+1;end
            if(command_state!=wanted) begin
                $display("FAIL wait_state %0d got %0d",wanted,command_state);
                $fatal(1);$finish;
            end
        end
    endtask
    task complete_tx;
        input good;
        begin
            wait_state(4);
            @(negedge clk);tx_done=1;tx_success=good;
            tx_may_have_submitted=1;
            @(negedge clk);tx_done=0;tx_success=0;
        end
    endtask
    task deliver_reply;
        input [31:0] value;
        begin
            wait_state(5);
            @(negedge clk);param_reply_valid=1;param_reply_token=param_req_token;
            param_reply_index=param_req_index;param_reply_bits=value;
            @(negedge clk);param_reply_valid=0;
        end
    endtask
    integer edges=0;
    reg prior_done=0;
    always @(posedge clk) begin
        if (!rst_n) begin prior_done<=0; edges<=0; end
        else begin
            prior_done<=command_done;
            if(command_done && !prior_done) edges<=edges+1;
        end
    end
    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        repeat(3) @(negedge clk);
        parameter_index=16'h7005; parameter_value=0;
        launch(); wait_state(4);
        check(!command_done && !command_success,"new read clears held status");
        complete_tx(1); deliver_reply(32'h0); repeat(4) @(negedge clk);
        check(command_done && command_success && !command_error,"first read completed");
        repeat(1500) @(negedge clk);
        check(command_done && command_success && !command_error && edges==1,
            "done held beyond 1024 samples, no repeated edge");
        check(!command_start_accepted && !param_req_valid && !param_reply_valid,
            "event probes low while done held high");
        launch(); wait_state(4);
        check(!command_done && !command_success,"second read clears old result");
        complete_tx(1); deliver_reply(32'hA5A55A5A); repeat(4) @(negedge clk);
        check(command_done && command_success && result_value==32'hA5A55A5A && edges==2,
            "new rising done distinguishes second transaction");
        repeat(1100) @(negedge clk);
        check(edges==2 && command_done,"held completion does not retrigger rising edge");
        check(tx_count==2,"exactly two parameter reads, no auto retry");
        stream_integrity_lost=1;
        @(negedge clk); start=1;
        #1; check(command_rejected && !command_start_accepted,
            "immediate reject is separate trigger event");
        @(negedge clk); start=0;
        repeat(3) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h03 && edges==2 && tx_count==2,
            "reject holds done high without edge or CAN TX");
        $display("PASS ALL 10 CAPTURE CHECKS"); $finish;
    end
    initial begin #200000;$display("FAIL global timeout");$fatal(1);end
endmodule
