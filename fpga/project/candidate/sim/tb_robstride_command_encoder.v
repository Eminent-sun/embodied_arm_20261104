`timescale 1ns / 1ps
module tb_robstride_command_encoder;
    reg clk=0,rst_n=0,config_valid=0,model_valid=0,allow=0;
    reg cmd_valid=0,ready=1;
    reg [3:0] op=0;
    reg [7:0] host=8'hFD,motor=1;
    reg [15:0] index=0;
    reg [31:0] bits=0;
    wire cmd_ready,valid,ide,rtr,rejected;
    wire [3:0] dlc,reason;
    wire [28:0] id;
    wire [63:0] data;
    wire [31:0] idr,dlcr,dw1,dw2;
    wire [28:0] decoded_id;
    wire decoded_ide,decoded_rtr;
    wire [3:0] decoded_dlc;
    wire [63:0] decoded_data;
    integer checks=0,failures=0,i;
    reg [92:0] held;
    always #10 clk=~clk;
    robstride_command_encoder dut(.clk(clk),.rst_n(rst_n),.config_valid(config_valid),
        .model_config_valid(model_valid),.allow_actuation(allow),.cmd_valid(cmd_valid),.cmd_ready(cmd_ready),
        .cmd_op(op),.host_id(host),.motor_id(motor),.parameter_index(index),.parameter_bits(bits),
        .frame_valid(valid),.frame_ready(ready),.can_id(id),.can_ide(ide),.can_rtr(rtr),.can_dlc(dlc),
        .can_data(data),.command_rejected(rejected),.reject_reason(reason));
    robstride_frame_adapter mapping(.can_id(id),.ide(ide),.rtr(rtr),.dlc(dlc),.data(data),
        .tx_idr(idr),.tx_dlcr(dlcr),.tx_dw1(dw1),.tx_dw2(dw2),
        .rx_idr(idr),.rx_dlcr(dlcr),.rx_dw1(dw1),.rx_dw2(dw2),
        .decoded_id(decoded_id),.decoded_ide(decoded_ide),.decoded_rtr(decoded_rtr),.decoded_dlc(decoded_dlc),.decoded_data(decoded_data));
    task check;
        input ok;input [8*100-1:0] name;
        begin checks=checks+1;if(ok!==1'b1)begin failures=failures+1;$display("FAIL: %0s",name);end
        else $display("PASS: %0s",name);end
    endtask
    task command;
        input [3:0] operation;input [15:0] address;input [31:0] value;
        begin @(negedge clk);op=operation;index=address;bits=value;cmd_valid=1;
            while(!cmd_ready) @(negedge clk);
            @(posedge clk);#1;@(negedge clk);cmd_valid=0;end
    endtask
    task frame;
        input [28:0] wanted_id;input [63:0] wanted_data;
        begin check(valid && id===wanted_id && data===wanted_data && dlc==8 && ide && !rtr,"literal CAN ID/data/DLC/IDE/RTR");
            check(decoded_id===id && decoded_data===data && decoded_ide && !decoded_rtr && decoded_dlc==8,"explicit AXI mapping round trip");end
    endtask
    initial begin
        repeat(3) @(negedge clk);rst_n=1;
        command(0,16'h7016,0);check(rejected&&!valid&&reason==1,"default address config rejects commands");
        config_valid=1;
        command(0,16'h7016,0);frame(29'h1100FD01,64'h0000000000007016);
        command(1,16'h7024,32'h3F800000);check(rejected&&!valid&&reason==4,"model not frozen: float write blocked");
        model_valid=1;command(5,0,0);check(rejected&&!valid,"explicit actuation permission still required");
        allow=1;
        command(1,16'h7024,32'h3F800000);frame(29'h1200FD01,64'h3F80000000007024);
        check(idr==32'h9019FA02 && dlcr==32'h80000000 && dw1==32'h24700000 && dw2==32'h0000803F,"literal PG096 register words / speed 1.0");
        command(1,16'h7016,32'hBF800000);frame(29'h1200FD01,64'hBF80000000007016);
        motor=3;command(1,16'h7024,32'h40000000);frame(29'h1200FD03,64'h4000000000007024);
        motor=6;command(1,16'h7016,0);frame(29'h1200FD06,64'h0000000000007016);
        motor=9;command(2,16'h7005,5);frame(29'h1200FD09,64'h0000000500007005);
        command(3,16'h1234,32'hABCD);frame(29'h1200FD09,64'h0000ABCD00001234);
        command(4,16'h1234,32'h89ABCDEF);frame(29'h1200FD09,64'h89ABCDEF00001234);
        command(2,16'h1234,256);check(rejected&&!valid&&reason==5,"u8 truncation rejected");
        command(3,16'h1234,65536);check(rejected&&!valid&&reason==5,"u16 truncation rejected");
        command(2,16'h7005,4);check(rejected&&!valid&&reason==6,"unconfirmed mode 4 rejected");
        command(1,16'h7005,1);check(rejected&&!valid&&reason==6,"mode parameter cannot be encoded as float");
        for(i=1;i<=6;i=i+1) begin
            motor=i;command(5,0,0);frame(29'h0300FD00+i,0);
            command(6,0,0);frame(29'h0400FD00+i,0);
        end
        command(7,0,0);frame(29'h0400FD06,1);
        allow=0;model_valid=0;
        command(6,0,0);frame(29'h0400FD06,0);
        command(7,0,0);check(rejected&&!valid,"fault clear remains explicitly gated");
        command(15,0,0);check(rejected&&!valid&&reason==3,"unknown TX operation rejected");
        motor=host;command(0,16'h7016,0);check(rejected&&!valid&&reason==2,"motor/host collision rejected");
        motor=1;ready=0;command(0,16'h7016,0);held={id,data};
        repeat(5) begin @(negedge clk);check(valid&&!cmd_ready&&held==={id,data},"output stable while downstream not ready");end
        ready=1;@(negedge clk);check(!valid,"exactly one output consumed");
        if(failures==0)$display("RESULT: PASS (%0d encoder checks)",checks);
        else $display("RESULT: FAIL (%0d failures / %0d)",failures,checks);
        $finish;
    end
    initial begin #1000000;$display("RESULT: FAIL watchdog");$finish;end
endmodule

