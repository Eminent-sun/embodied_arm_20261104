`timescale 1ns / 1ps
// Read-only, combinational view of the RX service's first-error snapshot.
// A 32-bit page avoids placing every six-axis cache field into ILA sample RAM.
module robstride_feedback_debug(
    input wire [4:0] page,
    input wire [2:0] axis,
    input wire query_valid,status_valid,fault_valid,
    input wire [7:0] motor_id,
    input wire [15:0] position_raw,velocity_raw,torque_raw,temperature_raw,
    input wire [1:0] pattern,
    input wire [5:0] error_code,feedback_timeout,
    input wire integrity_lost,mapping_valid,watchdog_config_valid,
    input wire [3:0] last_reject_reason,
    input wire [31:0] status_count,frame_count,invalid_count,timeout_count,
    input wire [31:0] fault,warning,fault_latched,warning_latched,
    input wire [63:0] time_now,last_frame_timestamp,fault_timestamp,
    input wire [31:0] id_mismatch_count,stale_count,parameter_unmatched_count,
    input wire [28:0] last_id,
    input wire [31:0] diag_isr_snapshot,diag_esr_snapshot,
    input wire [31:0] diag_ecr_snapshot,diag_sr_snapshot,
    input wire [7:0] diag_snapshot_status,
    output reg [31:0] data
);
    wire selected_timeout;
    assign selected_timeout=(axis<6)?feedback_timeout[axis]:1'b1;
    always @* begin
        data=0;
        case(page)
            0: data={2'd0,last_reject_reason,axis,watchdog_config_valid,
                mapping_valid,integrity_lost,selected_timeout,fault_valid,
                status_valid,query_valid,error_code,pattern,motor_id};
            1: data=status_count;
            2: data=frame_count;
            3: data=invalid_count;
            4: data=timeout_count;
            5: data={velocity_raw,position_raw};
            6: data={temperature_raw,torque_raw};
            7: data=fault;
            8: data=warning;
            9: data=fault_latched;
            10: data=warning_latched;
            11: data=time_now[31:0];
            12: data=time_now[63:32];
            13: data=last_frame_timestamp[31:0];
            14: data=last_frame_timestamp[63:32];
            15: data=fault_timestamp[31:0];
            16: data=fault_timestamp[63:32];
            17: data=id_mismatch_count;
            18: data=stale_count;
            19: data=parameter_unmatched_count;
            20: data={3'd0,last_id};
            21: data=diag_isr_snapshot;
            22: data=diag_esr_snapshot;
            23: data=diag_ecr_snapshot;
            24: data=diag_sr_snapshot;
            25: data={24'd0,diag_snapshot_status};
            default: data=0; // Pages26..31 are reserved.
        endcase
    end
endmodule
