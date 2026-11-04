`timescale 1ns / 1ps
// PG096 v5.1 / Vitis 2023.1 can_v3_6 configuration, through the shared executor.
module pl_can_init #(
    parameter integer INIT_TIMEOUT_CYCLES=50000000,
    parameter integer POLL_CYCLES=5000
) (
    input wire clk, input wire rst_n, input wire enable,
    // Both status inputs are synchronized to clk by the top-level reset system.
    input wire clock_locked, input wire reset_released,
    output reg cmd_valid, output reg cmd_write,
    output reg [31:0] cmd_addr, output reg [31:0] cmd_data,
    input wire cmd_ready,
    input wire response_valid, input wire response_error,
    input wire response_timeout, input wire [31:0] response_data,
    output reg can_initialized, output reg can_init_error,
    output reg [4:0] state, output reg [4:0] failed_state,
    output reg [3:0] error_code, output reg [31:0] last_status
);
    localparam [4:0] WAIT_CLOCK=0, WAIT_RESET=1, RESET_REQ=2, RESET_RESP=3,
        CONFIG_REQ=4, CONFIG_RESP=5, CONFIG_GAP=6,
        BRPR_REQ=7, BRPR_RESP=8, BTR_REQ=9, BTR_RESP=10,
        MSR_REQ=11, MSR_RESP=12, IER_REQ=13, IER_RESP=14,
        ENABLE_REQ=15, ENABLE_RESP=16, NORMAL_REQ=17, NORMAL_RESP=18,
        NORMAL_GAP=19, INIT_DONE=20, INIT_FAULT=21;
    reg [31:0] elapsed,gap;
    wire terminal;
    assign terminal=can_initialized||can_init_error;
    always @* begin
        cmd_valid=0;cmd_write=0;cmd_addr=32'h43C00018;cmd_data=0;
        if(enable && clock_locked && reset_released && !terminal) begin
            case(state)
                RESET_REQ: begin cmd_valid=1;cmd_write=1;cmd_addr=32'h43C00000;cmd_data=1;end
                CONFIG_REQ,NORMAL_REQ: cmd_valid=1;
                BRPR_REQ: begin cmd_valid=1;cmd_write=1;cmd_addr=32'h43C00008;cmd_data=0;end
                BTR_REQ: begin cmd_valid=1;cmd_write=1;cmd_addr=32'h43C0000C;cmd_data=32'h2F;end
                MSR_REQ: begin cmd_valid=1;cmd_write=1;cmd_addr=32'h43C00004;cmd_data=0;end
                IER_REQ: begin cmd_valid=1;cmd_write=1;cmd_addr=32'h43C00020;cmd_data=0;end
                ENABLE_REQ: begin cmd_valid=1;cmd_write=1;cmd_addr=32'h43C00000;cmd_data=2;end
                default: begin end
            endcase
        end
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=WAIT_CLOCK;failed_state<=0;error_code<=0;last_status<=0;
            can_initialized<=0;can_init_error<=0;elapsed<=0;gap<=0;
        end else if(enable && !terminal) begin
            elapsed<=elapsed+1;
            if(elapsed==INIT_TIMEOUT_CYCLES-1) begin
                failed_state<=state;state<=INIT_FAULT;can_init_error<=1;
                if(state==WAIT_CLOCK) error_code<=7;
                else if(state==WAIT_RESET) error_code<=8;
                else if(state>=CONFIG_REQ && state<=CONFIG_GAP) error_code<=1;
                else if(state>=NORMAL_REQ && state<=NORMAL_GAP) error_code<=2;
                else error_code<=6;
            end else if(response_timeout) begin
                failed_state<=state;state<=INIT_FAULT;can_init_error<=1;error_code<=3;
            end else if(response_valid && response_error) begin
                failed_state<=state;state<=INIT_FAULT;can_init_error<=1;
                if(state==CONFIG_RESP||state==NORMAL_RESP) error_code<=4;else error_code<=5;
            end else begin
                case(state)
                    WAIT_CLOCK: if(clock_locked) state<=WAIT_RESET;
                    WAIT_RESET: if(reset_released) state<=RESET_REQ;
                    RESET_REQ: if(cmd_valid&&cmd_ready) state<=RESET_RESP;
                    RESET_RESP: if(response_valid) state<=CONFIG_REQ;
                    CONFIG_REQ: if(cmd_valid&&cmd_ready) state<=CONFIG_RESP;
                    CONFIG_RESP: if(response_valid) begin
                        last_status<=response_data;
                        if(response_data[0]) state<=BRPR_REQ;
                        else begin state<=CONFIG_GAP;gap<=0;end
                    end
                    CONFIG_GAP: if(gap==POLL_CYCLES-1) state<=CONFIG_REQ;else gap<=gap+1;
                    BRPR_REQ: if(cmd_valid&&cmd_ready) state<=BRPR_RESP;
                    BRPR_RESP: if(response_valid) state<=BTR_REQ;
                    BTR_REQ: if(cmd_valid&&cmd_ready) state<=BTR_RESP;
                    BTR_RESP: if(response_valid) state<=MSR_REQ;
                    MSR_REQ: if(cmd_valid&&cmd_ready) state<=MSR_RESP;
                    MSR_RESP: if(response_valid) state<=IER_REQ;
                    IER_REQ: if(cmd_valid&&cmd_ready) state<=IER_RESP;
                    IER_RESP: if(response_valid) state<=ENABLE_REQ;
                    ENABLE_REQ: if(cmd_valid&&cmd_ready) state<=ENABLE_RESP;
                    ENABLE_RESP: if(response_valid) state<=NORMAL_REQ;
                    NORMAL_REQ: if(cmd_valid&&cmd_ready) state<=NORMAL_RESP;
                    NORMAL_RESP: if(response_valid) begin
                        last_status<=response_data;
                        if(response_data[3] && !response_data[0]) begin
                            state<=INIT_DONE;can_initialized<=1;
                        end else begin state<=NORMAL_GAP;gap<=0;end
                    end
                    NORMAL_GAP: if(gap==POLL_CYCLES-1) state<=NORMAL_REQ;else gap<=gap+1;
                    default: begin end
                endcase
            end
        end
    end
endmodule
