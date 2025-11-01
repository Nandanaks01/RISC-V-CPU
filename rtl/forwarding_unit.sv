// Forwarding Unit
// Detects RAW dependencies and generates forwarding control signals

import riscv_pkg::*;

module forwarding_unit (
    // ID/EX stage operands
    input  logic [4:0]    id_ex_rs1,
    input  logic [4:0]    id_ex_rs2,
    input  logic          id_ex_valid,

    // EX/MEM stage
    input  logic [4:0]    ex_mem_rd,
    input  logic          ex_mem_reg_write,
    input  logic          ex_mem_valid,

    // MEM/WB stage
    input  logic [4:0]    mem_wb_rd,
    input  logic          mem_wb_reg_write,
    input  logic          mem_wb_valid,

    // Forwarding control outputs
    output forward_e      forward_a,
    output forward_e      forward_b
);

    // Forward for operand A (RS1)
    always_comb begin
        forward_a = FWD_NONE;

        // Forward from EX/MEM stage (highest priority)
        if (ex_mem_reg_write && ex_mem_valid &&
            (ex_mem_rd != 5'b0) &&
            (ex_mem_rd == id_ex_rs1)) begin
            forward_a = FWD_EX_MEM;
        end
        // Forward from MEM/WB stage
        else if (mem_wb_reg_write && mem_wb_valid &&
                 (mem_wb_rd != 5'b0) &&
                 (mem_wb_rd == id_ex_rs1)) begin
            forward_a = FWD_MEM_WB;
        end
    end

    // Forward for operand B (RS2)
    always_comb begin
        forward_b = FWD_NONE;

        // Forward from EX/MEM stage (highest priority)
        if (ex_mem_reg_write && ex_mem_valid &&
            (ex_mem_rd != 5'b0) &&
            (ex_mem_rd == id_ex_rs2)) begin
            forward_b = FWD_EX_MEM;
        end
        // Forward from MEM/WB stage
        else if (mem_wb_reg_write && mem_wb_valid &&
                 (mem_wb_rd != 5'b0) &&
                 (mem_wb_rd == id_ex_rs2)) begin
            forward_b = FWD_MEM_WB;
        end
    end

endmodule : forwarding_unit
