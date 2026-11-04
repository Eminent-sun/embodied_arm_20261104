`timescale 1ns/1ps
// Independent single-servo AXI4-Lite endpoint. No automatic gripper sequence.
module pl_servo_axi #(
    parameter integer CLK_HZ=50000000,
    parameter integer LEASE_MS=1000
)(
    (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER="XIL_INTERFACENAME clk, ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET rst_n, FREQ_HZ 50000000" *)
    input wire clk,
    (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 rst_n RST" *)
    (* X_INTERFACE_PARAMETER="XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW" *)
    input wire rst_n,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    (* X_INTERFACE_PARAMETER="XIL_INTERFACENAME S_AXI, PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 12, FREQ_HZ 50000000, READ_WRITE_MODE READ_WRITE" *)
    input wire [11:0] s_axi_awaddr,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *) input wire s_axi_awvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *) output wire s_axi_awready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WDATA" *) input wire [31:0] s_axi_wdata,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *) input wire [3:0] s_axi_wstrb,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WVALID" *) input wire s_axi_wvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WREADY" *) output wire s_axi_wready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BRESP" *) output reg [1:0] s_axi_bresp,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BVALID" *) output reg s_axi_bvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BREADY" *) input wire s_axi_bready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *) input wire [11:0] s_axi_araddr,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *) input wire s_axi_arvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *) output wire s_axi_arready,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RDATA" *) output reg [31:0] s_axi_rdata,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RRESP" *) output reg [1:0] s_axi_rresp,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RVALID" *) output reg s_axi_rvalid,
    (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RREADY" *) input wire s_axi_rready,
    output wire servo_pwm
);
    localparam integer CYCLES_PER_US=CLK_HZ/1000000;
    localparam integer LEASE_CYCLES=(CLK_HZ/1000)*LEASE_MS;
    reg have_aw,have_w,enabled,lease_expired;
    reg [11:0] awaddr_q;
    reg [31:0] wdata_q;
    reg [3:0] wstrb_q;
    reg [31:0] stage_target,stage_slew,stage_interval;
    reg [15:0] target_us,active_us;
    reg [7:0] slew_us,step_frames,step_count;
    reg [15:0] us_div;
    reg [14:0] frame_us;
    reg [31:0] frame_count,lease_left;
    reg [31:0] merged,read_value;
    reg read_ok;
    assign s_axi_awready=rst_n && !have_aw && !s_axi_bvalid;
    assign s_axi_wready=rst_n && !have_w && !s_axi_bvalid;
    assign s_axi_arready=rst_n && !s_axi_rvalid;
    assign servo_pwm=rst_n && enabled && frame_us<active_us;
    function [31:0] merge_bytes;
        input [31:0] old_value,new_value;
        input [3:0] strobes;
        integer b;
        begin
            merge_bytes=old_value;
            for(b=0;b<4;b=b+1) if(strobes[b]) merge_bytes[b*8+:8]=new_value[b*8+:8];
        end
    endfunction
    always @* begin
        read_ok=1;read_value=0;
        case(s_axi_araddr)
            12'h000:read_value=32'h53525631; // SRV1
            12'h004:read_value=32'h00010000;
            12'h008:read_value={31'd0,enabled};
            12'h00c:read_value=stage_target;
            12'h010:read_value=stage_slew;
            12'h014:read_value=stage_interval;
            12'h018:read_value={28'd0,lease_expired,servo_pwm,(enabled && active_us!=target_us),enabled};
            12'h01c:read_value={16'd0,active_us};
            12'h020:read_value={16'd0,target_us};
            12'h024:read_value=frame_count;
            12'h028:read_value=0; // lease refresh is write-only
            12'h02c:read_value=LEASE_MS;
            12'h030:read_value=1110;
            12'h034:read_value=1490;
            12'h038:read_value=20000;
            default:read_ok=0;
        endcase
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            have_aw<=0;have_w<=0;awaddr_q<=0;wdata_q<=0;wstrb_q<=0;
            s_axi_bvalid<=0;s_axi_bresp<=0;s_axi_rvalid<=0;s_axi_rresp<=0;s_axi_rdata<=0;
            stage_target<=1400;stage_slew<=10;stage_interval<=5;
            target_us<=1400;active_us<=1400;slew_us<=10;step_frames<=5;step_count<=0;
            enabled<=0;lease_expired<=0;lease_left<=0;us_div<=0;frame_us<=0;frame_count<=0;
        end else begin
            if(enabled) begin
                if(lease_left>1) lease_left<=lease_left-1'b1;
                else begin enabled<=0;lease_expired<=1;lease_left<=0;end
                if(us_div==CYCLES_PER_US-1) begin
                    us_div<=0;
                    if(frame_us==19999) begin
                        frame_us<=0;frame_count<=frame_count+1'b1;
                        if(step_count+1>=step_frames) begin
                            step_count<=0;
                            if(target_us>active_us)
                                active_us<=target_us-active_us>slew_us ? active_us+slew_us : target_us;
                            else if(target_us<active_us)
                                active_us<=active_us-target_us>slew_us ? active_us-slew_us : target_us;
                        end else step_count<=step_count+1'b1;
                    end else frame_us<=frame_us+1'b1;
                end else us_div<=us_div+1'b1;
            end else begin us_div<=0;frame_us<=0;step_count<=0;end
            if(s_axi_awvalid && s_axi_awready) begin have_aw<=1;awaddr_q<=s_axi_awaddr;end
            if(s_axi_wvalid && s_axi_wready) begin have_w<=1;wdata_q<=s_axi_wdata;wstrb_q<=s_axi_wstrb;end
            if(s_axi_bvalid && s_axi_bready) s_axi_bvalid<=0;
            if(have_aw && have_w && !s_axi_bvalid) begin
                have_aw<=0;have_w<=0;s_axi_bvalid<=1;s_axi_bresp<=0;
                case(awaddr_q)
                    12'h008: begin
                        // Full-word explicit commit; staged writes never change live PWM.
                        if(wstrb_q!=4'hf || wdata_q>1) s_axi_bresp<=2;
                        else if(wdata_q==0) begin enabled<=0;lease_left<=0;end
                        else if(stage_target<1110 || stage_target>1490 || stage_slew<1 ||
                                stage_slew>10 || stage_interval<1 || stage_interval>50) s_axi_bresp<=2;
                        else begin
                            target_us<=stage_target[15:0];slew_us<=stage_slew[7:0];
                            step_frames<=stage_interval[7:0];step_count<=0;
                            enabled<=1;lease_expired<=0;lease_left<=LEASE_CYCLES;
                            // Starting from OFF sends exactly the requested pulse. There is
                            // no position sensor and no assumed intermediate center command.
                            if(!enabled || lease_left<=1) begin
                                active_us<=stage_target[15:0];frame_us<=0;us_div<=0;
                            end
                        end
                    end
                    12'h00c: begin
                        merged=merge_bytes(stage_target,wdata_q,wstrb_q);
                        if(merged<1110 || merged>1490) s_axi_bresp<=2;else stage_target<=merged;
                    end
                    12'h010: begin
                        merged=merge_bytes(stage_slew,wdata_q,wstrb_q);
                        if(merged<1 || merged>10) s_axi_bresp<=2;else stage_slew<=merged;
                    end
                    12'h014: begin
                        merged=merge_bytes(stage_interval,wdata_q,wstrb_q);
                        if(merged<1 || merged>50) s_axi_bresp<=2;else stage_interval<=merged;
                    end
                    12'h028: begin
                        if(wstrb_q!=4'hf || wdata_q!=32'h4b49434b) s_axi_bresp<=2;
                        else if(enabled && lease_left>1) lease_left<=LEASE_CYCLES;
                        // An expired output never restarts on a late heartbeat.
                    end
                    default:s_axi_bresp<=2;
                endcase
            end
            if(s_axi_rvalid && s_axi_rready) s_axi_rvalid<=0;
            if(s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid<=1;s_axi_rdata<=read_value;s_axi_rresp<=read_ok?2'd0:2'd2;
            end
        end
    end
endmodule
