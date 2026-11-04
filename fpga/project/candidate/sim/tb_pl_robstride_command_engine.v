`timescale 1ns / 1ps
module tb_pl_robstride_command_engine;
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
    initial begin
        repeat(3) @(negedge clk);rst_n=1;
        legacy=1;launch();wait_state(3);
        check(register_count==1 && param_req_index==16'h7005 &&
            tx_can_id==29'h1100FD05 && tx_can_data==64'h7005,
            "legacy safe read registers before TX");
        complete_tx(1);deliver_reply(32'h2);
        repeat(2) @(negedge clk);
        check(command_success && result_value==2,"legacy read reply completes");
        legacy=0;rst_n=0;repeat(3) @(negedge clk);rst_n=1;

        launch();wait_state(3);
        check(tx_can_id==29'h1100FD05 && tx_can_dlc==8 &&
            tx_can_data==64'h0000000000007019,"read frame fields");
        check(register_count==1 && param_req_host==8'hFD &&
            param_req_motor==5 && param_req_index==16'h7019,"read registered before TX");
        complete_tx(1);
        check(!command_success,"TXOK is not read success");
        deliver_reply(32'h3F800000);
        repeat(2) @(negedge clk);
        check(command_done && command_success && result_value==32'h3F800000,"read reply success");

        cmd_op=1;parameter_index=16'h7024;parameter_value=32'h40000000;
        launch();wait_state(3);
        check(tx_can_id==29'h1200FD05 && tx_can_data==64'h4000000000007024,
            "write frame fields");
        complete_tx(1);wait_state(6);
        check(!command_success,"TXOK is not write success");
        @(negedge clk);status_event_valid=1;
        @(negedge clk);status_event_valid=0;
        wait_state(3);
        check(tx_can_id==29'h1100FD05 && tx_can_data==64'h0000000000007024,
            "write readback frame");
        complete_tx(1);deliver_reply(32'h40000000);
        repeat(2) @(negedge clk);
        check(command_done && command_success && result_value==32'h40000000,
            "write verified by readback");

        reject_next=1;before_tx=tx_count;
        launch();wait_state(3);complete_tx(1);wait_state(6);
        @(negedge clk);status_event_valid=1;
        @(negedge clk);status_event_valid=0;
        repeat(4) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h05 &&
            fault_locked && tx_count==before_tx+1,
            "readback registration refusal locks after possible write");
        reject_next=0;
        rst_n=0;repeat(3) @(negedge clk);rst_n=1;
        repeat(2) @(negedge clk);

        launch();wait_state(3);complete_tx(1);wait_state(6);
        @(negedge clk);status_event_valid=1;
        @(negedge clk);status_event_valid=0;
        wait_state(3);complete_tx(1);deliver_reply(32'h00000000);
        repeat(2) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h41,
            "write mismatch rejected");
        check(fault_locked,"write mismatch locks until reset");
        rst_n=0;repeat(3) @(negedge clk);rst_n=1;
        repeat(2) @(negedge clk);

        cmd_op=0;parameter_index=0;
        launch();repeat(2) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h02,
            "illegal index rejected");
        motor_id=0;parameter_index=16'h7019;
        launch();repeat(2) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h01,
            "illegal motor rejected");
        motor_id=5;cmd_op=2;
        launch();repeat(2) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h02,
            "unsupported operation rejected");
        cmd_op=1;parameter_index=16'h7005;
        launch();repeat(2) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h02,
            "uint8 run mode rejected for float write");
        parameter_index=16'h7016;
        launch();repeat(2) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h02,
            "direct position reference rejected for float write");
        parameter_index=16'h700A;
        launch();repeat(2) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h02,
            "direct speed reference rejected for float write");
        parameter_index=16'h7006;
        launch();repeat(2) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h02,
            "direct current reference rejected for float write");
        cmd_op=0;parameter_index=16'h7019;
        reject_next=1;before_tx=tx_count;
        launch();repeat(3) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h05 &&
            tx_count==before_tx,"registration refusal blocks CAN TX");
        reject_next=0;

        before_tx=tx_count;tx_req_ready=0;
        launch();wait_state(3);repeat(5) @(negedge clk);
        check(tx_count==before_tx && tx_req_valid,"TX ready backpressure");
        tx_req_ready=1;wait_state(4);
        check(tx_count==before_tx+1,"exactly one TX accepted");
        complete_tx(1);deliver_reply(32'h12345678);
        repeat(2) @(negedge clk);
        check(command_success && result_value==32'h12345678,"backpressured read completes");

        before_tx=tx_count;
        launch();wait_state(4);
        @(negedge clk);tx_done=1;tx_success=0;tx_error_code=8'h04;
        tx_may_have_submitted=1;
        @(negedge clk);tx_done=0;tx_error_code=0;
        repeat(5) @(negedge clk);
        check(command_done && command_error && fault_locked &&
            command_error_code==8'h24 && param_poisoned[4],
            "uncertain TX failure locks and poisons read transaction");
        check(tx_count==before_tx+1,"fault does not retry");

        rst_n=0;repeat(3) @(negedge clk);rst_n=1;
        repeat(2) @(negedge clk);
        check(command_state==0 && !fault_locked && !param_poisoned[4],
            "reset releases local lock and bank model poison");
        cmd_op=0;parameter_index=16'h7019;
        launch();wait_state(4);complete_tx(1);deliver_reply(32'h11111111);
        repeat(2) @(negedge clk);
        check(command_success,"read works after reset");

        cmd_op=1;parameter_index=16'h7024;
        launch();wait_state(4);complete_tx(1);wait_state(6);
        repeat(43) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h33 &&
            fault_locked,"write acknowledgement timeout locks");

        rst_n=0;repeat(3) @(negedge clk);rst_n=1;
        repeat(2) @(negedge clk);
        cmd_op=0;parameter_index=16'h7019;
        launch();wait_state(4);complete_tx(1);wait_state(5);
        repeat(45) @(negedge clk);
        check(command_done && command_error && command_error_code==8'h42 &&
            fault_locked && param_poisoned[4],"read reply timeout poisons");
        $display("PASS ALL %0d CHECKS",checks);$finish;
    end
    initial begin #100000;$display("FAIL global timeout");$fatal(1);end
endmodule
