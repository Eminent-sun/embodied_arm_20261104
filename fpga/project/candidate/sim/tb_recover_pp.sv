`timescale 1ns / 1ps
module tb_recover_pp;
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
    pl_robstride_command_engine #(.ENABLE_PATH_PP(1),.PATH_LEASE_CYCLES(20000),.PATH_POSITION_AGE_CYCLES(30000),.PATH_WINDOW_CYCLES(100000),.ENABLE_PP_TEST(1),.ENABLE_MULTI_PP(1),.PP_MAX_DELTA_Q16(824442),.PP_MAX_SPEED_BITS(32'h404CCCCD),.PP_MAX_ACCEL_BITS(32'h404CCCCD),.PP_WINDOW_CYCLES(100000),
        .PP_POSITION_AGE_CYCLES(1000000),.REG_TIMEOUT_CYCLES(30),
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
                else begin param_req_active<=1;param_pending[param_req_motor-1]<=1;end
            end
            if(param_cancel_valid && param_cancel_ready) begin
                param_cancel_done<=1;param_req_active<=0;param_pending[param_cancel_motor-1]<=0;
                if(param_cancel_poison) param_poisoned[param_cancel_motor-1]<=1;
            end
            if(param_reply_valid) begin param_req_active<=0;param_pending[param_req_motor-1]<=0;end
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
            param_reply_index=param_req_index;param_reply_bits=value;param_reply_axis=param_req_motor-1;
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
            check(tx_can_id=={5'h12,8'h00,8'hFD,motor_id} && tx_can_data=={val,16'd0,idx},"write frame byte/type encoding");
            complete_tx(1);wait_state(6);
            status_event_motor=motor_id;status_event_valid=1;
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
            write_value(1,16'h7024,32'h40490FDB);
            write_value(1,16'h7025,32'h40490FDB);
            write_value(1,16'h7016,32'h3F800000);
        end
    endtask
    task enable_motor;
        begin
            cmd_op=3;parameter_index=0;parameter_value=32'h50505431;
            launch();wait_state(3);
            check(tx_can_id=={5'h03,8'h00,8'hFD,motor_id} && tx_can_data==0,"enable after complete admission");
            complete_tx(1);wait_state(6);
            status_event_motor=motor_id;status_event_valid=1;
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
    task quantized_write;
        input [15:0] idx;
        input [31:0] requested,actual;
        begin
            cmd_op=1;parameter_index=idx;parameter_value=requested;
            launch();wait_state(3);complete_tx(1);wait_state(6);
            status_event_motor=motor_id;status_event_valid=1;
            @(negedge clk);status_event_valid=0;
            wait_state(3);complete_tx(1);deliver_reply(actual);repeat(2) @(negedge clk);
        end
    endtask
    reg [31:0] targets[0:5];
    integer axis, baseline;
    task stage_one;
        input [31:0] value;
        begin
            cmd_op=5;parameter_index=16'h7016;parameter_value=value;
            baseline=tx_count;launch();check(!command_done,"local stage clears stale done before fresh completion");repeat(2) @(negedge clk);
            check(command_success && tx_count==baseline,"stage stores target without bus writes");
        end
    endtask
    task prepare_six;
        begin
            for(axis=0;axis<6;axis=axis+1) begin
                motor_id=axis+1;prepare();stage_one(targets[axis]);
            end
            check(dut.staged_mask==6'h3F && dut.mode_mask==6'h3F && dut.preload_mask==6'h3F,"six separate preparation caches");
        end
    endtask
    task commit_six;
        begin
            cmd_op=6;motor_id=1;parameter_index=0;parameter_value=32'h53495831;
            launch();
        end
    endtask
    task six_stops;
        integer k;
        begin
            for(k=0;k<6;k=k+1) begin
                tx_req_ready=1;wait_state(11);
                check(tx_can_id=={5'h04,8'h00,8'hFD,8'(k+1)} && tx_can_data==0,"stop addresses each configured motor");
                wait_state(12);tx_done=1;tx_success=1;
                @(negedge clk);tx_done=0;tx_success=0;
            end
            repeat(2) @(negedge clk);
        end
    endtask
    task arm_path;
        begin
            cmd_op=7;motor_id=1;parameter_index=0;parameter_value=32'h54524A31;
            baseline=tx_count;launch();repeat(2) @(negedge clk);
            check(command_success && dut.path_mode && dut.path_sequence==0 && tx_count==baseline,"explicit path arm is local and clears readiness");
        end
    endtask
    task path_commit;
        input [31:0] sequence_value;
        begin
            cmd_op=7;motor_id=1;parameter_index=1;parameter_value=sequence_value;launch();
        end
    endtask
    task finish_batch;
        input [31:0] expected_sequence;
        integer k;
        begin
            for(k=0;k<6;k=k+1) begin
                wait_state(3);
                check(tx_can_id=={5'h12,8'h00,8'hFD,8'(k+1)} && tx_can_data=={targets[k],16'd0,16'h7016},"path batch retains six independent addressed targets");
                tx_req_ready=1;
                complete_tx(1);wait_state(6);status_event_motor=k+1;status_event_valid=1;
                @(negedge clk);status_event_valid=0;
                wait_state(3);complete_tx(1);tx_req_ready=0;deliver_reply(targets[k]);repeat(2) @(negedge clk);
                if(k<5) check(!command_done,"path group completion cannot precede sixth readback");
            end
            tx_req_ready=1;
            check(command_success && result_value==expected_sequence && dut.path_sequence==expected_sequence && dut.active_mask==6'h3F,"verified group publishes exactly its sequence while enabled");
        end
    endtask
    task ready_path;
        begin
            fresh();arm_path();prepare_six();
            for(axis=0;axis<6;axis=axis+1) begin motor_id=axis+1;enable_motor();end
        end
    endtask
    reg [31:0] job_ticks_before;
    always @(posedge clk) if(rst_n && dut.watchdog_stop && !dut.in_stop)
        $display("PATH_STOP_DIAG st=%0d err=%h active=%h agesok=%b ticks=%0d lease=%0d reject=%b last=%h requested=%h reply=%h",command_state,command_error_code,dut.active_mask,dut.path_positions_fresh,dut.actuation_ticks,dut.path_lease_ticks,command_rejected,dut.path_last_targets[dut.latched_axis],dut.latched_value,dut.verified_bits);
    task marker(input [7:0] value);
        @(negedge clk);byte_reserved=value;
        @(negedge clk);byte_reserved=0;
    endtask
    task locked_stop;
        fresh();marker(8'hA5);six_stops();
        check(fault_locked && command_error_code==8'hE0,"manual stop locks until explicit recovery");
    endtask
    initial begin
        locked_stop();baseline=tx_count;
        marker(8'h5A);six_stops();
        check(!fault_locked && command_success && tx_count==baseline+6,"recovery emits six disables and returns idle");
        check(dut.active_mask==0 && dut.used_mask==0 && dut.staged_mask==0 && dut.preload_mask==0 &&
              !dut.path_mode && !dut.hold_mode,"recovery clears motion admission");
        repeat(100) @(negedge clk);check(tx_count==baseline+6,"recovery never auto replays or enables");
        motor_id=1;read_value(16'h7019,32'h3F800000);
        cmd_op=3;parameter_index=0;parameter_value=32'h50505431;baseline=tx_count;
        launch();repeat(4) @(negedge clk);check(command_error && tx_count==baseline,"enable still requires full fresh preparation");
        locked_stop();param_poisoned=1;baseline=tx_count;marker(8'h5A);repeat(5) @(negedge clk);
        check(fault_locked && tx_count==baseline,"poison prevents recovery");
        param_poisoned=0;param_pending=1;marker(8'h5A);repeat(5) @(negedge clk);
        check(fault_locked && tx_count==baseline,"pending request prevents recovery");
        param_pending=0;stream_integrity_lost=1;marker(8'h5A);repeat(5) @(negedge clk);
        check(fault_locked && tx_count==baseline,"integrity error prevents recovery");
        locked_stop();marker(8'h5A);wait_state(12);marker(8'hA5);
        tx_done=1;tx_success=1;@(negedge clk);tx_done=0;tx_success=0;
        for(axis=1;axis<6;axis=axis+1) begin
            wait_state(12);tx_done=1;tx_success=1;@(negedge clk);tx_done=0;tx_success=0;
        end
        repeat(3) @(negedge clk);check(fault_locked && command_error_code==8'hE0,"STOP during recovery keeps lock");
        locked_stop();marker(8'h5A);wait_state(12);tx_done=1;tx_success=0;
        @(negedge clk);tx_done=0;
        for(axis=1;axis<6;axis=axis+1) begin
            wait_state(12);tx_done=1;tx_success=1;@(negedge clk);tx_done=0;tx_success=0;
        end
        repeat(3) @(negedge clk);baseline=tx_count;
        check(fault_locked && command_error_code==8'hE2,"failed recovery disable remains locked");
        marker(8'h5A);repeat(6) @(negedge clk);check(fault_locked && tx_count==baseline,"hard TX failure cannot be cleared");
        locked_stop();marker(8'h5A);
        for(axis=0;axis<5;axis=axis+1) begin
            wait_state(12);tx_done=1;tx_success=1;@(negedge clk);tx_done=0;tx_success=0;
        end
        wait_state(12);tx_done=1;tx_success=1;byte_reserved=8'hA5;
        @(negedge clk);tx_done=0;tx_success=0;byte_reserved=0;
        repeat(3) @(negedge clk);check(fault_locked,"STOP wins on final completion edge");
        $display("PASS RECOVER_PP checks=%0d",checks);$finish;
    end
    initial begin #2000000;$fatal(1,"recovery test timeout");end
endmodule
