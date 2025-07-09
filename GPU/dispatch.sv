`default_nettype none
`timescale 1ns/1ns

module dispatch #(
    parameter NUM_CORES = 2,
    parameter THREADS_PER_BLOCK = 4
) (
    input logic clk,
    input logic reset,
    input logic start,

    // Kernel Thread Count
    input logic [7:0] thread_count,

    // Core States
    input logic [NUM_CORES-1:0] core_done,
    output logic [NUM_CORES-1:0] core_start,
    output logic [NUM_CORES-1:0] core_reset,
    output logic [7:0] core_block_id [NUM_CORES-1:0],
    output logic [$clog2(THREADS_PER_BLOCK):0] core_thread_count [NUM_CORES-1:0],

    // Done signal
    output logic done
);
    // Calculate total blocks needed (ceiling division)
    logic [7:0] total_blocks;
	 
	 assign total_blocks = (thread_count == 0) ? 8'd0 : 8'((thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK);

    // Control registers
    logic running;
    logic [7:0] blocks_dispatched;
    logic [7:0] blocks_done;
    logic [NUM_CORES-1:0] core_busy;

    integer i;
	 integer count_completions;
	 integer next_block;
	 
    always @(posedge clk) begin
        if (reset) begin
            // Reset state initialization
            done <= 1'b0;
            running <= 1'b0;
            blocks_dispatched <= 8'd0;
            blocks_done <= 8'd0;
            core_busy <= {NUM_CORES{1'b0}};
            
            for (i = 0; i < NUM_CORES; i++) begin
                core_start[i] <= 1'b0;
                core_reset[i] <= 1'b1;  // Assert reset on all cores
                core_block_id[i] <= 8'd0;
                core_thread_count[i] <= THREADS_PER_BLOCK[7:0];
            end
        end 
        else begin
            // Default outputs
            for (i = 0; i < NUM_CORES; i++) begin
                core_start[i] <= 1'b0;
                core_reset[i] <= 1'b0;
            end

            // Start new kernel execution
            if (start && !running) begin
                done <= 1'b0;
                running <= 1'b1;
                blocks_dispatched <= 8'd0;
                blocks_done <= 8'd0;
                core_busy <= {NUM_CORES{1'b0}};
                
                // Initialize cores with reset
                for (i = 0; i < NUM_CORES; i++) begin
                    core_reset[i] <= 1'b1;
                end
            end 
            // Kernel execution in progress
            else if (running) begin
                // Handle completed cores
                count_completions = 0;
                for (i = 0; i < NUM_CORES; i++) begin
                    if (core_busy[i] && core_done[i]) begin
                        count_completions++;
                        core_busy[i] <= 1'b0;
                        core_reset[i] <= 1'b1;  // Reset core after completion
                    end
                end
                blocks_done <= blocks_done + count_completions[7:0];

                // Dispatch new blocks to available cores
                next_block = blocks_dispatched;
                for (i = 0; i < NUM_CORES; i++) begin
                    if (!core_busy[i] && !core_reset[i] && (next_block < total_blocks)) begin
                        
                        core_start[i] <= 1'b1;
                        core_busy[i] <= 1'b1;
                        core_block_id[i] <= next_block[7:0];
                        
                        // Handle last block thread count
                        if (next_block == total_blocks - 1) begin
                            core_thread_count[i] <= 8'(thread_count - (next_block*THREADS_PER_BLOCK));
                        end else begin
                            core_thread_count[i] <= 8'(THREADS_PER_BLOCK);
                        end
                        
                        next_block = next_block + 1;  // Blocking assignment for sequential ID
                    end
                end
                blocks_dispatched <= next_block[7:0];  // Update once after loop

                if ((blocks_done + count_completions) == total_blocks) begin
                    done <= 1'b1;
                    running <= 1'b0;
                end
            end
        end
    end
endmodule 
