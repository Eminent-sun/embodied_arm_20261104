`timescale 1ns / 1ps
// Stage 4-B1: PG096 transaction model with destructive four-word RX FIFO.
// Not CAN bit-level or metastability simulation. RX set conditions win over ICR.
module can_axi_rx_slave_model #(
    parameter integer HW_RX_DEPTH=2,
    parameter integer SIX_AXIS_TEST=0,
    parameter integer SINGLE_TEST=0
)(
    input wire clk,rst_n,
    input wire rx_in_valid,
    input wire [31:0] rx_in_idr,rx_in_dlcr,rx_in_dw1,rx_in_dw2,
    input wire [31:0] inject_isr,
    input wire [1:0] read_error_response,write_error_response,
    input wire [31:0] response_delay,
    output integer rx_level,rx_popped,rx_dropped,rx_illegal_reads,
    output integer rx_word_reads,rx_icr_writes,tx_acked_count,

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
    // Test-only fault injection scoped to the first diagnostic ESR read.
    reg [1:0] diag_read_error_response;
    reg diag_hold_r,diag_r_pending;
    reg [31:0] diag_error_addr;
    reg [31:0] rx_ids[0:HW_RX_DEPTH-1],rx_dlcs[0:HW_RX_DEPTH-1];
    reg [31:0] rx_words1[0:HW_RX_DEPTH-1],rx_words2[0:HW_RX_DEPTH-1];
    integer rx_rd,rx_wr,rx_phase;
    reg rx_pop,rx_push;
    reg [31:0] isr_next,r_delay,b_delay;

    reg [31:0] aw_latched,w_latched,brpr,btr,msr,ier,isr;
    reg [31:0] esr_value,ecr_value;
    reg [31:0] id_word,dlc_word,dw1_word,tx_timer;
    reg normal,tx_waiting;
    integer fifo_phase;
    reg [31:0] write_addresses[0:63];
    reg [31:0] write_values[0:63];
    reg [7:0] data_bytes[0:7];
    assign awready=!hold_aw&&!aw_seen&&!b_pending;
    assign wready=!hold_w&&!w_seen&&!b_pending;
    assign arready=!hold_ar&&!r_pending;
    assign bvalid=b_pending&&!hold_b && b_delay>=response_delay;
    assign rvalid=r_pending&&!hold_r && !(diag_hold_r&&diag_r_pending) && r_delay>=response_delay;
    always @(posedge clk) begin
        if(!rst_n) begin
            aw_seen<=0;w_seen<=0;b_pending<=0;r_pending<=0;bresp<=0;rresp<=0;rdata<=0;
            diag_read_error_response<=0;diag_hold_r<=0;diag_r_pending<=0;
            diag_error_addr<=32'h43C00014;
            rx_level<=0;rx_popped<=0;rx_dropped<=0;rx_illegal_reads<=0;
            rx_word_reads<=0;rx_icr_writes<=0;tx_acked_count<=0;rx_rd<=0;rx_wr<=0;rx_phase<=0;r_delay<=0;b_delay<=0;
            write_count<=0;read_count<=0;enqueued_count<=0;protocol_errors<=0;reset_count<=0;
            aw_latched<=0;w_latched<=0;brpr<=0;btr<=0;msr<=0;ier<=0;isr<=0;normal<=0;
            esr_value<=0;ecr_value<=0;
            fifo_phase<=0;id_word<=0;dlc_word<=0;dw1_word<=0;tx_waiting<=0;tx_timer<=0;last_sequence<=0;
        end else begin
            isr_next=isr | inject_isr;rx_pop=0;rx_push=0;
            if(r_pending) r_delay<=r_delay+1;
            if(b_pending) b_delay<=b_delay+1;

            if(bvalid&&bready) b_pending<=0;
            if(rvalid&&rready) begin r_pending<=0;diag_r_pending<=0;end
            if(awvalid&&awready) begin aw_seen<=1;aw_latched<=awaddr;end
            if(wvalid&&wready) begin
                w_seen<=1;w_latched<=wdata;
                if(wstrb!=4'hF) begin protocol_errors<=protocol_errors+1;$display("FAIL: model saw non-full WSTRB");end
            end
            if(aw_seen&&w_seen&&!b_pending) begin
                aw_seen<=0;w_seen<=0;b_pending<=1;b_delay<=0;bresp<=(write_count==fail_write_index)?write_error_response:2'b00;
                if(write_count<64) begin write_addresses[write_count]<=aw_latched;write_values[write_count]<=w_latched;end
                write_count<=write_count+1;
                if(write_count!=fail_write_index) begin
                    case(aw_latched)
                        32'h43C00000: if(w_latched==1) begin
                            normal<=0;isr_next=0;brpr<=0;btr<=0;msr<=0;ier<=0;
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
                        32'h43C00024: begin
                            if((w_latched & ~32'h2)!=0) begin
                                rx_icr_writes<=rx_icr_writes+1;
                                if((w_latched & ~32'hF0)!=0) begin protocol_errors<=protocol_errors+1;$display("FAIL: RX clears unrelated ISR bit");end
                            end
                            isr_next=isr_next & ~w_latched;
                        end
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
                               (SINGLE_TEST!=0 && id_word!=32'h8819FA0A)||
                               (SINGLE_TEST==0 && SIX_AXIS_TEST==0 && id_word!=32'hD9B8ACF0)||
                               (SINGLE_TEST==0 && SIX_AXIS_TEST!=0 &&
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
                if(tx_timer>=txok_delay_cycles) begin isr_next[1]=1;tx_acked_count<=tx_acked_count+1;tx_waiting<=0;end
                else tx_timer<=tx_timer+1;
            end
            if(arvalid&&arready) begin
                r_pending<=1;r_delay<=0;
                diag_r_pending<=(araddr==32'h43C00014);
                rresp<=(araddr==diag_error_addr && diag_read_error_response!=0)?
                    diag_read_error_response:(read_count==fail_read_index)?read_error_response:2'b00;
                read_count<=read_count+1;
                case(araddr)
                    32'h43C00010: rdata<=ecr_value;
                    32'h43C00014: rdata<=esr_value;
                    32'h43C00018: rdata<=(config_stuck?32'd0:(normal?32'h98:32'h1)) | (fifo_full?32'h400:32'd0);
                    32'h43C0001C: rdata<=isr | (can_error?32'h100:32'd0);
                    32'h43C00050,32'h43C00054,32'h43C00058,32'h43C0005C: begin
                        rx_word_reads<=rx_word_reads+1;
                        if(rx_level==0) begin
                            rx_illegal_reads<=rx_illegal_reads+1;isr_next[5]=1;rdata<=0;
                        end else begin
                            if(araddr != 32'h43C00050+rx_phase*4) begin
                                protocol_errors<=protocol_errors+1;$display("FAIL: RX word order");
                            end
                            case(araddr)
                                32'h43C00050: rdata<=rx_ids[rx_rd];
                                32'h43C00054: rdata<=rx_dlcs[rx_rd];
                                32'h43C00058: rdata<=rx_words1[rx_rd];
                                32'h43C0005C: begin
                                    rdata<=rx_words2[rx_rd];rx_pop=1;rx_popped<=rx_popped+1;
                                    rx_rd<=(rx_rd==HW_RX_DEPTH-1)?0:rx_rd+1;
                                end
                            endcase
                            rx_phase<=(rx_phase==3)?0:rx_phase+1;
                        end
                    end
                    32'h43C00008: rdata<=brpr;
                    32'h43C0000C: rdata<=btr;
                    default: begin rdata<=0;rresp<=2;protocol_errors<=protocol_errors+1;$display("FAIL: unexpected model read address");end
                endcase
            end
            if(rx_in_valid) begin
                if(rx_level<HW_RX_DEPTH || rx_pop) begin
                    rx_push=1;rx_ids[rx_wr]<=rx_in_idr;rx_dlcs[rx_wr]<=rx_in_dlcr;
                    rx_words1[rx_wr]<=rx_in_dw1;rx_words2[rx_wr]<=rx_in_dw2;
                    rx_wr<=(rx_wr==HW_RX_DEPTH-1)?0:rx_wr+1;
                    isr_next[4]=1;
                end else begin rx_dropped<=rx_dropped+1;isr_next[6]=1;end
            end
            case({rx_push,rx_pop})
                2'b10: rx_level<=rx_level+1;
                2'b01: rx_level<=rx_level-1;
            endcase
            // Sticky RXNEMP can be cleared by ICR, but nonempty wins over clear.
            if(rx_level+(rx_push?1:0)-(rx_pop?1:0)>0) isr_next[7]=1;
            isr<=isr_next;
        end
    end
endmodule
