`timescale 1ns/1ps
module tb_robstride_cancel_lifecycle;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,req=0,cv=0,cp=0,fv=0;
reg [7:0] motor=5,cmotor=5;reg [15:0] idx=16'h7005,cidx=16'h7005;
reg [28:0] rxid=29'h110005FD;
reg [31:0] token=32'd42,ctoken=32'd42;
wire ready,rejected,active,cr,cd,matched,rv;wire [5:0] pending,poisoned;
integer passes=0;
robstride_protocol #(.CONFIG_ENABLE(1),.HOST_ID(8'hFD),.MOTOR_IDS(48'h060504030201),
 .FEEDBACK_TIMEOUT_CYCLES(100),.PARAM_TIMEOUT_CYCLES(20)) p(
 .clk(clk),.rst_n(rst_n),.consume_enable(1'b1),.frame_valid(fv),.frame_ready(),
 .can_id(rxid),.can_ide(1'b1),.can_rtr(1'b0),.can_dlc(4'd8),
 .can_data(64'h1234567800007005),.frame_timestamp(p.time_now),.frame_error(8'd0),.stream_integrity_lost(1'b0),
 .param_req_valid(req),.param_req_ready(ready),.param_req_rejected(rejected),
 .param_req_host(8'hFD),.param_req_motor(motor),.param_req_index(idx),.param_req_token(token),.param_req_active(active),
 .param_cancel_valid(cv),.param_cancel_ready(cr),.param_cancel_motor(cmotor),.param_cancel_index(cidx),
 .param_cancel_token(ctoken),.param_cancel_poison(cp),.param_cancel_done(cd),.param_cancel_matched(matched),
 .param_reply_valid(rv),.param_reply_failed(),.param_reply_axis(),.param_pending(pending),.param_poisoned(poisoned),.query_axis(3'd4),.debug_page(5'd0));
task step;input integer n;begin repeat(n) @(negedge clk);end endtask
task check;input ok;input [8*100-1:0] label;begin
 if(ok!==1) $fatal(1,"FAIL: %0s pending=%h poisoned=%h",label,pending,poisoned);
 passes=passes+1;$display("PASS: %0s",label);end endtask
task reset_all;begin rst_n=0;req=0;cv=0;cp=0;fv=0;motor=5;cmotor=5;idx=16'h7005;cidx=16'h7005;token=42;ctoken=42;
 step(3);rst_n=1;step(2);end endtask
task register;begin req=1;step(1);req=0;check(!rejected && active,"registration accepted and active");end endtask
task cancel;input expected;begin cv=1;step(1);cv=0;check(cd && matched==expected,"cancel returns explicit exact-match result");end endtask
initial begin #10000;$fatal(1,"global timeout");end
initial begin
 reset_all;cancel(0);check(pending==0 && poisoned==0,"cancel cannot invent transaction");
 register;check(!ready,"pending axis backpressures registration");
 cmotor=6;cancel(0);check(pending[4],"wrong motor preserves pending");
 cmotor=5;cidx=16'h7016;cancel(0);check(pending[4],"wrong index preserves pending");
 cidx=16'h7005;ctoken=43;cancel(0);check(pending[4],"wrong token preserves pending");
 ctoken=42;cancel(1);check(pending==0 && poisoned==0 && !active,"unsubmitted cancel clears pending");
 register;cp=1;cancel(1);check(poisoned[4] && !pending[4],"uncertainty poison clears pending and quarantines");
 cp=0;cancel(0);check(poisoned[4],"normal cancel cannot clear uncertainty poison");
 req=1;step(1);req=0;check(rejected && !active,"poisoned axis rejects new registration");
 fv=1;step(1);fv=0;step(1);check(!rv && poisoned[4],"poison rejects late response");
 reset_all;register;
 // Stage reply in dispatch, then cancel on the same edge as bank consumption.
 fv=1;step(1);fv=0;cv=1;step(1);cv=0;
 check(cd && matched && !rv && pending==0,"cancel wins over same-edge reply");
 reset_all;register;rxid=29'h020005FD;fv=1;step(1);fv=0;cv=1;step(1);cv=0;
 check(cd && matched && p.bank.statuses[4]==1,"cancel does not block concurrent status update");
 rxid=29'h110005FD;
 reset_all;register;step(19);
 check(!active && pending[4],"deadline combinationally invalidates before sequential expiry");
 cancel(1);check(pending==0 && poisoned==0,"unsubmitted cancel wins over same-edge expiry");
 reset_all;register;step(23);check(!active && poisoned[4] && !pending[4],"expiry quarantines transaction");
 cancel(1);check(poisoned==0 && pending==0,"proven unsubmitted expired transaction can be cleaned");
 $display("RESULT: PASS cancel bank checks=%0d",passes);$finish;
end
endmodule
