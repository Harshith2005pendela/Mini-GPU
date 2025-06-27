`default_nettype none
`timescale 1ns/1ns
// Calculates the next PC for all threads same PC for all threads sadly
// Each thread has its own calculation for the next PC 
// The NZP input is received from the ALU output for CMP Instruction
// branches to some IMM if nzp flags match and the dec_pc_mux is 1
module pc #(
    parameter data_mem_data_bits = 8,
    parameter prog_mem_data_bits = 8
) (
    input  logic clk,
    input  logic reset,
    input  logic enable,  // disable when thread doesn't run

    // Core state
    input  logic [2:0] core_state,
    
    // Control Signals
    input  logic [2:0] dec_nzp,
    input  logic [data_mem_data_bits-1:0] dec_imm,
    input  logic nzp_write_en,
    input  logic dec_pc_mux,
    
    // ALU Output 
    input  logic [data_mem_data_bits-1:0] alu_out,
    input  logic [prog_mem_data_bits-1:0] current_pc,
    output logic [prog_mem_data_bits-1:0] next_pc 
);
    `default_nettype none
`timescale 1ns/1ns

// Program Counter 
// Calculates the next PC for all threads
// Each thread has its own calculation for the next PC 
// The NZP input is received from the ALU output for CMP Instruction
module pc #(
    parameter data_mem_data_bits = 8,
    parameter prog_mem_data_bits = 8
) (
    input  logic clk,
    input  logic reset,
    input  logic enable,  // disable when thread doesn't run

    // Core state
    input  logic [2:0] core_state,
    
    // Control Signals
    input  logic [2:0] dec_nzp,
    input  logic [data_mem_data_bits-1:0] dec_imm,
    input  logic nzp_write_en,
    input  logic dec_pc_mux,
    
    // ALU Output 
    input  logic [data_mem_data_bits-1:0] alu_out,
    input  logic [prog_mem_data_bits-1:0] current_pc,
    output logic [prog_mem_data_bits-1:0] next_pc  // Changed to output
);
    
	logic [2:0] nzp_reg;  // NZP flags storage
    
    always_ff @(posedge clk) begin
        if (reset) begin
            nzp_reg <= 3'b0;
            next_pc <= '0;
        end
        else if (enable) begin
            // Execute Stage
            if (core_state == 3'b101) begin
                if (dec_pc_mux == 1'b1) begin
                    // Branch Imm if nzp flags match and mux is correctly selected
                    next_pc <= (nzp_reg == dec_nzp) ? dec_imm : (current_pc + 1);
                end
                else begin
                    // Default 
                    next_pc <= current_pc + 1;
                end
            end
            
            // Update Stage: Store NZP flags from ALU
            else if (core_state == 3'b110) begin
                if (nzp_write_en) begin
                    nzp_reg <= alu_out[2:0];  
                end
            end
        end
    end

endmodule

