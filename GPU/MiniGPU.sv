`default_nettype none
`timescale 1ns/1ns

module MiniGPU #(
    parameter DATA_MEM_ADDR_BITS = 8,        // Number of bits in data memory address (256 rows)
    parameter DATA_MEM_DATA_BITS = 8,        // Number of bits in data memory value (8 bit data)
    parameter DATA_MEM_NUM_CHANNELS = 4,     // Number of concurrent channels for sending requests to data memory
    parameter PROGRAM_MEM_ADDR_BITS = 8,     // Number of bits in program memory address (256 rows)
    parameter PROGRAM_MEM_DATA_BITS = 16,    // Number of bits in program memory value (16 bit instruction)
    parameter PROGRAM_MEM_NUM_CHANNELS = 1,  // Number of concurrent channels for sending requests to program memory
    parameter NUM_CORES = 2,                 // Number of cores to include in this GPU
    parameter THREADS_PER_BLOCK = 4          // Number of threads to handle 
)(
    input logic clk,
    input logic reset,
    
    //Kernel 
    input logic start,
    output logic done,
    
    //Device Control register 
    input logic device_control_write_enable,
    input logic [7:0] device_control_data,
    
    // Program Memory 
    output logic [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_ask,
    output logic [PROGRAM_MEM_ADDR_BITS-1:0] program_mem_addr [0:PROGRAM_MEM_NUM_CHANNELS-1],
    input logic [PROGRAM_MEM_DATA_BITS-1:0] program_mem_data [0:PROGRAM_MEM_NUM_CHANNELS-1],
    input logic [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_get,
    
    //Data Memory Read 
    output logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_ask,
    output logic [DATA_MEM_ADDR_BITS-1:0] data_mem_read_addr [0:DATA_MEM_NUM_CHANNELS-1],
    input logic [DATA_MEM_DATA_BITS-1:0] data_mem_read_data [0:DATA_MEM_NUM_CHANNELS-1],
    input logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_get,
    
    //Data Memory Write 
    output logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_ask,
    output logic [DATA_MEM_ADDR_BITS-1:0] data_mem_write_addr [0:DATA_MEM_NUM_CHANNELS-1],
    output logic [DATA_MEM_DATA_BITS-1:0] data_mem_write_data [0:DATA_MEM_NUM_CHANNELS-1],
    input logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_get
);

    logic [7:0] thread_count;
    
    // Core states 
    logic [NUM_CORES-1:0] core_start;
    logic [NUM_CORES-1:0] core_reset;
    logic [NUM_CORES-1:0] core_done;
    logic [7:0] core_block_id [0:NUM_CORES-1];
    logic [$clog2(THREADS_PER_BLOCK):0] core_thread_count [0:NUM_CORES-1];

    // Device Control Register
    device_control_register dcr_i (
        .clk(clk),
        .reset(reset),
        .device_ctrl_wt_en(device_control_write_enable),
        .thread_count(thread_count),
        .dcr(device_control_data)
    );
    
    // Dispatcher
    dispatch #(
        .NUM_CORES(NUM_CORES),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) dispatch_instance (
        .clk(clk),
        .reset(reset),
        .start(start),
        .thread_count(thread_count),
        .core_done(core_done),
        .core_start(core_start),
        .core_reset(core_reset),
        .core_block_id(core_block_id),
        .core_thread_count(core_thread_count),
        .done(done)
    );
    
    // LSU and data memory controller
    localparam NUM_LSU = NUM_CORES * THREADS_PER_BLOCK;
    
    logic [NUM_LSU-1:0] lsu_read_ask;
    logic [DATA_MEM_ADDR_BITS-1:0] lsu_read_address [0:NUM_LSU-1];
    logic [NUM_LSU-1:0] lsu_read_get;
    logic [DATA_MEM_DATA_BITS-1:0] lsu_read_data [0:NUM_LSU-1];
    
    logic [NUM_LSU-1:0] lsu_write_ask;
    logic [DATA_MEM_ADDR_BITS-1:0] lsu_write_address [0:NUM_LSU-1];
    logic [DATA_MEM_DATA_BITS-1:0] lsu_write_data [0:NUM_LSU-1];
    logic [NUM_LSU-1:0] lsu_write_get;

    // Data memory controller
    controller #(
        .ADDR_BITS(DATA_MEM_ADDR_BITS),
        .DATA_BITS(DATA_MEM_DATA_BITS),
        .NUM_CONSUMERS(NUM_LSU),
        .NUM_CHANNELS(DATA_MEM_NUM_CHANNELS)
    ) d_controller (
        .clk(clk),
        .reset(reset),
        
        // Read interface
        .consumer_read_valid(lsu_read_ask),
        .consumer_read_address(lsu_read_address),
        .consumer_read_ready(lsu_read_get),
        .consumer_read_data(lsu_read_data),
        
        // Write interface
        .consumer_write_valid(lsu_write_ask),
        .consumer_write_address(lsu_write_address),
        .consumer_write_ready(lsu_write_get),
        .consumer_write_data(lsu_write_data),
        
        // Memory read interface
        .mem_read_valid(data_mem_read_ask),
        .mem_read_address(data_mem_read_addr),
        .mem_read_ready(data_mem_read_get),
        .mem_read_data(data_mem_read_data),
        
        // Memory write interface
        .mem_write_valid(data_mem_write_ask),
        .mem_write_address(data_mem_write_addr),
        .mem_write_ready(data_mem_write_get),
        .mem_write_data(data_mem_write_data)
    );
    
    // Fetcher and program memory controller
    localparam NUM_FETCHERS = NUM_CORES;
    
    logic [NUM_FETCHERS-1:0] fetcher_read_ask;
    logic [PROGRAM_MEM_ADDR_BITS-1:0] fetcher_read_address [0:NUM_FETCHERS-1];
    logic [NUM_FETCHERS-1:0] fetcher_read_get;
    logic [PROGRAM_MEM_DATA_BITS-1:0] fetcher_read_data [0:NUM_FETCHERS-1];
    
    // Program memory controller
    controller #(
        .ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
        .DATA_BITS(PROGRAM_MEM_DATA_BITS),
        .NUM_CONSUMERS(NUM_FETCHERS),
        .NUM_CHANNELS(PROGRAM_MEM_NUM_CHANNELS),
        .write_en(0)  // Read-only for program memory
    ) Prog_controller (
        .clk(clk),
        .reset(reset),
        
        // Read interface
        .consumer_read_valid(fetcher_read_ask),
        .consumer_read_address(fetcher_read_address),
        .consumer_read_ready(fetcher_read_get),
        .consumer_read_data(fetcher_read_data),
        
        // Memory read interface
        .mem_read_valid(program_mem_ask),
        .mem_read_address(program_mem_addr),
        .mem_read_ready(program_mem_get),
        .mem_read_data(program_mem_data)
    );
    
    // Instantiate cores and connect to controllers
    genvar i, j;
