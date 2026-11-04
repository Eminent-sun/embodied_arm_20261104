`timescale 1ns / 1ps
// Complete-frame queue. Byte0 is data[7:0]. No partial frame is ever exposed.
module can_rx_frame_fifo #(
    parameter integer DEPTH=16
)(
    input wire clk,rst_n,
    input wire push,
    input wire [28:0] in_id,
    input wire in_ide,in_rtr,
    input wire [3:0] in_dlc,
    input wire [63:0] in_data,
    input wire [63:0] in_timestamp,
    input wire [7:0] in_error,
    output wire valid,
    input wire ready,
    output wire [28:0] out_id,
    output wire out_ide,out_rtr,
    output wire [3:0] out_dlc,
    output wire [63:0] out_data,out_timestamp,
    output wire [7:0] out_error,
    output wire [31:0] level,
    output wire drop
);
    // 29+1+1+4+64+64+8 = 171 bits per entry. Arbitrary positive DEPTH.
    // Keep the state narrow even when the public diagnostic level is 32 bits.
    function integer width_for_count;
        input integer max_value;
        integer remaining;
        begin
            remaining=max_value;
            width_for_count=0;
            while(remaining>0) begin
                width_for_count=width_for_count+1;
                remaining=remaining>>1;
            end
            if(width_for_count<1) width_for_count=1;
        end
    endfunction
    localparam integer PTR_W=width_for_count(DEPTH-1);
    localparam integer COUNT_W=width_for_count(DEPTH);
    reg [170:0] memory[0:DEPTH-1];
    reg [PTR_W-1:0] rd_ptr,wr_ptr;
    reg [COUNT_W-1:0] occupancy;
    wire pop,store;
    assign level={{(32-COUNT_W){1'b0}},occupancy};
    assign valid=(occupancy!=0);
    assign pop=valid && ready;
    assign store=push && (occupancy<DEPTH || pop);
    assign drop=push && !store;
    assign {out_id,out_ide,out_rtr,out_dlc,out_data,out_timestamp,out_error}=
        valid?memory[rd_ptr]:171'd0;
    always @(posedge clk) begin
        if(!rst_n) begin rd_ptr<=0;wr_ptr<=0;occupancy<=0;end
        else begin
            if(store) begin
                memory[wr_ptr]<={in_id,in_ide,in_rtr,in_dlc,in_data,in_timestamp,in_error};
                wr_ptr<=(wr_ptr==DEPTH-1)?0:wr_ptr+1'b1;
            end
            if(pop) rd_ptr<=(rd_ptr==DEPTH-1)?0:rd_ptr+1'b1;
            case({store,pop})
                2'b10: occupancy<=occupancy+1'b1;
                2'b01: occupancy<=occupancy-1'b1;
                default: begin end
            endcase
        end
    end
endmodule
