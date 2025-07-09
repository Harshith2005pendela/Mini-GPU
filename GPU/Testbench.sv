 `default_nettype none  
 `timescale 1ns/1ns

module gpu_tb;
  logic reset,start,dcr_write_en,done;
  logic clk;
  logic [7:0] device_control_data;
  
  localparam THREADS = 8;
  localparam DATA_MEM_ADDR_BITS = 8;
  localparam DATA_MEM_DATA_BITS = 8;        // Number of bits in data memory value (8 bit data)
  localparam DATA_MEM_NUM_CHANNELS = 4;     // Number of concurrent channels for sending requests to data memory
  localparam PROGRAM_MEM_ADDR_BITS = 8;     // Number of bits in program memory address (256 rows)
  localparam PROGRAM_MEM_DATA_BITS = 16;    // Number of bits in program memory value (16 bit instruction)
  localparam PROGRAM_MEM_NUM_CHANNELS = 1;  // Number of concurrent channels for sending requests to program memory
  localparam NUM_CORES = 2;                 // Number of cores to include in this GPU
  localparam THREADS_PER_BLOCK = 4;  
  
  //Program Memory
   logic [PROGRAM_MEM_DATA_BITS-1:0] program_mem [0:(1<<PROGRAM_MEM_ADDR_BITS)-1];
   
   logic [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_ready;
   logic [PROGRAM_MEM_DATA_BITS-1:0] program_mem_read_data [PROGRAM_MEM_NUM_CHANNELS-1:0];
   logic [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_valid;
   logic [PROGRAM_MEM_ADDR_BITS-1:0] program_mem_read_address [PROGRAM_MEM_NUM_CHANNELS-1:0];
   
   always_comb begin
   program_mem_read_ready = program_mem_read_valid;
   for (int i = 0; i < PROGRAM_MEM_NUM_CHANNELS; i++)begin
       program_mem_read_data[i] = program_mem[int'(program_mem_read_address[i])];
   end
   end
   
   //Data Memory
   logic [DATA_MEM_DATA_BITS-1:0] data_mem [0:(1<<DATA_MEM_ADDR_BITS)-1]; 
   
   logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_ready;
   wire [DATA_MEM_DATA_BITS-1:0] data_mem_read_data [DATA_MEM_NUM_CHANNELS-1:0];
   wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_valid;
   wire [DATA_MEM_ADDR_BITS-1:0] data_mem_read_address [DATA_MEM_NUM_CHANNELS-1:0];
   
   logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_ready; 
   wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_valid;
   wire [DATA_MEM_ADDR_BITS-1:0] data_mem_write_address [DATA_MEM_NUM_CHANNELS-1:0];
   wire [DATA_MEM_DATA_BITS-1:0] data_mem_write_data [DATA_MEM_NUM_CHANNELS-1:0];
   
   initial  clk = 1'b0;
   always #25 clk = ~clk;   // 50 ns → 125 ns half-period

   always@(posedge clk)begin
     for (int c = 0; c < DATA_MEM_NUM_CHANNELS; c++) begin
         if (data_mem_write_valid[c])
            data_mem[data_mem_write_address[c]] <= data_mem_write_data[c];

         data_mem_write_ready[c] <= data_mem_write_valid[c];
         data_mem_read_ready [c] <= data_mem_read_valid[c];
      end
   end
    
   for (genvar c = 0; c < DATA_MEM_NUM_CHANNELS; c++)
      assign data_mem_read_data[c] = data_mem[data_mem_read_address[c]];
      
   localparam int PROG_LEN = 13;
   initial begin
//      program_mem[0]  = 16'b0101_0000_1101_1110; // MUL R0, %blockIdx, %blockDim
//      program_mem[1]  = 16'b0011_0000_0000_1111; // ADD R0, R0, %threadIdx
//      program_mem[2]  = 16'b1001_0001_0000_0000; // CONST R1, #0
//      program_mem[3]  = 16'b1001_0010_0000_1000; // CONST R2, #8
//      program_mem[4]  = 16'b1001_0011_0001_0000; // CONST R3, #16
//      program_mem[5]  = 16'b0011_0100_0001_0000; // ADD R4, R1, R0
//      program_mem[6]  = 16'b0111_0100_0100_0000; // LDR R4, R4
//      program_mem[7]  = 16'b0011_0101_0010_0000; // ADD R5, R2, R0
//      program_mem[8]  = 16'b0111_0101_0101_0000; // LDR R5, R5
//      program_mem[9]  = 16'b0011_0110_0100_0101; // ADD R6, R4, R5
//      program_mem[10] = 16'b0011_0111_0011_0000; // ADD R7, R3, R0
//      program_mem[11] = 16'b1000_0000_0111_0110; // STR R7, R6
//      program_mem[12] = 16'b1111_0000_0000_0000; // RET
      
//      for (int i = 13; i < (1<<PROGRAM_MEM_ADDR_BITS); i = i + 1)
//      program_mem[i] = '0;

    program_mem[0]  = 16'b0101000011011110; // MUL R0, %blockIdx, %blockDim
    program_mem[1]  = 16'b0011000000001111; // ADD R0, R0, %threadIdx
    program_mem[2]  = 16'b1001000100000001; // CONST R1, #1
    program_mem[3]  = 16'b1001001000000010; // CONST R2, #2
    program_mem[4]  = 16'b1001001100000000; // CONST R3, #0
    program_mem[5]  = 16'b1001010000000100; // CONST R4, #4
    program_mem[6]  = 16'b1001010100001000; // CONST R5, #8
    program_mem[7]  = 16'b0110011000000010; // DIV R6, R0, R2
    program_mem[8]  = 16'b0101011101100010; // MUL R7, R6, R2
    program_mem[9]  = 16'b0100011100000111; // SUB R7, R0, R7
    program_mem[10] = 16'b1001100000000000; // CONST R8, #0
    program_mem[11] = 16'b1001100100000000; // CONST R9, #0
    program_mem[12] = 16'b0101101001100010; // MUL R10, R6, R2
    program_mem[13] = 16'b0011101010101001; // ADD R10, R10, R9
    program_mem[14] = 16'b0011101010100011; // ADD R10, R10, R3
    program_mem[15] = 16'b0111101010100000; // LDR R10, R10
    program_mem[16] = 16'b0101101110010010; // MUL R11, R9, R2
    program_mem[17] = 16'b0011101110110111; // ADD R11, R11, R7
    program_mem[18] = 16'b0011101110110100; // ADD R11, R11, R4
    program_mem[19] = 16'b0111101110110000; // LDR R11, R11
    program_mem[20] = 16'b0101110010101011; // MUL R12, R10, R11
    program_mem[21] = 16'b0011100010001100; // ADD R8, R8, R12
    program_mem[22] = 16'b0011100110010001; // ADD R9, R9, R1
    program_mem[23] = 16'b0010000010010010; // CMP R9, R2
    program_mem[24] = 16'b0001100000001100; // BRn LOOP (back to instr 12)
    program_mem[25] = 16'b0011100101010000; // ADD R9, R5, R0
    program_mem[26] = 16'b1000000010011000; // STR R9, R8
    program_mem[27] = 16'b1111000000000000; // RET

    // Clear the rest of memory (optional but good practice)
    for (int i = 28; i < (1 << PROGRAM_MEM_ADDR_BITS); i++)
        program_mem[i] = '0;
   end
    
   //Data Memory Initialization
   int idx;
    
   initial begin
      idx = 0;
      foreach (data_mem[idx])
         data_mem[idx] = '0;            // clear everything
      
      for (int i=1; i<5; i++)
         data_mem[i-1] = i;
      
      for (int i=1; i<5; i++)
         data_mem[i+3] = i;
   end 

    byte expected,result;
    int cycles;
    //Stimulus Process
   initial begin
      //---------------------------------------------------------------
      // Reset
      //---------------------------------------------------------------
      @(posedge clk);
      reset = 1'b1;
      dcr_write_en = 0;
      start = 0;
      repeat (1) @(posedge clk);
      reset = 0;

      //---------------------------------------------------------------
      // Write thread count
      //---------------------------------------------------------------
      @(posedge clk);
      device_control_data = THREADS;
      dcr_write_en  = 1;
      @(posedge clk);
      dcr_write_en  = 0;

      //---------------------------------------------------------------
      // Pulse start
      //---------------------------------------------------------------
      @(posedge clk);
      start = 1;
      @(posedge clk);
      start = 0;

      //---------------------------------------------------------------
      // Wait for DUT to assert done, tracking cycles
      //---------------------------------------------------------------
      cycles = 0;
      while (!done) begin
         @(posedge clk);
         cycles++;
      end

      $display("Kernel completed in %0d cycles", cycles);

      //---------------------------------------------------------------
      // Check results:  C[i]=A[i]+B[i]  stored at base address 16
      //---------------------------------------------------------------
      for (int i=0; i<8; i++) begin
         expected = byte'(i+i);
         result   = data_mem[i+16];
         if (result !== expected) begin
            $error("Mismatch @ index %0d : expected %0d, got %0d", i, expected, result);
         end
      end

      $display("All results correct – simulation PASSED.");
      $finish;
      end

   gpu inst(
    .clk(clk),
    .reset(reset),
    .start(start),
    .device_control_write_enable(dcr_write_en),
    .device_control_data(device_control_data),
    .program_mem_read_ready(program_mem_read_ready),
    .program_mem_read_data(program_mem_read_data),
    .data_mem_read_ready(data_mem_read_ready),
    .data_mem_read_data(data_mem_read_data),
    .data_mem_write_ready(data_mem_write_ready),
    .done(done),
    .program_mem_read_valid(program_mem_read_valid),
    .program_mem_read_address(program_mem_read_address),
    .data_mem_read_valid(data_mem_read_valid),
    .data_mem_read_address(data_mem_read_address),
    .data_mem_write_valid(data_mem_write_valid),
    .data_mem_write_address(data_mem_write_address),
    .data_mem_write_data(data_mem_write_data)
   );
    
    
endmodule
