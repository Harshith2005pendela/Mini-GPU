`default_nettype none
`timescale 1ns/1ns

// gets the Current PC from golbal Data Memory
// Each core has its own fetcher
module fetcher#( 
	parameter PROG_MEM_ADDR_BITS = 8,
	parameter PROG_MEM_DATA_BITS = 16
) (
	input logic clk,
	input logic reset,
	
	//get the core state from fetcher
	input logic[2:0] core_state,
	//getting PC
	input logic[PROG_MEM_ADDR_BITS-1:0] current_pc,
	
	//PROGRAM Memory
	output logic mem_read_ask,
	output logic [PROG_MEM_ADDR_BITS-1:0] mem_read_address,
	input logic mem_read_get,
	input logic [PROG_MEM_DATA_BITS-1:0] mem_read_data,
	
	//Fetcher 
	output logic [2:0] fetcher_state,
	output logic [PROG_MEM_DATA_BITS-1:0] instr
	);
	localparam IDLE = 3'b000,
				FETCHING = 3'b001,
				FETCHED = 3'b010;
	// 3 bits I am using if in future I expland the number of states
	always_ff@(posedge clk) begin
		if(reset) begin
			fetcher_state <= IDLE;
			mem_read_ask <= 0;
			instr <= {PROG_MEM_DATA_BITS{1'b0}};
			mem_read_address <= {PROG_MEM_ADDR_BITS{1'b0}};
		end
		else begin
			case(fetcher_state) 
				IDLE: begin
				//Start Fetch when the scheduler instructs me to fetch
					if(core_state == 3'b001) begin
						mem_read_ask <= 1'b1;
						mem_read_address <= current_pc;
						fetcher_state <= FETCHING;
					end
				end
				FETCHING: begin
				// See if handshaked with the memory correctly 
					if(mem_read_get == 1'b1) begin
						instr <= mem_read_data;
						fetcher_state <= FETCHED;
						mem_read_ask <= 1'b0;
					end
				end
				FETCHED: begin
				//Eat 5 star do nothing
					if(core_state == 3'b010) begin
						fetcher_state <= IDLE;
					end 
				end
			endcase
		end
	end
endmodule
					
					
				
		
	
	
	
	
	
	