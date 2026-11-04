`timescale 1ns / 1ps
// Static single-frame client. Master contract is documented in lifecycle_contract.md.
module pl_robstride_single_tx #(
    parameter [7:0] HOST_ID=8'hFD, MOTOR_ID=8'h05,
    parameter integer REG_TIMEOUT_CYCLES=1024, TX_ACCEPT_TIMEOUT_CYCLES=1024,
    parameter integer TX_RESULT_TIMEOUT_CYCLES=1000000, REPLY_TIMEOUT_CYCLES=1000000,
    parameter integer CANCEL_TIMEOUT_CYCLES=1024
)(
    input wire clk,rst_n,trigger,
    input wire [28:0] can_id,
    input wire [7:0] can_dlc,
    input wire [63:0] can_data,
    output wire param_req_valid,
    input wire param_req_ready,param_req_rejected,param_req_active,
    output wire [7:0] param_req_host,param_req_motor,
    output wire [15:0] param_req_index,
    output wire [31:0] param_req_token,
    output wire param_cancel_valid,
    input wire param_cancel_ready,param_cancel_done,param_cancel_matched,
    output wire [7:0] param_cancel_motor,
    output wire [15:0] param_cancel_index,
    output wire [31:0] param_cancel_token,
    output wire param_cancel_poison,
    input wire param_reply_valid,param_reply_failed,
    input wire [31:0] param_reply_token,
    output wire tx_req_valid,
    input wire tx_req_ready,
    output wire [28:0] tx_can_id,
    output wire [7:0] tx_can_dlc,
    output wire [63:0] tx_can_data,
    input wire tx_done,tx_success,tx_may_have_submitted,
    input wire [7:0] tx_error_code,
    output wire busy,fault_locked,
    output reg done,success,error,
    output reg [7:0] error_code,
    output wire [3:0] state
);
    localparam [3:0] IDLE=0,REGISTER=1,CHECK_REG=2,SUBMIT=3,WAIT_TX=4,
        CANCEL=5,CANCEL_RESULT=6,LOCKED=7,WAIT_REPLY=8;
    reg [3:0] st;
    reg previous,armed,poison,reply_seen,reply_failed;
    reg [31:0] ticks,next_token,token;
    reg [28:0] id;
    reg [7:0] dlc;
    reg [63:0] data;
    wire matching_reply=param_reply_valid && param_reply_token==token;
    assign state=st;
    assign busy=st!=IDLE;
    assign fault_locked=st==LOCKED;
    assign param_req_valid=st==REGISTER;
    assign param_req_host=id[15:8];
    assign param_req_motor=id[7:0];
    assign param_req_index=data[15:0];
    assign param_req_token=token;
    assign param_cancel_valid=st==CANCEL;
    assign param_cancel_motor=id[7:0];
    assign param_cancel_index=data[15:0];
    assign param_cancel_token=token;
    assign param_cancel_poison=poison;
    // An expired or consumed registration must never reach the Master.
    assign tx_req_valid=st==SUBMIT && param_req_active;
    assign tx_can_id=id;
    assign tx_can_dlc=dlc;
    assign tx_can_data=data;
    task fail_cleanup;
        input [7:0] code;
        input uncertain_tx;
        begin error_code<=code;poison<=uncertain_tx;st<=CANCEL;ticks<=0;end
    endtask
    task finish_error;
        input lock_it;
        begin done<=1;error<=1;st<=lock_it?LOCKED:IDLE;ticks<=0;end
    endtask
    always @(posedge clk) begin
        if(!rst_n) begin
            st<=IDLE;previous<=1;armed<=0;poison<=0;ticks<=0;next_token<=0;token<=0;
            id<=0;dlc<=0;data<=0;done<=0;success<=0;error<=0;error_code<=0;
            reply_seen<=0;reply_failed<=0;
        end else begin
            previous<=trigger;
            if(!trigger) armed<=1;
            done<=0;success<=0;error<=0;
            if(matching_reply && (st==WAIT_TX || st==WAIT_REPLY)) begin
                reply_seen<=1;reply_failed<=param_reply_failed;
            end
            case(st)
                IDLE: begin
                    ticks<=0;
                    if(armed && trigger && !previous) begin
                        if(HOST_ID!=8'hFD || MOTOR_ID!=8'h05 || can_id!=29'h1100FD05 ||
                           can_dlc!=8'd8 || can_data!=64'h0000000000007005) begin
                            done<=1;error<=1;error_code<=1;
                        end else begin
                            id<=can_id;dlc<=can_dlc;data<=can_data;token<=next_token;
                            next_token<=next_token+1'b1;error_code<=0;reply_seen<=0;reply_failed<=0;
                            st<=REGISTER;
                        end
                    end
                end
                REGISTER: if(param_req_ready) begin st<=CHECK_REG;ticks<=0;end
                    else if(ticks>=REG_TIMEOUT_CYCLES-1) begin error_code<=4;finish_error(0);end
                    else ticks<=ticks+1'b1;
                CHECK_REG: if(param_req_rejected) begin error_code<=2;finish_error(0);end
                    else if(!param_req_active) fail_cleanup(7,0);
                    else begin st<=SUBMIT;ticks<=0;end
                SUBMIT: if(!param_req_active) fail_cleanup(7,0);
                    else if(tx_req_ready) begin st<=WAIT_TX;ticks<=0;end
                    else if(ticks>=TX_ACCEPT_TIMEOUT_CYCLES-1) fail_cleanup(5,0);
                    else ticks<=ticks+1'b1;
                WAIT_TX: if(tx_done) begin
                        if(!tx_success) fail_cleanup(tx_error_code!=0?tx_error_code:8'd3,(tx_may_have_submitted !== 1'b0) || reply_seen || matching_reply);
                        else begin st<=WAIT_REPLY;ticks<=0;end
                    end else if(ticks>=TX_RESULT_TIMEOUT_CYCLES-1) fail_cleanup(6,1);
                    else ticks<=ticks+1'b1;
                WAIT_REPLY: if(reply_seen || matching_reply) begin
                        done<=1;success<=!(reply_failed || (matching_reply && param_reply_failed));
                        error<=reply_failed || (matching_reply && param_reply_failed);
                        if(reply_failed || (matching_reply && param_reply_failed)) error_code<=9;
                        st<=IDLE;ticks<=0;
                    end else if(!param_req_active || ticks>=REPLY_TIMEOUT_CYCLES-1) fail_cleanup(8,1);
                    else ticks<=ticks+1'b1;
                CANCEL: if(param_cancel_ready) begin st<=CANCEL_RESULT;ticks<=0;end
                    else if(ticks>=CANCEL_TIMEOUT_CYCLES-1) begin error_code<=10;finish_error(1);end
                    else ticks<=ticks+1'b1;
                CANCEL_RESULT: if(param_cancel_done) begin
                        if(!param_cancel_matched) error_code<=11;
                        finish_error(poison || !param_cancel_matched);
                    end else if(ticks>=CANCEL_TIMEOUT_CYCLES-1) begin error_code<=10;finish_error(1);end
                    else ticks<=ticks+1'b1;
                LOCKED: st<=LOCKED;
                default: begin error_code<=12;finish_error(1);end
            endcase
        end
    end
endmodule
