// Dual-Port Register File
// 32 registers x 32-bit with 4 read ports and 2 write ports for dual-issue

import riscv_pkg::*;

module register_file (
    input  logic                 clk,
    input  logic                 rst_n,

    // Read port 0 (Instruction 0)
    input  logic [4:0]           rs1_addr_0,
    input  logic [4:0]           rs2_addr_0,
    output logic [XLEN-1:0]      rs1_data_0,
    output logic [XLEN-1:0]      rs2_data_0,

    // Read port 1 (Instruction 1)
    input  logic [4:0]           rs1_addr_1,
    input  logic [4:0]           rs2_addr_1,
    output logic [XLEN-1:0]      rs1_data_1,
    output logic [XLEN-1:0]      rs2_data_1,

    // Write port 0
    input  logic                 wr_en_0,
    input  logic [4:0]           rd_addr_0,
    input  logic [XLEN-1:0]      rd_data_0,

    // Write port 1
    input  logic                 wr_en_1,
    input  logic [4:0]           rd_addr_1,
    input  logic [XLEN-1:0]      rd_data_1
);

    // Register file storage
    logic [XLEN-1:0] registers [0:NUM_REGS-1];

    // Read operations (combinational)
    // x0 is always 0 in RISC-V
    assign rs1_data_0 = (rs1_addr_0 == 5'b0) ? '0 : registers[rs1_addr_0];
    assign rs2_data_0 = (rs2_addr_0 == 5'b0) ? '0 : registers[rs2_addr_0];
    assign rs1_data_1 = (rs1_addr_1 == 5'b0) ? '0 : registers[rs1_addr_1];
    assign rs2_data_1 = (rs2_addr_1 == 5'b0) ? '0 : registers[rs2_addr_1];

    // Write operations (sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers to 0
            for (int i = 0; i < NUM_REGS; i++) begin
                registers[i] <= '0;
            end
        end else begin
            // Write port 0 (x0 is hardwired to 0, cannot be written)
            if (wr_en_0 && rd_addr_0 != 5'b0) begin
                registers[rd_addr_0] <= rd_data_0;
            end

            // Write port 1 (check for conflicts with port 0)
            if (wr_en_1 && rd_addr_1 != 5'b0) begin
                // If both ports write to the same register, port 0 takes priority
                if (!(wr_en_0 && rd_addr_0 == rd_addr_1)) begin
                    registers[rd_addr_1] <= rd_data_1;
                end
            end
        end
    end

    // Synthesis attributes for FPGA optimization
    // synthesis attribute ram_style of registers is "distributed"

endmodule : register_file
