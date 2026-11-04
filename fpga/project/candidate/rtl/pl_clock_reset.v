`timescale 1ns / 1ps

// Stage 2D: independent PL reset sequencing. No PS reset or FCLK dependency.
module pl_clock_reset #(
    parameter integer LOCK_STABLE_CYCLES = 16
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_axi_50m CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk_axi_50m, FREQ_HZ 50000000, ASSOCIATED_RESET axi_aresetn" *)
    input wire clk_axi_50m,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_can_20m CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk_can_20m, FREQ_HZ 20000000, ASSOCIATED_RESET can_aresetn" *)
    input wire clk_can_20m,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW" *)
    input wire rst_n,
    (* X_INTERFACE_IGNORE = "true" *) input wire clock_locked,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 axi_aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME axi_aresetn, POLARITY ACTIVE_LOW" *)
    output wire axi_aresetn,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 can_aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME can_aresetn, POLARITY ACTIVE_LOW" *)
    output wire can_aresetn,
    (* X_INTERFACE_IGNORE = "true" *) output reg clock_ready,
    (* X_INTERFACE_IGNORE = "true" *) output wire reset_released,
    (* X_INTERFACE_IGNORE = "true" *) output wire can_reset_released_axi,
    (* X_INTERFACE_IGNORE = "true" *) output wire clock_locked_axi
);
    // AND gates only assert reset asynchronously. Release always passes flops.
    wire raw_reset_n;
    wire qualified_reset_n;
    assign raw_reset_n = rst_n & clock_locked;
    assign qualified_reset_n = raw_reset_n & clock_ready;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] lock_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [2:0] axi_release;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [2:0] can_release;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] can_ready_sync;
    reg [31:0] stable_count;

    always @(posedge clk_axi_50m or negedge raw_reset_n) begin
        if (!raw_reset_n) lock_sync <= 0;
        else lock_sync <= {lock_sync[0], 1'b1};
    end

    // Only the synchronizer sees the raw reset release. The counter itself
    // uses the AXI-domain synchronized release, so its bits cannot recover
    // independently from an asynchronous reset removal.
    always @(posedge clk_axi_50m or negedge lock_sync[1]) begin
        if (!lock_sync[1]) begin
            stable_count <= 0;
            clock_ready <= 0;
        end else begin
            if (!clock_ready) begin
                if (stable_count == LOCK_STABLE_CYCLES-1)
                    clock_ready <= 1;
                else
                    stable_count <= stable_count + 1'b1;
            end
        end
    end

    always @(posedge clk_axi_50m or negedge qualified_reset_n) begin
        if (!qualified_reset_n) axi_release <= 0;
        else axi_release <= {axi_release[1:0], 1'b1};
    end
    always @(posedge clk_can_20m or negedge qualified_reset_n) begin
        if (!qualified_reset_n) can_release <= 0;
        else can_release <= {can_release[1:0], 1'b1};
    end
    always @(posedge clk_axi_50m or negedge qualified_reset_n) begin
        if (!qualified_reset_n) can_ready_sync <= 0;
        else can_ready_sync <= {can_ready_sync[0], can_release[2]};
    end
    assign axi_aresetn = axi_release[2];
    assign can_aresetn = can_release[2];
    assign reset_released = axi_release[2] & can_ready_sync[1];
    assign can_reset_released_axi = can_ready_sync[1];
    assign clock_locked_axi = lock_sync[1];
endmodule
