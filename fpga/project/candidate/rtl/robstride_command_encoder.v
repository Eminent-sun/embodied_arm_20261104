`timescale 1ns / 1ps
// Private-protocol framing only. No AXI, CAN transmission or physical-unit conversion.
// op:0 read,1 float-bits write,2 u8 write,3 u16 write,4 u32 write,
//    5 enable,6 ordinary disable,7 clear-fault request. Others rejected.
module robstride_command_encoder(
    input wire clk,rst_n,config_valid,model_config_valid,allow_actuation,
    input wire cmd_valid,
    output wire cmd_ready,
    input wire [3:0] cmd_op,
    input wire [7:0] host_id,motor_id,
    input wire [15:0] parameter_index,
    input wire [31:0] parameter_bits,
    output reg frame_valid,
    input wire frame_ready,
    output reg [28:0] can_id,
    output reg can_ide,can_rtr,
    output reg [3:0] can_dlc,
    output reg [63:0] can_data,
    output reg command_rejected,
    output reg [3:0] reject_reason
);
    reg [3:0] reason;
    reg authorized;
    reg [4:0] kind;
    reg [63:0] payload;
    assign cmd_ready=rst_n && (!frame_valid || frame_ready);
    always @* begin
        authorized=0;
        case({model_config_valid,allow_actuation}) 2'b11: authorized=1;default: authorized=0;endcase
        reason=0;kind=5'h12;payload={parameter_bits,16'd0,parameter_index};
        case(cmd_op)
            0: begin kind=5'h11;payload={48'd0,parameter_index};end
            1,4: begin end
            2: payload={24'd0,parameter_bits[7:0],16'd0,parameter_index};
            3: payload={16'd0,parameter_bits[15:0],16'd0,parameter_index};
            5: begin kind=5'h03;payload=0;end
            6: begin kind=5'h04;payload=0;end
            7: begin kind=5'h04;payload=1;end
            default: reason=3;
        endcase
        if(cmd_op==2 && parameter_bits[31:8]!=0) reason=5;
        if(cmd_op==3 && parameter_bits[31:16]!=0) reason=5;
        if(cmd_op>=1 && cmd_op<=4 && parameter_index==16'h7005 &&
           (cmd_op!=2 || !(parameter_bits==0 || parameter_bits==1 || parameter_bits==2 || parameter_bits==3 || parameter_bits==5))) reason=6;
        if((cmd_op>=1 && cmd_op<=5 || cmd_op==7) && !authorized) reason=4;
        if(host_id==0 || motor_id==0 || host_id==motor_id) reason=2;
        case(config_valid) 1'b1: begin end default: reason=1;endcase
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            frame_valid<=0;can_id<=0;can_ide<=0;can_rtr<=0;can_dlc<=0;can_data<=0;
            command_rejected<=0;reject_reason<=0;
        end else begin
            command_rejected<=0;
            if(cmd_ready) begin
                frame_valid<=0;
                if(cmd_valid) begin
                    if(reason!=0) begin command_rejected<=1;reject_reason<=reason;end
                    else begin
                        frame_valid<=1;can_id<={kind,8'd0,host_id,motor_id};
                        can_ide<=1;can_rtr<=0;can_dlc<=8;can_data<=payload;
                    end
                end
            end
        end
    end
endmodule
