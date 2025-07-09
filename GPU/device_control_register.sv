`default_nettype none
`timescale 1ns/1ns

module device_control_register(
    input  logic        clk,
    input  logic        reset,
    input  logic        device_ctrl_wt_en,
    output  logic [7:0]  thread_count,
    input logic [7:0]  dcr
);

    // Internal register declaration
    logic [7:0] device_ctrl_reg;

    // Connect output to register
    assign thread_count = device_ctrl_reg;

    always @(posedge clk) begin
        if (reset) begin
            // Reset the register, not the output directly
            device_ctrl_reg <= 8'b0;
        end
        else begin
            if (device_ctrl_wt_en) begin
                // Update register when write is enabled
                device_ctrl_reg <= dcr;
            end
            
        end
    end
endmodule 