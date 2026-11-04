`timescale 1ns / 1ps
// Stage 3-A virtual traffic only. One request at a time; completion means new TXOK.
module pl_six_axis_scheduler #(
    parameter integer PERIOD_CYCLES=500000
) (
    input wire clk,rst_n,enable,ready,start_req,stop_req,
    input wire [1:0] period_sel,limit_sel,
    input wire sender_busy,sender_fault,send_accept,
    input wire [31:0] tx_success_count,time_now,tx_completed_cycle,
    output reg send_request,
    output reg [31:0] cycle_seq,
    output reg [2:0] axis_index,
    output reg [31:0] cycle_started_count,cycle_completed_count,
    output reg [31:0] attempted_count,missed_cycle_count,max_cycle_span_cycles,
    output reg [31:0] cycle_limit,
    output wire [31:0] selected_period,
    output reg [2:0] state,
    output reg round_used,start_rejected,scheduler_fault,
    output wire completed,stopped,halt_new_frames
);
    localparam [2:0] IDLE=0,ARMED=1,RUNNING=2,STOPPING=3,COMPLETED=4,FAULT=5,STOPPED=6;
    reg previous_start,frame_waiting,cycle_active;
    reg [31:0] period_counter,success_baseline,cycle_start_tick;
    wire frame_finished,last_frame_finished,period_tick;
    wire [31:0] measured_span;
    assign selected_period=PERIOD_CYCLES;
    assign frame_finished=frame_waiting && tx_success_count!=success_baseline;
    assign last_frame_finished=frame_finished && axis_index==5;
    assign period_tick=(state==RUNNING && period_counter==PERIOD_CYCLES-1);
    assign measured_span=tx_completed_cycle-cycle_start_tick;
    // Combinational boundary gate prevents a request being accepted on the
    // very edge that declares an unfinished control cycle late.
    assign halt_new_frames=scheduler_fault || state==STOPPING || state==STOPPED ||
        (period_tick && cycle_active && !last_frame_finished);
    assign completed=(state==COMPLETED);
    assign stopped=(state==STOPPED);
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=IDLE;previous_start<=0;frame_waiting<=0;cycle_active<=0;
            send_request<=0;cycle_seq<=0;axis_index<=0;
            cycle_started_count<=0;cycle_completed_count<=0;attempted_count<=0;
            missed_cycle_count<=0;max_cycle_span_cycles<=0;cycle_limit<=0;
            period_counter<=0;success_baseline<=0;cycle_start_tick<=0;
            round_used<=0;start_rejected<=0;scheduler_fault<=0;
        end else if(enable) begin
            previous_start<=start_req;
            if(sender_fault || ((state==RUNNING || state==STOPPING) && !ready)) begin
                state<=FAULT;scheduler_fault<=1;send_request<=0;
            end else case(state)
                IDLE: if(ready && !start_req) state<=ARMED;
                ARMED: begin
                    if(!ready) state<=IDLE;
                    else if(start_req && !previous_start) begin
                        if(period_sel!=2'b01 || limit_sel[1] || stop_req)
                            start_rejected<=1;
                        else begin
                            state<=RUNNING;round_used<=1;period_counter<=0;
                            cycle_limit<=limit_sel[0]?32'd1000:32'd100;
                            cycle_seq<=0;axis_index<=0;cycle_active<=1;
                            cycle_started_count<=1;send_request<=1;
                        end
                    end
                end
                RUNNING: begin
                    if(period_tick) period_counter<=0;
                    else period_counter<=period_counter+1'b1;
                    if(send_request && send_accept) begin
                        send_request<=0;frame_waiting<=1;
                        success_baseline<=tx_success_count;
                        attempted_count<=attempted_count+1'b1;
                        if(axis_index==0) cycle_start_tick<=time_now;
                    end
                    if(frame_finished) begin
                        frame_waiting<=0;
                        if(axis_index==5) begin
                            cycle_active<=0;cycle_completed_count<=cycle_completed_count+1'b1;
                            if(measured_span>max_cycle_span_cycles) max_cycle_span_cycles<=measured_span;
                            if(cycle_completed_count+1>=cycle_limit) begin
                                state<=COMPLETED;send_request<=0;
                            end
                        end else if(!stop_req) begin
                            axis_index<=axis_index+1'b1;send_request<=1;
                        end
                    end
                    if(stop_req) begin state<=STOPPING;send_request<=0;end
                    else if(period_tick) begin
                        if(cycle_active && !last_frame_finished) begin
                            missed_cycle_count<=missed_cycle_count+1'b1;
                            scheduler_fault<=1;state<=FAULT;send_request<=0;
                        end else if(cycle_completed_count+(last_frame_finished?1:0)<cycle_limit) begin
                            cycle_seq<=cycle_seq+1'b1;axis_index<=0;cycle_active<=1;
                            cycle_started_count<=cycle_started_count+1'b1;send_request<=1;
                        end
                    end
                end
                STOPPING: begin
                    send_request<=0;
                    if(frame_finished) begin
                        frame_waiting<=0;
                        if(axis_index==5) begin
                            cycle_active<=0;cycle_completed_count<=cycle_completed_count+1'b1;
                            if(measured_span>max_cycle_span_cycles) max_cycle_span_cycles<=measured_span;
                        end
                    end
                    if(!sender_busy) begin state<=STOPPED;frame_waiting<=0;end
                end
                default: send_request<=0;
            endcase
        end
    end
endmodule
