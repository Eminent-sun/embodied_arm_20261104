`timescale 1ns/1ps
module tb_servo_axi;
    reg clk=0,rst_n=0;
    always #10 clk=~clk;
    reg [11:0] aw=0,ar=0;
    reg av=0,wv=0,br=0,rv=0,rr=0;
    reg [31:0] wd=0;
    reg [3:0] ws=0;
    wire a_ready,w_ready,bv,a_rready,rvalid,pwm;
    wire [1:0] bresp,rresp;
    wire [31:0] rd;
    integer checks=0;
    pl_servo_axi #(.LEASE_MS(100)) dut(
        .clk(clk),.rst_n(rst_n),.s_axi_awaddr(aw),.s_axi_awvalid(av),.s_axi_awready(a_ready),
        .s_axi_wdata(wd),.s_axi_wstrb(ws),.s_axi_wvalid(wv),.s_axi_wready(w_ready),
        .s_axi_bresp(bresp),.s_axi_bvalid(bv),.s_axi_bready(br),
        .s_axi_araddr(ar),.s_axi_arvalid(rv),.s_axi_arready(a_rready),
        .s_axi_rdata(rd),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rr),.servo_pwm(pwm));
    task check(input bit good,input string message);
        begin if(!good)$fatal(1,"FAIL %s at %t",message,$time);checks++;end
    endtask
    task send_aw(input [11:0] address,input integer delay_cycles);
        begin repeat(delay_cycles)@(negedge clk);aw=address;av=1;
            do @(posedge clk);while(!a_ready);@(negedge clk);av=0;end
    endtask
    task send_w(input [31:0] data,input [3:0] strobe,input integer delay_cycles);
        begin repeat(delay_cycles)@(negedge clk);wd=data;ws=strobe;wv=1;
            do @(posedge clk);while(!w_ready);@(negedge clk);wv=0;end
    endtask
    task write_reg(input [11:0] address,input [31:0] data,input [3:0] strobe,input [1:0] expected,input integer order);
        begin
            fork send_aw(address,order==1?5:1);send_w(data,strobe,order==2?5:1);join
            wait(bv);check(bresp===expected,"BRESP");
            repeat(4)begin @(negedge clk);check(bv&&bresp===expected,"stalled B stable");end
            br=1;@(negedge clk);br=0;
        end
    endtask
    task read_reg(input [11:0] address,input [31:0] expected,input [1:0] response);
        begin
            @(negedge clk);ar=address;rv=1;do @(posedge clk);while(!a_rready);
            @(negedge clk);rv=0;wait(rvalid);check(rd===expected&&rresp===response,"RDATA/RRESP");
            repeat(4)begin @(negedge clk);check(rvalid&&rd===expected&&rresp===response,"stalled R stable");end
            rr=1;@(negedge clk);rr=0;
        end
    endtask
    task pulse_width(input integer expected_us);
        realtime start_time;
        begin @(posedge pwm);start_time=$realtime;@(negedge pwm);
            check(($realtime-start_time)==expected_us*1000.0,"pulse width in real 50MHz clocks");end
    endtask
    realtime rise_time;
    reg [15:0] active_before;
    initial begin
        repeat(5)@(negedge clk);check(!pwm,"reset output low");rst_n=1;
        read_reg(0,32'h53525631,0);read_reg(4,32'h10000,0);read_reg(8,0,0);
        read_reg(12'h030,1110,0);read_reg(12'h034,1490,0);read_reg(12'h038,20000,0);
        write_reg(12'h00c,1220,15,0,1);write_reg(12'h010,10,15,0,2);
        write_reg(12'h014,1,15,0,0);check(!pwm,"staging never enables");
        write_reg(12'h00c,1000,15,2,0);read_reg(12'h00c,1220,0);
        write_reg(12'h00c,1109,15,2,0);write_reg(12'h00c,1491,15,2,0);read_reg(12'h00c,1220,0);
        write_reg(12'h010,0,15,2,0);write_reg(12'h014,51,15,2,0);
        write_reg(12'h00d,1400,15,2,0);write_reg(12'h000,0,15,2,0);read_reg(12'h03c,0,2);
        write_reg(12'h00c,32'h000000d0,1,0,0);read_reg(12'h00c,1232,0);
        write_reg(12'h00c,0,0,0,0);read_reg(12'h00c,1232,0);
        write_reg(12'h00c,1220,15,0,0);
        write_reg(8,1,1,2,0);check(!pwm,"partial control rejected");
        write_reg(8,1,15,0,0);check(pwm&&dut.active_us==1220,"explicit first target, no center sequence");
        pulse_width(1220);
        @(posedge pwm);rise_time=$realtime;@(posedge pwm);check($realtime-rise_time==20000000.0,"period 20ms");
        write_reg(12'h028,32'h4b49434b,15,0,0);
        write_reg(12'h00c,1360,15,0,0);check(dut.target_us==1220,"stage while enabled has no effect");
        write_reg(8,1,15,0,0);check(dut.active_us==1220,"commit preserves in-flight pulse width");
        pulse_width(1230);pulse_width(1240);
        write_reg(12'h014,3,15,0,0);write_reg(8,1,15,0,0);
        active_before=dut.active_us;
        pulse_width(active_before);pulse_width(active_before);pulse_width(active_before+10);
        write_reg(12'h028,32'h4b49434b,15,0,0);
        write_reg(12'h00c,1110,15,0,0);write_reg(12'h014,1,15,0,0);write_reg(8,1,15,0,0);
        pulse_width(active_before); // one decrement from active_before+10
        write_reg(8,0,15,0,0);check(!pwm&&!dut.enabled,"OFF immediate low");
        read_reg(12'h020,1110,0);
        write_reg(8,1,15,0,0);pulse_width(1110);write_reg(8,0,15,0,0);
        write_reg(12'h00c,1490,15,0,0);write_reg(8,1,15,0,0);pulse_width(1490);
        // Actual clocks, short simulated lease: expire and reject heartbeat restart.
        repeat(5000010)@(posedge clk);@(negedge clk);
        check(!pwm&&!dut.enabled&&dut.lease_expired,"watchdog expires without service");
        write_reg(12'h028,32'h4b49434b,15,0,0);check(!pwm&&!dut.enabled,"late kick cannot restart");
        write_reg(8,1,15,0,0);check(pwm&&!dut.lease_expired,"explicit command can restart");
        @(negedge clk);rst_n=0;@(negedge clk);check(!pwm,"reset while active low");
        rst_n=1;read_reg(8,0,0);read_reg(12'h00c,1400,0);
        $display("SERVO_AXI_PASS checks=%0d",checks);$finish;
    end
    initial begin #1000000000;$fatal(1,"FAIL simulation timeout");end
endmodule
