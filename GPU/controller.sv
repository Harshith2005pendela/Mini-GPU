`default_nettype none
`timescale 1ns/1ns

module controller #(
    parameter ADDR_BITS = 8,           // Address bit width
    parameter DATA_BITS = 16,          // Data bit width
    parameter NUM_CONSUMERS = 4,       // Number of requesters
    parameter NUM_CHANNELS = 1,        // Number of memory channels
    parameter write_en = 1             // Enable write operations 
) (
    input  logic clk,                  // System clock
    input  logic reset,                // Active-high reset

    // Consumer interfaces
    input  logic [NUM_CONSUMERS-1:0] consumer_read_valid,
    input  logic [ADDR_BITS-1:0]     consumer_read_address [NUM_CONSUMERS],
    output logic [NUM_CONSUMERS-1:0] consumer_read_ready,
    output logic [DATA_BITS-1:0]     consumer_read_data [NUM_CONSUMERS],
    
    input  logic [NUM_CONSUMERS-1:0] consumer_write_valid,
    input  logic [ADDR_BITS-1:0]     consumer_write_address [NUM_CONSUMERS],
    output logic [NUM_CONSUMERS-1:0] consumer_write_ready,
    input  logic [DATA_BITS-1:0]     consumer_write_data [NUM_CONSUMERS],

    // Memory interfaces
    output logic [NUM_CHANNELS-1:0]  mem_read_valid,
    output logic [ADDR_BITS-1:0]     mem_read_address [NUM_CHANNELS],
    input  logic [NUM_CHANNELS-1:0]  mem_read_ready,
    input  logic [DATA_BITS-1:0]     mem_read_data [NUM_CHANNELS],
    
    output logic [NUM_CHANNELS-1:0]  mem_write_valid,
    output logic [ADDR_BITS-1:0]     mem_write_address [NUM_CHANNELS],
    input  logic [NUM_CHANNELS-1:0]  mem_write_ready,
    output logic [DATA_BITS-1:0]     mem_write_data [NUM_CHANNELS]
);

// FSM states
localparam
    IDLE        = 3'b000,
    READ_WAIT   = 3'b001,
    WRITE_WAIT  = 3'b010,
    READ_RELAY  = 3'b011,
    WRITE_RELAY = 3'b100;

// Channel state tracking
logic [2:0] controller_state [NUM_CHANNELS];
logic [$clog2(NUM_CONSUMERS)-1:0] current_consumer [NUM_CHANNELS];
logic [NUM_CONSUMERS-1:0] channel_serving_consumer;

// Arbitration signals
logic [NUM_CONSUMERS-1:0] current_available;
logic [NUM_CONSUMERS-1:0] next_channel_serving_consumer;

always_ff @(posedge clk) begin
    if (reset) begin
        // Vector-wide resets
        mem_read_valid     <= '0;
        mem_write_valid    <= '0;
        consumer_read_ready  <= '0;
        consumer_write_ready <= '0;
        channel_serving_consumer <= '0;
        
        // Per-channel resets
        for (int i = 0; i < NUM_CHANNELS; i++) begin
            controller_state[i] <= IDLE;
				current_consumer[i] <= {$clog2(NUM_CONSUMERS){1'b0}};
            mem_read_address[i]  <= '0;
            mem_write_address[i] <= '0;
            mem_write_data[i]    <= '0;
        end
        
        // Per-consumer resets
        for (int i = 0; i < NUM_CONSUMERS; i++) begin
            consumer_read_data[i] <= '0;
        end
    end 
    else begin
        // Initialize available consumers
        current_available = ~channel_serving_consumer;
        next_channel_serving_consumer = channel_serving_consumer;

        // Process each channel in priority order (0 has highest priority)
        for (int channel = 0; channel < NUM_CHANNELS; channel++) begin
            case (controller_state[channel])
                IDLE: begin
                    // Search for next available consumer
                    for (int consumer = 0; consumer < NUM_CONSUMERS; consumer++) begin
                        if (current_available[consumer]) begin
                            // Prioritize reads over writes
                            if (consumer_read_valid[consumer]) begin
                                // Claim this consumer
                                current_available[consumer] = 1'b0;  
                                next_channel_serving_consumer[consumer] = 1'b1;
                                current_consumer[channel] = consumer;
                                
                                // Initiate memory read
                                mem_read_valid[channel] <= 1'b1;
                                mem_read_address[channel] <= consumer_read_address[consumer];
                                controller_state[channel] <= READ_WAIT;
                                break;
                            end
                            else if (write_en && consumer_write_valid[consumer]) begin
                                // Claim this consumer
                                current_available[consumer] = 1'b0;
                                next_channel_serving_consumer[consumer] = 1'b1;
                                current_consumer[channel] = consumer;
                                
                                // Initiate memory write
                                mem_write_valid[channel] <= 1'b1;
                                mem_write_address[channel] <= consumer_write_address[consumer];
                                mem_write_data[channel] <= consumer_write_data[consumer];
                                controller_state[channel] <= WRITE_WAIT;
                                break;
                            end
                        end
                    end
                end

                READ_WAIT: begin
                    // Memory has responded with data
                    if (mem_read_ready[channel]) begin
                        mem_read_valid[channel] <= 1'b0;
                        consumer_read_ready[current_consumer[channel]] <= 1'b1;
                        consumer_read_data[current_consumer[channel]] <= mem_read_data[channel];
                        controller_state[channel] <= READ_RELAY;
                    end
                end

                WRITE_WAIT: begin
                    // Memory is ready to accept write
                    if (mem_write_ready[channel]) begin
                        mem_write_valid[channel] <= 1'b0;
                        consumer_write_ready[current_consumer[channel]] <= 1'b1;
                        controller_state[channel] <= WRITE_RELAY;
                    end
                end

                READ_RELAY: begin
                    // Wait for consumer to acknowledge
                    if (!consumer_read_valid[current_consumer[channel]]) begin
                        consumer_read_ready[current_consumer[channel]] <= 1'b0;
                        next_channel_serving_consumer[current_consumer[channel]] = 1'b0;
                        controller_state[channel] <= IDLE;
                    end
                end

                WRITE_RELAY: begin
                    // Wait for consumer to acknowledge
                    if (!consumer_write_valid[current_consumer[channel]]) begin
                        consumer_write_ready[current_consumer[channel]] <= 1'b0;
                        next_channel_serving_consumer[current_consumer[channel]] = 1'b0;
                        controller_state[channel] <= IDLE;
                    end
                end

                default: controller_state[channel] <= IDLE;
            endcase
        end

        // Update serving vector at end of cycle
        channel_serving_consumer <= next_channel_serving_consumer;
    end
end  
endmodule
