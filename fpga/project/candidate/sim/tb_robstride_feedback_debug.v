`timescale 1ns / 1ps
// Compare every pre-existing public output against frozen B2/C0 RTL while
// exercising only new read-only diagnostics. No CAN hardware or AXI stimulus.
module tb_robstride_feedback_debug #(parameter integer REAL_TIMEOUT=0);
    localparam integer FB_CYCLES=REAL_TIMEOUT?5000000:200;
    reg clk=0,rst_n=0,consume_enable=1,frame_valid=0;
    reg [28:0] can_id=0;
    reg can_ide=1,can_rtr=0;
    reg [3:0] can_dlc=8;
    reg [63:0] can_data=0,frame_timestamp=0;
    reg [7:0] frame_error=0;
    reg stream_integrity_lost=0,param_req_valid=0;
    reg [7:0] param_req_host=0,param_req_motor=0;
    reg [15:0] param_req_index=0;
    reg [31:0] param_req_token=0;
    reg [2:0] query_axis=0;
    reg [4:0] debug_page=0;
    reg [31:0] snap_isr=32'h100,snap_esr=32'h11,snap_ecr=32'h2233,snap_sr=32'h98;
    reg [7:0] snap_status=8'h75;
    wire [31:0] debug_data;
    wire [15:0] diag_event_info;
    wire [5:0] diag_timeout_seen;
    integer checks=0,failures=0,a,n,j,k,expected_count=0,observed_count=0,compared_cycles=0;
    reg [15:0] expected_meta[0:1023];
    reg [63:0] saved_stamp;
    reg [31:0] saved_accepted,saved_invalid;
    always #10 clk=~clk;
    wire  frame_ready,ref_frame_ready;
    wire  param_req_ready,ref_param_req_ready;
    wire  param_req_rejected,ref_param_req_rejected;
    wire  param_reply_valid,ref_param_reply_valid;
    wire  param_reply_failed,ref_param_reply_failed;
    wire [2:0] param_reply_axis,ref_param_reply_axis;
    wire [15:0] param_reply_index,ref_param_reply_index;
    wire [31:0] param_reply_bits,ref_param_reply_bits;
    wire [31:0] param_reply_token,ref_param_reply_token;
    wire [5:0] param_pending,ref_param_pending;
    wire [5:0] param_poisoned,ref_param_poisoned;
    wire  query_valid,ref_query_valid;
    wire  query_status_valid,ref_query_status_valid;
    wire  query_fault_valid,ref_query_fault_valid;
    wire [7:0] query_motor_id,ref_query_motor_id;
    wire [15:0] query_position_raw,ref_query_position_raw;
    wire [15:0] query_velocity_raw,ref_query_velocity_raw;
    wire [15:0] query_torque_raw,ref_query_torque_raw;
    wire [15:0] query_temperature_raw,ref_query_temperature_raw;
    wire [1:0] query_pattern,ref_query_pattern;
    wire [5:0] query_error_code,ref_query_error_code;
    wire [31:0] query_fault,ref_query_fault;
    wire [31:0] query_warning,ref_query_warning;
    wire [31:0] query_fault_latched,ref_query_fault_latched;
    wire [31:0] query_warning_latched,ref_query_warning_latched;
    wire [63:0] query_feedback_timestamp,ref_query_feedback_timestamp;
    wire [63:0] query_last_frame_timestamp,ref_query_last_frame_timestamp;
    wire [63:0] query_fault_timestamp,ref_query_fault_timestamp;
    wire [31:0] query_frame_count,ref_query_frame_count;
    wire [31:0] query_status_count,ref_query_status_count;
    wire [31:0] query_invalid_count,ref_query_invalid_count;
    wire [31:0] query_timeout_count,ref_query_timeout_count;
    wire [15:0] query_parameter_index,ref_query_parameter_index;
    wire [31:0] query_parameter_bits,ref_query_parameter_bits;
    wire [31:0] query_parameter_token,ref_query_parameter_token;
    wire [31:0] query_parameter_count,ref_query_parameter_count;
    wire [31:0] query_parameter_failed_count,ref_query_parameter_failed_count;
    wire [63:0] query_parameter_timestamp,ref_query_parameter_timestamp;
    wire [63:0] query_uid_raw,ref_query_uid_raw;
    wire [28:0] query_last_id,ref_query_last_id;
    wire [5:0] feedback_timeout,ref_feedback_timeout;
    wire  mapping_valid,ref_mapping_valid;
    wire  watchdog_config_valid,ref_watchdog_config_valid;
    wire  integrity_lost,ref_integrity_lost;
    wire [31:0] accepted_frame_count,ref_accepted_frame_count;
    wire [31:0] invalid_frame_count,ref_invalid_frame_count;
    wire [31:0] stale_frame_count,ref_stale_frame_count;
    wire [31:0] parameter_unmatched_count,ref_parameter_unmatched_count;
    wire [31:0] parameter_timeout_count,ref_parameter_timeout_count;
    wire [3:0] last_reject_reason,ref_last_reject_reason;
    robstride_protocol #(.CONFIG_ENABLE(1),.HOST_ID(8'hFD),.MOTOR_IDS(48'h060504030201),.FEEDBACK_TIMEOUT_CYCLES(FB_CYCLES),.PARAM_TIMEOUT_CYCLES(64)) dut(
        .clk(clk),
        .rst_n(rst_n),
        .consume_enable(consume_enable),
        .frame_valid(frame_valid),
        .can_id(can_id),
        .can_ide(can_ide),
        .can_rtr(can_rtr),
        .can_dlc(can_dlc),
        .can_data(can_data),
        .frame_timestamp(frame_timestamp),
        .frame_error(frame_error),
        .stream_integrity_lost(stream_integrity_lost),
        .param_req_valid(param_req_valid),
        .param_req_host(param_req_host),
        .param_req_motor(param_req_motor),
        .param_req_index(param_req_index),
        .param_req_token(param_req_token),
        .query_axis(query_axis),
        .frame_ready(frame_ready),
        .param_req_ready(param_req_ready),
        .param_req_rejected(param_req_rejected),
        .param_reply_valid(param_reply_valid),
        .param_reply_failed(param_reply_failed),
        .param_reply_axis(param_reply_axis),
        .param_reply_index(param_reply_index),
        .param_reply_bits(param_reply_bits),
        .param_reply_token(param_reply_token),
        .param_pending(param_pending),
        .param_poisoned(param_poisoned),
        .query_valid(query_valid),
        .query_status_valid(query_status_valid),
        .query_fault_valid(query_fault_valid),
        .query_motor_id(query_motor_id),
        .query_position_raw(query_position_raw),
        .query_velocity_raw(query_velocity_raw),
        .query_torque_raw(query_torque_raw),
        .query_temperature_raw(query_temperature_raw),
        .query_pattern(query_pattern),
        .query_error_code(query_error_code),
        .query_fault(query_fault),
        .query_warning(query_warning),
        .query_fault_latched(query_fault_latched),
        .query_warning_latched(query_warning_latched),
        .query_feedback_timestamp(query_feedback_timestamp),
        .query_last_frame_timestamp(query_last_frame_timestamp),
        .query_fault_timestamp(query_fault_timestamp),
        .query_frame_count(query_frame_count),
        .query_status_count(query_status_count),
        .query_invalid_count(query_invalid_count),
        .query_timeout_count(query_timeout_count),
        .query_parameter_index(query_parameter_index),
        .query_parameter_bits(query_parameter_bits),
        .query_parameter_token(query_parameter_token),
        .query_parameter_count(query_parameter_count),
        .query_parameter_failed_count(query_parameter_failed_count),
        .query_parameter_timestamp(query_parameter_timestamp),
        .query_uid_raw(query_uid_raw),
        .query_last_id(query_last_id),
        .feedback_timeout(feedback_timeout),
        .mapping_valid(mapping_valid),
        .watchdog_config_valid(watchdog_config_valid),
        .integrity_lost(integrity_lost),
        .accepted_frame_count(accepted_frame_count),
        .invalid_frame_count(invalid_frame_count),
        .stale_frame_count(stale_frame_count),
        .parameter_unmatched_count(parameter_unmatched_count),
        .parameter_timeout_count(parameter_timeout_count),
        .last_reject_reason(last_reject_reason),
        .debug_page(debug_page),
        .rx_snapshot_isr(snap_isr),.rx_snapshot_esr(snap_esr),
        .rx_snapshot_ecr(snap_ecr),.rx_snapshot_sr(snap_sr),
        .rx_snapshot_status(snap_status),
        .debug_data(debug_data),
        .diag_event_info(diag_event_info),
        .diag_timeout_seen(diag_timeout_seen));
    baseline_robstride_protocol #(.CONFIG_ENABLE(1),.HOST_ID(8'hFD),.MOTOR_IDS(48'h060504030201),.FEEDBACK_TIMEOUT_CYCLES(FB_CYCLES),.PARAM_TIMEOUT_CYCLES(64)) reference(
        .clk(clk),
        .rst_n(rst_n),
        .consume_enable(consume_enable),
        .frame_valid(frame_valid),
        .can_id(can_id),
        .can_ide(can_ide),
        .can_rtr(can_rtr),
        .can_dlc(can_dlc),
        .can_data(can_data),
        .frame_timestamp(frame_timestamp),
        .frame_error(frame_error),
        .stream_integrity_lost(stream_integrity_lost),
        .param_req_valid(param_req_valid),
        .param_req_host(param_req_host),
        .param_req_motor(param_req_motor),
        .param_req_index(param_req_index),
        .param_req_token(param_req_token),
        .query_axis(query_axis),
        .frame_ready(ref_frame_ready),
        .param_req_ready(ref_param_req_ready),
        .param_req_rejected(ref_param_req_rejected),
        .param_reply_valid(ref_param_reply_valid),
        .param_reply_failed(ref_param_reply_failed),
        .param_reply_axis(ref_param_reply_axis),
        .param_reply_index(ref_param_reply_index),
        .param_reply_bits(ref_param_reply_bits),
        .param_reply_token(ref_param_reply_token),
        .param_pending(ref_param_pending),
        .param_poisoned(ref_param_poisoned),
        .query_valid(ref_query_valid),
        .query_status_valid(ref_query_status_valid),
        .query_fault_valid(ref_query_fault_valid),
        .query_motor_id(ref_query_motor_id),
        .query_position_raw(ref_query_position_raw),
        .query_velocity_raw(ref_query_velocity_raw),
        .query_torque_raw(ref_query_torque_raw),
        .query_temperature_raw(ref_query_temperature_raw),
        .query_pattern(ref_query_pattern),
        .query_error_code(ref_query_error_code),
        .query_fault(ref_query_fault),
        .query_warning(ref_query_warning),
        .query_fault_latched(ref_query_fault_latched),
        .query_warning_latched(ref_query_warning_latched),
        .query_feedback_timestamp(ref_query_feedback_timestamp),
        .query_last_frame_timestamp(ref_query_last_frame_timestamp),
        .query_fault_timestamp(ref_query_fault_timestamp),
        .query_frame_count(ref_query_frame_count),
        .query_status_count(ref_query_status_count),
        .query_invalid_count(ref_query_invalid_count),
        .query_timeout_count(ref_query_timeout_count),
        .query_parameter_index(ref_query_parameter_index),
        .query_parameter_bits(ref_query_parameter_bits),
        .query_parameter_token(ref_query_parameter_token),
        .query_parameter_count(ref_query_parameter_count),
        .query_parameter_failed_count(ref_query_parameter_failed_count),
        .query_parameter_timestamp(ref_query_parameter_timestamp),
        .query_uid_raw(ref_query_uid_raw),
        .query_last_id(ref_query_last_id),
        .feedback_timeout(ref_feedback_timeout),
        .mapping_valid(ref_mapping_valid),
        .watchdog_config_valid(ref_watchdog_config_valid),
        .integrity_lost(ref_integrity_lost),
        .accepted_frame_count(ref_accepted_frame_count),
        .invalid_frame_count(ref_invalid_frame_count),
        .stale_frame_count(ref_stale_frame_count),
        .parameter_unmatched_count(ref_parameter_unmatched_count),
        .parameter_timeout_count(ref_parameter_timeout_count),
        .last_reject_reason(ref_last_reject_reason));
    wire identical;
    assign identical=({frame_ready,param_req_ready,param_req_rejected,param_reply_valid,param_reply_failed,param_reply_axis,param_reply_index,param_reply_bits,param_reply_token,param_pending,param_poisoned,query_valid,query_status_valid,query_fault_valid,query_motor_id,query_position_raw,query_velocity_raw,query_torque_raw,query_temperature_raw,query_pattern,query_error_code,query_fault,query_warning,query_fault_latched,query_warning_latched,query_feedback_timestamp,query_last_frame_timestamp,query_fault_timestamp,query_frame_count,query_status_count,query_invalid_count,query_timeout_count,query_parameter_index,query_parameter_bits,query_parameter_token,query_parameter_count,query_parameter_failed_count,query_parameter_timestamp,query_uid_raw,query_last_id,feedback_timeout,mapping_valid,watchdog_config_valid,integrity_lost,accepted_frame_count,invalid_frame_count,stale_frame_count,parameter_unmatched_count,parameter_timeout_count,last_reject_reason}==={ref_frame_ready,ref_param_req_ready,ref_param_req_rejected,ref_param_reply_valid,ref_param_reply_failed,ref_param_reply_axis,ref_param_reply_index,ref_param_reply_bits,ref_param_reply_token,ref_param_pending,ref_param_poisoned,ref_query_valid,ref_query_status_valid,ref_query_fault_valid,ref_query_motor_id,ref_query_position_raw,ref_query_velocity_raw,ref_query_torque_raw,ref_query_temperature_raw,ref_query_pattern,ref_query_error_code,ref_query_fault,ref_query_warning,ref_query_fault_latched,ref_query_warning_latched,ref_query_feedback_timestamp,ref_query_last_frame_timestamp,ref_query_fault_timestamp,ref_query_frame_count,ref_query_status_count,ref_query_invalid_count,ref_query_timeout_count,ref_query_parameter_index,ref_query_parameter_bits,ref_query_parameter_token,ref_query_parameter_count,ref_query_parameter_failed_count,ref_query_parameter_timestamp,ref_query_uid_raw,ref_query_last_id,ref_feedback_timeout,ref_mapping_valid,ref_watchdog_config_valid,ref_integrity_lost,ref_accepted_frame_count,ref_invalid_frame_count,ref_stale_frame_count,ref_parameter_unmatched_count,ref_parameter_timeout_count,ref_last_reject_reason});
    task check;
        input ok;input [8*140-1:0] label;
        begin checks=checks+1;
            if(ok!==1'b1)begin failures=failures+1;$display("FAIL: %0s",label);end
            else $display("PASS: %0s",label);end
    endtask
    always @(posedge clk)begin
        if(rst_n)begin
            if(!REAL_TIMEOUT)begin
                compared_cycles=compared_cycles+1;
                if(!identical)begin failures=failures+1;if(failures<5)$display("FAIL: pre-existing public output differs from frozen reference");end
            end
            if(diag_event_info[0])begin
                if(observed_count>=expected_count || diag_event_info!==expected_meta[observed_count])begin
                    failures=failures+1;$display("FAIL: event metadata index=%0d got=%h expected=%h",observed_count,diag_event_info,expected_meta[observed_count]);
                end
                observed_count=observed_count+1;
            end
        end
    end
    task reset_all;
        begin @(negedge clk);rst_n=0;frame_valid=0;consume_enable=1;
            stream_integrity_lost=0;can_ide=1;can_rtr=0;can_dlc=8;frame_error=0;
            query_axis=0;debug_page=0;expected_count=0;observed_count=0;
            repeat(4)@(negedge clk);rst_n=1;repeat(4)@(negedge clk);end
    endtask
    task send;
        input [28:0] id;input [63:0] data;input [15:0] meta;
        begin @(negedge clk);can_id=id;can_data=data;frame_timestamp=dut.time_now;frame_valid=1;
            expected_meta[expected_count]=meta;expected_count=expected_count+1;
            while(!frame_ready)@(negedge clk);
            @(negedge clk);frame_valid=0;repeat(3)@(negedge clk);end
    endtask
    task page_check;
        input [4:0] page;input [31:0] wanted;input [8*140-1:0] label;
        begin debug_page=page;#1;check(debug_data===wanted,label);end
    endtask
    initial begin
        reset_all;
        check(feedback_timeout==6'h3F&&diag_timeout_seen==0,"startup missing feedback does not fabricate timeout event history");
        if(!REAL_TIMEOUT)begin
            // Different counts and positions for all six axes; no scheduler start.
            for(a=0;a<6;a=a+1)
                for(n=0;n<=a;n=n+1)
                    send(29'h02A501FD+(a<<8),64'h68245713CDAB3412+(a<<8),16'h0813+(a<<8));
            for(a=0;a<6;a=a+1)begin
                query_axis=a;#1;
                page_check(1,a+1,"six independent ordinary feedback counters via axis selection");
                page_check(2,a+1,"six independent all-valid frame counters");
                page_check(5,32'hABCD1234+a,"position and velocity raw cache preserved for selected axis");
                page_check(6,32'h24681357,"torque and temperature raw cache preserved");
                debug_page=0;#1;check(debug_data[7:0]==a+1&&debug_data[9:8]==2&&debug_data[15:10]==6'h25&&
                    debug_data[18:16]==3'b011&&debug_data[25:23]==a,"health page identifies independent selected axis and raw status");
            end
            query_axis=0;
            send(29'h150001FD,64'h8807060584030201,16'h08AB);
            page_check(7,32'h84030201,"latest full32 fault observed");
            page_check(8,32'h88070605,"latest full32 warning observed");
            send(29'h150001FD,64'h0000000200000008,16'h08AB);
            page_check(9,32'h84030209,"sticky fault history observed");
            page_check(10,32'h88070607,"sticky warning history observed");
            page_check(7,8,"latest fault remains distinct from sticky history");
            debug_page=15;#1;check(debug_data==query_fault_timestamp[31:0],"fault timestamp low page");
            debug_page=16;#1;check(debug_data==query_fault_timestamp[63:32],"fault timestamp high page");
            debug_page=13;#1;check(debug_data==query_last_frame_timestamp[31:0],"any-valid frame timestamp low page");
            debug_page=14;#1;check(debug_data==query_last_frame_timestamp[63:32],"any-valid frame timestamp high page");
            page_check(20,32'h150001FD,"last accepted complete CAN ID observed");
            send(29'h028001FC,0,16'h5815);
            send(29'h028007FD,0,16'h6715);
            page_check(17,2,"effective host and motor ID mismatch rejections counted");
            send(29'h110001FD,64'hBF80000000007016,16'hC88D);
            page_check(19,1,"unsolicited parameter is diagnostic rejection, never request admission");
            page_check(3,2,"selected axis invalid count excludes unknown-axis rejection");
            can_ide=0;send(29'h028001FD,0,16'h2815);can_ide=1;
            page_check(17,2,"higher-priority frame attribute rejection not double-classified as ID mismatch");
            saved_stamp=query_feedback_timestamp;
            @(negedge clk);can_id=29'h028001FD;can_data=0;frame_timestamp=saved_stamp;frame_valid=1;
            expected_meta[expected_count]=16'hB815;expected_count=expected_count+1;
            @(negedge clk);frame_valid=0;repeat(3)@(negedge clk);
            page_check(18,1,"stale local feedback record visible without changing cached data");
            check(!param_pending&&query_parameter_count==0,"diagnostic selectors cannot create parameter requests");
            query_axis=6;debug_page=0;#1;
            check(!debug_data[16]&&debug_data[19]&&debug_data[7:0]==0,"axis6 invalid, no alias to a real axis");
            page_check(1,0,"invalid axis count returns zero");query_axis=7;
            page_check(5,0,"axis7 raw cache returns zero");
            for(j=26;j<32;j=j+1)page_check(j,0,"reserved page returns zero without aliasing");
            reset_all;consume_enable=0;
            send(29'h028001FD,64'h68245713CDAB3412,16'h0813);
            saved_accepted=accepted_frame_count;
            check(!frame_ready&&observed_count==0&&diag_event_info==0,"no decode event is reported while event consumer stalls");
            @(negedge clk);frame_valid=1;can_id=29'h028002FD;can_data=64'h68245713CDAB3512;frame_timestamp=dut.time_now;
            expected_meta[expected_count]=16'h0913;expected_count=expected_count+1;
            for(j=0;j<12;j=j+1)begin
                query_axis=j%6;debug_page=j%21;@(negedge clk);
                if(frame_ready||accepted_frame_count!=saved_accepted||diag_event_info!=0)begin failures=failures+1;$display("FAIL: debug selection affected stalled frame");end
            end
            consume_enable=1;@(negedge clk);frame_valid=0;repeat(4)@(negedge clk);
            check(accepted_frame_count==2&&observed_count==2,"selector activity during backpressure does not alter accepted transactions");
            check(observed_count==expected_count&&identical,"decode event metadata agrees with all handshakes and frozen public behavior");
            stream_integrity_lost=1;@(negedge clk);stream_integrity_lost=0;
            send(29'h028001FD,0,16'h8815);
            check(integrity_lost&&accepted_frame_count==2,"passive diagnostics do not bypass sticky transport integrity fault");
        end
        reset_all;
        send(29'h028001FD,64'h68245713CDAB3412,16'h0813);
        query_axis=0;debug_page=11;saved_stamp=query_feedback_timestamp;
        while(dut.time_now-saved_stamp<FB_CYCLES-1)@(negedge clk);
        #1;check(!feedback_timeout[0]&&!diag_timeout_seen[0],"one clock before configured feedback timeout: fresh with no sticky event");
        @(negedge clk);#1;
        check(feedback_timeout[0]&&dut.time_now-saved_stamp==FB_CYCLES,"timeout occurs at configured age with unchanged threshold");
        check(debug_data-query_feedback_timestamp[31:0]==FB_CYCLES,"existing timebase page plus always-probed timestamp measures deadline without long capture");
        @(negedge clk);#1;page_check(4,1,"selected axis timeout transition counter visible");
        check(diag_timeout_seen==1,"timeout history is per-axis sticky, not startup stale mask");
        repeat(5)@(negedge clk);page_check(4,1,"persistent timeout is counted once");
        send(29'h150001FD,64'h8807060584030201,16'h08AB);
        check(feedback_timeout[0]&&query_feedback_timestamp==saved_stamp,"fault feedback cannot refresh ordinary feedback time");
        send(29'h028001FD,64'h68245713CDAB3412,16'h0813);
        check(!feedback_timeout[0]&&diag_timeout_seen[0]&&query_timeout_count==1,"new feedback recovers freshness while preserving timeout history");
        check(observed_count==expected_count&&identical,"all pre-existing public outputs remain identical to frozen reference");
        reset_all;check(diag_timeout_seen==0,"common reset clears diagnostic timeout history");
        if(!REAL_TIMEOUT)begin
            for(a=0;a<6;a=a+1)send(29'h028001FD+(a<<8),64'h68245713CDAB3412,16'h0813+(a<<8));
            repeat(FB_CYCLES+5)@(negedge clk);
            check(diag_timeout_seen==6'h3F&&feedback_timeout==6'h3F,"all six timeout histories are independent and retained");
            for(a=0;a<6;a=a+1)begin query_axis=a;page_check(4,1,"each selected axis preserves its own timeout count");end
            check(observed_count==expected_count&&identical,"multi-axis timeout diagnostics remain equivalent to frozen behavior");
        end
        debug_page=21;#1;check(debug_data==snap_isr,"page21 shows first ISR");
        debug_page=22;#1;check(debug_data==snap_esr,"page22 shows ESR");
        debug_page=23;#1;check(debug_data==snap_ecr,"page23 shows ECR");
        debug_page=24;#1;check(debug_data==snap_sr,"page24 shows SR");
        debug_page=25;#1;check(debug_data=={24'd0,snap_status},"page25 shows snapshot validity");
        if(failures==0)$display("RESULT: PASS FEEDBACK_DEBUG real100ms=%0d (%0d checks)",REAL_TIMEOUT,checks);
        else $display("RESULT: FAIL FEEDBACK_DEBUG (%0d failures / %0d checks)",failures,checks);
        $display("FROZEN_REFERENCE_COMPARISON_CYCLES=%0d",compared_cycles);
        $finish;
    end
    initial begin #200000000;$display("RESULT: FAIL diagnostic watchdog");$finish;end
endmodule
module tb_robstride_feedback_debug_100ms;
    tb_robstride_feedback_debug #(.REAL_TIMEOUT(1)) test();
endmodule
