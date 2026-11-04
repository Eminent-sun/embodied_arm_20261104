`timescale 1ns / 1ps
module tb_can_rx_frame_fifo;
    reg clk=0,rst_n=0,push=0,ready=0;
    reg [28:0] id=0;
    wire valid,drop;
    wire [28:0] out_id;
    wire [31:0] level;
    integer checks=0,failures=0,i;
    always #10 clk=~clk;
    can_rx_frame_fifo #(.DEPTH(3)) dut(.clk(clk),.rst_n(rst_n),.push(push),
        .in_id(id),.in_ide(1'b1),.in_rtr(1'b0),.in_dlc(4'd8),.in_data(64'h8877665544332211),
        .in_timestamp(64'h123456789ABCDEF0),.in_error(8'hA5),.valid(valid),.ready(ready),
        .out_id(out_id),.out_ide(),.out_rtr(),.out_dlc(),.out_data(),.out_timestamp(),.out_error(),
        .level(level),.drop(drop));
    task check;
        input ok;input [8*100-1:0] label;
        begin checks=checks+1;if(ok!==1) begin failures=failures+1;$display("FAIL: %0s",label);end
            else $display("PASS: %0s",label);end
    endtask
    initial begin
        repeat(3) @(negedge clk);rst_n=1;
        check(!valid&&level==0&&!drop,"empty FIFO has no valid frame");
        push=1;
        for(i=0;i<3;i=i+1) begin id=i;@(negedge clk);end
        push=0;check(level==3&&out_id==0,"arbitrary non-power-of-two depth and FIFO order");
        repeat(3) @(negedge clk);
        check(level==3&&out_id==0,"backpressure preserves head and count");
        push=1;id=99;#1;check(drop,"full queue reports drop instead of overwriting oldest");
        @(negedge clk);push=0;check(level==3&&out_id==0,"dropped push leaves queued data intact");
        ready=1;push=1;id=3;#1;check(!drop,"simultaneous full pop/push uses the freed entry");
        @(negedge clk);push=0;check(level==3&&out_id==1,"full replacement preserves remaining FIFO order");
        @(negedge clk);check(out_id==2&&level==2,"second original frame retained");
        @(negedge clk);check(out_id==3&&level==1,"new replacement frame delivered last");
        @(negedge clk);check(!valid&&level==0,"queue drains exactly without underflow");
        repeat(3) @(negedge clk);check(level==0,"ready on empty cannot decrement count");
        if(failures==0) $display("RESULT: PASS RX_FIFO (%0d checks)",checks);
        else $display("RESULT: FAIL RX_FIFO (%0d failures)",failures);
        $finish;
    end
endmodule
