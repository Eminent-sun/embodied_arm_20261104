`timescale 1ns / 1ps
module tb_pp_commissioning;
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
    pl_robstride_command_engine #(.ENABLE_PP_TEST(1),.PP_WINDOW_CYCLES(300),
        .PP_POSITION_AGE_CYCLES(600),.REG_TIMEOUT_CYCLES(30),
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

    task fresh;
        begin
            rst_n=0;start=0;byte_reserved=0;stream_integrity_lost=0;
            param_reply_valid=0;status_event_valid=0;tx_done=0;tx_success=0;
            tx_req_ready=1;motor_id=5;command_reserved=0;value_reserved=0;
            repeat(3) @(negedge clk);rst_n=1;
            repeat(3) @(negedge clk);
        end
    endtask
    task read_value;
        input [15:0] idx;
        input [31:0] val;
        begin
            cmd_op=0;parameter_index=idx;parameter_value=0;
            launch();complete_tx(1);deliver_reply(val);
            repeat(2) @(negedge clk);
            check(command_success && result_value==val,"verified parameter read");
        end
    endtask
    task write_value;
        input [2:0] op;
        input [15:0] idx;
        input [31:0] val;
        begin
            cmd_op=op;parameter_index=idx;parameter_value=val;
            launch();wait_state(3);
            check(tx_can_id==29'h1200FD05 && tx_can_data=={val,16'd0,idx},"write frame byte/type encoding");
            complete_tx(1);wait_state(6);
            status_event_valid=1;
            @(negedge clk);status_event_valid=0;
            wait_state(3);complete_tx(1);deliver_reply(val);
            repeat(2) @(negedge clk);
            check(command_success,"write requires verified readback");
        end
    endtask
    task prepare;
        begin
            read_value(16'h7005,1);
            read_value(16'h7019,32'h3F800000);
            write_value(1,16'h7024,32'h3F000000);
            write_value(1,16'h7025,32'h3F000000);
            write_value(1,16'h7016,32'h3F800000);
        end
    endtask
    task enable_motor;
        begin
            cmd_op=3;parameter_index=0;parameter_value=32'h50505431;
            launch();wait_state(3);
            check(tx_can_id==29'h0300FD05 && tx_can_data==0,"enable after complete admission");
            complete_tx(1);wait_state(6);
            status_event_valid=1;
            @(negedge clk);status_event_valid=0;
            repeat(2) @(negedge clk);
            check(command_success && !command_busy,"enable consumes addressed status");
        end
    endtask
    task stop_result;
        begin
            wait_state(11);
            check(tx_can_id==29'h0400FD05 && tx_can_data==0,"ordinary disable never clears errors");
            wait_state(12);
            tx_done=1;tx_success=1;
            @(negedge clk);tx_done=0;tx_success=0;
            repeat(2) @(negedge clk);
        end
    endtask
    integer n;
    initial begin
        fresh();
        cmd_op=3;parameter_index=0;parameter_value=32'h50505431;
        launch();check(command_error && tx_count==0,"unprepared enable blocked");
        cmd_op=2;parameter_index=16'h7005;parameter_value=2;
        launch();check(command_error && tx_count==0,"mode write limited to PP one-byte value");
        cmd_op=2;motor_id=1;parameter_value=1;
        launch();check(command_error && tx_count==0,"new actuation operations limited to ID5");
        motor_id=5;
        write_value(2,16'h7005,1);
        read_value(16'h7019,32'hBF800000);
        cmd_op=1;parameter_index=16'h7016;parameter_value=32'h7FC00000;
        before_tx=tx_count;launch();check(command_error && tx_count==before_tx,"NaN target rejected without TX");
        parameter_value=32'h3F800000;launch();check(command_error && tx_count==before_tx,"two-radian displacement rejected");
        write_value(1,16'h7016,32'hBF000000);
        cmd_op=3;parameter_index=0;parameter_value=32'h50505431;
        launch();check(command_error,"off-current preload cannot arm motor");

        fresh();prepare();enable_motor();
        write_value(1,16'h7016,32'h3FC00000);
        before_tx=tx_count;cmd_op=1;parameter_index=16'h7016;parameter_value=32'h3FA00000;
        launch();check(command_error && tx_count==before_tx,"second moving target blocked");
        n=0;
        while(command_state!=11 && n<350) begin @(negedge clk);n=n+1;end
        check(command_state==11,"five-second hardware window expires independently of host");
        stop_result();check(fault_locked && command_error_code==8'hE1,"watchdog completion locks further actuation");
        before_tx=tx_count;repeat(20) @(negedge clk);
        check(tx_count==before_tx,"watchdog has no repeated stop or enable loop");

        fresh();prepare();enable_motor();
        cmd_op=0;parameter_index=16'h7019;parameter_value=0;
        launch();complete_tx(1);wait_state(5);
        byte_reserved=8'hA5;stop_result();
        check(fault_locked && command_error_code==8'hE0,"manual stop preempts parameter reply wait");
        before_tx=tx_count;repeat(20) @(negedge clk);
        check(tx_count==before_tx,"held stop marker is not retransmitted");

        fresh();prepare();enable_motor();
        cmd_op=0;parameter_index=16'h7019;parameter_value=0;
        launch();wait_state(4);tx_req_ready=0;byte_reserved=8'hA5;
        repeat(5) @(negedge clk);
        check(command_state==10 && !tx_req_valid,"stop drains an accepted in-flight frame");
        tx_done=1;tx_success=1;@(negedge clk);tx_done=0;tx_success=0;tx_req_ready=1;
        stop_result();check(fault_locked,"drained transaction followed by one disable");

        fresh();prepare();enable_motor();stream_integrity_lost=1;
        stop_result();check(fault_locked,"RX integrity loss takes disable path without clearing protection");

        fresh();prepare();repeat(610) @(negedge clk);
        cmd_op=3;parameter_index=0;parameter_value=32'h50505431;
        before_tx=tx_count;launch();check(command_error && tx_count==before_tx,"stale position blocks enable");

        fresh();byte_reserved=8'hA5;tx_req_ready=0;
        repeat(40) @(negedge clk);
        check(fault_locked && command_error_code==8'hE2,"unavailable Master reports disable failure");
        before_tx=tx_count;repeat(20) @(negedge clk);
        check(tx_count==before_tx,"failed disable does not retry indefinitely");

        fresh();cmd_op=4;parameter_index=0;parameter_value=0;
        launch();stop_result();check(command_success && command_state==0,"explicit ordinary stop is available before arming");
        $display("PASS ALL %0d PP CHECKS",checks);$finish;
    end
    initial begin #1000000;$fatal(1,"PP global timeout");end
endmodule
