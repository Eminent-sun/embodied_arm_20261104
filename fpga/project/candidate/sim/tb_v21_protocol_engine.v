`timescale 1ns/1ps
module tb_v21_protocol_engine;
    reg clk=0; always #10 clk=~clk;
    reg rst_n=0,start=0;
    reg [28:0] command_word=29'h0380C805;
    reg [63:0] command_value_word=0;
    wire param_req_valid,param_req_ready,param_req_rejected,param_req_active;
    wire [7:0] param_req_host,param_req_motor;
    wire [15:0] param_req_index;
    wire [31:0] param_req_token;
    wire param_cancel_valid,param_cancel_ready,param_cancel_done,param_cancel_matched;
    wire [7:0] param_cancel_motor;
    wire [15:0] param_cancel_index;
    wire [31:0] param_cancel_token;
    wire param_cancel_poison;
    wire param_reply_valid,param_reply_failed;
    wire [2:0] param_reply_axis;
    wire [15:0] param_reply_index;
    wire [31:0] param_reply_bits,param_reply_token;
    wire [5:0] param_pending,param_poisoned;
    wire status_event_valid;
    wire [7:0] status_event_motor;
    wire [5:0] status_event_error;
    wire tx_req_valid;
    wire [28:0] tx_can_id;
    wire [7:0] tx_can_dlc;
    wire [63:0] tx_can_data;
    reg tx_done=0,tx_success=0;
    integer tx_delay=0,tx_count=0,checks=0;
    wire command_busy,fault_locked,command_done,command_success,command_error;
    wire [7:0] command_error_code;
    wire [31:0] result_value;
    wire [3:0] command_state;
    reg frame_valid=0;
    wire frame_ready;
    reg [28:0] can_id=0;
    reg [63:0] can_data=0,frame_timestamp=0;
    wire integrity_lost,mapping_valid;
    wire [31:0] invalid_frame_count;
    pl_robstride_command_engine #(.REG_TIMEOUT_CYCLES(100),
        .TX_ACCEPT_TIMEOUT_CYCLES(100),.TX_RESULT_TIMEOUT_CYCLES(100),
        .REPLY_TIMEOUT_CYCLES(100),.CANCEL_TIMEOUT_CYCLES(100)) engine(
        .clk(clk),.rst_n(rst_n),.start(start),
        .command_word(command_word),.byte_reserved(8'd0),
        .command_value_word(command_value_word),
        .mapping_valid(mapping_valid),.stream_integrity_lost(integrity_lost),
        .param_pending(param_pending),.param_poisoned(param_poisoned),
        .param_req_valid(param_req_valid),.param_req_ready(param_req_ready),
        .param_req_rejected(param_req_rejected),.param_req_active(param_req_active),
        .param_req_host(param_req_host),.param_req_motor(param_req_motor),
        .param_req_index(param_req_index),.param_req_token(param_req_token),
        .param_cancel_valid(param_cancel_valid),.param_cancel_ready(param_cancel_ready),
        .param_cancel_done(param_cancel_done),.param_cancel_matched(param_cancel_matched),
        .param_cancel_motor(param_cancel_motor),.param_cancel_index(param_cancel_index),
        .param_cancel_token(param_cancel_token),.param_cancel_poison(param_cancel_poison),
        .param_reply_valid(param_reply_valid),.param_reply_failed(param_reply_failed),
        .param_reply_axis(param_reply_axis),.param_reply_index(param_reply_index),
        .param_reply_bits(param_reply_bits),.param_reply_token(param_reply_token),
        .status_event_valid(status_event_valid),.status_event_motor(status_event_motor),
        .status_event_error(status_event_error),.tx_req_valid(tx_req_valid),
        .tx_req_ready(1'b1),.tx_can_id(tx_can_id),.tx_can_dlc(tx_can_dlc),
        .tx_can_data(tx_can_data),.tx_done(tx_done),.tx_success(tx_success),
        .tx_may_have_submitted(1'b1),.tx_error_code(8'd0),
        .command_busy(command_busy),.fault_locked(fault_locked),
        .command_done(command_done),.command_success(command_success),
        .command_error(command_error),.command_error_code(command_error_code),
        .result_value(result_value),.command_state(command_state));
    robstride_protocol #(.CONFIG_ENABLE(1),.HOST_ID(8'hFD),
        .MOTOR_IDS(48'h060504030201),.ALLOW_IDENTITY(0),
        .FEEDBACK_TIMEOUT_CYCLES(500),.PARAM_TIMEOUT_CYCLES(500)) proto(
        .clk(clk),.rst_n(rst_n),.consume_enable(1'b1),
        .frame_valid(frame_valid),.frame_ready(frame_ready),.can_id(can_id),
        .can_ide(1'b1),.can_rtr(1'b0),.can_dlc(4'd8),
        .can_data(can_data),.frame_timestamp(frame_timestamp),
        .frame_error(8'd0),.stream_integrity_lost(1'b0),
        .param_req_valid(param_req_valid),.param_req_ready(param_req_ready),
        .param_req_rejected(param_req_rejected),.param_req_active(param_req_active),
        .param_req_host(param_req_host),.param_req_motor(param_req_motor),
        .param_req_index(param_req_index),.param_req_token(param_req_token),
        .param_cancel_valid(param_cancel_valid),.param_cancel_ready(param_cancel_ready),
        .param_cancel_done(param_cancel_done),.param_cancel_matched(param_cancel_matched),
        .param_cancel_motor(param_cancel_motor),.param_cancel_index(param_cancel_index),
        .param_cancel_token(param_cancel_token),.param_cancel_poison(param_cancel_poison),
        .param_reply_valid(param_reply_valid),.param_reply_failed(param_reply_failed),
        .param_reply_axis(param_reply_axis),.param_reply_index(param_reply_index),
        .param_reply_bits(param_reply_bits),.param_reply_token(param_reply_token),
        .param_pending(param_pending),.param_poisoned(param_poisoned),
        .status_event_valid(status_event_valid),.status_event_motor(status_event_motor),
        .status_event_error(status_event_error),.query_axis(3'd4),
        .integrity_lost(integrity_lost),.mapping_valid(mapping_valid),
        .invalid_frame_count(invalid_frame_count),.debug_page(5'd0),
        .rx_snapshot_isr(32'd0),.rx_snapshot_esr(32'd0),
        .rx_snapshot_ecr(32'd0),.rx_snapshot_sr(32'd0),
        .rx_snapshot_status(8'd0));
    always @(posedge clk) begin
        if(!rst_n) begin tx_delay<=0;tx_done<=0;tx_success<=0;tx_count<=0;end
        else begin
            tx_done<=0;
            if(tx_req_valid) begin tx_count<=tx_count+1;tx_delay<=3;end
            else if(tx_delay>0) begin
                tx_delay<=tx_delay-1;
                if(tx_delay==1) begin tx_done<=1;tx_success<=1;end
            end
        end
    end
    task check;
        input ok;
        input [255:0] name;
        begin
            if(ok !== 1'b1) begin
                $display("FAIL %0s state=%0d error=%h time=%0t",name,command_state,command_error_code,$time);
                $fatal(1);$finish;
            end else begin checks=checks+1;$display("PASS %0s",name);end
        end
    endtask
    task launch;
        begin
            @(negedge clk);start=0;repeat(2) @(negedge clk);
            start=1;@(negedge clk);start=0;
        end
    endtask
    task wait_state;
        input [3:0] wanted;
        integer n;
        begin
            n=0;
            while(command_state!=wanted && n<200) begin @(negedge clk);n=n+1;end
            if(command_state!=wanted) begin $display("FAIL waiting state %0d got %0d",wanted,command_state);$fatal(1);$finish;end
        end
    endtask
    task send_frame;
        input [28:0] id;
        input [63:0] data;
        begin
            @(negedge clk);can_id=id;can_data=data;
            frame_timestamp=proto.time_now;frame_valid=1;
            @(negedge clk);frame_valid=0;
            repeat(3) @(negedge clk);
        end
    endtask
    initial begin
        repeat(3) @(negedge clk);rst_n=1;
        launch();wait_state(5);
        check(tx_count==1 && param_pending[4],"read registered and sent once");
        send_frame(29'h110005FC,64'h3F80000000007019);
        check(!command_done && param_pending[4],"wrong host cannot finish read");
        send_frame(29'h020005FD,64'h0102030405060708);
        check(!command_done && param_pending[4],"type 2 cannot finish read");
        send_frame(29'h110005FD,64'h3F80000000007024);
        check(!command_done && param_pending[4],"wrong index cannot finish read");
        send_frame(29'h110005FD,64'h3F80000000007019);
        check(command_done && command_success && result_value==32'h3F800000,
            "exact host motor index read reply matched");

        command_word=29'h03812105;command_value_word=64'h0000000040000000;
        launch();wait_state(6);
        check(tx_count==2 && !param_pending[4],"write sent before readback registration");
        send_frame(29'h020005FC,64'h0102030405060708);
        check(command_state==6,"wrong host status cannot acknowledge write");
        send_frame(29'h020005FD,64'h0102030405060708);
        wait_state(5);
        check(tx_count==3 && param_pending[4],"accepted status starts registered readback");
        send_frame(29'h110005FD,64'h4000000000007024);
        check(command_done && command_success && result_value==32'h40000000,
            "write succeeds only after exact 32-bit readback");
        check(invalid_frame_count>=2,"protocol rejects wrong host and index");
        $display("PASS ALL %0d CHECKS",checks);$finish;
    end
    initial begin #200000;$display("FAIL global timeout");$fatal(1);$finish;end
endmodule
