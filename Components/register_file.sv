'default_nettype none
'timescale 1ns/1ns

// -----------------------------------------------------------
// Register File Module 
// -----------------------------------------------------------
// Each thread has its own register file with:
// - 13 general-purpose registers (R0 to R12)
// - 3 read-only special registers:
//    * R13 -> Block ID
//    * R14 -> Block Dimension (threads per block)
//    * R15 -> Thread ID (unique within the block)
// -----------------------------------------------------------

module registers #(
    parameter int Threads_per_block = 4,      // Number of threads in a block
    parameter int Thread_id = 0,              // Thread ID for this instance
    parameter int data_bits = 8               // Register width
)(
    // ---------------------
    // Clock and Control
    input  logic clk,
    input  logic reset,
    input  logic enable,

    // ---------------------
    // Runtime Inputs
    input  logic [data_bits-1:0] block_id,    // Block ID (can change per dispatch)

    // ---------------------
	 
    // Control Signals
    input  logic [2:0] core_state,            // Core FSM state
    input  logic dec_reg_write_en,            // Register write enable
    input  logic [1:0] dec_reg_input_mux,     // Selects input source for write

	 
    // Register addresses (4-bit for 16 registers)
    input  logic [3:0] dec_rs_address,
    input  logic [3:0] dec_rt_address,
    input  logic [3:0] dec_rd_address,

    // ---------------------
    // Data Inputs
    input  logic [data_bits-1:0] dec_imm,     // Immediate value
    input  logic [data_bits-1:0] alu_out,     // ALU output
    input  logic [data_bits-1:0] lsu_out,     // Memory (Load/Store Unit) output

    // ---------------------
    // Data Outputs (Read values)
    output logic [data_bits-1:0] rs,          // Source register 1
    output logic [data_bits-1:0] rt           // Source register 2
);

    // ---------------------
    // Mux Selector Constants
    localparam ARITHMETIC = 2'b00,
               CONSTANT   = 2'b01,
               MEMORY     = 2'b10;

    // ---------------------
    // Register File: 16 registers per thread
    // 0-12: general-purpose
    // 13:   block ID (runtime updated)
    // 14:   block dimension (fixed per block)
    // 15:   thread ID (fixed per thread)
    logic [data_bits-1:0] registers [15:0];

    // ---------------------
    // Sequential Logic
    always_ff @(posedge clk) begin
        if (reset) begin
            // Reset general-purpose registers
            for (int i = 0; i < 13; i++) begin
                registers[i] <= '0;
            end

            // Initialize read-only special registers
            registers[13] <= '0;                     // Block ID (runtime updates)
            registers[14] <= Threads_per_block;      // Block Dimension
            registers[15] <= Thread_id;              // Thread ID

            // Clear outputs
            rs <= '0;
            rt <= '0;
        end 
        else if (enable) begin
            // danger
            registers[13] <= block_id;

            // ---------------------
            // Register Read Stage
            if (core_state == 3'b011) begin   // 'Request' stage
                rs <= registers[dec_rs_address];
                rt <= registers[dec_rt_address];
            end

            // ---------------------
            // Register Write Stage
            if (core_state == 3'b110) begin   // 'Update' stage
                if (dec_reg_write_en && (dec_rd_address < 13)) begin
                    unique case (dec_reg_input_mux)
                        ARITHMETIC: registers[dec_rd_address] <= alu_out;
                        MEMORY:     registers[dec_rd_address] <= lsu_out;
                        CONSTANT:   registers[dec_rd_address] <= dec_imm;
                        default:    registers[dec_rd_address] <= '0;
                    endcase
                end
            end
        end
    end

endmodule
