`default_nettype none
`timescale 1ns/1ns

module core # (
    parameter DATA_MEM_ADDR_BITS = 8,
    parameter DATA_MEM_DATA_BITS = 8,
    parameter PROG_MEM_ADDR_BITS = 8,
    parameter PROG_MEM_DATA_BITS = 16,
    parameter THREADS_PER_BLOCK = 4,
    parameter IMM_SIZE = 8
)(
    input logic clk,
    input logic reset,
    input logic start,
    output logic complete,
    input logic [7:0] block_id,
    input logic [$clog2(THREADS_PER_BLOCK):0] thread_count,
	 
    output logic prog_read_ask,
    output logic [PROG_MEM_ADDR_BITS-1:0] prog_mem_addr,
    input logic [PROG_MEM_DATA_BITS-1:0] prog_mem_data,
    input logic prog_read_get,
    output logic [THREADS_PER_BLOCK-1:0] data_mem_read_ask,
	 
    output logic [DATA_MEM_ADDR_BITS-1:0] data_mem_read_addr [THREADS_PER_BLOCK-1:0],
    input logic  [THREADS_PER_BLOCK-1:0] data_mem_read_get,
    input logic [DATA_MEM_DATA_BITS-1:0] data_mem_read_data [THREADS_PER_BLOCK-1:0],
    output logic [THREADS_PER_BLOCK-1:0] data_mem_write_ask,
	 
    output logic [DATA_MEM_ADDR_BITS-1:0] data_mem_write_addr [THREADS_PER_BLOCK-1:0],
    input logic  [THREADS_PER_BLOCK-1:0] data_mem_write_get,
    output logic [DATA_MEM_DATA_BITS-1:0] data_mem_write_data [THREADS_PER_BLOCK-1:0]
);

    reg [2:0] core_state;
    reg [2:0] fetcher_state;
    reg [PROG_MEM_DATA_BITS-1:0] instruction;
    logic [1:0] lsu_state [THREADS_PER_BLOCK-1:0];

    // Intermediate Signals
    logic [DATA_MEM_DATA_BITS-1:0] rs[THREADS_PER_BLOCK-1:0];
    logic [DATA_MEM_DATA_BITS-1:0] rt[THREADS_PER_BLOCK-1:0];
    logic [DATA_MEM_DATA_BITS-1:0] alu_out[THREADS_PER_BLOCK-1:0];
    logic [DATA_MEM_DATA_BITS-1:0] lsu_out[THREADS_PER_BLOCK-1:0];
    reg [PROG_MEM_ADDR_BITS-1:0] current_pc;
    reg [PROG_MEM_ADDR_BITS-1:0] next_pc [THREADS_PER_BLOCK-1:0];
    
    // Decoded signals
    logic [3:0] dec_rd_addr;
    logic [3:0] dec_rs_addr;
    logic [3:0] dec_rt_addr;
    logic [2:0] dec_nzp;
    logic [IMM_SIZE-1:0] dec_imm;
    logic dec_reg_write_en;
    logic [1:0] dec_alu_arith_mux;
    logic dec_alu_out_mux;
    logic dec_mem_read_en;
    logic dec_mem_write_en;
    logic [1:0] dec_reg_input_mux;
    logic dec_nzp_write_en;
    logic dec_pc_mux;
    logic dec_ret;

    // Scheduler
    scheduler #(
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)   
    ) scheduler_instance (
        .clk(clk),
        .reset(reset),
        .start(start),
        .dec_ret(dec_ret),
        .fetcher_state(fetcher_state),
        .lsu_state(lsu_state),
        .current_pc(current_pc),
        .next_pc(next_pc),
        .core_state(core_state),
        .complete(complete)
    );

    // Fetcher
    fetcher #(
        .PROG_MEM_ADDR_BITS(PROG_MEM_ADDR_BITS),
        .PROG_MEM_DATA_BITS(PROG_MEM_DATA_BITS)
    ) inst_fetcher (
        .clk(clk),
        .reset(reset),
        .core_state(core_state),
        .current_pc(current_pc),
        .mem_read_ask(prog_read_ask),
        .mem_read_address(prog_mem_addr),
        .mem_read_get(prog_read_get),
        .mem_read_data(prog_mem_data),
        .fetcher_state(fetcher_state),
        .instr(instruction)
    );

    // Decoder
    decoder #(
        .PROG_MEM_DATA_BITS(PROG_MEM_DATA_BITS),
        .imm_size(IMM_SIZE)
    ) decoder_instance (
        .clk(clk),
        .reset(reset),
        .core_state(core_state),
        .instr(instruction),
        .dec_rd_addr(dec_rd_addr),
        .dec_rs_addr(dec_rs_addr),
        .dec_rt_addr(dec_rt_addr),
        .dec_nzp(dec_nzp),
        .dec_imm(dec_imm),
        .dec_reg_write_en(dec_reg_write_en),
        .dec_alu_arith_mux(dec_alu_arith_mux),
        .dec_alu_out_mux(dec_alu_out_mux),
        .dec_mem_read_en(dec_mem_read_en),
        .dec_mem_write_en(dec_mem_write_en),
        .dec_reg_input_mux(dec_reg_input_mux),
        .dec_nzp_write_en(dec_nzp_write_en),
        .dec_pc_mux(dec_pc_mux),
        .dec_ret(dec_ret)
    );

    genvar i;
    generate 
        for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin: threads
            // ALU
            alu alu_instance (
                .clk(clk),
                .reset(reset),
                .enable(i < thread_count),
                .core_state(core_state),
                .alu_op_code(dec_alu_arith_mux),
                .dec_alu_out_mux(dec_alu_out_mux),
                .rs(rs[i]),
                .rt(rt[i]),
                .alu_out(alu_out[i])
            );
            
            // LSU
            lsu #(
                .data_length(DATA_MEM_DATA_BITS)
            ) lsu_instance (
                .clk(clk),
                .reset(reset),
                .enable(i < thread_count),
                .core_state(core_state),
                .dec_mem_read_en(dec_mem_read_en),
                .dec_mem_write_en(dec_mem_write_en),
                .rs(rs[i]),
                .rt(rt[i]),
                .mem_get_read(data_mem_read_get[i]),
                .mem_read_address(data_mem_read_addr[i]),
                .mem_ask_read(data_mem_read_ask[i]),
                .mem_read_data(data_mem_read_data[i]),
                .mem_get_write(data_mem_write_get[i]),
                .mem_write_address(data_mem_write_addr[i]),
                .mem_ask_write(data_mem_write_ask[i]),
                .mem_write_data(data_mem_write_data[i]),
                .lsu_state(lsu_state[i]),
                .lsu_out(lsu_out[i])
            );
            
            // Register File
            registers #(
                .Threads_per_block(THREADS_PER_BLOCK),
                .Thread_id(i),
                .data_bits(DATA_MEM_DATA_BITS)
            ) register_instance (
                .clk(clk),
                .reset(reset),
                .enable(i < thread_count),
                .block_id(block_id),
                .core_state(core_state),
                .dec_reg_write_en(dec_reg_write_en),
                .dec_reg_input_mux(dec_reg_input_mux),
                .dec_rs_address(dec_rs_addr),
                .dec_rt_address(dec_rt_addr),
                .dec_rd_address(dec_rd_addr),
                .dec_imm(dec_imm),
                .alu_out(alu_out[i]),
                .lsu_out(lsu_out[i]),
                .rs(rs[i]),
                .rt(rt[i])
            );
            
            // Program Counter
            pc #(
                .data_mem_data_bits(DATA_MEM_DATA_BITS),
                .prog_mem_addr_bits(PROG_MEM_ADDR_BITS)
            ) pc_instance (
                .clk(clk),
                .reset(reset),
                .enable(i < thread_count),
                .core_state(core_state),
                .dec_nzp(dec_nzp),
                .dec_imm(dec_imm),
                .nzp_write_en(dec_nzp_write_en),
                .dec_pc_mux(dec_pc_mux),
                .alu_out(alu_out[i]),
                .current_pc(current_pc),
                .next_pc(next_pc[i])
            );
        end
    endgenerate
endmodule 