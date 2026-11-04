`timescale 1ns / 1ps
module pl_can_scheduler #(
    parameter integer PERIOD_10HZ_CYCLES=5000000,
    parameter integer PERIOD_100HZ_CYCLES=500000,
    parameter integer PERIOD_200HZ_CYCLES=250000
) (
    input wire clk,rst_n,enable,ready,
    input wire start_req,stop_req,
    input wire [1:0] period_sel,limit_sel,
    input wire sender_busy,sender_fault,send_accept,
    input wire [31:0] tx_success_count,
    output reg send_request,
    output reg [31:0] request_sequence,last_sequence,
    output reg [31:0] scheduled_count,attempted_count,missed_deadline_count,
    output reg [31:0] latched_period,frame_limit,
    output reg [2:0] state,
    output reg round_used,start_rejected,
    output wire completed,stopped,deadline_violation
);
    localparam [2:0] IDLE=0,ARMED=1,RUNNING=2,STOPPING=3,COMPLETED=4,FAULT=5,STOPPED=6;
    reg previous_start;
    reg [31:0] period_counter,next_sequence;
    assign completed=(state==COMPLETED);
    assign stopped=(state==STOPPED);
    assign deadline_violation=(missed_deadline_count!=0);
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=IDLE;previous_start<=0;round_used<=0;start_rejected<=0;
            send_request<=0;request_sequence<=0;last_sequence<=0;next_sequence<=0;
            scheduled_count<=0;attempted_count<=0;missed_deadline_count<=0;
            latched_period<=0;frame_limit<=0;period_counter<=0;
        end else if(enable) begin
            previous_start<=start_req;
            // Terminal states are sticky until the common PL reset.
            if(sender_fault) begin state<=FAULT;send_request<=0;end
            else case(state)
                IDLE: if(ready&&!start_req) state<=ARMED;
                ARMED: begin
                    if(!ready) state<=IDLE;
                    else if(start_req&&!previous_start) begin
                        if(period_sel==2'b11||stop_req) start_rejected<=1;
                        else begin
                            round_used<=1;state<=RUNNING;period_counter<=0;
                            case(period_sel)
                                0:latched_period<=PERIOD_10HZ_CYCLES;
                                1:latched_period<=PERIOD_100HZ_CYCLES;
                                2:latched_period<=PERIOD_200HZ_CYCLES;
                            endcase
                            case(limit_sel)
                                0:frame_limit<=100;
                                1:frame_limit<=1000;
                                2:frame_limit<=2000;
                                3:frame_limit<=360000;
                            endcase
                            // t=0 is the first scheduled opportunity.
                            scheduled_count<=1;send_request<=1;request_sequence<=next_sequence;
                        end
                    end
                end
                RUNNING: begin
                    if(send_request&&send_accept) begin
                        attempted_count<=attempted_count+1;last_sequence<=request_sequence;
                        next_sequence<=next_sequence+1;send_request<=0;
                    end
                    if(stop_req) begin
                        state<=STOPPING;send_request<=0;
                    end else if(tx_success_count>=frame_limit && !sender_busy && !send_request) begin
                        state<=COMPLETED;
                    end else if(period_counter==latched_period-1) begin
                        period_counter<=0;scheduled_count<=scheduled_count+1;
                        if(sender_busy||send_request) missed_deadline_count<=missed_deadline_count+1;
                        else begin send_request<=1;request_sequence<=next_sequence;end
                    end else period_counter<=period_counter+1;
                end
                STOPPING: begin
                    send_request<=0;
                    if(!sender_busy) state<=STOPPED;
                end
                default: send_request<=0;
            endcase
        end
    end
endmodule
