`timescale 1ns / 1ps
// Transaction-level PG096 register model, NOT a CAN bit-level controller.
module can_axi_slave_model #(
    parameter integer SIX_AXIS_TEST=0,
    parameter integer SINGLE_TEST=0,
    parameter integer V21_GENERIC_TEST=0,
    parameter integer START_NORMAL=0
)(
    input wire clk,rst_n,
    input wire [31:0] awaddr,wdata,araddr,
    input wire [3:0] wstrb,
    input wire awvalid,wvalid,bready,arvalid,rready,
    output wire awready,wready,bvalid,arready,rvalid,
    output reg [1:0] bresp,rresp,
    output reg [31:0] rdata,
    input wire hold_aw,hold_w,hold_b,hold_ar,hold_r,
    input wire config_stuck,normal_stuck,fifo_full,no_txok,can_error,
    input wire [31:0] txok_delay_cycles,
    input wire [31:0] fail_write_index,fail_read_index,
    output integer write_count,read_count,enqueued_count,protocol_errors,reset_count,
    output reg [31:0] last_sequence
);
    reg aw_seen,w_seen,b_pending,r_pending;
    reg [31:0] aw_latched,w_latched,brpr,btr,msr,ier,isr;
    reg [31:0] id_word,dlc_word,dw1_word,tx_timer;
    reg normal,tx_waiting;
    integer fifo_phase;
    reg [31:0] write_addresses[0:127];
    reg [31:0] write_values[0:127];
    reg [7:0] data_bytes[0:7];
    assign awready=!hold_aw&&!aw_seen&&!b_pending;
    assign wready=!hold_w&&!w_seen&&!b_pending;
    assign arready=!hold_ar&&!r_pending;
    assign bvalid=b_pending&&!hold_b;
    assign rvalid=r_pending&&!hold_r;
    always @(posedge clk) begin
        if(!rst_n) begin
            aw_seen<=0;w_seen<=0;b_pending<=0;r_pending<=0;bresp<=0;rresp<=0;rdata<=0;
            write_count<=0;read_count<=0;enqueued_count<=0;protocol_errors<=0;reset_count<=0;
            aw_latched<=0;w_latched<=0;brpr<=0;btr<=0;msr<=0;ier<=0;isr<=0;normal<=START_NORMAL!=0;
            fifo_phase<=0;id_word<=0;dlc_word<=0;dw1_word<=0;tx_waiting<=0;tx_timer<=0;last_sequence<=0;
        end else begin
            if(bvalid&&bready) b_pending<=0;
            if(rvalid&&rready) r_pending<=0;
            if(awvalid&&awready) begin aw_seen<=1;aw_latched<=awaddr;end
            if(wvalid&&wready) begin
                w_seen<=1;w_latched<=wdata;
                if(wstrb!=4'hF) begin protocol_errors<=protocol_errors+1;$display("FAIL: model saw non-full WSTRB");end
            end
            if(aw_seen&&w_seen&&!b_pending) begin
                aw_seen<=0;w_seen<=0;b_pending<=1;bresp<=(write_count==fail_write_index)?2'b10:2'b00;
                if(write_count<128) begin write_addresses[write_count]<=aw_latched;write_values[write_count]<=w_latched;end
                write_count<=write_count+1;
                if(write_count!=fail_write_index) begin
                    case(aw_latched)
                        32'h43C00000: if(w_latched==1) begin
                            normal<=0;isr<=0;brpr<=0;btr<=0;msr<=0;ier<=0;
                            fifo_phase<=0;tx_waiting<=0;reset_count<=reset_count+1;
                        end else if(w_latched==2) begin
                            if(brpr!=0||btr!=32'h2F||msr!=0||ier!=0) begin
                                protocol_errors<=protocol_errors+1;$display("FAIL: CAN enabled before correct BRPR/BTR/MSR/IER");
                            end
                            normal<=!normal_stuck;
                        end
                        32'h43C00008: brpr<=w_latched;
                        32'h43C0000C: btr<=w_latched;
                        32'h43C00004: msr<=w_latched;
                        32'h43C00020: ier<=w_latched;
                        32'h43C00024: isr<=isr & ~w_latched;
                        32'h43C00030: begin
                            if(fifo_phase!=0||!normal) begin protocol_errors<=protocol_errors+1;$display("FAIL: FIFO ID order/initialization");end
                            id_word<=w_latched;fifo_phase<=1;
                        end
                        32'h43C00034: begin
                            if(fifo_phase!=1) begin protocol_errors<=protocol_errors+1;$display("FAIL: FIFO DLC order");end
                            dlc_word<=w_latched;fifo_phase<=2;
                        end
                        32'h43C00038: begin
                            if(fifo_phase!=2) begin protocol_errors<=protocol_errors+1;$display("FAIL: FIFO DW1 order");end
                            dw1_word<=w_latched;fifo_phase<=3;
                        end
                        32'h43C0003C: begin
                            if(fifo_phase!=3||dlc_word!=32'h80000000||
                               (V21_GENERIC_TEST==0 && SINGLE_TEST!=0 && id_word!=32'h8819FA0A)||
                               (V21_GENERIC_TEST==0 && SINGLE_TEST==0 && SIX_AXIS_TEST==0 && id_word!=32'hD9B8ACF0)||
                               (V21_GENERIC_TEST==0 && SINGLE_TEST==0 && SIX_AXIS_TEST!=0 &&
                                ((((id_word>>21)<<18)|((id_word>>1)&32'h3FFFF))<32'h1B345670 ||
                                 (((id_word>>21)<<18)|((id_word>>1)&32'h3FFFF))>32'h1B345675 ||
                                 id_word[20:19]!=2'b11 || id_word[0]))) begin
                                protocol_errors<=protocol_errors+1;$display("FAIL: complete frame IDR/DLC/order");
                            end
                            fifo_phase<=0;enqueued_count<=enqueued_count+1;last_sequence<=dw1_word;
                            data_bytes[0]<=dw1_word[31:24];data_bytes[1]<=dw1_word[23:16];
                            data_bytes[2]<=dw1_word[15:8];data_bytes[3]<=dw1_word[7:0];
                            data_bytes[4]<=w_latched[31:24];data_bytes[5]<=w_latched[23:16];
                            data_bytes[6]<=w_latched[15:8];data_bytes[7]<=w_latched[7:0];
                            tx_waiting<=1;tx_timer<=0;
                        end
                        default: begin protocol_errors<=protocol_errors+1;$display("FAIL: unexpected model write address %h",aw_latched);end
                    endcase
                end
            end
            if(tx_waiting&&!no_txok) begin
                if(tx_timer>=txok_delay_cycles) begin isr[1]<=1;tx_waiting<=0;end
                else tx_timer<=tx_timer+1;
            end
            if(arvalid&&arready) begin
                r_pending<=1;rresp<=(read_count==fail_read_index)?2'b10:2'b00;read_count<=read_count+1;
                case(araddr)
                    32'h43C00018: rdata<=(config_stuck?32'd0:(normal?32'h98:32'h1)) | (fifo_full?32'h400:32'd0);
                    32'h43C0001C: rdata<=isr | (can_error?32'h100:32'd0);
                    32'h43C00008: rdata<=brpr;
                    32'h43C0000C: rdata<=btr;
                    default: begin rdata<=0;rresp<=2;protocol_errors<=protocol_errors+1;$display("FAIL: unexpected model read address");end
                endcase
            end
        end
    end
endmodule