// Fix in MiniGPU module - change the core instantiation section:

generate
    for (i = 0; i < NUM_CORES; i = i + 1) begin : core_gen
        // LSU connections - these should be OUTPUTS from the core
        logic [THREADS_PER_BLOCK-1:0] core_lsu_read_ask;
        logic [DATA_MEM_ADDR_BITS-1:0] core_lsu_read_addr [0:THREADS_PER_BLOCK-1];
        logic [THREADS_PER_BLOCK-1:0] core_lsu_read_get;
        logic [DATA_MEM_DATA_BITS-1:0] core_lsu_read_data [0:THREADS_PER_BLOCK-1];
        
        logic [THREADS_PER_BLOCK-1:0] core_lsu_write_ask;
        logic [DATA_MEM_ADDR_BITS-1:0] core_lsu_write_addr [0:THREADS_PER_BLOCK-1];
        logic [THREADS_PER_BLOCK-1:0] core_lsu_write_get;
        logic [DATA_MEM_DATA_BITS-1:0] core_lsu_write_data [0:THREADS_PER_BLOCK-1];
        
        // Connect LSUs to global LSU arrays
        for (j = 0; j < THREADS_PER_BLOCK; j = j + 1) begin : lsu_conn
            localparam lsu_index = i * THREADS_PER_BLOCK + j;
            
            // READ connections
            assign lsu_read_ask[lsu_index] = core_lsu_read_ask[j];
            assign lsu_read_address[lsu_index] = core_lsu_read_addr[j];
            assign core_lsu_read_get[j] = lsu_read_get[lsu_index];
            assign core_lsu_read_data[j] = lsu_read_data[lsu_index];
            
            // WRITE connections
            assign lsu_write_ask[lsu_index] = core_lsu_write_ask[j];
            assign lsu_write_address[lsu_index] = core_lsu_write_addr[j];
            assign lsu_write_data[lsu_index] = core_lsu_write_data[j];  
            assign core_lsu_write_get[j] = lsu_write_get[lsu_index];
        end
        
        // Instantiate core
        core #(
            .DATA_MEM_ADDR_BITS(DATA_MEM_ADDR_BITS),
            .DATA_MEM_DATA_BITS(DATA_MEM_DATA_BITS),
            .PROG_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
            .PROG_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS),
            .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
        ) core_inst (
            .clk(clk),
            .reset(core_reset[i]),
            .start(core_start[i]),
            .complete(core_done[i]),
            .block_id(core_block_id[i]),
            .thread_count(core_thread_count[i]),
            
            // Program memory interface
            .prog_read_ask(fetcher_read_ask[i]),
            .prog_mem_addr(fetcher_read_address[i]),
            .prog_mem_data(fetcher_read_data[i]),
            .prog_read_get(fetcher_read_get[i]),
            
            // Data memory read interface
            .data_mem_read_ask(core_lsu_read_ask),
            .data_mem_read_addr(core_lsu_read_addr),
            .data_mem_read_get(core_lsu_read_get),
            .data_mem_read_data(core_lsu_read_data),
            
            // Data memory write interface 
            .data_mem_write_ask(core_lsu_write_ask),      // OUTPUT from core
            .data_mem_write_addr(core_lsu_write_addr),    // OUTPUT from core  
            .data_mem_write_get(core_lsu_write_get),      // INPUT to core
            .data_mem_write_data(core_lsu_write_data)     // OUTPUT from core
        );
    end
endgenerate
endmodule
