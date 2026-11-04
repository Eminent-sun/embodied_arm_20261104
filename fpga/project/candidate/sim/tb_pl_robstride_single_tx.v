`timescale 1ns/1ps
module single_tx_lifecycle_suite #(parameter REAL_PROTOCOL=1, ACCEPT_CYCLES=12);
reg clk=0; always #5 clk=~clk;
reg rst_n=0,trigger=0;
reg [28:0] can_id=29'h1100FD05;
reg [7:0] can_dlc=8;
reg [63:0] can_data=64'h7005;
reg reg_enable=1,reject_reg=0,cancel_enable=1,bad_cancel=0,cancel_response_enable=1; 
reg tx_ready=0,tx_done=0,tx_success=0,tx_may=0;
reg [7:0] tx_error=0;
wire req,ready,rejected,active,cv,cr,cd,bank_cd,cm,cp;
assign cd=bank_cd && cancel_response_enable;
wire [7:0] host,motor,c_motor;
wire [15:0] idx,c_idx;
wire [31:0] token,c_token;
wire tv,busy,done,success,error,locked;
wire [28:0] tid; wire [7:0] tdlc; wire [63:0] tdata;
wire [7:0] ec; wire [3:0] state;
wire rv,rf; wire [31:0] rt;
wire [5:0] pending,poisoned;
reg frame_valid=0;wire frame_ready;
wire [31:0] unmatched;
reg mock_reply=0;
integer reserved_byte;
integer passes=0,regs=0,txs=0,cancels=0,replies=0,completions=0;
reg [7:0] last_error;reg last_success;
pl_robstride_single_tx #(.REG_TIMEOUT_CYCLES(8),.TX_ACCEPT_TIMEOUT_CYCLES(ACCEPT_CYCLES),
 .TX_RESULT_TIMEOUT_CYCLES(20),.REPLY_TIMEOUT_CYCLES(20),.CANCEL_TIMEOUT_CYCLES(8)) dut(
 .clk(clk),.rst_n(rst_n),.trigger(trigger),.can_id(can_id),.can_dlc(can_dlc),.can_data(can_data),
 .param_req_valid(req),.param_req_ready(ready),.param_req_rejected(rejected),.param_req_active(active),
 .param_req_host(host),.param_req_motor(motor),.param_req_index(idx),.param_req_token(token),
 .param_cancel_valid(cv),.param_cancel_ready(cr),.param_cancel_done(cd),.param_cancel_matched(cm),
 .param_cancel_motor(c_motor),.param_cancel_index(c_idx),.param_cancel_token(c_token),.param_cancel_poison(cp),
 .param_reply_valid(rv),.param_reply_failed(rf),.param_reply_token(rt),
 .tx_req_valid(tv),.tx_req_ready(tx_ready),.tx_can_id(tid),.tx_can_dlc(tdlc),.tx_can_data(tdata),
 .tx_done(tx_done),.tx_success(tx_success),.tx_may_have_submitted(tx_may),.tx_error_code(tx_error),
 .busy(busy),.fault_locked(locked),.done(done),.success(success),.error(error),.error_code(ec),.state(state));
generate if(REAL_PROTOCOL) begin: real_bank
 wire br,bcr;
 robstride_protocol #(.CONFIG_ENABLE(1),.HOST_ID(8'hFD),.MOTOR_IDS(48'h060504030201),
 .FEEDBACK_TIMEOUT_CYCLES(100),.PARAM_TIMEOUT_CYCLES(60)) protocol(
 .clk(clk),.rst_n(rst_n),.consume_enable(1'b1),.frame_valid(frame_valid),.frame_ready(frame_ready),
 .can_id(29'h110005FD),.can_ide(1'b1),.can_rtr(1'b0),.can_dlc(4'd8),
 .can_data(64'h1234567800007005),.frame_timestamp(protocol.time_now),.frame_error(8'd0),.stream_integrity_lost(1'b0),
 .param_req_valid(req && reg_enable),.param_req_ready(br),.param_req_rejected(rejected),
 .param_req_host(reject_reg?8'hFC:host),.param_req_motor(motor),.param_req_index(idx),.param_req_token(token),
 .param_req_active(active),.param_cancel_valid(cv && cancel_enable),.param_cancel_ready(bcr),
 .param_cancel_motor(c_motor),.param_cancel_index(c_idx),.param_cancel_token(bad_cancel?c_token+1'b1:c_token),
 .param_cancel_poison(cp),.param_cancel_done(bank_cd),.param_cancel_matched(cm),
 .param_reply_valid(rv),.param_reply_failed(rf),.param_reply_axis(),.param_reply_token(rt),.param_pending(pending),.param_poisoned(poisoned),
 .query_axis(3'd4),.debug_page(5'd0),.parameter_unmatched_count(unmatched));
 assign ready=br && reg_enable;assign cr=bcr && cancel_enable;
end else begin: mocked
 reg m_active=0,m_reject=0,m_done=0,m_match=0,m_poison=0;
 assign ready=reg_enable;assign rejected=m_reject;assign active=m_active;
 assign cr=cancel_enable;assign bank_cd=m_done;assign cm=m_match;
 assign pending={1'b0,m_active,4'b0};assign poisoned={1'b0,m_poison,4'b0};
 assign rv=mock_reply && m_active && !m_poison;assign rf=0;assign rt=token;assign unmatched=0;assign frame_ready=1;
 always @(posedge clk) begin
  if(!rst_n) begin m_active<=0;m_reject<=0;m_done<=0;m_match<=0;m_poison<=0;end
  else begin
   m_reject<=req && ready && reject_reg;m_done<=cv && cr;m_match<=cv && cr && !bad_cancel;
   if(req && ready && !reject_reg) m_active<=1;
   if(mock_reply) m_active<=0;
   if(cv && cr && !bad_cancel) begin m_active<=0;m_poison<=cp;end
  end
 end
end endgenerate
always @(posedge clk) if(!rst_n) begin regs<=0;txs<=0;cancels<=0;replies<=0;completions<=0;last_error<=0;last_success<=0;end
else begin
 if(req && ready) regs<=regs+1;
 if(tv && tx_ready) begin
  txs<=txs+1;
  if(tid!==29'h1100FD05 || tdlc!==8 || tdata!==64'h7005) $fatal(1,"bad submitted payload");
 end
 if(cv && cr) cancels<=cancels+1;
 if(rv) replies<=replies+1;
 if(done) begin completions<=completions+1;last_error<=ec;last_success<=success;end
 if(tv && !active) $fatal(1,"TX with inactive registration");
 if(locked && (req || tv)) $fatal(1,"request while locked");
end
task check;input cond;input [8*120-1:0] label;begin
 if(cond!==1'b1) $fatal(1,"FAIL: %0s state=%0d ec=%0d txs=%0d pending=%h poison=%h",label,state,ec,txs,pending,poisoned);
 passes=passes+1;$display("PASS: %0s",label);
end endtask
task step;input integer n;begin repeat(n) @(negedge clk);end endtask
task reset_all;begin
 @(negedge clk);rst_n=0;trigger=0;reg_enable=1;reject_reg=0;cancel_enable=1;bad_cancel=0;cancel_response_enable=1;
 tx_ready=0;tx_done=0;tx_success=0;tx_may=0;tx_error=0;frame_valid=0;mock_reply=0;
 can_id=29'h1100FD05;can_dlc=8;can_data=64'h7005;step(3);rst_n=1;step(2);
end endtask
task fire;begin trigger=0;step(1);trigger=1;step(1);end endtask
task wait_state;input [3:0] target;integer n;begin
 n=0;while(state!=target && n<150) begin step(1);n=n+1;end
 if(state!=target) $fatal(1,"state timeout target=%0d actual=%0d",target,state);
end endtask
task wait_complete;integer n;begin
 n=0;while(completions==0 && n<200) begin step(1);n=n+1;end
 if(completions!=1) $fatal(1,"completion timeout/duplicate");
end endtask
task accept_tx;begin wait_state(3);tx_ready=1;step(1);tx_ready=0;check(txs==1 && state==4,"one Master acceptance");end endtask
task result_tx;input ok;input may_tx;begin tx_success=ok;tx_may=may_tx;tx_done=1;step(1);tx_done=0;end endtask
task reply;begin
 if(REAL_PROTOCOL) begin frame_valid=1;step(1);frame_valid=0;step(3);end
 else begin mock_reply=1;step(1);mock_reply=0;step(2);end
end endtask
task illegal;input [28:0] id;input [7:0] dlc;input [63:0] data;begin
 reset_all;can_id=id;can_dlc=dlc;can_data=data;fire;step(2);
 check(completions==1 && last_error==1 && regs==0 && txs==0 && pending==0,"illegal frame zero registration / zero submission");
end endtask
initial begin #100000; $fatal(1,"global timeout");end
initial begin
 reset_all;
 // High at reset must not arm a rising edge.
 rst_n=0;trigger=1;step(3);rst_n=1;step(12);
 check(regs==0 && txs==0 && !busy,"reset-high trigger remains disarmed");
 fire;wait_state(3);can_id=0;can_dlc=0;can_data=0;
 trigger=0;step(1);trigger=1;step(2);
 check(regs==1 && txs==0 && tv && tid==29'h1100FD05 && tdata==64'h7005,"latching / backpressure / busy trigger");
 accept_tx;result_tx(1,1);reply;wait_complete;
 check(last_success && !busy && pending==0 && txs==1,"legal 7005 completes only after reply");
 step(10);check(regs==1 && txs==1 && completions==1,"held trigger no repeat");
 illegal(29'h1100FD05,8,64'h7016);
 illegal(29'h1100FC05,8,64'h7005);
 illegal(29'h1100FD06,8,64'h7005);
 illegal(29'h1100FD05,7,64'h7005);
 illegal(29'h1100FD05,8,64'h100007005);
 for(reserved_byte=2;reserved_byte<8;reserved_byte=reserved_byte+1)
  illegal(29'h1100FD05,8,64'h7005 | (64'hFF << (reserved_byte*8)));
 illegal(29'h0300FD05,8,64'h7005);
 illegal(29'h1101FD05,8,64'h7005);
 reset_all;reject_reg=1;fire;wait_complete;
 check(last_error==2 && regs==1 && txs==0 && pending==0 && !locked,"explicit registration rejection");
 reset_all;reg_enable=0;fire;wait_complete;
 check(last_error==4 && regs==0 && txs==0 && !busy,"bounded registration wait");
 reset_all;fire;wait_state(3);wait_complete;
 check(txs==0 && cancels==1 && pending==0 && poisoned==0 && !busy,"unsubmitted wait timeout/expiry cancels exact transaction");
 fire;accept_tx;result_tx(0,0);step(4);
 check(txs==1 && regs==2 && pending==0 && !locked,"safe retry after unsubmitted cancellation");
 reset_all;fire;accept_tx;tx_error=8'h22;result_tx(0,0);wait_complete;
 check(last_error==8'h22 && cancels==1 && pending==0 && !locked,"TX error with proof of no submission cancels");
 reset_all;fire;accept_tx;result_tx(0,1);wait_complete;
 check(locked && pending==0 && poisoned[4],"possibly submitted TX error poisons and locks");
 fire;reply;step(5);
 check(locked && txs==1 && regs==1 && replies==0,"late reply isolated / retry forbidden");
 if(REAL_PROTOCOL) check(unmatched==1,"late reply counted unmatched by real protocol");
 reset_all;fire;accept_tx;result_tx(0,1'bx);wait_complete;
 check(locked && poisoned[4],"unknown submission evidence locks conservatively");
 reset_all;fire;accept_tx;wait_complete;
 check(last_error==6 && locked && poisoned[4],"TX result timeout locks conservatively");
 reset_all;fire;accept_tx;result_tx(1,1);wait_complete;
 check(last_error==8 && locked && poisoned[4],"reply timeout locks after successful TX");
 reset_all;cancel_enable=0;fire;accept_tx;result_tx(0,0);wait_complete;
 check(last_error==10 && locked,"cancel acceptance timeout locks");
 reset_all;cancel_response_enable=0;fire;accept_tx;result_tx(0,0);wait_complete;
 check(last_error==10 && locked && pending==0,"cancel result timeout locks even after bank cleanup");
 reset_all;reg_enable=0;fire;step(3);reg_enable=1;accept_tx;result_tx(0,0);wait_complete;
 check(!locked && regs==1 && txs==1,"registration backpressure released within deadline");
 reset_all;bad_cancel=1;fire;accept_tx;result_tx(0,0);wait_complete;
 check(last_error==11 && locked && pending[4],"mismatched token cancellation does not erase pending");
 reset_all;fire;accept_tx;reply;result_tx(1,1);wait_complete;
 check(last_success && !locked && txs==1,"reply preceding TX result retained");
 if(REAL_PROTOCOL && ACCEPT_CYCLES>60) begin
  reset_all;fire;wait_state(3);step(65);
  check(txs==0 && !tv && pending==0 && poisoned==0 && !busy,"registration expiry before Master ready prevents submission and cleans");
 end
 $display("RESULT: PASS suite real_protocol=%0d checks=%0d",REAL_PROTOCOL,passes);$finish;
end
endmodule
module tb_pl_robstride_single_tx;single_tx_lifecycle_suite #(.REAL_PROTOCOL(0)) suite();endmodule
module tb_robstride_single_tx_integration;single_tx_lifecycle_suite #(.REAL_PROTOCOL(1)) suite();endmodule

module tb_robstride_single_tx_expiry;single_tx_lifecycle_suite #(.REAL_PROTOCOL(1),.ACCEPT_CYCLES(80)) suite();endmodule
