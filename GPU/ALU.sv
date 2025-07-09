//==============================================================================
// ALU Module - Arithmetic Logic Unit with NZP Flag Generation
//==============================================================================
// Description: Parameterizable ALU supporting ADD, SUB, MUL, DIV operations
//              with NZP (Negative, Zero, Positive) flag generation for 
//              conditional branching. Operates in Execute stage.
//==============================================================================
`default_nettype none
`timescale 1ns/1ns

module alu (
    input wire clk,                             // System clock
    input wire reset,                           // Asynchronous reset
    input wire enable,                          // Module enable signal
    input logic [2:0] core_state,               // Current  stage
    input logic [1:0] alu_op_code,   // Selects arithmetic operation
    input logic dec_alu_out_mux,                // Output select: 0=arithmetic, 1=NZP flags
    input logic [data_length-1:0] rs,           // Source register 1
    input logic [data_length-1:0] rt,           // Source register 2
    output logic [data_length-1:0] alu_out      // ALU output (arithmetic or flags)
);
    localparam data_length = 8;                 // Register/data bus width in bits
    
    // ALU Operation Encoding
    localparam ADD = 2'b00,                     // Addition operation
               SUB = 2'b01,                     // Subtraction operation  
               MUL = 2'b10,                     // Multiplication operation
               DIV = 2'b11;                     // Division operation
    
    localparam EXECUTE_STAGE = 3'b101;          
	 logic [data_length-1:0] alu_result;        // Intermediate arithmetic result
    logic [2:0] nzp_flags;                      // Status flags: [N, Z, P]

    // N (Negative): rs < rt
    // Z (Zero):     rs == rt  
    // P (Positive): rs > rt
	 
    assign nzp_flags = { (rs < rt), (rs == rt), (rs > rt) };
    
    always_comb begin
        case (alu_op_code)  
            ADD: alu_result = rs + rt;                              // Addition
            SUB: alu_result = rs - rt;                              // Subtraction
            MUL: alu_result = rs * rt;                              // Multiplication
            DIV: alu_result = (rt != 0) ? (rs / rt) : {data_length{1'b1}};                 // zero protection
            default: alu_result = {data_length{1'b0}};             // Default: zero
        endcase
    end
	 
    always_ff @(posedge clk) begin
        if (reset) begin
            alu_out <= {data_length{1'b0}};
        end
        else if (enable && (core_state == EXECUTE_STAGE)) begin
            alu_out <= dec_alu_out_mux ? 
                       {{(data_length-3){1'b0}}, nzp_flags} :  // NZP flags (zero-padded)
                       alu_result;                              // Arithmetic result
        end
        // Note: Output holds previous value when not in Execute stage or disabled
    end

endmodule

