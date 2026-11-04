`timescale 1ns / 1ps
// Explicit static receive address map, not a motor-model/scaling profile.
module robstride_axis_map #(
    parameter integer CONFIG_ENABLE=0,
    parameter [7:0] HOST_ID=8'h00,
    parameter [47:0] MOTOR_IDS=48'd0
)(
    input wire [7:0] motor_id,
    output reg config_valid,mapped,
    output reg [2:0] axis
);
    integer i,j;
    always @* begin
        config_valid=(CONFIG_ENABLE!=0 && HOST_ID!=0);mapped=0;axis=0;
        for(i=0;i<6;i=i+1) begin
            if(MOTOR_IDS[i*8 +: 8]==0 || MOTOR_IDS[i*8 +: 8]==HOST_ID) config_valid=0;
            for(j=0;j<i;j=j+1)
                if(MOTOR_IDS[i*8 +: 8]==MOTOR_IDS[j*8 +: 8]) config_valid=0;
            if(motor_id==MOTOR_IDS[i*8 +: 8]) begin mapped=1;axis=i;end
        end
        if(!config_valid) begin mapped=0;axis=0;end
    end
endmodule
