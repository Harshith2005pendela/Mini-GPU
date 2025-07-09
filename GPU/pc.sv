`default_nettype none
`timescale 1ns/1ns

module pc #(
    parameter data_mem_data_bits = 8,
    parameter prog_mem_addr_bits = 8
) (
    input  logic clk,
    input  logic reset,
    input  logic enable,

    input  logic [2:0] core_state,
    input  logic [2:0] dec_nzp,
    input  logic [data_mem_data_bits-1:0] dec_imm,
    input  logic nzp_write_en,
    input  logic dec_pc_mux,

    input  logic [data_mem_data_bits-1:0] alu_out,
    input  logic [prog_mem_addr_bits-1:0] current_pc,
    output logic [prog_mem_addr_bits-1:0] next_pc
);

    logic [2:0] nzp_reg;

    always_ff @(posedge clk) begin
        if (reset) begin
            nzp_reg <= 3'b0;
            next_pc <= '0;  // Default PC address (16-bit zero)
        end
        else if (enable) begin
            // Update Stage: store NZP flags from ALU
            if (core_state == 3'b110) begin
                if (nzp_write_en) begin
                    nzp_reg <= alu_out[2:0];
                end

                // PC update happens in UPDATE
                if (dec_pc_mux) begin
                    // Branch if any nzp_reg bits match dec_nzp
                    if ((nzp_reg & dec_nzp) != 0) begin
                        // Sign-extend 8-bit immediate to 16 bits for branch target
                        next_pc <= dec_imm;
                    end else begin
                        next_pc <= current_pc + 1'b1; // Use 1-bit literal (no truncation)
                    end
                end else begin
                    next_pc <= current_pc + 1'b1; // Use 1-bit literal (no truncation)
                end
            end
        end
    end

endmodule
