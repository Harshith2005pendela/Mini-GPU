`default_nettype none
`timescale 1ns/1ns

module lsu #(
    parameter data_length = 8
) (
    input  logic clk,
    input  logic reset,
    input  logic enable,
    
    // CORE STAGE
    input  logic [2:0] core_state,
    
    // Decoded instructions
    input  logic dec_mem_read_en,
    input  logic dec_mem_write_en,
    
    // Register inputs
    input  logic [data_length-1:0] rs,
    input  logic [data_length-1:0] rt,
    
    // Memory interface (reads)
    input  logic mem_get_read,
    output logic [data_length-1:0] mem_read_address,
    output logic mem_ask_read,
    input  logic [data_length-1:0] mem_read_data,
    
    // Memory interface (writes)
    input  logic mem_get_write,
    output logic [data_length-1:0] mem_write_address,
    output logic mem_ask_write,
    output logic [data_length-1:0] mem_write_data,
    
    // LSU outputs
    output logic [1:0] lsu_state,
    output logic [data_length-1:0] lsu_out
);

    typedef enum logic [1:0] {
        IDLE       = 2'b00,
        REQUESTING = 2'b01,
        WAITING    = 2'b10,
        DONE       = 2'b11
    } state_t;
    
    state_t lsu_state_internal;
    assign lsu_state = lsu_state_internal;

    always_ff @(posedge clk) begin
        if (reset) begin
            lsu_state_internal <= IDLE;
            lsu_out            <= '0;
            mem_ask_read       <= 1'b0;
            mem_read_address   <= '0;
            mem_ask_write      <= 1'b0;
            mem_write_address  <= '0;
            mem_write_data     <= '0;
        end
        else if (enable) begin
            mem_ask_read  <= 1'b0;
            mem_ask_write <= 1'b0;
            
            case (lsu_state_internal)
                IDLE: begin
                    if (core_state == 3'b011) begin  // Request stage
                        lsu_state_internal <= REQUESTING;
                    end
                end
                
                REQUESTING: begin
                    if (dec_mem_read_en) begin
                        lsu_state_internal <= WAITING;
                        mem_ask_read     <= 1'b1;
                        mem_read_address <= rs;
                    end
                    else if (dec_mem_write_en) begin
                        lsu_state_internal <= WAITING;
                        mem_ask_write     <= 1'b1;
                        mem_write_address <= rs;
                        mem_write_data    <= rt;
                    end
                end
                
                WAITING: begin
                    if (dec_mem_read_en && mem_get_read) begin
                        lsu_out           <= mem_read_data;
                        lsu_state_internal <= DONE;
                    end
                    else if (dec_mem_write_en && mem_get_write) begin
                        lsu_state_internal <= DONE;
                    end
                end
                
                DONE: begin
                    if (core_state == 3'b110) begin  // Update stage
                        lsu_state_internal <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
