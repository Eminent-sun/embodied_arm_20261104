`timescale 1ns/1ps
// Current BD static mode, actual client/protocol/master/RX service, AXI-CAN model.
// Timers are shortened only for simulation. No physical CAN or motor access.
module tb_single_tx_fault_repro;
    reg clk=0; always #10 clk=~clk;
    reg rst_n=0,locked=0,released=0,trigger=0,stage3_start=0;
    reg [28:0] frame_id=29'h1100FD05;
    reg [7:0] frame_dlc=8;
    reg [63:0] frame_data=64'h0000000000007005;
    reg hold_aw=0,hold_w=0,hold_b=0,hold_ar=0,hold_r=0,no_txok=0;
    reg rx_in_valid=0;
    reg [31:0] rx_in_idr=0,rx_in_dlcr=0,rx_in_dw1=0,rx_in_dw2=0,inject_isr=0;
    reg [31:0] fail_write_index=32'hFFFFFFFF;
    wire preg_valid,preg_ready,preg_rejected,preg_active;
    wire [7:0] preg_host,preg_motor;
    wire [15:0] preg_index;
    wire [31:0] preg_token;
    wire cancel_valid,cancel_ready,cancel_done,cancel_matched,cancel_poison;
    wire [7:0] cancel_motor;
    wire [15:0] cancel_index;
    wire [31:0] cancel_token;
    wire reply_valid,reply_failed;
    wire [31:0] reply_token;
    wire req_valid,req_ready;
    wire [28:0] req_id;
    wire [7:0] req_dlc;
    wire [63:0] req_data;
    wire master_done,master_result_valid,master_success,master_error,master_timeout,master_maybe;
    wire [7:0] master_code;
    wire client_busy,client_locked,client_done,client_success,client_error;
    wire [7:0] client_code;
    wire [3:0] client_state,tx_state;
    wire initialized,init_error,tx_busy,tx_fifo_write_done,tx_error,rx_valid,rx_ready;
    wire [31:0] tx_success_count,tx_error_count,enqueued_count,rx_frame_count;
    wire [7:0] rx_error_flags;
    wire rx_integrity_lost;
    wire [28:0] rx_id;
    wire rx_ide,rx_rtr;
    wire [3:0] rx_dlc;
    wire [63:0] rx_data,rx_stamp;
    wire [7:0] rx_frame_error;
    wire [31:0] awaddr,wdata,araddr,rdata;
    wire [3:0] wstrb;
    wire awvalid,awready,wvalid,wready,bvalid,bready,arvalid,arready,rvalid,rready;
    wire [1:0] bresp,rresp;
    integer hw_level,hw_popped,hw_dropped,hw_illegal,hw_words,hw_acks,hw_txacks;
    integer write_count,read_count,model_enqueued,model_errors,reset_count;
    integer register_count=0,request_count=0,master_done_count=0,client_done_count=0;
    integer aw_count=0,w_count=0,b_count=0,cycles=0;
    reg last_master_success=0,last_master_error=0,last_master_timeout=0,last_master_maybe=0;
    reg [7:0] last_master_code=0,last_client_code=0;
    reg last_client_success=0,last_client_error=0;
    reg saw_reject=0;

    pl_robstride_single_tx #(.REG_TIMEOUT_CYCLES(80),.TX_ACCEPT_TIMEOUT_CYCLES(80),
        .TX_RESULT_TIMEOUT_CYCLES(1000),.REPLY_TIMEOUT_CYCLES(5000),
        .CANCEL_TIMEOUT_CYCLES(80)) client(
        .clk(clk),.rst_n(rst_n),.trigger(trigger),.can_id(frame_id),.can_dlc(frame_dlc),.can_data(frame_data),
        .param_req_valid(preg_valid),.param_req_ready(preg_ready),.param_req_rejected(preg_rejected),
        .param_req_active(preg_active),.param_req_host(preg_host),.param_req_motor(preg_motor),
        .param_req_index(preg_index),.param_req_token(preg_token),
        .param_cancel_valid(cancel_valid),.param_cancel_ready(cancel_ready),.param_cancel_done(cancel_done),
        .param_cancel_matched(cancel_matched),.param_cancel_motor(cancel_motor),
        .param_cancel_index(cancel_index),.param_cancel_token(cancel_token),.param_cancel_poison(cancel_poison),
        .param_reply_valid(reply_valid),.param_reply_failed(reply_failed),.param_reply_token(reply_token),
        .tx_req_valid(req_valid),.tx_req_ready(req_ready),.tx_can_id(req_id),.tx_can_dlc(req_dlc),
        .tx_can_data(req_data),.tx_done(master_done),.tx_success(master_success),
        .tx_may_have_submitted(master_maybe),.tx_error_code(master_code),.busy(client_busy),
        .fault_locked(client_locked),.done(client_done),.success(client_success),
        .error(client_error),.error_code(client_code),.state(client_state));

    can_axi_lite_master #(.ENABLE_SINGLE_TX(1),.ENABLE_PERIODIC(1),.ENABLE_SIX_AXIS(1),
        .ENABLE_PL_INIT(1),.ENABLE_RX(1),.RX_POLL_CYCLES(20),.RX_FIFO_DEPTH(16),
        .INIT_TIMEOUT_CYCLES(500),.INIT_POLL_CYCLES(3),.TIMEOUT_CYCLES(64),
        .POLL_INTERVAL_CYCLES(1000),.TXOK_POLL_CYCLES(20),
        .TXOK_TIMEOUT_CYCLES(500),.SEND_TIMEOUT_CYCLES(1200)) master(
        .aclk(clk),.aresetn(rst_n),.clock_locked(locked),.reset_released(released),
        .send_req(stage3_start),.stop_req(1'b0),.period_sel(2'b01),.limit_sel(2'b00),
        .single_tx_req_valid(req_valid),.single_tx_req_ready(req_ready),
        .single_tx_can_id(req_id),.single_tx_can_dlc(req_dlc),.single_tx_can_data(req_data),
        .single_tx_done(master_done),.single_tx_result_valid(master_result_valid),
        .single_tx_success(master_success),
        .single_tx_error(master_error),.single_tx_timeout(master_timeout),
        .single_tx_may_have_submitted(master_maybe),.single_tx_error_code(master_code),
        .tx_state(tx_state),.tx_busy(tx_busy),.tx_fifo_write_done(tx_fifo_write_done),
        .tx_error(tx_error),.tx_success_count(tx_success_count),.tx_error_count(tx_error_count),
        .enqueued_count(enqueued_count),.can_initialized(initialized),.can_init_error(init_error),
        .rx_ready(rx_ready),.rx_valid(rx_valid),.rx_can_id(rx_id),.rx_ide(rx_ide),.rx_rtr(rx_rtr),
        .rx_dlc(rx_dlc),.rx_data(rx_data),.rx_timestamp(rx_stamp),.rx_frame_error(rx_frame_error),
        .rx_error_flags(rx_error_flags),.rx_integrity_lost(rx_integrity_lost),.rx_frame_count(rx_frame_count),
        .m_axi_awaddr(awaddr),.m_axi_awvalid(awvalid),.m_axi_awready(awready),
        .m_axi_wdata(wdata),.m_axi_wstrb(wstrb),.m_axi_wvalid(wvalid),.m_axi_wready(wready),
        .m_axi_bresp(bresp),.m_axi_bvalid(bvalid),.m_axi_bready(bready),
        .m_axi_araddr(araddr),.m_axi_arvalid(arvalid),.m_axi_arready(arready),
        .m_axi_rdata(rdata),.m_axi_rresp(rresp),.m_axi_rvalid(rvalid),.m_axi_rready(rready));

    robstride_protocol #(.CONFIG_ENABLE(1),.HOST_ID(8'hFD),
        .MOTOR_IDS(48'h060504030201),.FEEDBACK_TIMEOUT_CYCLES(5000),
        .PARAM_TIMEOUT_CYCLES(5000)) protocol(
        .clk(clk),.rst_n(rst_n),.consume_enable(1'b1),
        .frame_valid(rx_valid),.frame_ready(rx_ready),.can_id(rx_id),.can_ide(rx_ide),
        .can_rtr(rx_rtr),.can_dlc(rx_dlc),.can_data(rx_data),.frame_timestamp(rx_stamp),
        .frame_error(rx_frame_error),.stream_integrity_lost(rx_integrity_lost),
        .param_req_valid(preg_valid),.param_req_ready(preg_ready),.param_req_host(preg_host),
        .param_req_motor(preg_motor),.param_req_index(preg_index),.param_req_token(preg_token),
        .param_req_rejected(preg_rejected),.param_req_active(preg_active),
        .param_cancel_valid(cancel_valid),.param_cancel_ready(cancel_ready),
        .param_cancel_motor(cancel_motor),.param_cancel_index(cancel_index),
        .param_cancel_token(cancel_token),.param_cancel_poison(cancel_poison),
        .param_cancel_done(cancel_done),.param_cancel_matched(cancel_matched),
        .param_reply_valid(reply_valid),.param_reply_failed(reply_failed),
        .param_reply_token(reply_token),.query_axis(3'd4),.debug_page(5'd0));

    can_axi_rx_slave_model #(.SINGLE_TEST(1)) slave(
        .clk(clk),.rst_n(rst_n),.rx_in_valid(rx_in_valid),.rx_in_idr(rx_in_idr),
        .rx_in_dlcr(rx_in_dlcr),.rx_in_dw1(rx_in_dw1),.rx_in_dw2(rx_in_dw2),
        .inject_isr(inject_isr),.read_error_response(2'b10),.write_error_response(2'b10),
        .response_delay(32'd0),.rx_level(hw_level),.rx_popped(hw_popped),.rx_dropped(hw_dropped),
        .rx_illegal_reads(hw_illegal),.rx_word_reads(hw_words),.rx_icr_writes(hw_acks),
        .tx_acked_count(hw_txacks),.awaddr(awaddr),.wdata(wdata),.araddr(araddr),
        .wstrb(wstrb),.awvalid(awvalid),.wvalid(wvalid),.bready(bready),
        .arvalid(arvalid),.rready(rready),.arready(arready),.awready(awready),.wready(wready),
        .bvalid(bvalid),.bresp(bresp),.rvalid(rvalid),.rresp(rresp),.rdata(rdata),
        .hold_aw(hold_aw),.hold_w(hold_w),.hold_b(hold_b),.hold_ar(hold_ar),.hold_r(hold_r),
        .config_stuck(1'b0),.normal_stuck(1'b0),.fifo_full(1'b0),.no_txok(no_txok),
        .can_error(1'b0),.txok_delay_cycles(32'd5),
        .fail_write_index(fail_write_index),.fail_read_index(32'hFFFFFFFF),
        .write_count(write_count),.read_count(read_count),.enqueued_count(model_enqueued),
        .protocol_errors(model_errors),.reset_count(reset_count),.last_sequence());

    always @(posedge clk) if(!rst_n) begin
        register_count<=0;request_count<=0;master_done_count<=0;client_done_count<=0;
        aw_count<=0;w_count<=0;b_count<=0;saw_reject<=0;
        last_master_success<=0;last_master_error<=0;last_master_timeout<=0;
        last_master_maybe<=0;last_master_code<=0;last_client_code<=0;
        last_client_success<=0;last_client_error<=0;
    end else begin
        if(preg_valid&&preg_ready) register_count<=register_count+1;
        if(preg_rejected) saw_reject<=1;
        if(req_valid&&req_ready) request_count<=request_count+1;
        if(awvalid&&awready) aw_count<=aw_count+1;
        if(wvalid&&wready) w_count<=w_count+1;
        if(bvalid&&bready) b_count<=b_count+1;
        if(master_done) begin
            master_done_count<=master_done_count+1;
            last_master_success<=master_success;last_master_error<=master_error;
            last_master_timeout<=master_timeout;last_master_maybe<=master_maybe;
            last_master_code<=master_code;
        end
        if(client_done) begin
            client_done_count<=client_done_count+1;
            last_client_success<=client_success;last_client_error<=client_error;
            last_client_code<=client_code;
        end
        if(req_ready && !req_valid) $fatal(1,"ready without a valid single request");
        if(master_done && !(master_success^master_error)) $fatal(1,"invalid Master result");
    end

    task automatic check(input bit good,input string label);
        if(good!==1'b1) $fatal(1,"FAIL %s at %0t",label,$time);
        $display("PASS %s",label);
    endtask
    task automatic wait_init;
        integer n; begin
            n=0;while(!initialized && !init_error && n<1000) begin @(negedge clk);n=n+1;end
            $display("INIT_TRACE initialized=%b error=%b state=%d failed=%d code=%d last=%h writes=%0d reads=%0d xstate=%d owner=%d xbad=%b timeout=%b model_errors=%0d",initialized,init_error,master.can_init_state,master.can_init_failed_state,master.can_init_error_code,master.can_init_last_status,write_count,read_count,master.x_state,master.x_owner,master.x_bad,master.transaction_timeout,model_errors);
            $display("AXI_TRACE ARVALID=%b ARREADY=%b RVALID=%b RREADY=%b RPENDING=%b HOLD_AR=%b HOLD_R=%b ARADDR=%h",arvalid,arready,rvalid,rready,slave.r_pending,hold_ar,hold_r,araddr);
            check(initialized&&!init_error,"PL CAN init completes");
        end
    endtask
    task automatic reset_case;
        begin
            @(negedge clk);rst_n=0;locked=0;released=0;trigger=0;stage3_start=0;
            frame_id=29'h1100FD05;frame_dlc=8;frame_data=64'h7005;
            hold_aw=0;hold_w=0;hold_b=0;hold_ar=0;hold_r=0;no_txok=0;
            rx_in_valid=0;inject_isr=0;fail_write_index=32'hFFFFFFFF;
            repeat(4)@(negedge clk);rst_n=1;locked=1;released=1;
            wait_init();repeat(3)@(negedge clk);
        end
    endtask
    task automatic pulse_trigger;
        begin @(negedge clk);trigger=0;@(negedge clk);trigger=1;
            @(negedge clk);trigger=0;end
    endtask
    task automatic wait_master;
        integer n;begin
            n=0;while(master_done_count==0 && n<2000)begin @(negedge clk);n=n+1;end
            check(master_done_count==1,"one Master result event");
        end
    endtask
    task automatic wait_client;
        integer n;begin
            n=0;while(client_done_count==0 && n<7000)begin @(negedge clk);n=n+1;end
            check(client_done_count==1,"one client result event");
        end
    endtask
    task automatic inject_param_reply;
        reg [28:0] id; begin
            id=29'h110005FD;
            @(negedge clk);
            rx_in_idr={id[28:18],1'b1,1'b1,id[17:0],1'b0};
            rx_in_dlcr=32'h80000000;rx_in_dw1=32'h05700000;
            rx_in_dw2=32'h0000803F;rx_in_valid=1;
            @(negedge clk);rx_in_valid=0;
        end
    endtask

    initial begin #500000; $fatal(1,"global simulation timeout");end
    initial begin
        reset_case();
        check(!preg_active && !req_valid && client_state==0,"boot is idle and VIO low is sampled");
        pulse_trigger();
        wait_master();
        check(register_count==1 && request_count==1 && last_master_success &&
               tx_success_count==1 && model_enqueued==1,"VIO-like 0-1-0 pulse registers and sends exactly once");
        check(slave.write_addresses[write_count-4]==32'h43C00030 &&
               slave.write_values[write_count-4]==32'h8819FA0A &&
               slave.write_addresses[write_count-3]==32'h43C00034 &&
               slave.write_values[write_count-3]==32'h80000000 &&
               slave.write_addresses[write_count-2]==32'h43C00038 &&
               slave.write_values[write_count-2]==32'h05700000 &&
               slave.write_addresses[write_count-1]==32'h43C0003C &&
               slave.write_values[write_count-1]==0,"four AXI FIFO writes match EL05 parameter read frame");
        check(aw_count==write_count&&w_count==write_count&&b_count==write_count&&
               model_errors==0,"AW W B handshakes all complete");
        inject_param_reply();wait_client();
        check(last_client_success&&!last_client_error&&client_state==0&&rx_frame_count==1,
               "RX parameter reply matches registration and returns client to IDLE");
        check(master_result_valid && master_maybe && !master_done && !master_error &&
              master_success && master_code==0,
              "sticky result-valid disambiguates VIO after the done pulse");
        check(stage3_start==0 && tx_success_count==1,
               "old Stage3 VIO trigger stays low while single TX succeeds");
        pulse_trigger();
        begin: await_second_accept
            integer n;n=0;
            while(request_count<2 && n<300)begin @(negedge clk);n=n+1;end
            check(request_count==2,"second admitted request is identified independently");
        end
        check(!master_result_valid && !master_maybe && !master_success &&
              !master_error && master_code==0,
              "new accepted request clears all stale VIO result fields");

        reset_case();
        inject_isr=32'h100;@(negedge clk);inject_isr=0;
        begin: await_integrity
            integer n;n=0;
            while(!rx_integrity_lost && n<500)begin @(negedge clk);n=n+1;end
            check(rx_integrity_lost,"ISR.ERROR reaches sticky RX integrity protection");
        end
        cycles=write_count;pulse_trigger();wait_client();
        check(saw_reject&&last_client_error&&last_client_code==2&&
               request_count==0&&write_count==cycles,
               "reproduced registration refusal has zero TX FIFO writes");

        reset_case();hold_aw=1;hold_w=1;
        pulse_trigger();repeat(12)@(negedge clk);hold_aw=0;hold_w=0;
        wait_master();
        check(last_master_success&&request_count==1&&model_enqueued==1,
               "finite AXI AW/W backpressure preserves one transaction");

        reset_case();no_txok=1;
        pulse_trigger();wait_master();wait_client();
        check(master_result_valid&&last_master_error&&last_master_timeout&&last_master_maybe&&
               last_client_error&&client_locked&&model_enqueued==1,
               "missing TXOK reports uncertain submission and locks client");

        reset_case();fail_write_index=write_count+2;
        pulse_trigger();wait_master();wait_client();
        check(master_result_valid&&last_master_error&&last_master_maybe&&last_master_code==4&&
               last_client_error&&client_locked,"FIFO BRESP error is not reported as success");
        $display("RESULT: PASS SINGLE_TX_FAULT_REPRO");$finish;
    end
endmodule
