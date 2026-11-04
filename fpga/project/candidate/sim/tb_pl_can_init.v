`timescale 1ns / 1ps
module tb_pl_can_init;
    reg clk=0,rst_n=0,locked=0,released=0,send_req=0;
    reg hold_aw=0,hold_w=0,hold_b=0,hold_ar=0,hold_r=0,config_stuck=0,normal_stuck=0;
    integer fail_write=-1,fail_read=-1,checks=0,failures=0,i;
    wire [31:0] awaddr,wdata,araddr,rdata,last_status;
    wire [3:0] wstrb,init_error_code;
    wire [1:0] bresp,rresp;
    wire awvalid,wvalid,bready,arvalid,rready,awready,wready,bvalid,arready,rvalid,initialized,init_error;
    wire [4:0] init_state,failed_state;
    wire [31:0] status_count,tx_count;
    wire [31:0] last_seq;
    wire [31:0] writes,reads,enqueues,model_errors,reset_count;
    always #10 clk=~clk;
    can_axi_lite_master #(.ENABLE_PL_INIT(1),.INIT_TIMEOUT_CYCLES(300),.INIT_POLL_CYCLES(3),
        .TIMEOUT_CYCLES(20),.POLL_INTERVAL_CYCLES(40)) dut(
        .aclk(clk),.aresetn(rst_n),.clock_locked(locked),.reset_released(released),.send_req(send_req),
        .m_axi_awaddr(awaddr),.m_axi_awprot(),.m_axi_awvalid(awvalid),.m_axi_awready(awready),
        .m_axi_wdata(wdata),.m_axi_wstrb(wstrb),.m_axi_wvalid(wvalid),.m_axi_wready(wready),
        .m_axi_bresp(bresp),.m_axi_bvalid(bvalid),.m_axi_bready(bready),
        .m_axi_araddr(araddr),.m_axi_arprot(),.m_axi_arvalid(arvalid),.m_axi_arready(arready),
        .m_axi_rdata(rdata),.m_axi_rresp(rresp),.m_axi_rvalid(rvalid),.m_axi_rready(rready),
        .can_initialized(initialized),.can_init_error(init_error),.can_init_state(init_state),
        .can_init_failed_state(failed_state),.can_init_error_code(init_error_code),.can_init_last_status(last_status),
        .success_count(status_count),.tx_success_count(tx_count));
    can_axi_slave_model slave(.clk(clk),.rst_n(rst_n),
        .awaddr(awaddr),.wdata(wdata),.araddr(araddr),.wstrb(wstrb),
        .awvalid(awvalid),.wvalid(wvalid),.bready(bready),.arvalid(arvalid),.rready(rready),
        .awready(awready),.wready(wready),.bvalid(bvalid),.arready(arready),.rvalid(rvalid),
        .bresp(bresp),.rresp(rresp),.rdata(rdata),
        .hold_aw(hold_aw),.hold_w(hold_w),.hold_b(hold_b),.hold_ar(hold_ar),.hold_r(hold_r),
        .config_stuck(config_stuck),.normal_stuck(normal_stuck),.fifo_full(1'b0),.no_txok(1'b0),
        .can_error(1'b0),.txok_delay_cycles(32'd3),.fail_write_index(fail_write),.fail_read_index(fail_read),
        .write_count(writes),.read_count(reads),.enqueued_count(enqueues),.protocol_errors(model_errors),
        .reset_count(reset_count),.last_sequence(last_seq));
    task check;
        input ok;input [8*120-1:0] text;
        begin checks=checks+1;if(ok!==1'b1) begin failures=failures+1;$display("FAIL: %0s",text);end
        else $display("PASS: %0s",text);end
    endtask
    task reset;
        begin
            @(negedge clk);rst_n=0;locked=0;released=0;send_req=0;
            hold_aw=0;hold_w=0;hold_b=0;hold_ar=0;hold_r=0;config_stuck=0;normal_stuck=0;fail_write=-1;fail_read=-1;
            repeat(4) @(negedge clk);rst_n=1;
        end
    endtask
    task boot;
        begin locked=1;released=1;wait(initialized||init_error);@(negedge clk);end
    endtask
    always @(posedge clk) if(rst_n) begin
        if((awvalid||arvalid)&&(!locked||!released)) begin failures=failures+1;$display("FAIL: AXI before clock/reset gates");end
        if(awvalid&&awaddr>=32'h43C00030&&awaddr<=32'h43C0003C&&!initialized) begin
            failures=failures+1;$display("FAIL: TX FIFO access before initialization");
        end
    end
    initial begin
        reset;send_req=1;
        repeat(8) @(negedge clk);check(writes==0&&reads==0,"no operations before clock lock");
        locked=1;repeat(8) @(negedge clk);check(writes==0&&reads==0,"no operations before reset release");
        released=1;wait(initialized||init_error);@(negedge clk);
        check(initialized&&!init_error&&last_status==32'h98,"independent initialization completes without PS");
        check(writes==6&&reset_count==1,"exactly six ordered configuration writes and one CAN reset");
        check(slave.write_addresses[0]==32'h43C00000&&slave.write_values[0]==1,"SRR reset write");
        check(slave.write_addresses[1]==32'h43C00008&&slave.write_values[1]==0,"BRPR extracted from successful RX software");
        check(slave.write_addresses[2]==32'h43C0000C&&slave.write_values[2]==32'h2F,"BTR extracted from successful RX software");
        check(slave.write_addresses[3]==32'h43C00004&&slave.write_values[3]==0,"MSR normal mode selection");
        check(slave.write_addresses[4]==32'h43C00020&&slave.write_values[4]==0,"IER disabled, TXOK owned by PL");
        check(slave.write_addresses[5]==32'h43C00000&&slave.write_values[5]==2,"SRR enable after bit timing configuration");
        repeat(100) @(negedge clk);
        check(enqueues==0&&tx_count==0,"start held high before initialization cannot auto-send");
        check(status_count>0,"background Reader starts after initialization");
        reset;config_stuck=1;boot;check(init_error&&!initialized&&init_error_code==1,"configuration mode bounded timeout");
        reset;normal_stuck=1;boot;check(init_error&&!initialized&&init_error_code==2,"normal mode bounded timeout");
        reset;fail_write=2;boot;check(init_error&&init_error_code==5&&writes==3,"BTR BRESP failure stops remaining writes");
        reset;fail_read=0;boot;check(init_error&&init_error_code==4,"SR RRESP error is reported");
        reset;hold_b=1;boot;check(init_error&&init_error_code==3,"AXI B timeout reported without reinitialization");
        repeat(50) @(negedge clk);check(writes==1&&enqueues==0,"fault cannot retry or enqueue frames");
        hold_b=0;repeat(30) @(negedge clk);check(init_error&&!initialized,"late AXI response cannot turn failed init into success");
        reset;locked=1;released=1;wait(writes==2);@(negedge clk);rst_n=0;
        repeat(4) @(negedge clk);check(!initialized&&!init_error,"shared reset interrupts init and clears state");
        rst_n=1;wait(initialized||init_error);@(negedge clk);
        check(initialized&&writes==6&&reset_count==1,"reset recovery replays full register initialization");
        check(model_errors==0,"slave model found no illegal access or FIFO write");
        if(failures==0) $display("RESULT: PASS PL_CAN_INIT (%0d checks)",checks);
        else $display("RESULT: FAIL PL_CAN_INIT (%0d failures)",failures);
        $finish;
    end
    initial begin #1000000;$display("FAIL: init test guard timeout");$finish;end
endmodule
