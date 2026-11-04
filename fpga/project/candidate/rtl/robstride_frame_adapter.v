`timescale 1ns / 1ps
// Combinational PG096 mapping. A caller must latch outputs on its handshake.
module robstride_frame_adapter(
    input wire [28:0] can_id,
    input wire ide,rtr,
    input wire [3:0] dlc,
    input wire [63:0] data,
    output wire [31:0] tx_idr,tx_dlcr,tx_dw1,tx_dw2,
    input wire [31:0] rx_idr,rx_dlcr,rx_dw1,rx_dw2,
    output wire [28:0] decoded_id,
    output wire decoded_ide,decoded_rtr,
    output wire [3:0] decoded_dlc,
    output wire [63:0] decoded_data
);
    assign tx_idr=ide?{can_id[28:18],1'b1,1'b1,can_id[17:0],rtr}:{can_id[10:0],rtr,20'd0};
    assign tx_dlcr={dlc,28'd0};
    assign tx_dw1={data[7:0],data[15:8],data[23:16],data[31:24]};
    assign tx_dw2={data[39:32],data[47:40],data[55:48],data[63:56]};
    assign decoded_id=rx_idr[19]?{rx_idr[31:21],rx_idr[18:1]}:{18'd0,rx_idr[31:21]};
    assign decoded_ide=rx_idr[19];
    assign decoded_rtr=rx_idr[19]?rx_idr[0]:rx_idr[20];
    assign decoded_dlc=rx_dlcr[31:28];
    assign decoded_data={rx_dw2[7:0],rx_dw2[15:8],rx_dw2[23:16],rx_dw2[31:24],
                         rx_dw1[7:0],rx_dw1[15:8],rx_dw1[23:16],rx_dw1[31:24]};
endmodule
