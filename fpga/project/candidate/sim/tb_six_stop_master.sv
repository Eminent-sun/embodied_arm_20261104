`timescale 1ns/1ps
module tb_six_stop_master;
    reg clk=0; always #10 clk=~clk;
    reg rst_n=0,trigger=0,stage3_start=0;
    reg [28:0] frame_id=29'h0380C805;
    reg [7:0] frame_dlc=8'd0;
    reg [63:0] frame_data=64'd0;
    reg reject_registration=0;
    reg no_txok=0,can_error=0;
    reg [31:0] fail_write_index=32'hFFFFFFFF;
    wire preg_valid,preg_ready,preg_rejected,preg_active;
    wire [7:0] preg_host,preg_motor;
    wire [15:0] preg_index;
    wire [31:0] preg_token;
    wire cancel_valid,cancel_ready,cancel_done,cancel_matched,cancel_poison;
    wire [7:0] cancel_motor;
    wire [15:0] cancel_index;
    wire [31:0] cancel_token;
    wire request_valid,request_ready;
    wire [28:0] request_id;
    wire [7:0] request_dlc;
    wire [63:0] request_data;
    wire master_done,master_success,master_error,master_timeout,master_maybe;
    wire [7:0] master_error_code;
    wire client_busy,client_locked,client_done,client_success,client_error;
    wire [7:0] client_error_code;
    wire [3:0] client_state,tx_state;
    wire tx_busy,tx_fifo_write_done,tx_success,tx_error,tx_timeout,tx_may_pending;
    wire [31:0] tx_success_count,tx_error_count,enqueued_count;
    wire [2:0] scheduler_state;
    reg param_pending=0,param_rejected_reg=0,cancel_done_reg=0;
    reg [31:0] registered_token=0;
    reg reply_valid=0;
    reg [31:0] reply_bits=32'h3F800000;
    reg status_event_valid=0;
    wire [31:0] reply_token=registered_token;
    integer req_accept_count=0,reg_accept_count=0,result_count=0;

    wire [31:0] awaddr,wdata,araddr,rdata;
    wire [3:0] wstrb;
    wire awvalid,awready,wvalid,wready,bvalid,bready,arvalid,arready,rvalid,rready;
    wire [1:0] bresp,rresp;
    integer write_count,read_count,slave_enqueued,protocol_errors,reset_count;

    assign preg_ready=rst_n && !param_pending;
    assign preg_rejected=param_rejected_reg;
    assign preg_active=param_pending;
    assign cancel_ready=rst_n;
    assign cancel_done=cancel_done_reg;
    assign cancel_matched=cancel_done_reg;
    always @(posedge clk) begin
        if(!rst_n) begin
            param_pending<=0;param_rejected_reg<=0;cancel_done_reg<=0;
            registered_token<=0;req_accept_count<=0;reg_accept_count<=0;result_count<=0;
        end else begin
            param_rejected_reg<=0;cancel_done_reg<=0;
            if(preg_valid && preg_ready) begin
                reg_accept_count<=reg_accept_count+1;
                param_rejected_reg<=reject_registration;
                if(!reject_registration) begin
                    param_pending<=1;registered_token<=preg_token;
                end
            end
            if(cancel_valid && cancel_ready) begin
                cancel_done_reg<=1;param_pending<=0;
            end
            if(reply_valid) param_pending<=0;
            if(request_valid && request_ready) req_accept_count<=req_accept_count+1;
            if(master_done) result_count<=result_count+1;
        end
    end

    pl_robstride_command_engine #(.ENABLE_PP_TEST(1),.ENABLE_MULTI_PP(1),.PP_WINDOW_CYCLES(3000),.PP_POSITION_AGE_CYCLES(10000),.REG_TIMEOUT_CYCLES(40),
        .TX_ACCEPT_TIMEOUT_CYCLES(40),.TX_RESULT_TIMEOUT_CYCLES(200),
        .REPLY_TIMEOUT_CYCLES(200),.CANCEL_TIMEOUT_CYCLES(40)) client(
        .clk(clk),.rst_n(rst_n),.start(trigger),.command_word(frame_id),
        .byte_reserved(frame_dlc),.command_value_word(frame_data),
        .mapping_valid(1'b1),.stream_integrity_lost(1'b0),
        .param_pending({1'b0,param_pending,4'b0}),.param_poisoned(6'b0),
        .param_req_valid(preg_valid),.param_req_ready(preg_ready),
        .param_req_rejected(preg_rejected),.param_req_active(preg_active),
        .param_req_host(preg_host),.param_req_motor(preg_motor),
        .param_req_index(preg_index),.param_req_token(preg_token),
        .param_cancel_valid(cancel_valid),.param_cancel_ready(cancel_ready),
        .param_cancel_done(cancel_done),.param_cancel_matched(cancel_matched),
        .param_cancel_motor(cancel_motor),.param_cancel_index(cancel_index),
        .param_cancel_token(cancel_token),.param_cancel_poison(cancel_poison),
        .param_reply_valid(reply_valid),.param_reply_failed(1'b0),
        .param_reply_token(reply_token),.param_reply_axis(3'd4),
        .param_reply_index(preg_index),.param_reply_bits(reply_bits),
        .status_event_valid(status_event_valid),.status_event_motor(8'h05),
        .status_event_error(6'd0),
        .tx_req_valid(request_valid),.tx_req_ready(request_ready),
        .tx_can_id(request_id),.tx_can_dlc(request_dlc),
        .tx_can_data(request_data),.tx_done(master_done),
        .tx_success(master_success),.tx_may_have_submitted(master_maybe),
        .tx_error_code(master_error_code),.command_busy(client_busy),
        .fault_locked(client_locked),.command_done(client_done),
        .command_success(client_success),.command_error(client_error),
        .command_error_code(client_error_code),.command_state(client_state));

    can_axi_lite_master #(.ENABLE_SINGLE_TX(1),.ENABLE_PERIODIC(1),
        .ENABLE_SIX_AXIS(1),.ENABLE_PL_INIT(0),.ENABLE_RX(0),
        .POLL_INTERVAL_CYCLES(1000),.TIMEOUT_CYCLES(8),
        .TXOK_TIMEOUT_CYCLES(35),.SEND_TIMEOUT_CYCLES(120),
        .TXOK_POLL_CYCLES(2),.PERIOD_100HZ_CYCLES(30)) master(
        .aclk(clk),.aresetn(rst_n),.send_req(stage3_start),
        .single_tx_req_valid(request_valid),.single_tx_req_ready(request_ready),
        .single_tx_can_id(request_id),.single_tx_can_dlc(request_dlc),
        .single_tx_can_data(request_data),.single_tx_done(master_done),
        .single_tx_success(master_success),.single_tx_error(master_error),
        .single_tx_timeout(master_timeout),
        .single_tx_may_have_submitted(master_maybe),
        .single_tx_error_code(master_error_code),
        .tx_state(tx_state),.tx_busy(tx_busy),
        .tx_fifo_write_done(tx_fifo_write_done),.tx_success(tx_success),
        .tx_error(tx_error),.tx_timeout(tx_timeout),
        .tx_success_count(tx_success_count),.tx_error_count(tx_error_count),
        .tx_may_be_pending(tx_may_pending),.enqueued_count(enqueued_count),
        .scheduler_state(scheduler_state),
        .clock_locked(1'b1),.reset_released(1'b1),
        .stop_req(1'b0),.period_sel(2'b01),.limit_sel(2'b00),
        .rx_ready(1'b1),
        .m_axi_awaddr(awaddr),.m_axi_awvalid(awvalid),.m_axi_awready(awready),
        .m_axi_wdata(wdata),.m_axi_wstrb(wstrb),.m_axi_wvalid(wvalid),
        .m_axi_wready(wready),.m_axi_bresp(bresp),.m_axi_bvalid(bvalid),
        .m_axi_bready(bready),.m_axi_araddr(araddr),
        .m_axi_arvalid(arvalid),.m_axi_arready(arready),
        .m_axi_rdata(rdata),.m_axi_rresp(rresp),.m_axi_rvalid(rvalid),
        .m_axi_rready(rready));

    can_axi_slave_model #(.V21_GENERIC_TEST(1),.START_NORMAL(1)) slave(
        .clk(clk),.rst_n(rst_n),.awaddr(awaddr),.wdata(wdata),.araddr(araddr),
        .wstrb(wstrb),.awvalid(awvalid),.wvalid(wvalid),.bready(bready),
        .arvalid(arvalid),.rready(rready),.awready(awready),.wready(wready),
        .bvalid(bvalid),.arready(arready),.rvalid(rvalid),
        .bresp(bresp),.rresp(rresp),.rdata(rdata),
        .hold_aw(1'b0),.hold_w(1'b0),.hold_b(1'b0),
        .hold_ar(1'b0),.hold_r(1'b0),.config_stuck(1'b0),
        .normal_stuck(1'b0),.fifo_full(1'b0),.no_txok(no_txok),
        .can_error(can_error),.txok_delay_cycles(32'd1),
        .fail_write_index(fail_write_index),.fail_read_index(32'hFFFFFFFF),
        .write_count(write_count),.read_count(read_count),
        .enqueued_count(slave_enqueued),.protocol_errors(protocol_errors),
        .reset_count(reset_count),.last_sequence());

    // Transaction trace accompanies the XSim waveform database. The slave
    // records an AXI write only after both AW and W have handshaken.
    always @(posedge clk) begin
        if(rst_n && slave.aw_seen && slave.w_seen && !slave.b_pending &&
           write_count<5)
            $display("AXI_WRITE t=%0t index=%0d addr=%08h data=%08h",
                     $time,write_count,slave.aw_latched,slave.w_latched);
    end

    task automatic verify(input bit cond,input string label);
        if(cond !== 1'b1) $fatal(1,"FAIL %s at %0t",label,$time);
        else $display("PASS %s",label);
    endtask
    task automatic fresh;
        @(negedge clk);
        rst_n=0;trigger=0;stage3_start=0;reply_valid=0;
        frame_id=29'h0380C805;frame_dlc=8'd0;
        frame_data=64'd0;reply_bits=32'h3F800000;status_event_valid=0;
        reject_registration=0;no_txok=0;can_error=0;
        fail_write_index=32'hFFFFFFFF;
        repeat(4) @(negedge clk);
        rst_n=1;
        repeat(3) @(negedge clk);
    endtask
    task automatic launch;
        @(negedge clk); trigger=1;
        @(negedge clk); trigger=0;
    endtask
    task automatic await_master_result;
        integer n;
        begin
            n=0;
            while(!master_done && n<300) begin @(negedge clk);n=n+1;end
            if(!master_done) $fatal(1,"master result timeout: client=%0d tx=%0d reg=%0d req=%0d write=%0d",
                                    client_state,tx_state,reg_accept_count,req_accept_count,write_count);
        end
    endtask
    task automatic await_client_result;
        integer n;
        begin
            n=0;
            while(!client_done && n<300) begin @(negedge clk);n=n+1;end
            if(!client_done) $fatal(1,"client result timeout");
        end
    endtask
    initial begin
        #200000; $fatal(1,"global simulation timeout");
    end

    task automatic state_is(input integer state);
        integer i=0;
        while(client_state!=state && i<400) begin @(negedge clk);i++;end
        verify(client_state==state,"client state deadline");
    endtask
    task automatic send_reply(input [31:0] bits);
        state_is(5);reply_bits=bits;reply_valid=1;
        @(negedge clk);reply_valid=0;
        await_client_result();verify(client_success,"readback verified through real Master");
        @(negedge clk);
    endtask
    task automatic read_param(input [15:0] idx,input [31:0] bits);
        frame_id={2'd0,idx,3'd0,8'd5};frame_data=0;
        launch();await_master_result();@(negedge clk);send_reply(bits);
    endtask
    task automatic write_param(input [15:0] idx,input [31:0] bits);
        frame_id={2'd0,idx,3'd1,8'd5};frame_data={32'd0,bits};
        launch();await_master_result();@(negedge clk);state_is(6);
        status_event_valid=1;@(negedge clk);status_event_valid=0;
        await_master_result();@(negedge clk);send_reply(bits);
    endtask
    task automatic ready_enable;
        read_param(16'h7005,1);read_param(16'h7019,32'h3F800000);
        write_param(16'h7024,32'h3F000000);write_param(16'h7025,32'h3F000000);
        write_param(16'h7016,32'h3F800000);
        frame_id=29'h305;frame_data=64'h50505431;
        launch();await_master_result();@(negedge clk);state_is(6);
        status_event_valid=1;@(negedge clk);status_event_valid=0;
        await_client_result();verify(client_success,"ID5 enable reaches real Master after guards");
    endtask
    integer base_writes;
    initial begin
        fresh();ready_enable();
        frame_id=29'h0380C805;frame_data=0;
        launch();wait(request_valid);@(negedge clk);
        frame_dlc=8'hA5;
        base_writes=write_count;
        await_client_result();
        verify(client_locked && client_error_code==8'hE0,"manual stop drains real in-flight TX then disables");
        verify(write_count==80 && req_accept_count==16,"ten setup/read frames plus exactly one disable");
        for(integer k=0;k<6;k++) begin
            $display("STOP_FIFO k=%0d address=%h idr=%h dw1=%h dw2=%h",k,slave.write_addresses[51+5*k],slave.write_values[51+5*k],slave.write_values[53+5*k],slave.write_values[54+5*k]);
            verify(slave.write_addresses[51+5*k]==32'h43C00030 &&
                   slave.write_values[51+5*k]==((((29'h0400FD00+(k+1))>>18)<<21)|32'h00180000|(((29'h0400FD00+(k+1))&18'h3FFFF)<<1)) &&
                   slave.write_values[53+5*k]==0 && slave.write_values[54+5*k]==0,
                   "real Master encodes each of six stop IDs with eight zero bytes");
        end
        repeat(20) @(negedge clk);
        verify(write_count==80,"held manual stop is not duplicated by Master");
        $display("PASS SIX STOP MASTER INTEGRATION");$finish;
    end
endmodule
