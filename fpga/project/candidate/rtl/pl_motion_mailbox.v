`timescale 1ns/1ps
// PS AXI-Lite command mailbox. No autonomous start and no direct CAN access.
// AW and W are independently buffered; responses remain stable under stalls.
module pl_motion_mailbox #(parameter [31:0] ABI_VERSION=32'h00010000)(
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
    output reg engine_start,
    output reg [28:0] engine_word,
    output wire [7:0] engine_reserved,
    output reg [63:0] engine_value,
    output reg [2:0] query_axis,
    output reg [4:0] query_page,
    input wire command_busy, command_done, command_success, command_error, fault_locked,
    input wire [3:0] command_state,
    input wire [7:0] command_error_code,
    input wire [31:0] result_value,
    input wire command_accepted, command_rejected,
    input wire clock_locked, can_initialized, can_init_error, mapping_valid, integrity_lost,
    input wire [5:0] feedback_timeout, param_pending, param_poisoned,
    input wire [31:0] feedback_data, rx_frame_count, rx_last_isr, rx_overflow_count,
    input wire [7:0] rx_error_flags,
    input wire [3:0] tx_error_code,
    input wire tx_may_be_pending
);
    reg have_aw, have_w, stop_pulse, recover_pulse, prior_done;
    reg [11:0] awaddr_q;
    reg [31:0] wdata_q, stage_word, stage_lo, stage_hi;
    reg [3:0] wstrb_q;
    reg [31:0] accepted_count, completed_count, rejected_count;
    reg [31:0] merged;
    reg read_ok;
    reg [31:0] read_value;
    assign engine_reserved=stop_pulse ? 8'hA5 : recover_pulse ? 8'h5A : 8'd0;
    // Explicit recovery only after a completed software/watchdog stop. It
    // reissues disable frames; it never publishes a staged motion command.
    wire recovery_allowed=fault_locked && !command_busy && command_state==9 &&
        (command_error_code==8'hE0 || command_error_code==8'hE1) &&
        clock_locked && can_initialized && !can_init_error && mapping_valid &&
        !integrity_lost && param_pending==0 && param_poisoned==0 &&
        rx_error_flags==0 && rx_overflow_count==0 && !tx_may_be_pending && tx_error_code==0;
    assign s_axi_awready=rst_n && !have_aw && !s_axi_bvalid;
    assign s_axi_wready=rst_n && !have_w && !s_axi_bvalid;
    assign s_axi_arready=rst_n && !s_axi_rvalid;
    function [31:0] merge_bytes;
        input [31:0] old_value,new_value;
        input [3:0] strobes;
        integer b;
        begin
            merge_bytes=old_value;
            for(b=0;b<4;b=b+1) if(strobes[b]) merge_bytes[b*8 +: 8]=new_value[b*8 +: 8];
        end
    endfunction
    always @* begin
        read_ok=1;read_value=0;
        case(s_axi_araddr)
            12'h000: read_value=32'h43414E36; // CAN6
            12'h004: read_value=ABI_VERSION;
            12'h008: read_value=0;
            12'h010: read_value=stage_word;
            12'h014: read_value=stage_lo;
            12'h018: read_value=stage_hi;
            12'h01C: read_value={19'd0,query_page,5'd0,query_axis};
            12'h020: read_value={8'd0,command_error_code,4'd0,command_state,3'd0,fault_locked,command_error,command_success,command_done,command_busy};
            12'h024: read_value=result_value;
            12'h028: read_value={2'd0,param_poisoned,2'd0,param_pending,2'd0,feedback_timeout,3'd0,integrity_lost,mapping_valid,can_init_error,can_initialized,clock_locked};
            12'h02C: read_value=feedback_data;
            12'h030: read_value={24'd0,rx_error_flags};
            12'h034: read_value=rx_frame_count;
            12'h038: read_value={15'd0,tx_may_be_pending,12'd0,tx_error_code};
            12'h03C: read_value=accepted_count;
            12'h040: read_value=completed_count;
            12'h044: read_value=rejected_count;
            12'h048: read_value=rx_last_isr;
            12'h04C: read_value=rx_overflow_count;
            default: read_ok=0;
        endcase
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            have_aw<=0;have_w<=0;awaddr_q<=0;wdata_q<=0;wstrb_q<=0;
            s_axi_bvalid<=0;s_axi_bresp<=0;s_axi_rvalid<=0;s_axi_rresp<=0;s_axi_rdata<=0;
            stage_word<=0;stage_lo<=0;stage_hi<=0;engine_word<=0;engine_value<=0;
            query_axis<=0;query_page<=0;engine_start<=0;stop_pulse<=0;recover_pulse<=0;
            accepted_count<=0;completed_count<=0;rejected_count<=0;prior_done<=0;
        end else begin
            engine_start<=0;stop_pulse<=0;recover_pulse<=0;prior_done<=command_done;
            if(command_accepted) accepted_count<=accepted_count+1'b1;
            if(command_rejected) rejected_count<=rejected_count+1'b1;
            if(command_done && !prior_done) completed_count<=completed_count+1'b1;
            if(s_axi_awvalid && s_axi_awready) begin have_aw<=1;awaddr_q<=s_axi_awaddr;end
            if(s_axi_wvalid && s_axi_wready) begin have_w<=1;wdata_q<=s_axi_wdata;wstrb_q<=s_axi_wstrb;end
            if(s_axi_bvalid && s_axi_bready) s_axi_bvalid<=0;
            if(have_aw && have_w && !s_axi_bvalid) begin
                have_aw<=0;have_w<=0;s_axi_bvalid<=1;s_axi_bresp<=0;
                case(awaddr_q)
                    12'h008: begin
                        if(wstrb_q[0] && wdata_q[7:2]!=0) s_axi_bresp<=2;
                        else if(wstrb_q[0] && wdata_q[1]) stop_pulse<=1;
                        else if(wstrb_q[0] && wdata_q[0]) begin
                            if(command_busy || fault_locked) s_axi_bresp<=2;
                            else begin engine_word<=stage_word[28:0];engine_value<={stage_hi,stage_lo};engine_start<=1;end
                        end
                    end
                    12'h010: begin
                        merged=merge_bytes(stage_word,wdata_q,wstrb_q);
                        if(merged[31:29]!=0) s_axi_bresp<=2;else stage_word<=merged;
                    end
                    12'h014: stage_lo<=merge_bytes(stage_lo,wdata_q,wstrb_q);
                    12'h018: stage_hi<=merge_bytes(stage_hi,wdata_q,wstrb_q);
                    12'h01C: begin
                        merged=merge_bytes({19'd0,query_page,5'd0,query_axis},wdata_q,wstrb_q);
                        if((merged & 32'hFFFFE0F8)!=0 || merged[2:0]>5) s_axi_bresp<=2;
                        else begin query_axis<=merged[2:0];query_page<=merged[12:8];end
                    end
                    12'h050: begin
                        if(wstrb_q!=4'hF || wdata_q!=32'h52454331 || !recovery_allowed) s_axi_bresp<=2;
                        else begin
                            recover_pulse<=1;
                            stage_word<=0;stage_lo<=0;stage_hi<=0;
                            engine_word<=0;engine_value<=0;
                        end
                    end
                    default: s_axi_bresp<=2;
                endcase
            end
            if(s_axi_rvalid && s_axi_rready) s_axi_rvalid<=0;
            if(s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid<=1;s_axi_rdata<=read_value;s_axi_rresp<=read_ok ? 2'd0 : 2'd2;
            end
        end
    end
endmodule
