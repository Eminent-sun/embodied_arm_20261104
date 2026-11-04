`timescale 1ns / 1ps
// Observation only. No connection from this module to any CAN output driver.
module can_line_scope(input wire clk, rst_n, rx_async, tx_async,
                      output wire rx_sample, tx_sample);
    (* ASYNC_REG = "TRUE" *) reg [1:0] rx_sync, tx_sync;
    always @(posedge clk) begin
        if (!rst_n) begin rx_sync <= 2'b11; tx_sync <= 2'b11; end
        else begin rx_sync <= {rx_sync[0],rx_async};
                   tx_sync <= {tx_sync[0],tx_async}; end
    end
    assign rx_sample=rx_sync[1];
    assign tx_sample=tx_sync[1];
endmodule
