// RISC-V System-on-Chip
// Integrates CPU core with instruction and data memories

import riscv_pkg::*;

module riscv_soc #(
    parameter IMEM_SIZE = 4096,
    parameter DMEM_SIZE = 4096,
    parameter INIT_FILE = ""
) (
    input  logic clk,
    input  logic rst_n
);

    // Instruction memory interface
    logic [ADDR_WIDTH-1:0] imem_addr;
    logic [ILEN-1:0]       imem_data_0;
    logic [ILEN-1:0]       imem_data_1;
    logic                  imem_ready;

    // Data memory interface
    logic [ADDR_WIDTH-1:0] dmem_addr;
    logic [DATA_WIDTH-1:0] dmem_wdata;
    logic                  dmem_wen;
    logic [3:0]            dmem_byte_en;
    logic [DATA_WIDTH-1:0] dmem_rdata;
    logic                  dmem_ready;

    // Instantiate CPU Core
    riscv_core cpu (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_data_0(imem_data_0),
        .imem_data_1(imem_data_1),
        .imem_ready(imem_ready),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_wen(dmem_wen),
        .dmem_byte_en(dmem_byte_en),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready)
    );

    // Instantiate Instruction Memory
    instruction_memory #(
        .MEM_SIZE(IMEM_SIZE),
        .INIT_FILE(INIT_FILE)
    ) imem (
        .clk(clk),
        .rst_n(rst_n),
        .addr(imem_addr),
        .data_0(imem_data_0),
        .data_1(imem_data_1),
        .ready(imem_ready)
    );

    // Instantiate Data Memory
    data_memory #(
        .MEM_SIZE(DMEM_SIZE)
    ) dmem (
        .clk(clk),
        .rst_n(rst_n),
        .addr(dmem_addr),
        .wdata(dmem_wdata),
        .wen(dmem_wen),
        .byte_en(dmem_byte_en),
        .rdata(dmem_rdata),
        .ready(dmem_ready)
    );

endmodule : riscv_soc
