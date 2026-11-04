`timescale 1ns / 1ps
module tb_robstride_protocol;
    reg clk=0,rst_n=0,consume=1,push=0,transport_loss=0;
    reg [28:0] in_id=0;
    reg in_ide=1,in_rtr=0;
    reg [3:0] in_dlc=8;
    reg [63:0] in_data=0,in_stamp=0;
    reg [7:0] in_error=0;
    wire valid,ready,ide,rtr,drop;
    wire [28:0] id;
    wire [3:0] dlc;
    wire [63:0] data,stamp;
    wire [7:0] ferr;
    wire [31:0] level;
    reg req=0;
    wire req_ready,req_rejected,reply,reply_failed;
    reg [7:0] req_host=8'hFD,req_motor=9;
    reg [15:0] req_index=16'h7016;
    reg [31:0] req_token=0;
    reg [2:0] axis=0;
    wire [2:0] reply_axis;
    wire [15:0] reply_index,pos,vel,torque,temp,param_index;
    wire [31:0] reply_bits,reply_token,fault,warning,sticky_fault,sticky_warning;
    wire [31:0] frames,statuses,invalids,timeouts,param_bits,param_token,param_count,param_failed;
    wire [31:0] accepted,invalid,stale,unmatched,param_timeouts;
    wire [63:0] feedback_stamp,last_stamp,fault_stamp,param_stamp,uid;
    wire [1:0] pattern;
    wire [5:0] error_code,pending,poisoned,timed_out;
    wire config_valid,watchdog_valid,integrity,status_valid,fault_valid,query_valid;
    wire [7:0] motor;
    wire [3:0] reason;
    integer checks=0,failures=0,i,j,before_good,before_bad,reply_count=0,failed_count=0;
    reg [63:0] old_stamp;
    reg [31:0] captured_bits,captured_token;
    localparam [47:0] IDS=48'h634D2A170B09;
    always #10 clk=~clk;
    can_rx_frame_fifo #(.DEPTH(16)) fifo(.clk(clk),.rst_n(rst_n),.push(push),
        .in_id(in_id),.in_ide(in_ide),.in_rtr(in_rtr),.in_dlc(in_dlc),.in_data(in_data),
        .in_timestamp(in_stamp),.in_error(in_error),.valid(valid),.ready(ready),
        .out_id(id),.out_ide(ide),.out_rtr(rtr),.out_dlc(dlc),.out_data(data),
        .out_timestamp(stamp),.out_error(ferr),.level(level),.drop(drop));
    robstride_protocol #(.CONFIG_ENABLE(1),.HOST_ID(8'hFD),.MOTOR_IDS(IDS),
        .ALLOW_IDENTITY(1),.FEEDBACK_TIMEOUT_CYCLES(200),.PARAM_TIMEOUT_CYCLES(256)) dut(
        .clk(clk),.rst_n(rst_n),.debug_page(5'd0),.consume_enable(consume),.frame_valid(valid),.frame_ready(ready),
        .can_id(id),.can_ide(ide),.can_rtr(rtr),.can_dlc(dlc),.can_data(data),.frame_timestamp(stamp),
        .frame_error(ferr),.stream_integrity_lost(transport_loss),
        .param_req_valid(req),.param_req_ready(req_ready),.param_req_host(req_host),.param_req_motor(req_motor),
        .param_req_index(req_index),.param_req_token(req_token),.param_req_rejected(req_rejected),
        .param_reply_valid(reply),.param_reply_failed(reply_failed),.param_reply_axis(reply_axis),
        .param_reply_index(reply_index),.param_reply_bits(reply_bits),.param_reply_token(reply_token),
        .param_pending(pending),.param_poisoned(poisoned),.query_axis(axis),.query_valid(query_valid),
        .query_status_valid(status_valid),.query_fault_valid(fault_valid),.query_motor_id(motor),
        .query_position_raw(pos),.query_velocity_raw(vel),.query_torque_raw(torque),.query_temperature_raw(temp),
        .query_pattern(pattern),.query_error_code(error_code),.query_fault(fault),.query_warning(warning),
        .query_fault_latched(sticky_fault),.query_warning_latched(sticky_warning),
        .query_feedback_timestamp(feedback_stamp),.query_last_frame_timestamp(last_stamp),.query_fault_timestamp(fault_stamp),
        .query_frame_count(frames),.query_status_count(statuses),.query_invalid_count(invalids),.query_timeout_count(timeouts),
        .query_parameter_index(param_index),.query_parameter_bits(param_bits),.query_parameter_token(param_token),
        .query_parameter_count(param_count),.query_parameter_failed_count(param_failed),.query_parameter_timestamp(param_stamp),
        .query_uid_raw(uid),.feedback_timeout(timed_out),.mapping_valid(config_valid),.watchdog_config_valid(watchdog_valid),
        .integrity_lost(integrity),.accepted_frame_count(accepted),.invalid_frame_count(invalid),.stale_frame_count(stale),
        .parameter_unmatched_count(unmatched),.parameter_timeout_count(param_timeouts),.last_reject_reason(reason));
    wire default_valid,bad_map_valid;
    robstride_axis_map default_map(.motor_id(8'd1),.config_valid(default_valid),.mapped(),.axis());
    robstride_axis_map #(.CONFIG_ENABLE(1),.HOST_ID(8'hFD),.MOTOR_IDS(48'h060504030101)) bad_map(
        .motor_id(8'd1),.config_valid(bad_map_valid),.mapped(),.axis());
    always @(posedge clk) begin
        if(!rst_n) begin reply_count=0;failed_count=0;end
        else begin
            if(drop) transport_loss<=1;
            if(reply)begin reply_count=reply_count+1;if(reply_failed)failed_count=failed_count+1;
                captured_bits=reply_bits;captured_token=reply_token;end
        end
    end
    task check;
        input ok;input [8*130-1:0] name;
        begin checks=checks+1;if(ok!==1'b1)begin failures=failures+1;$display("FAIL: %0s",name);end
        else $display("PASS: %0s",name);end
    endtask
    task reset_all;
        begin @(negedge clk);rst_n=0;push=0;req=0;consume=1;transport_loss=0;
            in_ide=1;in_rtr=0;in_dlc=8;in_error=0;axis=0;req_motor=9;req_host=8'hFD;req_index=16'h7016;
            repeat(4)@(negedge clk);rst_n=1;repeat(5)@(negedge clk);end
    endtask
    task inject;
        input [28:0] new_id;input [63:0] new_data;input [63:0] new_stamp;
        begin @(negedge clk);in_id=new_id;in_data=new_data;in_stamp=new_stamp;push=1;
            @(negedge clk);push=0;end
    endtask
    task send;
        input [28:0] new_id;input [63:0] new_data;
        begin inject(new_id,new_data,dut.time_now);repeat(5)@(negedge clk);end
    endtask
    task reject;
        input [28:0] new_id;input [63:0] new_data;input [3:0] wanted_reason;
        begin before_good=accepted;before_bad=invalid;send(new_id,new_data);
            check(accepted==before_good && invalid==before_bad+1 && reason==wanted_reason,"invalid frame rejected without state acceptance");end
    endtask
    task request;
        input [31:0] token;
        begin @(negedge clk);req_token=token;req=1;
            if(!req_ready)begin $display("FAIL request unexpectedly busy");failures=failures+1;end
            @(negedge clk);req=0;end
    endtask
    initial begin
        reset_all;
        check(!default_valid&&!bad_map_valid,"unconfigured and duplicate address maps invalid");
        check(config_valid&&watchdog_valid&&timed_out==6'h3F,"explicit map valid; no feedback starts stale");
        send(29'h02A509FD,64'h68245713CDAB3412);
        check(pos==16'h1234&&vel==16'hABCD&&torque==16'h1357&&temp==16'h2468,"golden type02 four big-endian raw words");
        check(pattern==2 && error_code==6'h25 && status_valid && !timed_out[0],"type02 ID state/error fields and freshness");
        old_stamp=feedback_stamp;
        inject(29'h02A509FD,64'hFFFFFFFFFFFFFFFF,old_stamp);repeat(5)@(negedge clk);
        check(stale==1&&pos==16'h1234&&feedback_stamp==old_stamp,"same timestamp duplicate cannot overwrite");
        inject(29'h02A509FD,0,old_stamp-1);repeat(5)@(negedge clk);
        check(stale==2&&pos==16'h1234,"older timestamp rejected");
        send(29'h02A509FD,64'h68245713CDAB3412);
        check(statuses==2&&feedback_stamp>old_stamp,"identical values with a newer timestamp remain valid");
        for(i=1;i<6;i=i+1)begin
            send(29'h028000FD | (IDS[i*8 +: 8]<<8),64'h0100020003000000+i);
            axis=i;#1;check(statuses==1 && motor==IDS[i*8 +: 8],"six-axis explicit map and independent counts");
        end
        axis=0;#1;check(statuses==2&&pos==16'h1234,"other axes cannot overwrite axis0");
        in_ide=0;reject(29'h02A509FD,0,2);in_ide=1;
        in_rtr=1;reject(29'h02A509FD,0,3);in_rtr=0;
        in_dlc=7;reject(29'h02A509FD,0,4);in_dlc=8;
        reject(29'h02A509FC,0,5);reject(29'h028008FD,0,6);reject(29'h1B3409FD,0,7);
        reject(29'h02C009FD,0,9);
        in_error=1;reject(29'h02A509FD,0,8);in_error=0;
        // Transport fault is sticky and requires the common reset.
        reject(29'h02A509FD,0,8);check(integrity,"transport loss remains latched");
        reset_all;
        reject(29'h110009FD,64'hBF80000000007016,12);
        request(32'h12345678);check(pending==1,"parameter request admitted for axis0");
        reject(29'h110009FC,64'hBF80000000007016,5);
        reject(29'h11000BFD,64'hBF80000000007016,12);
        reject(29'h110009FD,64'hBF80000000007017,12);
        reject(29'h110209FD,64'hBF80000000007016,9);
        reject(29'h110009FD,64'hBF80000000017016,9);
        check(pending==1 && param_count==0,"nonmatching replies do not consume pending request");
        send(29'h110009FD,64'hBF80000000007016);
        check(!pending[0]&&reply_count==1&&captured_bits==32'hBF800000&&captured_token==32'h12345678,"host/motor/index/status matching returns local token");
        check(param_index==16'h7016&&param_bits==32'hBF800000&&param_count==1,"successful parameter raw bits cached without float math");
        reject(29'h110009FD,64'hBF80000000007016,12);
        request(32'h87654321);send(29'h110109FD,64'hDEADBEEF00007016);
        check(reply_count==2&&failed_count==1&&param_failed==1&&!pending[0],"status1 produces explicit failed transaction completion");
        check(param_bits==32'hBF800000&&param_count==2,"failed response cannot overwrite last successful value");
        request(32'hAABBCCDD);repeat(260)@(negedge clk);
        check(poisoned[0]&&!pending[0]&&param_timeouts==1,"parameter deadline expires and blocks axis reuse");
        request(32'hAABBCCEE);check(req_rejected&&!pending[0],"no automatic transaction reuse after timeout");
        reject(29'h110009FD,64'hBF80000000007016,12);
        reset_all;
        send(29'h02A509FD,64'h68245713CDAB3412);old_stamp=feedback_stamp;
        send(29'h150009FD,64'h8807060584030201);
        check(fault==32'h84030201&&warning==32'h88070605&&fault_valid,"type15 all 32 fault and all 32 warning bits preserved");
        send(29'h150009FD,64'h0000000200000008);
        check(fault==8&&warning==2&&sticky_fault==32'h84030209&&sticky_warning==32'h88070607,"latest and sticky fault/warning maintained separately");
        send(29'h000009FE,64'h0807060504030201);
        check(uid==64'h0807060504030201,"optional identity reply retains eight UID bytes");
        check(feedback_stamp==old_stamp&&statuses==1,"fault/identity do not refresh ordinary feedback watchdog");
        inject(29'h02A509FD,0,dut.time_now+1000);repeat(5)@(negedge clk);
        check(reason==10&&feedback_stamp==old_stamp,"future service timestamp rejected");
        repeat(210)@(negedge clk);
        check(timed_out[0]&&timeouts==1&&pos==16'h1234,"missing feedback expires without destroying cached raw values");
        send(29'h02A509FD,64'h68245713CDAB3412);
        check(!timed_out[0]&&timeouts==1,"new valid feedback clears stale state without clearing history");
        axis=7;#1;check(!query_valid&&pos==0&&frames==0,"illegal query axis never exposes arbitrary array entry");
        reset_all;consume=0;
        for(i=0;i<17;i=i+1) inject(29'h02A509FD,64'h68245713CDAB3412,dut.time_now);
        repeat(3)@(negedge clk);
        check(level==16&&!ready&&accepted==0&&!integrity,"one elastic stage plus all 16 FIFO entries backpressured without duplication");
        consume=1;repeat(25)@(negedge clk);
        check(level==0&&accepted==17&&statuses==17&&!integrity,"backpressure release drains complete frames exactly once");
        // Continuous input, including gaps in service timestamps; no wire SEQ is invented.
        for(j=0;j<1000;j=j+1)begin
            for(i=0;i<6;i=i+1)inject(29'h028000FD | (IDS[i*8 +: 8]<<8),64'h0100020003000000+j,dut.time_now);
        end
        repeat(10)@(negedge clk);
        check(accepted==6017&&invalid==0&&level==0,"6000 continuous six-axis frames accepted without cross-axis corruption");
        for(i=0;i<6;i=i+1)begin axis=i;#1;check(statuses==1000+(i==0?17:0),"continuous per-axis count exact");end
        reset_all;consume=0;
        for(i=0;i<18;i=i+1)inject(29'h02A509FD,0,dut.time_now);
        repeat(3)@(negedge clk);consume=1;repeat(25)@(negedge clk);
        check(integrity&&accepted==0&&invalid==17,"overflow becomes sticky incomplete stream, never silently healthy");
        reset_all;req_host=8'hFC;request(1);check(req_rejected&&!pending,"wrong-host request registration rejected");
        req_host=8'hFD;req_motor=8;request(2);check(req_rejected&&!pending,"unmapped request registration rejected");
        reset_all;
        // Six independent in-flight reads, replies deliberately returned in reverse axis order.
        for(i=0;i<6;i=i+1)begin req_motor=IDS[i*8 +: 8];request(32'hAB000000+i);end
        check(pending==6'h3F,"six independent pending parameter slots");
        req_motor=9;#1;check(!req_ready,"busy axis backpressures request registration");
        for(i=5;i>=0;i=i-1)begin
            send(29'h110000FD | (IDS[i*8 +: 8]<<8),64'h3F80000000007016+i*64'h100000000);
            axis=i;#1;
            check(param_token==32'hAB000000+i&&param_bits==32'h3F800000+i&&param_count==1,"reverse-order replies match corresponding axis and local token");
        end
        check(pending==0&&reply_count==6&&invalid==0,"inter-axis reply reordering never consumes another transaction");
        reset_all;old_stamp=dut.time_now;repeat(3)@(negedge clk);request(99);
        inject(29'h110009FD,64'hBF80000000007016,old_stamp);repeat(5)@(negedge clk);
        check(reason==12&&pending[0]&&param_count==0,"reply timestamp before admission cannot satisfy new transaction");
        // Even a timely wire/service timestamp is rejected if buffering postpones
        // processing beyond the local deadline; there is no automatic retry.
        consume=0;send(29'h110009FD,64'hBF80000000007016);
        repeat(260)@(negedge clk);consume=1;repeat(5)@(negedge clk);
        check(poisoned[0]&&param_count==0&&param_timeouts==1,"buffered response cannot bypass expired processing deadline");
        reset_all;
        for(i=0;i<6;i=i+1)begin req_motor=IDS[i*8 +: 8];request(i);end
        repeat(270)@(negedge clk);
        check(poisoned==6'h3F&&pending==0&&param_timeouts==6,"all independent parameter timeouts counted exactly once");
        reset_all;transport_loss=1;@(negedge clk);transport_loss=0;request(1);
        check(req_rejected&&!pending&&integrity,"sticky transport loss blocks new parameter registration");
        if(failures==0)$display("RESULT: PASS (%0d protocol/state checks)",checks);
        else $display("RESULT: FAIL (%0d failures / %0d)",failures,checks);
        $finish;
    end
    initial begin #10000000;$display("RESULT: FAIL watchdog");$finish;end
endmodule
