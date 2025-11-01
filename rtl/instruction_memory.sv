// Instruction Memory
// Dual-port ROM for instruction fetch (supports dual-issue)

import riscv_pkg::*;

module instruction_memory #(
    parameter MEM_SIZE = 4096,  // Memory size in bytes
    parameter INIT_FILE = ""    // Optional initialization file
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Read port for dual instructions
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [ILEN-1:0]       data_0,      // Instruction at addr
    output logic [ILEN-1:0]       data_1,      // Instruction at addr+4
    output logic                  ready
);

    // Memory array (word-addressed for efficiency)
    localparam int MEM_WORDS = MEM_SIZE / 4;
    logic [31:0] mem [0:MEM_WORDS-1];

    // Word address calculation
    logic [ADDR_WIDTH-1:0] word_addr;
    assign word_addr = addr[ADDR_WIDTH-1:2];  // Byte to word address

    // Read operations
    always_comb begin
        if (word_addr < MEM_WORDS) begin
            data_0 = mem[word_addr];
        end else begin
            data_0 = 32'h00000013;  // NOP (addi x0, x0, 0)
        end

        if ((word_addr + 1) < MEM_WORDS) begin
            data_1 = mem[word_addr + 1];
        end else begin
            data_1 = 32'h00000013;  // NOP
        end
    end

    assign ready = 1'b1;  // Always ready for synchronous memory

    // Memory initialization
    initial begin
        // Initialize to NOPs
        for (int i = 0; i < MEM_WORDS; i++) begin
            mem[i] = 32'h00000013;  // NOP (addi x0, x0, 0)
        end

        // Load program from file if specified
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

endmodule : instruction_memory
