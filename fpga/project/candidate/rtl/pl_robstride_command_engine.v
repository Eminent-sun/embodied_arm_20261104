`timescale 1ns / 1ps
// V2.1 parameter-only client. All signals share the AXI 50 MHz clock.
// A type-2 status frame is only an acknowledgement candidate for a write;
// write success is reported solely after an exact type-17 readback.
module pl_robstride_command_engine #(
    parameter [7:0] HOST_ID = 8'hFD,
    parameter [47:0] MOTOR_IDS = 48'h060504030201,
    parameter integer REG_TIMEOUT_CYCLES = 1024,
    parameter integer TX_ACCEPT_TIMEOUT_CYCLES = 1024,
    parameter integer TX_RESULT_TIMEOUT_CYCLES = 1000000,
    parameter integer REPLY_TIMEOUT_CYCLES = 1000000,
    parameter integer CANCEL_TIMEOUT_CYCLES = 1024,
    // Explicit opt-in for an isolated, single-axis commissioning build.
    parameter integer ENABLE_PP_TEST = 0,
    parameter integer ENABLE_MULTI_PP = 0,
    // Separate opt-in: staged PP setpoint stream; legacy one-shot stays default.
    parameter integer ENABLE_PATH_PP = 0,
    // Calibration/idle hold is frozen-target only, under a renewable lease.
    parameter integer ENABLE_HOLD_PP = 0,
    parameter [31:0] PATH_WINDOW_CYCLES = 32'd3000000000,
    parameter [31:0] PATH_LEASE_CYCLES = 32'd25000000,
    parameter [31:0] PATH_POSITION_AGE_CYCLES = 32'd25000000,
    parameter integer PATH_MAX_STEP_Q16 = 6554,
    // Limits of this commissioning client, not motor rated limits.
    parameter integer PP_MAX_DELTA_Q16 = 32768,
    parameter [31:0] PP_MAX_SPEED_BITS = 32'h3F000000,
    parameter [31:0] PP_MAX_ACCEL_BITS = 32'h3F000000,
    parameter integer PP_WINDOW_CYCLES = 250000000,
    parameter integer PP_POSITION_AGE_CYCLES = 100000000
)(
    input wire clk, rst_n, start,
    input wire [28:0] command_word,
    input wire [7:0] byte_reserved,
    input wire [63:0] command_value_word,
    input wire mapping_valid, stream_integrity_lost,
    input wire [5:0] param_pending, param_poisoned,
    output wire param_req_valid,
    input wire param_req_ready, param_req_rejected, param_req_active,
    output wire [7:0] param_req_host, param_req_motor,
    output wire [15:0] param_req_index,
    output wire [31:0] param_req_token,
    output wire param_cancel_valid,
    input wire param_cancel_ready, param_cancel_done, param_cancel_matched,
    output wire [7:0] param_cancel_motor,
    output wire [15:0] param_cancel_index,
    output wire [31:0] param_cancel_token,
    output wire param_cancel_poison,
    input wire param_reply_valid, param_reply_failed,
    input wire [2:0] param_reply_axis,
    input wire [15:0] param_reply_index,
    input wire [31:0] param_reply_bits, param_reply_token,
    input wire status_event_valid,
    input wire [7:0] status_event_motor,
    input wire [5:0] status_event_error,
    output wire tx_req_valid,
    input wire tx_req_ready,
    output wire [28:0] tx_can_id,
    output wire [7:0] tx_can_dlc,
    output wire [63:0] tx_can_data,
    input wire tx_done, tx_success, tx_may_have_submitted,
    input wire [7:0] tx_error_code,
    output wire command_busy, fault_locked,
    output reg command_done, command_success, command_error,
    output reg [7:0] command_error_code,
    output reg [31:0] result_value,
    output wire [3:0] command_state,
    output wire command_start_accepted,
    output wire command_param_registered,
    output wire command_rejected
);
    localparam [3:0] IDLE=0, REGISTER=1, CHECK_REG=2, SUBMIT=3,
        WAIT_TX=4, WAIT_REPLY=5, WAIT_WRITE_ACK=6, CANCEL=7,
        CANCEL_RESULT=8, LOCKED=9, STOP_DRAIN=10, STOP_SUBMIT=11, STOP_WAIT=12, LOCAL_DONE=13;
    reg [3:0] st;
    reg prior_start, armed, read_phase, was_write, registered, uncertain;
    reg reply_seen, reply_failed_seen, status_seen, status_failed_seen;
    reg [31:0] ticks, next_token, token, latched_value, reply_bits_seen;
    reg [7:0] latched_motor;
    reg [15:0] latched_index;
    reg [2:0] latched_axis;
    reg [7:0] pending_error_code;
    wire legacy_read = command_word==29'h1100FD05 && byte_reserved==8'd8 &&
        command_value_word==64'h0000000000007005;
    wire [28:0] decoded_word = legacy_read ? {2'd0,16'h7005,3'd0,8'h05} : command_word;
    wire [7:0] decoded_byte = legacy_read ? 8'd0 : byte_reserved;
    wire [7:0] motor_id=decoded_word[7:0];
    wire [2:0] cmd_op=decoded_word[10:8];
    wire [15:0] parameter_index=decoded_word[26:11];
    wire [1:0] command_reserved=decoded_word[28:27];
    wire [31:0] parameter_value=command_value_word[31:0];
    wire [31:0] value_reserved=command_value_word[63:32];
    reg [2:0] latched_op;
    wire mapped;
    wire [2:0] mapped_axis;
    reg [5:0] active_mask, used_mask, mode_mask, speed_mask, accel_mask;
    reg [5:0] position_mask, preload_mask, staged_mask;
    reg [31:0] positions[0:5], ages[0:5], staged_targets[0:5], staged_position[0:5];
    reg stop_wait_tx, stop_lock, manual_stop_seen, stop_failed;
    reg [2:0] stop_axis, batch_axis;
    reg batch_running;
    reg [31:0] actuation_ticks;
    reg path_mode;
    reg hold_mode;
    reg [31:0] hold_sequence;
    reg [31:0] path_sequence, path_pending_sequence, path_lease_ticks;
    reg [31:0] path_last_targets[0:5];
    integer ai;
    wire actuation_active=active_mask[mapped_axis];
    wire target_used=used_mask[mapped_axis];
    wire mode_verified=mode_mask[mapped_axis];
    wire speed_verified=speed_mask[mapped_axis];
    wire accel_verified=accel_mask[mapped_axis];
    wire position_valid=position_mask[mapped_axis];
    wire target_preloaded=preload_mask[mapped_axis];
    wire [31:0] position_bits=positions[mapped_axis];
    wire [31:0] position_age=ages[mapped_axis];
    wire pp_address=ENABLE_MULTI_PP!=0 ? mapped : motor_id==5;
    reg [7:0] stop_reason;
    wire start_edge = armed && start && !prior_start;
    wire status_match = status_event_valid && status_event_motor==latched_motor;
    function signed [31:0] position_q16;
        input [31:0] bits;
        reg [31:0] magnitude;
        begin
            magnitude=0;
            if(bits[30:23]>=111 && bits[30:23]<131)
                magnitude={8'd0,1'b1,bits[22:0]} >> (134-bits[30:23]);
            position_q16=bits[31] ? -$signed(magnitude) : $signed(magnitude);
        end
    endfunction
    wire signed [31:0] position_delta=position_q16(parameter_value)-position_q16(position_bits);
    wire position_fresh=position_valid && position_age<PP_POSITION_AGE_CYCLES;
    // Both positions must be finite and inside (-16,16) rad. Positive and
    // negative 0.5-rad bounds are checked in Q16.16.
    wire target_in_bounds=position_fresh && parameter_value[30:23]<131 &&
        position_delta<=PP_MAX_DELTA_Q16 && position_delta>=-PP_MAX_DELTA_Q16;
    wire pp_target_write=ENABLE_PP_TEST!=0 && pp_address &&
        parameter_index==16'h7016 && target_in_bounds &&
        (ENABLE_MULTI_PP!=0 ? ((active_mask==0 || (hold_mode && !actuation_active)) && position_delta<=64 && position_delta>=-64) :
        (!actuation_active || !target_used));
    wire multi_limit_ok=ENABLE_MULTI_PP==0 ||
        (!parameter_value[31] && parameter_value>=32'h3DCCCCCD &&
        ((parameter_index==16'h7024 && parameter_value<=PP_MAX_SPEED_BITS) ||
         (parameter_index==16'h7025 && parameter_value<=PP_MAX_ACCEL_BITS)));
    wire write_index_allowed=(valid_float_write_index(parameter_index) && multi_limit_ok &&
        (active_mask==0 || ENABLE_PP_TEST==0 || (hold_mode && !actuation_active &&
         (parameter_index==16'h7024 || parameter_index==16'h7025)))) || pp_target_write;
    wire pp_mode_write=ENABLE_PP_TEST!=0 && !actuation_active && pp_address &&
        parameter_index==16'h7005 && parameter_value==1;
    // Preload a verified current-position reference before allowing enable.
    wire pp_enable=ENABLE_PP_TEST!=0 && pp_address && parameter_index==0 &&
        parameter_value==32'h50505431 && !actuation_active && mode_verified &&
        speed_verified && accel_verified && target_preloaded && position_fresh &&
        (!hold_mode || position_age<PATH_POSITION_AGE_CYCLES);
    wire pp_disable=ENABLE_PP_TEST!=0 && pp_address && parameter_index==0 && parameter_value==0;
    wire signed [31:0] path_stage_delta=position_q16(parameter_value)-position_q16(path_last_targets[mapped_axis]);
    wire path_stage_allowed=ENABLE_PATH_PP!=0 && path_mode &&
        (active_mask==0 || (active_mask==6'h3F && used_mask==6'h3F)) &&
        !staged_mask[mapped_axis] && preload_mask[mapped_axis] &&
        ages[mapped_axis]<PATH_POSITION_AGE_CYCLES &&
        path_stage_delta<=PATH_MAX_STEP_Q16 && path_stage_delta>=-PATH_MAX_STEP_Q16;
    wire stage_target=ENABLE_PP_TEST!=0 && ENABLE_MULTI_PP!=0 && cmd_op==5 &&
        parameter_index==16'h7016 && target_in_bounds &&
        ((!path_mode && !hold_mode && active_mask==0) || path_stage_allowed);
    reg batch_fresh;
    reg path_positions_fresh;
    reg held_positions_fresh;
    integer bi;
    always @* begin
        batch_fresh=1;
        path_positions_fresh=1;
        held_positions_fresh=1;
        for(bi=0;bi<6;bi=bi+1)
            begin
                if(!position_mask[bi] || ages[bi]>=PP_POSITION_AGE_CYCLES ||
                    staged_position[bi]!=positions[bi]) batch_fresh=0;
                if(!position_mask[bi] || ages[bi]>=PATH_POSITION_AGE_CYCLES) path_positions_fresh=0;
                if(active_mask[bi] && (!position_mask[bi] || ages[bi]>=PATH_POSITION_AGE_CYCLES)) held_positions_fresh=0;
            end
    end
    wire batch_commit=ENABLE_PP_TEST!=0 && ENABLE_MULTI_PP!=0 && cmd_op==6 &&
        motor_id==MOTOR_IDS[7:0] && parameter_index==0 && parameter_value==32'h53495831 &&
        staged_mask==6'h3F && active_mask==6'h3F && mode_mask==6'h3F &&
        speed_mask==6'h3F && accel_mask==6'h3F && preload_mask==6'h3F &&
        used_mask==0 && batch_fresh && param_pending==0 && param_poisoned==0 && !path_mode && !hold_mode;
    wire path_arm=ENABLE_PATH_PP!=0 && ENABLE_PP_TEST!=0 && ENABLE_MULTI_PP!=0 && cmd_op==7 &&
        motor_id==MOTOR_IDS[7:0] && parameter_index==0 && parameter_value==32'h54524A31 &&
        active_mask==0 && !hold_mode && param_pending==0 && param_poisoned==0;
    wire path_commit=ENABLE_PATH_PP!=0 && path_mode && cmd_op==7 &&
        motor_id==MOTOR_IDS[7:0] && parameter_index==1 && parameter_value!=0 &&
        path_sequence!=32'hFFFFFFFF && parameter_value==path_sequence+1'b1 &&
        staged_mask==6'h3F && active_mask==6'h3F && mode_mask==6'h3F &&
        speed_mask==6'h3F && accel_mask==6'h3F && preload_mask==6'h3F &&
        (path_sequence==0 ? (used_mask==0 || used_mask==6'h3F) : used_mask==6'h3F) &&
        batch_fresh && path_positions_fresh && param_pending==0 && param_poisoned==0;
    wire hold_arm=ENABLE_HOLD_PP!=0 && ENABLE_PATH_PP!=0 && ENABLE_MULTI_PP!=0 &&
        ENABLE_PP_TEST!=0 && cmd_op==7 && motor_id==MOTOR_IDS[7:0] &&
        parameter_index==2 && parameter_value==32'h484C4431 && param_pending==0 && param_poisoned==0 &&
        (active_mask==0 || (path_mode && active_mask==6'h3F && used_mask==6'h3F && staged_mask==0 && path_positions_fresh));
    wire hold_renew=ENABLE_HOLD_PP!=0 && hold_mode && cmd_op==7 && motor_id==MOTOR_IDS[7:0] &&
        parameter_index==3 && parameter_value!=0 && hold_sequence!=32'hFFFFFFFF && parameter_value==hold_sequence+1'b1 &&
        held_positions_fresh && param_pending==0 && param_poisoned==0;
    wire held_path_arm=ENABLE_HOLD_PP!=0 && hold_mode && cmd_op==7 && motor_id==MOTOR_IDS[7:0] &&
        parameter_index==4 && parameter_value==32'h54524A31 && active_mask==6'h3F &&
        mode_mask==6'h3F && speed_mask==6'h3F && accel_mask==6'h3F && preload_mask==6'h3F &&
        staged_mask==0 && path_positions_fresh && param_pending==0 && param_poisoned==0;
    wire operation_allowed=(cmd_op==0 && valid_read_index(parameter_index)) ||
        (cmd_op==1 && write_index_allowed) || (cmd_op==2 && pp_mode_write) ||
        (cmd_op==3 && pp_enable) || stage_target || batch_commit || path_arm || path_commit || hold_arm || hold_renew || held_path_arm;
    // The A5 stop marker bypasses normal command/start admission and also works
    // while the client is waiting or locked. It does not clear any CAN errors.
    wire manual_stop=ENABLE_PP_TEST!=0 && byte_reserved==8'hA5 && !manual_stop_seen;
    wire explicit_recover=ENABLE_PP_TEST!=0 && ENABLE_MULTI_PP!=0 && st==LOCKED &&
        byte_reserved==8'h5A && active_mask==0 && mapping_valid && !stream_integrity_lost &&
        param_pending==0 && param_poisoned==0 &&
        (command_error_code==8'hE0 || command_error_code==8'hE1);
    wire ordinary_stop=st==IDLE && start_edge && cmd_op==4 && pp_disable &&
        command_reserved==0 && decoded_byte==0 && value_reserved==0;
    wire in_stop=st==STOP_DRAIN || st==STOP_SUBMIT || st==STOP_WAIT;
    wire watchdog_stop=active_mask!=0 &&
        ((hold_mode ? (path_lease_ticks>=PATH_LEASE_CYCLES-1 || !held_positions_fresh || command_rejected) :
          path_mode ? (actuation_ticks>=PATH_WINDOW_CYCLES-1 || path_lease_ticks>=PATH_LEASE_CYCLES-1 ||
                      !path_positions_fresh || command_rejected) : actuation_ticks>=PP_WINDOW_CYCLES-1) ||
        stream_integrity_lost || (status_event_valid && status_event_error!=0 &&
        (ENABLE_MULTI_PP!=0 || status_event_motor==5)) || (ENABLE_MULTI_PP!=0 && st==LOCKED));
    // Compatibility is deliberately limited to the previously documented
    // read-only motor-5 run_mode query. Never pass arbitrary raw frames.
    // These indices and types come from the vendor's private-protocol table.
    // No model range or physical-unit conversion is performed here.
    function valid_read_index;
        input [15:0] idx;
        begin
            case(idx)
                16'h7005,16'h7006,16'h700A,16'h700B,16'h7010,16'h7011,
                16'h7014,16'h7016,16'h7017,16'h7018,16'h7019,16'h701A,
                16'h701B,16'h701C,16'h701E,16'h701F,16'h7020,16'h7021,
                16'h7022,16'h7024,16'h7025,16'h7026,16'h7028,16'h7029,
                16'h702B: valid_read_index=1;
                default: valid_read_index=0;
            endcase
        end
    endfunction
    function valid_float_write_index;
        input [15:0] idx;
        begin
            case(idx)
                // Direct current, speed and position references are excluded.
                // Zero offset is also excluded from this parameter-only mode.
                16'h700B,16'h7010,16'h7011,16'h7014,16'h7017,16'h7018,
                16'h701E,16'h701F,16'h7020,16'h7021,16'h7022,
                16'h7024,16'h7025:
                    valid_float_write_index=1;
                default: valid_float_write_index=0;
            endcase
        end
    endfunction
    wire reply_match = param_reply_valid && param_reply_token==token &&
        param_reply_axis==latched_axis && param_reply_index==latched_index;
    wire [31:0] verified_bits=reply_match ? param_reply_bits : reply_bits_seen;
    wire signed [31:0] verified_q16=position_q16(verified_bits);
    wire signed [31:0] requested_q16=position_q16(latched_value);
    wire signed [31:0] cached_q16=position_q16(positions[latched_axis]);
    wire signed [31:0] readback_delta=verified_q16-requested_q16;
    wire signed [31:0] readback_from_current=verified_q16-cached_q16;
    // A client acceptance bound, not an assumption about motor quantization.
    // Retain the original 64-Q16-unit (~0.001rad) preload criterion, but
    // apply it to the ACTUAL readback rather than the requested value.
    wire bounded_position_reply=ENABLE_MULTI_PP!=0 && ENABLE_PP_TEST!=0 &&
        was_write && latched_index==16'h7016 && verified_bits[30:23]<131 &&
        position_mask[latched_axis] && ages[latched_axis]<PP_POSITION_AGE_CYCLES &&
        readback_delta<=64 && readback_delta>=-64 &&
        readback_from_current<=PP_MAX_DELTA_Q16 && readback_from_current>=-PP_MAX_DELTA_Q16;
    wire signed [31:0] path_readback_delta=verified_q16-position_q16(path_last_targets[latched_axis]);
    wire path_readback_ok=!path_mode || !was_write || latched_index!=16'h7016 || !active_mask[latched_axis] ||
        (verified_bits[30:23]<131 && path_readback_delta<=PATH_MAX_STEP_Q16 && path_readback_delta>=-PATH_MAX_STEP_Q16);
    wire write_value_matches=((latched_value==verified_bits) || bounded_position_reply) && path_readback_ok;
    robstride_axis_map #(.CONFIG_ENABLE(1), .HOST_ID(HOST_ID),
        .MOTOR_IDS(MOTOR_IDS)) axis_map(.motor_id(motor_id),
        .config_valid(), .mapped(mapped), .axis(mapped_axis));

    assign command_state=st;
    assign command_busy=(st!=IDLE && st!=LOCKED);
    assign fault_locked=(st==LOCKED);
    assign command_start_accepted=explicit_recover || ordinary_stop || (st==IDLE && start_edge && mapped &&
        operation_allowed && mapping_valid &&
        !stream_integrity_lost && !param_pending[mapped_axis] &&
        !param_poisoned[mapped_axis] && command_reserved==0 &&
        decoded_byte==0 && value_reserved==0);
    assign command_rejected=(st==IDLE && start_edge && !command_start_accepted);
    assign command_param_registered=(st==CHECK_REG && !param_req_rejected && param_req_active);
    assign param_req_valid=(st==REGISTER);
    assign param_req_host=HOST_ID;
    assign param_req_motor=latched_motor;
    assign param_req_index=latched_index;
    assign param_req_token=token;
    assign param_cancel_valid=(st==CANCEL);
    assign param_cancel_motor=latched_motor;
    assign param_cancel_index=latched_index;
    assign param_cancel_token=token;
    assign param_cancel_poison=uncertain;
    assign tx_req_valid=((st==SUBMIT) && (!read_phase || param_req_active)) || st==STOP_SUBMIT;
    wire [7:0] stop_motor=ENABLE_MULTI_PP!=0 ? MOTOR_IDS[stop_axis*8 +: 8] : 8'h05;
    assign tx_can_id=st==STOP_SUBMIT || st==STOP_WAIT ? {5'h04,8'h00,HOST_ID,stop_motor} :
        {read_phase ? 5'h11 : latched_op==3 ? 5'h03 : 5'h12, 8'h00, HOST_ID, latched_motor};
    assign tx_can_dlc=8'd8;
    assign tx_can_data=(in_stop || latched_op==3) ? 64'd0 : read_phase ? {48'd0,latched_index} :
        {latched_value,16'd0,latched_index};

    always @(posedge clk) begin
        if(!rst_n) begin
            st<=IDLE;prior_start<=1;armed<=0;read_phase<=0;was_write<=0;
            registered<=0;uncertain<=0;reply_seen<=0;reply_failed_seen<=0;
            status_seen<=0;status_failed_seen<=0;reply_bits_seen<=0;
            ticks<=0;next_token<=0;token<=0;latched_value<=0;
            latched_motor<=0;latched_index<=0;latched_axis<=0;
            pending_error_code<=0;command_done<=0;command_success<=0;
            command_error<=0;command_error_code<=0;result_value<=0;
            latched_op<=0;active_mask<=0;used_mask<=0;mode_mask<=0;
            speed_mask<=0;accel_mask<=0;position_mask<=0;preload_mask<=0;staged_mask<=0;
            stop_axis<=0;stop_failed<=0;batch_axis<=0;batch_running<=0;
            path_mode<=0;path_sequence<=0;path_pending_sequence<=0;path_lease_ticks<=0;
            hold_mode<=0;hold_sequence<=0;
            for(ai=0;ai<6;ai=ai+1) path_last_targets[ai]<=0;
            for(ai=0;ai<6;ai=ai+1) begin positions[ai]<=0;ages[ai]<=0;staged_targets[ai]<=0;staged_position[ai]<=0;end
            stop_wait_tx<=0;stop_lock<=0;
                actuation_ticks<=0;stop_reason<=0;manual_stop_seen<=0;
        end else begin
            prior_start<=start;
            if(!start) armed<=1;
            if(byte_reserved!=8'hA5) manual_stop_seen<=0;
            else if(manual_stop) manual_stop_seen<=1;
            if(in_stop && manual_stop) begin stop_lock<=1;stop_reason<=8'hE0;end
            for(ai=0;ai<6;ai=ai+1)
                if(position_mask[ai] && ages[ai]<PP_POSITION_AGE_CYCLES) ages[ai]<=ages[ai]+1'b1;
            if(active_mask!=0 && !hold_mode && actuation_ticks<(path_mode ? PATH_WINDOW_CYCLES : PP_WINDOW_CYCLES)) actuation_ticks<=actuation_ticks+1'b1;
            if(active_mask!=0 && (path_mode || hold_mode) && path_lease_ticks<PATH_LEASE_CYCLES) path_lease_ticks<=path_lease_ticks+1'b1;
            if(reply_match && (st==WAIT_TX || st==WAIT_REPLY) && read_phase) begin
                reply_seen<=1;reply_failed_seen<=param_reply_failed;
                reply_bits_seen<=param_reply_bits;
            end
            if(status_match && (st==WAIT_TX || st==WAIT_WRITE_ACK) && !read_phase) begin
                status_seen<=1;status_failed_seen<=status_event_error!=0;
            end
            if(!in_stop && (manual_stop || ordinary_stop || watchdog_stop || explicit_recover)) begin
                stop_wait_tx<=(st==WAIT_TX && !tx_done) ||
                    (st==SUBMIT && tx_req_valid && tx_req_ready);
                stop_lock<=manual_stop || watchdog_stop || !(ordinary_stop || explicit_recover);
                stop_reason<=manual_stop ? 8'hE0 : watchdog_stop ? 8'hE1 : 8'd0;
                active_mask<=0;preload_mask<=0;position_mask<=0;
                mode_mask<=0;speed_mask<=0;accel_mask<=0;staged_mask<=0;
                batch_running<=0;stop_axis<=0;stop_failed<=0;
                path_mode<=0;path_sequence<=0;path_pending_sequence<=0;path_lease_ticks<=0;
                hold_mode<=0;hold_sequence<=0;
                if(explicit_recover) begin
                    used_mask<=0;registered<=0;uncertain<=0;
                    reply_seen<=0;reply_failed_seen<=0;status_seen<=0;status_failed_seen<=0;
                    result_value<=0;
                end
                command_done<=0;command_success<=0;command_error<=0;
                ticks<=0;st<=STOP_DRAIN;
            end else case(st)
                IDLE: begin
                    ticks<=0;
                    if(start_edge) begin
                        command_done<=0;command_success<=0;command_error<=0;
                        command_error_code<=0;result_value<=0;
                        if(!mapped || !mapping_valid) begin
                            command_done<=1;command_error<=1;command_error_code<=8'h01;
                        end else if(!operation_allowed ||
                            command_reserved!=0 || decoded_byte!=0 || value_reserved!=0) begin
                            command_done<=1;command_error<=1;command_error_code<=8'h02;
                        end else if(stream_integrity_lost || param_poisoned[mapped_axis] ||
                            param_pending[mapped_axis]) begin
                            command_done<=1;command_error<=1;command_error_code<=8'h03;
                        end else begin
                            latched_motor<=motor_id;latched_axis<=mapped_axis;
                            latched_index<=parameter_index;latched_value<=parameter_value;
                            latched_op<=cmd_op;
                            token<=next_token;next_token<=next_token+1'b1;
                            read_phase<=cmd_op==0;was_write<=cmd_op==1 || cmd_op==2;
                            if(cmd_op==3) begin active_mask[mapped_axis]<=1;if(active_mask==0) begin actuation_ticks<=0;path_lease_ticks<=0;end used_mask[mapped_axis]<=0;end
                            if(cmd_op==1 && parameter_index==16'h7016 && actuation_active) used_mask[mapped_axis]<=1;
                            if(cmd_op==2) mode_mask[mapped_axis]<=0;
                            registered<=0;uncertain<=0;
                            reply_seen<=0;reply_failed_seen<=0;status_seen<=0;
                            status_failed_seen<=0;
                            if(hold_arm) begin
                                hold_mode<=1;path_mode<=0;hold_sequence<=0;path_lease_ticks<=0;
                                if(active_mask==0) begin
                                    mode_mask<=0;speed_mask<=0;accel_mask<=0;position_mask<=0;preload_mask<=0;staged_mask<=0;used_mask<=0;
                                end
                                result_value<=0;st<=LOCAL_DONE;
                            end else if(hold_renew) begin
                                hold_sequence<=parameter_value;path_lease_ticks<=0;result_value<=parameter_value;st<=LOCAL_DONE;
                            end else if(held_path_arm) begin
                                hold_mode<=0;path_mode<=1;path_sequence<=0;path_pending_sequence<=0;
                                path_lease_ticks<=0;actuation_ticks<=0;used_mask<=6'h3F;
                                result_value<=0;st<=LOCAL_DONE;
                            end else if(path_arm) begin
                                path_mode<=1;path_sequence<=0;path_pending_sequence<=0;path_lease_ticks<=0;
                                mode_mask<=0;speed_mask<=0;accel_mask<=0;position_mask<=0;preload_mask<=0;staged_mask<=0;used_mask<=0;
                                result_value<=0;st<=LOCAL_DONE;
                            end else if(stage_target) begin
                                staged_targets[mapped_axis]<=parameter_value;staged_mask[mapped_axis]<=1;
                                staged_position[mapped_axis]<=positions[mapped_axis];
                                st<=LOCAL_DONE;
                            end else if(batch_commit || path_commit) begin
                                batch_running<=1;batch_axis<=0;staged_mask<=0;
                                if(path_commit) path_pending_sequence<=parameter_value;
                                latched_motor<=MOTOR_IDS[7:0];latched_axis<=0;
                                latched_index<=16'h7016;latched_value<=staged_targets[0];
                                latched_op<=1;read_phase<=0;was_write<=1;used_mask[0]<=1;
                                st<=SUBMIT;
                            end else st<=cmd_op==0 ? REGISTER : SUBMIT;
                        end
                    end
                end
                REGISTER: begin
                    if(param_req_ready) begin st<=CHECK_REG;ticks<=0;end
                    else if(ticks>=REG_TIMEOUT_CYCLES-1) begin
                        command_done<=1;command_error<=1;command_error_code<=8'h04;st<=LOCKED;
                    end else ticks<=ticks+1'b1;
                end
                CHECK_REG: begin
                    if(param_req_rejected) begin
                        command_done<=1;command_error<=1;command_error_code<=8'h05;
                        st<=was_write ? LOCKED : IDLE;
                    end else if(!param_req_active) begin
                        pending_error_code<=8'h06;uncertain<=0;st<=CANCEL;ticks<=0;
                    end else begin registered<=1;st<=SUBMIT;ticks<=0;end
                end
                SUBMIT: begin
                    if(stream_integrity_lost || (read_phase && !param_req_active)) begin
                        pending_error_code<=8'h07;uncertain<=0;
                        if(registered) st<=CANCEL;
                        else begin command_done<=1;command_error<=1;command_error_code<=8'h07;st<=LOCKED;end
                        ticks<=0;
                    end else if(tx_req_valid && tx_req_ready) begin st<=WAIT_TX;ticks<=0;end
                    else if(ticks>=TX_ACCEPT_TIMEOUT_CYCLES-1) begin
                        pending_error_code<=8'h08;uncertain<=0;
                        if(registered) st<=CANCEL;
                        else begin command_done<=1;command_error<=1;command_error_code<=8'h08;
                            st<=was_write ? LOCKED : IDLE;end
                        ticks<=0;
                    end else ticks<=ticks+1'b1;
                end
                WAIT_TX: begin
                    if(tx_done) begin
                        if(!tx_success) begin
                            pending_error_code<=8'h20 | tx_error_code;
                            uncertain<=tx_may_have_submitted;
                            if(registered) st<=CANCEL;
                            else begin
                                command_done<=1;command_error<=1;
                                command_error_code<=8'h20 | tx_error_code;
                                st<=(was_write || tx_may_have_submitted) ? LOCKED : IDLE;
                            end
                            ticks<=0;
                        end else begin
                            st<=read_phase ? WAIT_REPLY : WAIT_WRITE_ACK;
                            ticks<=0;
                        end
                    end else if(ticks>=TX_RESULT_TIMEOUT_CYCLES-1) begin
                        pending_error_code<=8'h30;uncertain<=1;
                        if(registered) st<=CANCEL;
                        else begin command_done<=1;command_error<=1;
                            command_error_code<=8'h30;st<=LOCKED;end
                        ticks<=0;
                    end else ticks<=ticks+1'b1;
                end
                WAIT_WRITE_ACK: begin
                    if(status_seen || status_match) begin
                        if(status_failed_seen || (status_match && status_event_error!=0)) begin
                            command_done<=1;command_error<=1;
                            command_error_code<=8'h31;st<=LOCKED;
                        end else begin
                            if(latched_op==3) begin
                                command_done<=1;command_success<=1;command_error<=0;st<=IDLE;
                            end else begin
                                read_phase<=1;status_seen<=0;reply_seen<=0;
                                registered<=0;st<=REGISTER;
                            end
                            ticks<=0;
                        end
                    end else if(stream_integrity_lost || ticks>=REPLY_TIMEOUT_CYCLES-1) begin
                        command_done<=1;command_error<=1;
                        command_error_code<=stream_integrity_lost ? 8'h32 : 8'h33;
                        st<=LOCKED;
                    end else ticks<=ticks+1'b1;
                end
                WAIT_REPLY: begin
                    if(reply_seen || reply_match) begin
                        if(reply_failed_seen || (reply_match && param_reply_failed)) begin
                            command_done<=1;command_error<=1;command_error_code<=8'h40;
                            st<=was_write ? LOCKED : IDLE;
                        end else if(was_write &&
                            !write_value_matches) begin
                            command_done<=1;command_error<=1;command_error_code<=8'h41;
                            st<=LOCKED;
                        end else begin
                            result_value<=reply_match ? param_reply_bits : reply_bits_seen;
                            command_done<=1;command_success<=1;command_error<=0;
                            if(ENABLE_PP_TEST!=0 && (ENABLE_MULTI_PP!=0 || latched_motor==5)) begin
                                if(latched_index==16'h7005)
                                    mode_mask[latched_axis]<=(reply_match ? param_reply_bits : reply_bits_seen)==1;
                                if(!was_write && latched_index==16'h7019) begin
                                    positions[latched_axis]<=reply_match ? param_reply_bits : reply_bits_seen;
                                    position_mask[latched_axis]<=(reply_match ? param_reply_bits[30:23] : reply_bits_seen[30:23])<131;
                                    ages[latched_axis]<=0;
                                    if((!path_mode && !hold_mode) || !active_mask[latched_axis]) preload_mask[latched_axis]<=0;
                                end
                                if(was_write && latched_index==16'h7024)
                                    speed_mask[latched_axis]<=!latched_value[31] && latched_value>=32'h3DCCCCCD && latched_value<=PP_MAX_SPEED_BITS;
                                if(was_write && latched_index==16'h7025)
                                    accel_mask[latched_axis]<=!latched_value[31] && latched_value>=32'h3DCCCCCD && latched_value<=PP_MAX_ACCEL_BITS;
                                if(was_write && latched_index==16'h7016 && !active_mask[latched_axis])
                                    preload_mask[latched_axis]<=(ENABLE_MULTI_PP!=0 ? readback_from_current<=64 && readback_from_current>=-64 :
                                        position_q16(latched_value)-position_q16(positions[latched_axis])<=64 &&
                                        position_q16(latched_value)-position_q16(positions[latched_axis])>=-64);
                                if((path_mode || hold_mode) && was_write && latched_index==16'h7016)
                                    path_last_targets[latched_axis]<=verified_bits;
                            end
                        end
                        if(!was_write &&
                            !(reply_failed_seen || (reply_match && param_reply_failed)))
                            st<=IDLE;
                        else if(was_write &&
                            !(reply_failed_seen || (reply_match && param_reply_failed)) &&
                            write_value_matches)
                            st<=IDLE;
                        if(batch_running && !(reply_failed_seen || (reply_match && param_reply_failed)) &&
                            write_value_matches) begin
                            if(batch_axis==5) begin
                                batch_running<=0;st<=IDLE;
                                if(path_mode) begin path_sequence<=path_pending_sequence;path_lease_ticks<=0;result_value<=path_pending_sequence;end
                            end
                            else begin
                                batch_axis<=batch_axis+1'b1;latched_axis<=batch_axis+1'b1;
                                latched_motor<=MOTOR_IDS[(batch_axis+1)*8 +: 8];
                                latched_value<=staged_targets[batch_axis+1];
                                used_mask[batch_axis+1]<=1;token<=next_token;next_token<=next_token+1'b1;
                                read_phase<=0;reply_seen<=0;reply_failed_seen<=0;status_seen<=0;status_failed_seen<=0;
                                command_done<=0;command_success<=0;st<=SUBMIT;
                            end
                        end
                        registered<=0;ticks<=0;
                    end else if(stream_integrity_lost || !param_req_active ||
                        ticks>=REPLY_TIMEOUT_CYCLES-1) begin
                        pending_error_code<=8'h42;uncertain<=1;st<=CANCEL;ticks<=0;
                    end else ticks<=ticks+1'b1;
                end
                CANCEL: begin
                    if(param_cancel_ready) begin st<=CANCEL_RESULT;ticks<=0;end
                    else if(ticks>=CANCEL_TIMEOUT_CYCLES-1) begin
                        command_done<=1;command_error<=1;command_error_code<=8'h50;st<=LOCKED;
                    end else ticks<=ticks+1'b1;
                end
                CANCEL_RESULT: begin
                    if(param_cancel_done) begin
                        command_done<=1;command_error<=1;
                        command_error_code<=param_cancel_matched ? pending_error_code : 8'h51;
                        st<=(was_write || uncertain || !param_cancel_matched) ? LOCKED : IDLE;
                        registered<=0;
                    end else if(ticks>=CANCEL_TIMEOUT_CYCLES-1) begin
                        command_done<=1;command_error<=1;command_error_code<=8'h50;st<=LOCKED;
                    end else ticks<=ticks+1'b1;
                end
                LOCAL_DONE: begin command_done<=1;command_success<=1;st<=IDLE;end
                LOCKED: st<=LOCKED;
                STOP_DRAIN: begin
                    if(!stop_wait_tx || tx_done) begin ticks<=0;st<=STOP_SUBMIT;end
                    else if(ticks>=TX_RESULT_TIMEOUT_CYCLES-1) begin
                        command_done<=1;command_error<=1;command_error_code<=8'hE2;st<=LOCKED;
                    end else ticks<=ticks+1'b1;
                end
                STOP_SUBMIT: begin
                    if(tx_req_ready) begin ticks<=0;st<=STOP_WAIT;end
                    else if(ticks>=TX_ACCEPT_TIMEOUT_CYCLES-1) begin
                        if(ENABLE_MULTI_PP!=0 && stop_axis<5) begin
                            stop_axis<=stop_axis+1'b1;stop_failed<=1;ticks<=0;st<=STOP_SUBMIT;
                        end else begin command_done<=1;command_error<=1;command_error_code<=8'hE2;st<=LOCKED;end
                    end else ticks<=ticks+1'b1;
                end
                STOP_WAIT: begin
                    if(tx_done) begin
                        if(ENABLE_MULTI_PP!=0 && stop_axis<5) begin
                            stop_axis<=stop_axis+1'b1;stop_failed<=stop_failed || !tx_success;
                            ticks<=0;st<=STOP_SUBMIT;
                        end else begin
                            command_done<=1;command_success<=tx_success && !stop_failed && !stop_lock && !manual_stop;
                            command_error<=!tx_success || stop_failed || stop_lock || manual_stop;
                            command_error_code<=tx_success && !stop_failed ? (manual_stop ? 8'hE0 : stop_reason) : 8'hE2;
                            st<=tx_success && !stop_failed && !stop_lock && !manual_stop ? IDLE : LOCKED;
                        end
                    end else if(ticks>=TX_RESULT_TIMEOUT_CYCLES-1) begin
                        if(ENABLE_MULTI_PP!=0 && stop_axis<5) begin
                            stop_axis<=stop_axis+1'b1;stop_failed<=1;ticks<=0;st<=STOP_SUBMIT;
                        end else begin command_done<=1;command_error<=1;command_error_code<=8'hE2;st<=LOCKED;end
                    end else ticks<=ticks+1'b1;
                end
                default: begin st<=LOCKED;command_done<=1;command_error<=1;command_error_code<=8'h7F;end
            endcase
        end
    end
endmodule
