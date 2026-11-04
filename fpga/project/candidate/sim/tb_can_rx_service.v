`timescale 1ns / 1ps
module tb_can_rx_service #(parameter integer REAL_TIMING=0);
    localparam integer PERIOD=REAL_TIMING?500000:5000;
    reg clk=0,rst_n=0,locked=0,released=0,start_req=0,stop_req=0;
    reg [1:0] period_sel=0,limit_sel=0;
    reg hold_aw=0,hold_w=0,hold_b=0,hold_ar=0,hold_r=0,fifo_full=0,no_txok=0,can_error=0;
    reg [31:0] ack_delay=5;
    integer fail_write=-1,fail_read=-1,checks=0,failures=0,i,n,saved_count;
    wire [31:0] awaddr,wdata,araddr,rdata,scheduled,attempted,enqueued,successes,errors,missed,sequence;
    wire [31:0] selected_period,frame_limit,status_count,last_isr,last_attempt_cycle,last_complete_cycle;
    wire [3:0] wstrb,error_code;
    wire [1:0] bresp,rresp;
    wire awvalid,wvalid,bready,arvalid,rready,awready,wready,bvalid,arready,rvalid;
    wire initialized,init_error,done,stopped,tx_busy,tx_error,quarantined,may_pending,round_used,rejected,violation;
    wire [2:0] scheduler_state;
    wire [31:0] writes,reads,model_enqueued,model_errors,reset_count,model_sequence;
    integer previous_enqueues=0,previous_scheduled=0,cycle=0,previous_tick=0,previous_isr_cycle=-1,isr_reads=0;
    integer first_attempt_cycle=-1,second_attempt_cycle=-1,previous_attempts=0;
    reg previous_ar_stall=0,previous_aw_stall=0,previous_w_stall=0;
    reg [31:0] held_ar=0,held_aw=0,held_w=0;
    always #10 clk=~clk;
    wire [31:0] seq3,started3,completed3,missed3,maxspan3,limit3;
    wire [2:0] axis3;
    wire fault3;
    reg rx_in_valid=0,rx_ready=1;
    reg [31:0] rx_in_idr=0,rx_in_dlcr=0,rx_in_dw1=0,rx_in_dw2=0,inject_isr=0,response_delay=0;
    reg [1:0] read_error_response=2,write_error_response=2;
    wire rx_valid,rx_ide,rx_rtr,integrity,rx_fault;
    wire [28:0] rx_id,rx_last_id;
    wire [3:0] rx_dlc,rx_last_dlc,rx_state;
    wire [63:0] rx_data,rx_timestamp;
    wire [7:0] rx_flags,frame_error;
    wire [31:0] rx_frames,rx_overflows,rx_underflows,rx_axi_errors,rx_invalid,rx_drops,rx_level,rx_isr;
    wire [31:0] snap_isr,snap_esr,snap_ecr,snap_sr;
    wire [7:0] snap_status;
    wire [31:0] hw_level,hw_popped,hw_dropped,hw_illegal,hw_words,hw_acks,model_tx_acks;
    can_axi_lite_master #(.ENABLE_RX(1),.RX_FIFO_DEPTH(4),.RX_POLL_CYCLES(REAL_TIMING?2500:20),.ENABLE_PL_INIT(1),.ENABLE_PERIODIC(1),.ENABLE_SIX_AXIS(1),
        .INIT_TIMEOUT_CYCLES(500),.INIT_POLL_CYCLES(3),.TIMEOUT_CYCLES(64),
        .POLL_INTERVAL_CYCLES(73),.PERIOD_100HZ_CYCLES(PERIOD),
        .TXOK_POLL_CYCLES(REAL_TIMING?5000:20),
        .TXOK_TIMEOUT_CYCLES(REAL_TIMING?500000:500),
        .SEND_TIMEOUT_CYCLES(REAL_TIMING?1000000:1200)) dut(
        .rx_ready(rx_ready),.rx_valid(rx_valid),.rx_can_id(rx_id),.rx_ide(rx_ide),.rx_rtr(rx_rtr),
        .rx_dlc(rx_dlc),.rx_data(rx_data),.rx_timestamp(rx_timestamp),.rx_frame_error(frame_error),
        .rx_error_flags(rx_flags),.rx_integrity_lost(integrity),.rx_service_fault(rx_fault),
        .rx_service_state(rx_state),.rx_frame_count(rx_frames),.rx_overflow_count(rx_overflows),
        .rx_underflow_count(rx_underflows),.rx_axi_error_count(rx_axi_errors),
        .rx_invalid_frame_count(rx_invalid),.rx_sw_drop_count(rx_drops),.rx_fifo_level(rx_level),
        .rx_last_id(rx_last_id),.rx_last_dlc(rx_last_dlc),.rx_last_isr(rx_isr),
        .rx_snapshot_isr(snap_isr),.rx_snapshot_esr(snap_esr),
        .rx_snapshot_ecr(snap_ecr),.rx_snapshot_sr(snap_sr),
        .rx_snapshot_status(snap_status),
        .aclk(clk),.aresetn(rst_n),.clock_locked(locked),.reset_released(released),
        .send_req(start_req),.stop_req(stop_req),.period_sel(period_sel),.limit_sel(limit_sel),
        .m_axi_awaddr(awaddr),.m_axi_awprot(),.m_axi_awvalid(awvalid),.m_axi_awready(awready),
        .m_axi_wdata(wdata),.m_axi_wstrb(wstrb),.m_axi_wvalid(wvalid),.m_axi_wready(wready),
        .m_axi_bresp(bresp),.m_axi_bvalid(bvalid),.m_axi_bready(bready),
        .m_axi_araddr(araddr),.m_axi_arprot(),.m_axi_arvalid(arvalid),.m_axi_arready(arready),
        .m_axi_rdata(rdata),.m_axi_rresp(rresp),.m_axi_rvalid(rvalid),.m_axi_rready(rready),
        .can_initialized(initialized),.can_init_error(init_error),.success_count(status_count),
        .scheduled_count(scheduled),.attempted_count(attempted),.enqueued_count(enqueued),
        .tx_success_count(successes),.tx_error_count(errors),.missed_deadline_count(missed),
        .last_sequence(sequence),.selected_period(selected_period),.frame_limit(frame_limit),
        .periodic_completed(done),.periodic_stopped(stopped),.scheduler_state(scheduler_state),
        .tx_busy(tx_busy),.tx_error(tx_error),.tx_error_code(error_code),.last_isr(last_isr),
        .bus_quarantined(quarantined),.tx_may_be_pending(may_pending),.round_used(round_used),
        .start_rejected(rejected),.deadline_violation(violation),
        .last_attempt_cycle(last_attempt_cycle),.tx_completed_cycle(last_complete_cycle),
        .cycle_seq(seq3),.axis_index(axis3),.cycle_started_count(started3),.cycle_completed_count(completed3),
        .missed_cycle_count(missed3),.max_cycle_span_cycles(maxspan3),.cycle_limit(limit3),.scheduler_fault(fault3));
    can_axi_rx_slave_model #(.SIX_AXIS_TEST(1)) slave(.clk(clk),.rst_n(rst_n),
        .rx_in_valid(rx_in_valid),.rx_in_idr(rx_in_idr),.rx_in_dlcr(rx_in_dlcr),
        .rx_in_dw1(rx_in_dw1),.rx_in_dw2(rx_in_dw2),.inject_isr(inject_isr),
        .read_error_response(read_error_response),.write_error_response(write_error_response),
        .response_delay(response_delay),.rx_level(hw_level),.rx_popped(hw_popped),
        .rx_dropped(hw_dropped),.rx_illegal_reads(hw_illegal),.rx_word_reads(hw_words),.rx_icr_writes(hw_acks),.tx_acked_count(model_tx_acks),
        .awaddr(awaddr),.wdata(wdata),.araddr(araddr),.wstrb(wstrb),
        .awvalid(awvalid),.wvalid(wvalid),.bready(bready),.arvalid(arvalid),.rready(rready),
        .awready(awready),.wready(wready),.bvalid(bvalid),.arready(arready),.rvalid(rvalid),
        .bresp(bresp),.rresp(rresp),.rdata(rdata),
        .hold_aw(hold_aw),.hold_w(hold_w),.hold_b(hold_b),.hold_ar(hold_ar),.hold_r(hold_r),
        .config_stuck(1'b0),.normal_stuck(1'b0),.fifo_full(fifo_full),.no_txok(no_txok),
        .can_error(can_error),.txok_delay_cycles(ack_delay),.fail_write_index(fail_write),.fail_read_index(fail_read),
        .write_count(writes),.read_count(reads),.enqueued_count(model_enqueued),.protocol_errors(model_errors),
        .reset_count(reset_count),.last_sequence(model_sequence));
    reg [28:0] exp_id[0:8191];
    reg exp_ide[0:8191],exp_rtr[0:8191];
    reg [3:0] exp_dlc[0:8191];
    reg [63:0] exp_data[0:8191];
    integer exp_count=0,consumed=0,slot=0,old_started=0,last_start=0;
    integer accepted=0,old_enqueued=0,k,j,phase,code_index;
    integer expected_phase=0,observed_groups=0,max_rx_age=0,old_popped=0;
    integer diagnostic_reads=0;
    integer injected_tick[0:8191];
    reg scoreboard=1,atomic_rx=0,stalled=0;
    reg stress_waits=0;
    reg prev_ar_stall=0,prev_aw_stall=0,prev_w_stall=0;
    reg [31:0] saved_ar,saved_aw,saved_w;
    reg [170:0] stalled_frame;
    reg [63:0] last_stamp=0;
    integer request_states[0:5];
    task expect;
        input ok;input [8*140-1:0] label;
        begin if(ok!==1'b1) begin failures=failures+1;if(failures<30)$display("FAIL: %0s",label);end end
    endtask
    task check;
        input ok;input [8*140-1:0] label;
        begin checks=checks+1;expect(ok,label);if(ok===1'b1)$display("PASS: %0s",label);end
    endtask
    task reset_all;
        begin
            @(negedge clk);rst_n=0;locked=0;released=0;start_req=0;stop_req=0;
            rx_in_valid=0;rx_ready=1;inject_isr=0;response_delay=0;scoreboard=1;stress_waits=0;
            hold_aw=0;hold_w=0;hold_b=0;hold_ar=0;hold_r=0;fifo_full=0;no_txok=0;can_error=0;
            fail_write=-1;fail_read=-1;read_error_response=2;write_error_response=2;
            ack_delay=5;period_sel=1;limit_sel=0;exp_count=0;
            repeat(4) @(negedge clk);rst_n=1;locked=1;released=1;
            k=0;while(!initialized&&!init_error&&k<1000) begin @(negedge clk);k=k+1;end
            expect(initialized&&!init_error,"autonomous init completes with RX enabled");
            repeat(5) @(negedge clk);
        end
    endtask
    task inject_frame;
        input [28:0] id;
        input ide,rtr;
        input [3:0] dlc;
        input [63:0] data;
        begin
            @(negedge clk);
            rx_in_idr=ide?{id[28:18],1'b1,1'b1,id[17:0],rtr}:{id[10:0],rtr,20'd0};
            rx_in_dlcr={dlc,28'd0};
            rx_in_dw1={data[7:0],data[15:8],data[23:16],data[31:24]};
            rx_in_dw2={data[39:32],data[47:40],data[55:48],data[63:56]};
            rx_in_valid=1;
            if(scoreboard && dlc<=8) begin
                exp_id[exp_count]=id;exp_ide[exp_count]=ide;exp_rtr[exp_count]=rtr;
                exp_dlc[exp_count]=dlc;exp_data[exp_count]=data;injected_tick[exp_count]=slot;
                exp_count=exp_count+1;
            end
            @(negedge clk);rx_in_valid=0;
        end
    endtask
    task wait_received;
        input integer count;
        integer n;
        begin
            n=0;while(consumed<count && !rx_fault && n<10000) begin @(negedge clk);n=n+1;end
            expect(consumed==count&&!rx_fault,"all expected frames consumed within bound");
        end
    endtask
    task wait_rx_request;
        input integer wanted;
        integer n;
        begin
            n=0;
            while(!(rx_state==wanted && dut.req_valid && dut.req_owner==3 && dut.req_ready) && n<5000) begin
                @(negedge clk);n=n+1;
            end
            expect(n<5000,"target RX transaction reached");
        end
    endtask
    task wait_fault;
        integer n;
        begin
            n=0;while(!rx_fault && n<1000) begin @(negedge clk);n=n+1;end
            expect(rx_fault,"RX reports AXI error/timeout within bound");
            repeat(5) @(negedge clk);
        end
    endtask
    task nominal;
        input integer count;
        integer c,a,n;
        begin
            reset_all;limit_sel=(count==1000)?1:0;
            if(REAL_TIMING) begin response_delay=12;stress_waits=1;end
            @(negedge clk);start_req=1;
            for(c=0;c<count;c=c+1) begin
                n=0;while(started3<c+1 && !fault3 && n<PERIOD+100) begin @(negedge clk);n=n+1;end
                expect(started3==c+1&&!fault3,"each fixed control cycle starts");
                for(a=0;a<6;a=a+1) begin
                    inject_frame(29'h020001FD+(a<<8),1'b1,1'b0,8,64'h9800000002000000+(c*6+a));
                    repeat(REAL_TIMING?6000:100) @(negedge clk);
                end
            end
            if(REAL_TIMING) begin @(negedge clk);stop_req=1;end
            n=0;while(!done&&!stopped&&!fault3 && n<PERIOD+5000) begin @(negedge clk);n=n+1;end
            wait_received(6*count);
            check(!fault3&&!tx_error&&!rx_fault&&errors==0,"simultaneous TX and RX complete without cross-owner errors");
            check(successes==6*count&&model_tx_acks==6*count&&enqueued==6*count&&completed3==count&&missed3==0,
                "six-axis 100Hz-compatible fixed schedule retains exact TX counts and deadlines");
            check(rx_frames==6*count&&consumed==6*count&&rx_level==0&&!integrity&&hw_dropped==0,
                "all incoming frames pass FIFO/scoreboard with no silent loss");
            check(hw_words==24*count&&hw_illegal==0&&model_errors==0&&observed_groups==6*count,
                "every RX frame reads exactly four words under exclusive group ownership");
            check(status_count>0&&maxspan3<PERIOD,"Status Reader still serviced; six TX frames finish before next cycle");
            $display("RX_NOMINAL cycles=%0d tx=%0d rx=%0d max_tx_span=%0d max_inject_to_pop=%0d period=%0d response_delay=%0d",
                count,successes,rx_frames,maxspan3,max_rx_age,PERIOD,response_delay);
        end
    endtask
    always @(posedge clk) begin
        if(!rst_n) begin consumed=0;last_stamp=0;stalled=0;accepted=0;end
        else begin
            if(stalled) expect(rx_valid&&{rx_id,rx_ide,rx_rtr,rx_dlc,rx_data,rx_timestamp,frame_error}==stalled_frame,
                "complete frame and metadata remain stable under backpressure");
            stalled=rx_valid&&!rx_ready;
            stalled_frame={rx_id,rx_ide,rx_rtr,rx_dlc,rx_data,rx_timestamp,frame_error};
            if(rx_valid&&rx_ready) begin
                if(scoreboard) begin
                    expect(consumed<exp_count,"no phantom RX output");
                    expect(rx_id==exp_id[consumed]&&rx_ide==exp_ide[consumed]&&rx_rtr==exp_rtr[consumed],
                        "IDR independently decodes extended/standard ID and RTR");
                    expect(rx_dlc==exp_dlc[consumed]&&rx_data==exp_data[consumed],"DLC and all eight bytes match independent expected data");
                    expect(rx_timestamp>last_stamp&&rx_timestamp<=dut.rx_time_counter,"64-bit timestamp is monotonic IDR service time");
                    last_stamp=rx_timestamp;
                end
                consumed=consumed+1;
            end
            if(dut.send_trigger) begin
                expect(successes==accepted,"next TX frame requires previous new TXOK despite RX data bit1");
                accepted=accepted+1;
            end
            if(prev_ar_stall) expect(arvalid&&araddr==saved_ar,"AR payload remains stable under waits");
            if(prev_aw_stall) expect(awvalid&&awaddr==saved_aw,"AW payload remains stable under waits");
            if(prev_w_stall) expect(wvalid&&wdata==saved_w,"W payload remains stable under waits");
            expect(!((arvalid||rready)&&(awvalid||wvalid||bready)),"single unchanged AXI executor serializes channels");
            if(dut.req_valid&&dut.req_ready && dut.req_owner==3 && dut.req_write)
                expect((dut.req_data & ~32'hF0)==0,"RX event clear never touches TXOK/ERROR/BSOFF");
        end
        prev_ar_stall=rst_n&&arvalid&&!arready;saved_ar=araddr;
        prev_aw_stall=rst_n&&awvalid&&!awready;saved_aw=awaddr;
        prev_w_stall=rst_n&&wvalid&&!wready;saved_w=wdata;
    end
    always @(negedge clk) begin
        if(!rst_n) begin
            slot=0;old_started=0;last_start=0;expected_phase=0;atomic_rx=0;
            diagnostic_reads=0;
            old_enqueued=0;observed_groups=0;max_rx_age=0;old_popped=0;
        end else begin
            slot=slot+1;
            expect(successes<=model_tx_acks,"RX data/ISR cannot fabricate a TXOK success");
            if(stress_waits) begin
                hold_ar=(slot%17<8);hold_aw=(slot%19<7);hold_w=(slot%23<9);
                hold_b=(slot%29<6);hold_r=(slot%31<7);
            end
            if(started3!=old_started) begin
                if(old_started) expect(slot-last_start==PERIOD,"control starts stay on fixed grid during RX traffic");
                old_started=started3;last_start=slot;
            end
            if(rx_fault) atomic_rx=0;
            if(dut.req_valid&&dut.req_ready) begin
                if(atomic_rx) expect(dut.req_owner==3,"RX four-word group is not interleaved with another owner");
                if(dut.req_owner==3) begin
                    if(dut.req_addr==32'h43C00014 || dut.req_addr==32'h43C00010 ||
                       dut.req_addr==32'h43C00018) begin
                        expect(!dut.req_write&&!atomic_rx,"diagnostic reads never interrupt RX FIFO group");
                        case(diagnostic_reads)
                            0: expect(dut.req_addr==32'h43C00014,"diagnostic order: ESR first");
                            1: expect(dut.req_addr==32'h43C00010,"diagnostic order: ECR second");
                            2: expect(dut.req_addr==32'h43C00018,"diagnostic order: SR third");
                            default: expect(0,"no duplicate diagnostic snapshot");
                        endcase
                        diagnostic_reads=diagnostic_reads+1;
                    end
                    if(dut.req_addr==32'h43C00050) begin atomic_rx=1;expected_phase=0;end
                    if(dut.req_addr>=32'h43C00050&&dut.req_addr<=32'h43C0005C) begin
                        expect(dut.req_addr==32'h43C00050+4*expected_phase,"RX ID/DLC/DW1/DW2 ordered");
                        expected_phase=expected_phase+1;
                    end
                    if(dut.req_write&&dut.req_addr==32'h43C00024) begin
                        if(atomic_rx) begin expect(expected_phase==4,"RX ack follows four words");observed_groups=observed_groups+1;end
                        atomic_rx=0;
                    end
                end
            end
            if(hw_popped!=old_popped) begin
                if(scoreboard) begin
                    if(slot-injected_tick[old_popped]>max_rx_age) max_rx_age=slot-injected_tick[old_popped];
                end
                old_popped=hw_popped;
            end
            if(model_enqueued!=old_enqueued) begin
                expect(slave.dw1_word==old_enqueued/6,"TX cycle sequence is unmodified by RX arbitration");
                expect((((slave.id_word>>21)<<18)|((slave.id_word>>1)&32'h3FFFF))==32'h1B345670+old_enqueued%6,
                    "TX six IDs are unchanged");
                expect(slave.data_bytes[4]==old_enqueued%6&&slave.data_bytes[5]==8'hA5&&
                    slave.data_bytes[6]==8'h5A&&slave.data_bytes[7]==8'hC3,"TX suffix remains unchanged");
                old_enqueued=model_enqueued;
            end
        end
    end
    initial begin
        request_states[0]=0;request_states[1]=2;request_states[2]=4;
        request_states[3]=6;request_states[4]=8;request_states[5]=10;
        if(REAL_TIMING) nominal(2);
        else begin
            reset_all;repeat(150) @(negedge clk);
            check(hw_words==0&&rx_frames==0&&!rx_valid&&hw_illegal==0,"empty FIFO polls never read RX data words");
            inject_frame(29'h1234567,1,0,8,64'h8877665544332211);wait_received(1);
            check(rx_frames==1&&hw_words==4&&rx_last_id==29'h1234567&&rx_last_dlc==8,
                "single extended frame, four words, Byte0=11 through Byte7=88");
            inject_frame(29'h321,0,1,0,64'h12345678DEADBEEF);wait_received(2);
            check(hw_words==8&&rx_frames==2,"standard RTR DLC0 still drains all four words");
            inject_frame(29'h1ABCDE,1,1,3,64'h01FE23DC45BA6798);wait_received(3);
            check(hw_words==12&&rx_frames==3,"extended RTR and short DLC preserve complete physical frame");
            reset_all;rx_ready=0;
            inject_frame(29'h101,1,0,8,64'h2);inject_frame(29'h102,1,0,1,64'h98);
            repeat(250) @(negedge clk);
            check(rx_frames==2&&rx_level==2&&hw_dropped==0&&rx_id==29'h101,"two-frame hardware burst fits depth2 and software queue preserves head");
            rx_ready=1;wait_received(2);
            reset_all;inject_frame(29'h201,1,0,8,64'h2);
            wait_rx_request(10);
            inject_frame(29'h202,1,0,8,64'h98);wait_received(2);
            check(rx_frames==2&&hw_illegal==0&&!integrity,"arrival during RX ICR acknowledgement survives set-over-clear race");
            reset_all;scoreboard=0;hold_ar=1;
            inject_frame(1,1,0,8,1);inject_frame(2,1,0,8,2);inject_frame(3,1,0,8,3);
            hold_ar=0;repeat(350) @(negedge clk);
            check(hw_dropped==1&&rx_overflows==1&&rx_flags[0]&&integrity&&rx_frames==2,
                "third burst frame overflows depth2; sticky integrity loss survives hardware clear");
            repeat(100) @(negedge clk);check(rx_overflows==1&&rx_flags[0],"one latched overflow episode is not recounted each poll");
            reset_all;inject_isr=32'h20;@(negedge clk);inject_isr=0;repeat(150) @(negedge clk);
            check(rx_underflows==1&&rx_flags[1]&&integrity&&hw_words==0,"RXUFLW event detected without issuing an empty read");
            reset_all;slave.esr_value=32'h00000001;slave.ecr_value=32'h00000703;
            inject_isr=32'h300;@(negedge clk);inject_isr=0;repeat(150) @(negedge clk);
            check(rx_flags[6:5]==2'b11&&slave.isr[9:8]==2'b11,"CAN ERROR and BSOFF latched without clearing shared TX diagnostics");
            check(snap_status[6:0]==7'b1110101&&snap_isr[9:8]==2'b11&&
                  snap_esr==32'h00000001&&snap_ecr==32'h00000703&&snap_sr==32'h00000098,
                  "first ERROR captures ISR, ESR, ECR, SR after successful AXI responses");
            slave.esr_value=32'h0000001F;slave.ecr_value=32'h0000FFEE;
            repeat(150) @(negedge clk);
            check(snap_esr==32'h00000001&&snap_ecr==32'h00000703&&snap_status[2],
                  "repeated ERROR never overwrites first snapshot");
            check(diagnostic_reads==3,"one-shot snapshot uses exactly three diagnostic reads");
            reset_all;scoreboard=0;
            inject_frame(29'h405,1,0,8,64'h8877665544332211);
            wait_rx_request(4);
            inject_isr=32'h100;@(negedge clk);inject_isr=0;
            wait_received(1);repeat(150)@(negedge clk);
            check(rx_frames==1&&hw_words==4&&snap_status[2]&&diagnostic_reads==3&&hw_illegal==0,
                  "ERROR during locked RX group drains four FIFO words before diagnostic reads");
            reset_all;
            check(snap_status==0&&snap_isr==0&&snap_esr==0&&snap_ecr==0&&snap_sr==0,
                  "PL reset clears the first-error snapshot and validity state");
            slave.diag_read_error_response=2;
            inject_isr=32'h100;@(negedge clk);inject_isr=0;wait_fault;
            check(snap_status[3]&&!snap_status[2]&&!snap_status[1]&&snap_status[6:4]==0&&
                  rx_axi_errors==1&&diagnostic_reads==1,"diagnostic SLVERR is reported; failed ESR value is not latched");
            reset_all;slave.esr_value=32'h00000008;
            slave.diag_error_addr=32'h43C00010;slave.diag_read_error_response=3;
            inject_isr=32'h100;@(negedge clk);inject_isr=0;wait_fault;
            check(snap_status[3]&&!snap_status[2]&&snap_status[6:4]==3'b001&&
                  snap_esr==32'h00000008&&snap_ecr==0&&diagnostic_reads==2,
                  "ECR DECERR retains valid ESR and does not claim ECR or SR");
            reset_all;slave.esr_value=32'h00000004;slave.ecr_value=32'h00000102;
            slave.diag_error_addr=32'h43C00018;slave.diag_read_error_response=2;
            inject_isr=32'h100;@(negedge clk);inject_isr=0;wait_fault;
            check(snap_status[3]&&!snap_status[2]&&snap_status[6:4]==3'b011&&
                  snap_esr==32'h00000004&&snap_ecr==32'h00000102&&snap_sr==0&&diagnostic_reads==3,
                  "SR SLVERR retains ESR/ECR but does not claim complete snapshot");
            reset_all;slave.diag_hold_r=1;
            inject_isr=32'h100;@(negedge clk);inject_isr=0;wait_fault;
            check(snap_status[3]&&!snap_status[2]&&rx_axi_errors==1&&quarantined,
                  "diagnostic R timeout retains failure and AXI quarantine");
            slave.diag_hold_r=0;repeat(100)@(negedge clk);
            reset_all;scoreboard=0;rx_ready=0;
            for(j=0;j<6;j=j+1) begin inject_frame(j,1,0,8,j);repeat(100) @(negedge clk);end
            check(rx_frames==6&&rx_level==4&&rx_drops==2&&rx_flags[4]&&hw_dropped==0,
                "software queue saturation drains hardware but records every discarded complete frame");
            rx_ready=1;repeat(20) @(negedge clk);check(consumed==4&&rx_level==0,"software overflow cannot overwrite oldest four frames");
            reset_all;scoreboard=0;inject_frame(1,1,0,9,64'h0123456789ABCDEF);repeat(180) @(negedge clk);
            check(rx_frames==1&&rx_invalid==1&&rx_flags[3]&&hw_words==4&&consumed==0,
                "invalid classic DLC9 drains four words then rejects output");
            // Every read position gets both SLVERR and DECERR. A partial read
            // may already have a side effect, so no automatic retry is allowed.
            for(code_index=2;code_index<=3;code_index=code_index+1) begin
                for(phase=0;phase<6;phase=phase+1) begin
                    reset_all;scoreboard=0;read_error_response=code_index;write_error_response=code_index;
                    if(phase!=0) inject_frame(1,1,0,8,64'h2);
                    wait_rx_request(request_states[phase]);
                    if(phase==5) fail_write=writes;else fail_read=reads;
                    wait_fault;
                    check(rx_axi_errors==1&&rx_flags[2]&&rx_fault&&consumed==0,
                        "RX SLVERR/DECERR at ISR/ID/DLC/DW1/DW2/ICR fails once without partial output");
                    fail_write=-1;fail_read=-1;repeat(150) @(negedge clk);
                    expect(rx_axi_errors==1&&rx_fault,"AXI error remains terminal without retry");
                end
            end
            reset_all;wait_rx_request(0);hold_ar=1;wait_fault;
            check(quarantined&&rx_axi_errors==1&&hw_words==0,"RX AR timeout keeps executor quarantined and RX reports fault");
            hold_ar=0;repeat(100) @(negedge clk);
            check(!quarantined&&rx_fault&&rx_axi_errors==1,"late AR/R retires without restarting RX or double-counting");
            reset_all;inject_frame(1,1,0,8,1);wait_rx_request(4);hold_r=1;wait_fault;
            check(quarantined&&rx_frames==0&&consumed==0,"RX R timeout discards partial frame and preserves AXI transaction");
            hold_r=0;repeat(100) @(negedge clk);check(!quarantined&&rx_axi_errors==1&&rx_fault,"late R completion cannot publish failed partial frame");
            reset_all;inject_frame(1,1,0,8,1);wait_rx_request(10);hold_b=1;wait_fault;
            check(quarantined&&consumed==0&&rx_axi_errors==1,"RX ICR B timeout reports uncertainty without publishing frame");
            hold_b=0;repeat(100) @(negedge clk);check(!quarantined&&rx_fault&&consumed==0,"late B cannot auto-recover RX");
            nominal(100);nominal(1000);
        end
        if(failures==0) $display("RESULT: PASS CAN_RX real_timing=%0d (%0d checks)",REAL_TIMING,checks);
        else $display("RESULT: FAIL CAN_RX (%0d failures / %0d checks)",failures,checks);
        $finish;
    end
    initial begin #500000000;$display("FAIL: test watchdog expired");$finish;end
endmodule
module tb_can_rx_real_timing;
    tb_can_rx_service #(.REAL_TIMING(1)) test();
endmodule
