// Data Memory
// RAM for load/store operations with byte-enable support

import riscv_pkg::*;

module data_memory #(
    parameter MEM_SIZE = 4096  // Memory size in bytes
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Memory interface
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic                  wen,
    input  logic [3:0]            byte_en,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  ready
);

    // Memory array (byte-addressable but word-organized)
    localparam int MEM_WORDS = MEM_SIZE / 4;
    logic [31:0] mem [0:MEM_WORDS-1];

    // Word address
    logic [ADDR_WIDTH-1:0] word_addr;
    assign word_addr = addr[ADDR_WIDTH-1:2];

    // Read operation (asynchronous for simplicity)
    always_comb begin
        if (word_addr < MEM_WORDS) begin
            rdata = mem[word_addr];
        end else begin
            rdata = '0;
        end
    end

    // Write operation (synchronous with byte enables)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize memory to zero
            for (int i = 0; i < MEM_WORDS; i++) begin
                mem[i] <= '0;
            end
        end else if (wen && (word_addr < MEM_WORDS)) begin
            // Byte-enable write
            if (byte_en[0]) mem[word_addr][7:0]   <= wdata[7:0];
            if (byte_en[1]) mem[word_addr][15:8]  <= wdata[15:8];
            if (byte_en[2]) mem[word_addr][23:16] <= wdata[23:16];
            if (byte_en[3]) mem[word_addr][31:24] <= wdata[31:24];
        end
    end

    assign ready = 1'b1;  // Always ready for synchronous memory

endmodule : data_memory
