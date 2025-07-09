`default_nettype none
`timescale 1ns/1ns

module decoder #(
    parameter PROG_MEM_DATA_BITS = 16,
    parameter imm_size = 8
)(
    input logic clk,
    input logic reset,
    input logic [2:0] core_state,
    input logic [PROG_MEM_DATA_BITS-1:0] instr,
    
    // Data outputs
    output logic [3:0] dec_rd_addr,  // 4-bit register address
    output logic [3:0] dec_rs_addr,  // 4-bit register address
    output logic [3:0] dec_rt_addr,  // 4-bit register address
    output logic [2:0] dec_nzp,      // 3-bit NZP flags
    output logic [imm_size-1:0] dec_imm,
    
    // Control signals
    output logic dec_reg_write_en,
    output logic [1:0] dec_alu_arith_mux,  // 2-bit ALU op selection
    output logic dec_alu_out_mux,
    output logic dec_mem_read_en,
    output logic dec_mem_write_en,
    output logic [1:0] dec_reg_input_mux,
    output logic dec_nzp_write_en,
    output logic dec_pc_mux,
    output logic dec_ret  // return instruction flag
);

// Opcode definitions (4-bit)
localparam 
    NOP   = 4'b0000,
    BRNZP = 4'b0001,
    CMP   = 4'b0010,
    ADD   = 4'b0011,
    SUB   = 4'b0100,
    MUL   = 4'b0101,
    DIV   = 4'b0110,
    LDR   = 4'b0111,
    STR   = 4'b1000,
    CONST = 4'b1001,
    RET   = 4'b1111;

always_ff @(posedge clk) begin
    if (reset) begin
        // Reset all outputs
        dec_rd_addr         <= 0;
        dec_rs_addr         <= 0;
        dec_rt_addr         <= 0;
        dec_nzp             <= 0;
        dec_imm             <= 0;
        dec_reg_write_en    <= 0;
        dec_alu_arith_mux   <= 0;
        dec_alu_out_mux     <= 0;
        dec_mem_read_en    <= 0;
        dec_mem_write_en  <= 0;
        dec_reg_input_mux   <= 0;
        dec_nzp_write_en    <= 0;
        dec_pc_mux          <= 0;
        dec_ret             <= 0;
    end
    else begin
        // Decode only in core state 010 (decode stage)
        if (core_state == 3'b010) begin
            // Default assignments
            dec_rd_addr         <= instr[11:8];  // 4 bits
            dec_rs_addr         <= instr[7:4];   // 4 bits
            dec_rt_addr         <= instr[3:0];   // 4 bits
            dec_imm             <= instr[7:0];   // 8 bits
            dec_nzp             <= instr[11:9];  // 3 bits
            dec_reg_write_en    <= 0;
            dec_alu_arith_mux   <= 0;
            dec_alu_out_mux     <= 0;
            dec_mem_read_en    <= 0;
            dec_mem_write_en   <= 0;
            dec_reg_input_mux   <= 0;
            dec_nzp_write_en    <= 0;
            dec_pc_mux          <= 0;
            dec_ret             <= 0;
            
            // Instruction decoding
            case (instr[15:12])
                NOP: begin
                    // No operation
                end
                BRNZP: begin
                    dec_pc_mux <= 1;  // Branch taken
                end
                CMP: begin
                    dec_nzp_write_en <= 1;  // Write NZP flags
                    dec_alu_out_mux  <= 1;  // Select ALU output for flags
                end
                ADD: begin 
                    dec_reg_write_en  <= 1;  // Write to register
                    dec_reg_input_mux <= 2'b00;  // Select ALU output
                    dec_alu_arith_mux <= 2'b00;  // ADD operation
                end
                SUB: begin 
                    dec_reg_write_en  <= 1;
                    dec_reg_input_mux <= 2'b00;
                    dec_alu_arith_mux <= 2'b01;  // SUB operation
                end
                MUL: begin
                    dec_reg_write_en  <= 1;
                    dec_reg_input_mux <= 2'b00;
                    dec_alu_arith_mux <= 2'b10;  // MUL operation
                end
                DIV: begin
                    dec_reg_write_en  <= 1;
                    dec_reg_input_mux <= 2'b00;
                    dec_alu_arith_mux <= 2'b11;  // DIV operation
                end
                LDR: begin
                    dec_mem_read_en  <= 1;      // Request memory read
                    dec_reg_write_en  <= 1;       // Write to register
                    dec_reg_input_mux <= 2'b10;   // Select memory data
                end
                STR: begin
                    dec_mem_write_en <= 1;       // Request memory write
                end
                CONST: begin 
                    dec_reg_write_en  <= 1;       // Enable write 
                    dec_reg_input_mux <= 2'b01;   // Select immediate value
                end
                RET: begin 
                    dec_ret <= 1;  // Return instruction
                end
                default: begin
                    // Handle undefined opcodes 
                end
            endcase
        end
    end
end
endmodule 