`timescale 1ns / 1ps
// The reference is the unmodified pre-optimization FIFO, compiled only in sim.
module fifo_width_case #(parameter integer DEPTH=1)(
    input wire clk,
    output reg done,
    output reg [31:0] checks,
    output reg [31:0] failures
);
    reg rst_n, push, ready;
    reg [31:0] sequence;
    reg [31:0] lfsr;
    reg initialized;
    wire [28:0] id_in=sequence[28:0];
    wire [63:0] data_in={~sequence,sequence};
    wire [63:0] timestamp_in={sequence,~sequence};
    wire [170:0] new_frame,old_frame;
    wire new_valid,old_valid,new_drop,old_drop;
    wire [31:0] new_level,old_level;
    integer i;

    can_rx_frame_fifo #(.DEPTH(DEPTH)) dut(
        .clk(clk),.rst_n(rst_n),.push(push),.in_id(id_in),
        .in_ide(sequence[0]),.in_rtr(sequence[1]),.in_dlc(sequence[3:0]),
        .in_data(data_in),.in_timestamp(timestamp_in),.in_error(sequence[7:0]),
        .valid(new_valid),.ready(ready),.out_id(new_frame[170:142]),
        .out_ide(new_frame[141]),.out_rtr(new_frame[140]),
        .out_dlc(new_frame[139:136]),.out_data(new_frame[135:72]),
        .out_timestamp(new_frame[71:8]),.out_error(new_frame[7:0]),
        .level(new_level),.drop(new_drop));
    baseline_can_rx_frame_fifo #(.DEPTH(DEPTH)) reference_fifo(
        .clk(clk),.rst_n(rst_n),.push(push),.in_id(id_in),
        .in_ide(sequence[0]),.in_rtr(sequence[1]),.in_dlc(sequence[3:0]),
        .in_data(data_in),.in_timestamp(timestamp_in),.in_error(sequence[7:0]),
        .valid(old_valid),.ready(ready),.out_id(old_frame[170:142]),
        .out_ide(old_frame[141]),.out_rtr(old_frame[140]),
        .out_dlc(old_frame[139:136]),.out_data(old_frame[135:72]),
        .out_timestamp(old_frame[71:8]),.out_error(old_frame[7:0]),
        .level(old_level),.drop(old_drop));

    task compare_outputs;
        begin
            checks=checks+1;
            if({new_valid,new_drop,new_level,new_frame} !==
               {old_valid,old_drop,old_level,old_frame}) begin
                failures=failures+1;
                $display("FAIL FIFO DEPTH=%0d time=%0t new level=%0d old level=%0d",
                         DEPTH,$time,new_level,old_level);
            end
        end
    endtask

    task cycle;
        input reset_value, push_value, ready_value;
        begin
            @(negedge clk);
            rst_n=reset_value;
            push=push_value;
            ready=ready_value;
            sequence=sequence+1;
            #1 if(initialized) compare_outputs;
            @(posedge clk);
            initialized=1;
            #1 compare_outputs;
        end
    endtask

    task expect;
        input condition;
        input [8*80-1:0] label;
        begin
            checks=checks+1;
            if(condition !== 1'b1) begin
                failures=failures+1;
                $display("FAIL FIFO DEPTH=%0d: %0s",DEPTH,label);
            end
        end
    endtask

    initial begin
        done=0;checks=0;failures=0;
        rst_n=0;push=0;ready=0;sequence=0;lfsr=32'hA54E_39B1+DEPTH;
        initialized=0;
        cycle(0,0,0);
        cycle(0,1,1);
        cycle(1,0,1);
        expect(!new_valid && !new_drop && new_level==0 && new_frame==0,
               "empty output is zero; no underflow");
        for(i=0;i<DEPTH;i=i+1) cycle(1,1,0);
        expect(new_valid && new_level==DEPTH,"fill reaches exact DEPTH");
        repeat(3) cycle(1,0,0);
        expect(new_level==DEPTH,"backpressure retains all frames");
        cycle(1,1,0);
        expect(new_drop && new_level==DEPTH,"full push drops without overwrite");
        cycle(1,1,1);
        expect(!new_drop && new_level==DEPTH,"full pop plus push replaces head");
        for(i=0;i<DEPTH;i=i+1) cycle(1,0,1);
        expect(!new_valid && new_level==0 && new_frame==0,
               "drain returns to empty zero output");
        for(i=0;i<DEPTH;i=i+1) cycle(1,1,0);
        for(i=0;i<4*DEPTH+3;i=i+1) cycle(1,1,1);
        expect(new_level==DEPTH,"repeated full replacement wraps pointers");
        cycle(0,1,1);
        expect(!new_valid && new_level==0 && new_frame==0,
               "reset clears state without exposing stale memory");
        cycle(1,0,0);
        expect(new_level==0,"reset release stays empty");
        for(i=0;i<1200;i=i+1) begin
            lfsr={lfsr[30:0],lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
            cycle(1,lfsr[0] | lfsr[3],lfsr[1] | lfsr[5]);
        end
        done=1;
        if(failures==0)
            $display("RESULT: PASS FIFO_WIDTH DEPTH=%0d (%0d checks)",DEPTH,checks);
        else
            $display("RESULT: FAIL FIFO_WIDTH DEPTH=%0d (%0d failures)",DEPTH,failures);
    end
endmodule

module tb_can_rx_frame_fifo_width;
    reg clk;
    wire [4:0] done;
    wire [31:0] failures0,failures1,failures2,failures3,failures4;
    wire [31:0] checks0,checks1,checks2,checks3,checks4;
    initial clk=0;
    always #5 clk=~clk;
    fifo_width_case #(.DEPTH(1))  case0(clk,done[0],checks0,failures0);
    fifo_width_case #(.DEPTH(2))  case1(clk,done[1],checks1,failures1);
    fifo_width_case #(.DEPTH(3))  case2(clk,done[2],checks2,failures2);
    fifo_width_case #(.DEPTH(16)) case3(clk,done[3],checks3,failures3);
    fifo_width_case #(.DEPTH(17)) case4(clk,done[4],checks4,failures4);
    initial begin
        wait(&done);
        if(failures0+failures1+failures2+failures3+failures4==0)
            $display("RESULT: PASS FIFO_WIDTH_ALL (%0d checks)",
                     checks0+checks1+checks2+checks3+checks4);
        else
            $display("RESULT: FAIL FIFO_WIDTH_ALL (%0d failures)",
                     failures0+failures1+failures2+failures3+failures4);
        $finish;
    end
endmodule
