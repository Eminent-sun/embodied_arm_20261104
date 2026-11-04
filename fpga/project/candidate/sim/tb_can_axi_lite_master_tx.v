`timescale 1ns/1ps
module tb_can_axi_lite_master_tx;
    localparam integer POLL=64, LIMIT=12;
    reg clk=0; always #10 clk=~clk;
    reg rst_n=0, send_req=0;
    reg [31:0] sr_value=32'h98, aw_delay=0,w_delay=0,b_delay=0,ack_delay=12;
    reg ack_enable=1,hold_ar=0;
    reg [2:0] fault_mode=0;
    reg [31:0] fault_index=0;
    reg [1:0] bad_bresp=2, bad_rresp=0;
    reg [31:0] bad_read_address=0;
    wire [31:0] awaddr,wdata,araddr,rdata,status_value,success_count,completed_count,timeout_count;
    wire [2:0] awprot,arprot,error_flags;
    wire [3:0] wstrb,tx_state,tx_error_code,write_error_flags;
    wire [1:0] bresp,rresp,last_bresp,last_rresp,debug_state;
    wire awvalid,awready,wvalid,wready,bvalid,bready,arvalid,arready,rvalid,rready;
    wire busy,read_done,rresp_valid,transaction_timeout,tx_busy,tx_fifo_write_done;
    wire tx_success,tx_error,tx_timeout,bus_quarantined,tx_may_be_pending,send_used;
    wire [31:0] tx_success_count,tx_error_count,last_isr,last_sr;
    wire [31:0] write_count,enqueued_count,read_count;
    integer errors=0,cases_run=0,case_errors,guard,idx,previous_success;
    reg prev_aw_stall=0,prev_w_stall=0,prev_ar_stall=0;
    reg [31:0] held_aw,held_w,held_ar;
    reg [3:0] held_strb;
    integer read_outstanding=0,write_outstanding=0;
    can_axi_lite_master #(.POLL_INTERVAL_CYCLES(POLL),.TIMEOUT_CYCLES(LIMIT),
        .TXOK_TIMEOUT_CYCLES(100),.SEND_TIMEOUT_CYCLES(400)) dut (
        .aclk(clk),.aresetn(rst_n),.send_req(send_req),
        .clock_locked(1'b1),.reset_released(1'b1),.stop_req(1'b0),.period_sel(2'b00),.limit_sel(2'b00),
        .m_axi_awaddr(awaddr),.m_axi_awprot(awprot),.m_axi_awvalid(awvalid),.m_axi_awready(awready),
        .m_axi_wdata(wdata),.m_axi_wstrb(wstrb),.m_axi_wvalid(wvalid),.m_axi_wready(wready),
        .m_axi_bresp(bresp),.m_axi_bvalid(bvalid),.m_axi_bready(bready),
        .m_axi_araddr(araddr),.m_axi_arprot(arprot),.m_axi_arvalid(arvalid),.m_axi_arready(arready),
        .m_axi_rdata(rdata),.m_axi_rresp(rresp),.m_axi_rvalid(rvalid),.m_axi_rready(rready),
        .status_value(status_value),.success_count(success_count),.completed_count(completed_count),
        .timeout_count(timeout_count),.error_flags(error_flags),.last_rresp(last_rresp),
        .rresp_valid(rresp_valid),.read_done(read_done),.busy(busy),.debug_state(debug_state),
        .transaction_timeout(transaction_timeout),.tx_state(tx_state),.tx_busy(tx_busy),
        .tx_fifo_write_done(tx_fifo_write_done),.tx_success(tx_success),.tx_error(tx_error),
        .tx_timeout(tx_timeout),.tx_success_count(tx_success_count),.tx_error_count(tx_error_count),
        .last_bresp(last_bresp),.last_isr(last_isr),.last_sr(last_sr),.tx_error_code(tx_error_code),
        .write_error_flags(write_error_flags),.bus_quarantined(bus_quarantined),
        .tx_may_be_pending(tx_may_be_pending),.send_used(send_used)
    );
    can_tx_slave_model model (
        .clk(clk),.rst_n(rst_n),.sr_value(sr_value),.aw_delay(aw_delay),.w_delay(w_delay),
        .b_delay(b_delay),.ack_delay(ack_delay),.ack_enable(ack_enable),.hold_ar(hold_ar),.fault_mode(fault_mode),
        .fault_index(fault_index),.bad_bresp(bad_bresp),.bad_rresp(bad_rresp),.bad_read_address(bad_read_address),
        .awaddr(awaddr),.awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),
        .wvalid(wvalid),.wready(wready),.bresp(bresp),.bvalid(bvalid),.bready(bready),
        .araddr(araddr),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),
        .rvalid(rvalid),.rready(rready),.write_count(write_count),.enqueued_count(enqueued_count),.read_count(read_count)
    );
    task check;
        input condition; input [8*140-1:0] label;
        begin if(condition!==1'b1) begin errors=errors+1;
            if(errors<40) $display("FAIL @%0t: %0s",$time,label); end end
    endtask
    task start_case;
        begin case_errors=errors; end
    endtask
    task end_case;
        input [8*140-1:0] label;
        begin cases_run=cases_run+1;
            if(errors==case_errors) $display("PASS [%0d]: %0s",cases_run,label);
            else $display("FAIL [%0d]: %0s",cases_run,label); end
    endtask
    task reset_all;
        begin
            @(negedge clk);rst_n=0;send_req=0;sr_value=32'h98;
            aw_delay=0;w_delay=0;b_delay=0;ack_delay=12;ack_enable=1;hold_ar=0;
            fault_mode=0;fault_index=0;bad_bresp=2;bad_rresp=0;bad_read_address=0;
            repeat(3) @(posedge clk);
            @(negedge clk);rst_n=1;
            repeat(2) @(posedge clk);@(negedge clk);
        end
    endtask
    task trigger_send;
        begin @(negedge clk);send_req=1;@(negedge clk);send_req=0;end
    endtask
    task terminal;
        integer n;
        begin n=0;while(!tx_success && !tx_error && n<2000) begin @(posedge clk);#2;n=n+1;end
            check(tx_success || tx_error,"send FSM reaches a bounded terminal state");
            check(tx_busy===0,"terminal state releases TX scheduler busy");end
    endtask
    task normal_result;
        begin terminal;
            check(tx_success && !tx_error && !tx_timeout,"TXOK is successful, no TX error");
            check(write_count===5 && enqueued_count===1,"exactly clear + four FIFO writes, one enqueued frame");
            check(tx_fifo_write_done && tx_success_count===1 && tx_error_count===0,"enqueue and CAN success counters distinct");
            check(last_bresp===0 && last_isr[1] && !tx_may_be_pending,"TXOK observed, no uncertain pending frame");
            check(model.sequence_errors===0,"literal write address/data sequence and WSTRB correct");
            check(model.idr_seen===32'hD9B8ACF0,"independent literal IDR expected value");
            check({model.idr_seen[31:21],model.idr_seen[18:1]}===29'h1B345678,
                  "decode ID1/ID2 independently recovers original 29-bit ID");
            check(model.idr_seen[20:19]===2'b11 && model.idr_seen[0]===0,"SRR=1 IDE=1 RTR=0");
            check(model.isr_value[4]===1,"ICR only clears TXOK and preserves unrelated RXOK");
        end
    endtask

    // Protocol invariants run for every cycle, including fault/quarantine.
    always @(posedge clk) begin
        if(!rst_n) begin
            prev_aw_stall=0;prev_w_stall=0;prev_ar_stall=0;read_outstanding=0;write_outstanding=0;
        end else begin
            if(prev_aw_stall) check(awvalid && awaddr===held_aw,"AWVALID/address held until acceptance");
            if(prev_w_stall) check(wvalid && wdata===held_w && wstrb===held_strb,"WVALID/data/strobes held until acceptance");
            if(prev_ar_stall) check(arvalid && araddr===held_ar,"ARVALID/address held until acceptance");
            if(wvalid) check(wstrb===4'b1111,"all writes use full strobes");
            check(!(arvalid && (awvalid || wvalid)),"one executor never issues read and write together");
            if(arvalid && arready) begin
                check(!read_outstanding && !write_outstanding,"read cannot overlap an outstanding transaction");
                read_outstanding=1;
                check(araddr===32'h43C00018 || araddr===32'h43C0001C,"only SR/ISR reads are issued");
            end
            if((awvalid && awready)||(wvalid && wready)) begin
                check(!read_outstanding,"write cannot overlap an outstanding read");write_outstanding=1;
            end
            if(rvalid && rready) begin check(read_outstanding==1,"R matches accepted AR");read_outstanding=0;end
            if(bvalid && bready) begin
                check(write_outstanding==1 && model.have_aw && model.have_w,"B accepted only after both AW and W");
                write_outstanding=0;
            end
            if(awvalid || wvalid) check(send_used===1,"no writes before a manual accepted request");
            prev_aw_stall=awvalid&&!awready;held_aw=awaddr;
            prev_w_stall=wvalid&&!wready;held_w=wdata;held_strb=wstrb;
            prev_ar_stall=arvalid&&!arready;held_ar=araddr;
        end
    end

    initial begin
        start_case;reset_all;
        repeat(POLL*4+10) @(posedge clk);#2;
        check(write_count===0 && !send_used && !tx_busy && success_count>=4,"no power-up writes; periodic Reader runs");
        check(status_value===32'h98 && success_count===completed_count,"Reader status and counters preserved");
        end_case("no automatic TX; periodic Reader remains active");

        start_case;reset_all;trigger_send;normal_result;
        for(idx=0;idx<5;idx=idx+1)
            $display("VERIFIED WRITE %08h = %08h",model.write_addresses[idx],model.write_values[idx]);
        check(model.aw_cycle[0]==model.w_cycle[0],"AW/W simultaneous handshake observed");
        end_case("normal simultaneous AW/W, exact FIFO order, independent IDR and byte order");
        start_case;reset_all;w_delay=4;trigger_send;normal_result;
        check(model.aw_cycle[0]<model.w_cycle[0],"AW handshake precedes W");
        end_case("AWREADY before WREADY");
        start_case;reset_all;aw_delay=4;trigger_send;normal_result;
        check(model.w_cycle[0]<model.aw_cycle[0],"W handshake precedes AW");
        end_case("WREADY before AWREADY");
        start_case;reset_all;b_delay=6;trigger_send;normal_result;
        check(model.b_wait_cycles>=6,"write response was actually delayed");
        end_case("delayed BVALID after both independent handshakes");

        start_case;reset_all;fault_mode=4;bad_bresp=2;trigger_send;terminal;
        check(tx_error && !tx_success && tx_error_code===4 && last_bresp===2 && write_count===1,
              "SLVERR aborts before any FIFO word");
        end_case("BRESP SLVERR");
        start_case;reset_all;fault_mode=4;bad_bresp=3;trigger_send;terminal;
        check(tx_error && last_bresp===3 && tx_error_count===1,"DECERR recorded once");
        end_case("BRESP DECERR");

        for(idx=1;idx<=3;idx=idx+1) begin
            start_case;reset_all;fault_mode=idx;trigger_send;terminal;
            check(tx_error && tx_timeout && tx_error_code===5 && timeout_count===1,
                  "AW/W/B timeout reaches TX error without hanging upper scheduler");
            check(bus_quarantined && busy,"unretired AXI transaction is quarantined");
            check(write_error_flags[idx]===1,"specific write phase timeout flag set");
            previous_success=read_count;
            repeat(POLL*2) @(posedge clk);#2;
            check(read_count===previous_success && tx_error_count===1,"no conflicting read or repeated TX after timeout");
            @(negedge clk);fault_mode=0;
            repeat(POLL*2+30) @(posedge clk);#2;
            check(!bus_quarantined && !busy && success_count>0 && write_count===1,
                  "late handshake/B drains old write; only Reader resumes, TX never requeues");
            if(idx==1) end_case("AW timeout with W already accepted; quarantine and late recovery");
            else if(idx==2) end_case("W timeout with AW already accepted; quarantine and late recovery");
            else end_case("B timeout; quarantine and late recovery");
        end
        start_case;reset_all;sr_value=32'h498;trigger_send;terminal;
        check(tx_error && tx_error_code===2 && write_count===0 && enqueued_count===0,"full FIFO prohibits all writes");
        end_case("TX FIFO full precondition");
        start_case;reset_all;sr_value=32'h90;trigger_send;terminal;
        check(tx_error && tx_error_code===1 && write_count===0,"non-Normal mode prohibits all writes");
        end_case("CAN not in Normal Mode");
        start_case;reset_all;ack_enable=0;trigger_send;terminal;
        check(tx_error && tx_timeout && tx_error_code===6 && tx_fifo_write_done && !tx_success,
              "OKAY writes/enqueue alone do not mean CAN TX success");
        check(tx_may_be_pending && write_count===5 && enqueued_count===1,"TXOK timeout reports possible hardware retransmission");
        repeat(POLL*3) @(posedge clk);#2;
        check(write_count===5 && tx_error_count===1 && success_count>0,"no software requeue; Reader resumes after TXOK timeout");
        end_case("TXOK timeout, no ACK, pending hardware frame, no automatic requeue");
        start_case;reset_all;@(negedge clk);send_req=1;normal_result;
        repeat(POLL*3) @(posedge clk);#2;
        check(write_count===5 && tx_success_count===1,"held request cannot repeat");
        end_case("send_req held high sends one frame only");
        start_case;reset_all;b_delay=5;trigger_send;
        repeat(8) @(posedge clk);trigger_send;normal_result;trigger_send;
        repeat(POLL*2) @(posedge clk);#2;
        check(write_count===5 && tx_success_count===1,"requests during/after TX ignored for the rest of this reset epoch");
        end_case("extra rising edges during TX and after completion ignored");
        start_case;reset_all;trigger_send;normal_result;reset_all;trigger_send;normal_result;
        end_case("shared reset restores one-shot permission and clears counters");
        start_case;reset_all;@(negedge clk);rst_n=0;send_req=1;
        repeat(3) @(posedge clk);@(negedge clk);rst_n=1;
        repeat(POLL*2) @(posedge clk);#2;
        check(write_count===0 && !send_used,"request high across reset is not an automatic send");
        @(negedge clk);send_req=0;repeat(2) @(posedge clk);trigger_send;normal_result;
        end_case("must observe low after reset, then a fresh rising edge");

        for(idx=1;idx<=4;idx=idx+1) begin
            start_case;reset_all;fault_mode=4;fault_index=idx;trigger_send;terminal;
            check(tx_error && tx_error_code===4 && write_count==idx+1 && !tx_fifo_write_done,
                  "every FIFO word checks BRESP and stops at first failed response");
            if(idx==4) check(tx_may_be_pending,"failed DW2 response may still have committed a frame");
            repeat(POLL*2) @(posedge clk);#2;
            check(write_count==idx+1,"failed FIFO write never automatically repeats");
            end_case("BRESP error at each ID/DLC/DW1/DW2 position");
        end
        start_case;reset_all;bad_rresp=2;bad_read_address=32'h43C00018;trigger_send;terminal;
        check(tx_error_code===3 && tx_error && write_count===0,"bad preflight SR response prevents writes");
        end_case("preflight SR AXI read response error");
        start_case;reset_all;bad_rresp=2;bad_read_address=32'h43C0001C;trigger_send;terminal;
        check(tx_error_code===3 && tx_error && tx_fifo_write_done && !tx_success,"bad ISR response cannot be CAN success");
        end_case("ISR AXI read response error");
        start_case;reset_all;ack_delay=60;trigger_send;
        guard=0;while(!tx_fifo_write_done && !tx_error && guard<1000) begin @(posedge clk);#2;guard=guard+1;end
        check(tx_fifo_write_done && !tx_success,"enqueue completion is visible before TXOK");
        normal_result;
        previous_success=success_count;repeat(POLL*3) @(posedge clk);#2;
        check(success_count>previous_success && completed_count===success_count && error_flags===0,
              "Reader resumes; internal sender SR/ISR reads do not corrupt Reader counters");
        end_case("enqueue versus TXOK distinction and Reader/Sender unified arbitration");
        start_case;reset_all;hold_ar=1;
        repeat(POLL+LIMIT+10) @(posedge clk);#2;
        check(bus_quarantined,"background Reader has an outstanding timed-out address");
        trigger_send;terminal;
        check(tx_error && tx_timeout && tx_error_code===7 && write_count===0,
              "whole-send deadline bounds scheduler even behind a previously stalled Reader");
        @(negedge clk);hold_ar=0;
        repeat(POLL*2+30) @(posedge clk);#2;
        check(success_count>0 && write_count===0,"Reader recovers after draining; expired send attempt does not restart");
        end_case("bounded scheduler behind an already quarantined Reader");
        start_case;reset_all;fault_mode=1;trigger_send;
        guard=0;while(!model.have_w && guard<100) begin @(posedge clk);#2;guard=guard+1;end
        check(model.have_w && awvalid,"partial W-before-AW transaction exists before shared reset");
        reset_all;
        check(!send_used && !tx_error && timeout_count===0,"shared reset clears partial transaction and one-shot state");
        trigger_send;normal_result;
        end_case("shared reset during a partially accepted write, then fresh manual send");
        if(errors==0) $display("RESULT: PASS (%0d/%0d TX tests)",cases_run,cases_run);
        else $display("RESULT: FAIL (%0d errors in %0d TX tests)",errors,cases_run);
        $finish;
    end
    initial begin #10000000;$display("RESULT: FAIL (global TX TB watchdog)");$finish;end
endmodule

// AXI slave + minimal CAN register model. No DUT constants/functions used in
// expected write values. AW and W are captured independently, including W first.
module can_tx_slave_model (
    input wire clk,rst_n,
    input wire [31:0] sr_value,aw_delay,w_delay,b_delay,ack_delay,
    input wire ack_enable,hold_ar,input wire [2:0] fault_mode,input wire [31:0] fault_index,
    input wire [1:0] bad_bresp,bad_rresp,input wire [31:0] bad_read_address,
    input wire [31:0] awaddr,input wire awvalid,output wire awready,
    input wire [31:0] wdata,input wire [3:0] wstrb,input wire wvalid,output wire wready,
    output reg [1:0] bresp,output reg bvalid,input wire bready,
    input wire [31:0] araddr,input wire arvalid,output wire arready,
    output reg [31:0] rdata,output reg [1:0] rresp,output reg rvalid,input wire rready,
    output reg [31:0] write_count,enqueued_count,read_count
);
    reg have_aw,have_w,b_pending,r_pending;
    reg [31:0] saved_aw,saved_w,aw_wait,w_wait,b_wait,ack_wait;
    reg [3:0] saved_strb;
    reg [31:0] isr_value,idr_seen;
    integer sequence_errors,cycles,b_wait_cycles;
    integer aw_cycle[0:7],w_cycle[0:7];
    reg [31:0] write_addresses[0:7],write_values[0:7];
    reg [31:0] expected_address,expected_data;
    assign awready=rst_n && !have_aw && !b_pending && aw_wait>=aw_delay &&
        !(fault_mode==1 && write_count==fault_index);
    assign wready=rst_n && !have_w && !b_pending && w_wait>=w_delay &&
        !(fault_mode==2 && write_count==fault_index);
    assign arready=rst_n && !hold_ar && !r_pending && !rvalid;
    always @(posedge clk) begin
        if(!rst_n) begin
            have_aw<=0;have_w<=0;b_pending<=0;r_pending<=0;
            aw_wait<=0;w_wait<=0;b_wait<=0;ack_wait<=0;bvalid<=0;bresp<=0;rvalid<=0;rresp<=0;rdata<=0;
            write_count<=0;enqueued_count<=0;read_count<=0;isr_value<=32'h12;idr_seen<=0;
            saved_aw<=0;saved_w<=0;saved_strb<=0;sequence_errors<=0;cycles<=0;b_wait_cycles<=0;
        end else begin
            cycles<=cycles+1;
            if(enqueued_count!=0 && ack_enable) begin
                if(ack_wait>=ack_delay) isr_value[1]<=1;
                else ack_wait<=ack_wait+1;
            end
            if(arvalid && arready) begin
                r_pending<=1;read_count<=read_count+1;
                if(araddr==32'h43C00018) rdata<=sr_value;
                else if(araddr==32'h43C0001C) rdata<=isr_value;
                else rdata<=32'hBAD00000;
                if(araddr==bad_read_address) rresp<=bad_rresp;else rresp<=0;
            end else if(r_pending && !rvalid) rvalid<=1;
            if(rvalid && rready) begin rvalid<=0;r_pending<=0;end
            if(awvalid && awready) begin
                have_aw<=1;saved_aw<=awaddr;
                if(write_count<8) aw_cycle[write_count]<=cycles;
            end else if(awvalid && !have_aw) aw_wait<=aw_wait+1;
            if(wvalid && wready) begin
                have_w<=1;saved_w<=wdata;saved_strb<=wstrb;
                if(write_count<8) w_cycle[write_count]<=cycles;
            end else if(wvalid && !have_w) w_wait<=w_wait+1;
            if(have_aw && have_w && !b_pending) begin
                b_pending<=1;b_wait<=0;
                if(write_count<8) begin
                    write_addresses[write_count]<=saved_aw;write_values[write_count]<=saved_w;
                end
                case(write_count)
                    0: begin expected_address=32'h43C00024;expected_data=32'h00000002;end
                    1: begin expected_address=32'h43C00030;expected_data=32'hD9B8ACF0;end
                    2: begin expected_address=32'h43C00034;expected_data=32'h80000000;end
                    3: begin expected_address=32'h43C00038;expected_data=32'h11223344;end
                    4: begin expected_address=32'h43C0003C;expected_data=32'h55667788;end
                    default: begin expected_address=32'hFFFFFFFF;expected_data=32'hFFFFFFFF;end
                endcase
                if(saved_aw!==expected_address || saved_w!==expected_data || saved_strb!==4'hF)
                    sequence_errors<=sequence_errors+1;
                if(saved_aw==32'h43C00024) isr_value<=isr_value & ~saved_w;
                if(saved_aw==32'h43C00030) idr_seen<=saved_w;
                if(saved_aw==32'h43C0003C) begin enqueued_count<=enqueued_count+1;ack_wait<=0;end
                if(fault_mode==4 && write_count==fault_index) bresp<=bad_bresp;else bresp<=0;
            end else if(b_pending && !bvalid && !(fault_mode==3 && write_count==fault_index)) begin
                if(b_wait>=b_delay) bvalid<=1;
                else begin b_wait<=b_wait+1;b_wait_cycles<=b_wait_cycles+1;end
            end
            if(bvalid && bready) begin
                bvalid<=0;b_pending<=0;have_aw<=0;have_w<=0;
                aw_wait<=0;w_wait<=0;write_count<=write_count+1;
            end
        end
    end
endmodule
