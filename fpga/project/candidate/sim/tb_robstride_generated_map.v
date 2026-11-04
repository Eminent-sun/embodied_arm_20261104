`timescale 1ns / 1ps
// Test the ACTUAL BD-generated wrapper, not another explicitly parameterized
// robstride_protocol instance which could hide wrapper literal truncation.
module tb_robstride_generated_map;
    reg clk=0,rst_n=0,frame_valid=0;
    reg [63:0] now=0,frame_timestamp=0,can_data=0;
    reg [28:0] can_id=0;
    reg [2:0] query_axis=0;
    reg [4:0] debug_page=1;
    wire frame_ready,mapping_valid,query_valid,query_status_valid;
    wire [7:0] query_motor_id;
    wire [15:0] position_raw,velocity_raw,torque_raw,temperature_raw;
    wire [31:0] accepted_count,invalid_count,status_count,debug_data;
    wire [5:0] feedback_timeout;
    integer checks=0,failures=0,axis_id;
    reg [7:0] motor;
    reg [15:0] p,v,t,c;
    always #10 clk=~clk;
    always @(posedge clk) if(!rst_n)now<=0;else now<=now+1'b1;

    can_test_pl_robstride_feedback_0 dut(
        .clk(clk),.rst_n(rst_n),.consume_enable(1'b1),
        .frame_valid(frame_valid),.frame_ready(frame_ready),
        .can_id(can_id),.can_ide(1'b1),.can_rtr(1'b0),.can_dlc(4'd8),
        .can_data(can_data),.frame_timestamp(frame_timestamp),.frame_error(8'd0),
        .stream_integrity_lost(1'b0),.param_req_valid(1'b0),
        .param_req_host(8'd0),.param_req_motor(8'd0),.param_req_index(16'd0),.param_req_token(32'd0),
        .query_axis(query_axis),.query_valid(query_valid),.query_status_valid(query_status_valid),
        .query_motor_id(query_motor_id),.query_position_raw(position_raw),.query_velocity_raw(velocity_raw),
        .query_torque_raw(torque_raw),.query_temperature_raw(temperature_raw),
        .query_status_count(status_count),.feedback_timeout(feedback_timeout),
        .mapping_valid(mapping_valid),.accepted_frame_count(accepted_count),.invalid_frame_count(invalid_count),
        .debug_page(debug_page),.debug_data(debug_data));

    task check;
        input ok;
        input [8*120-1:0] label;
        begin
            checks=checks+1;
            if(ok!==1'b1)begin failures=failures+1;$display("FAIL: %0s",label);end
            else $display("PASS: %0s",label);
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst_n=1;repeat(3)@(negedge clk);
        check(dut.inst.MOTOR_IDS===48'h060504030201,"generated wrapper retains all 48 MOTOR_IDS bits");
        check(mapping_valid===1'b1,"six distinct nonzero IDs and host are valid");
        for(axis_id=0;axis_id<6;axis_id=axis_id+1)begin
            query_axis=axis_id;motor=axis_id+1;#1;
            check(query_valid&&query_motor_id===motor,"Byte i selects Axis i motor ID, including Axis4/5");
            p=16'h1001+axis_id;v=16'h2001+axis_id;t=16'h3001+axis_id;c=16'h4001+axis_id;
            @(negedge clk);
            can_id={5'h02,2'b10,6'd0,motor,8'hFD};
            can_data={c[7:0],c[15:8],t[7:0],t[15:8],v[7:0],v[15:8],p[7:0],p[15:8]};
            frame_timestamp=now;frame_valid=1;
            while(!frame_ready)@(negedge clk);
            @(negedge clk);frame_valid=0;repeat(4)@(negedge clk);#1;
            check(query_status_valid&&status_count==1&&debug_data==1,"generated wrapper accepts corresponding axis feedback once");
            check(position_raw===p&&velocity_raw===v&&torque_raw===t&&temperature_raw===c,
                "feedback big-endian payload unchanged after parameter fix");
        end
        check(accepted_count==6&&invalid_count==0&&feedback_timeout==0,"all six real wrapper IDs accepted, no rejected or stale axes");
        for(axis_id=0;axis_id<6;axis_id=axis_id+1)begin
            query_axis=axis_id;#1;
            check(status_count==1&&position_raw==16'h1001+axis_id,"six independent caches retain data after other axis updates");
        end
        query_axis=6;#1;check(!query_valid&&query_motor_id==0,"invalid query axis still rejected");
        if(!failures)$display("RESULT: PASS GENERATED_MOTOR_MAP (%0d checks)",checks);
        else $display("RESULT: FAIL GENERATED_MOTOR_MAP (%0d failures)",failures);
        $finish;
    end
    initial begin #100000;$display("RESULT: FAIL generated wrapper timeout");$finish;end
endmodule
