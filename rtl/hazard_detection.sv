// Hazard Detection Unit
// Detects load-use hazards and structural hazards for dual-issue

import riscv_pkg::*;

module hazard_detection (
    // IF/ID stage
    input  logic [4:0]    if_id_rs1_0,
    input  logic [4:0]    if_id_rs2_0,
    input  logic [4:0]    if_id_rs1_1,
    input  logic [4:0]    if_id_rs2_1,
    input  logic          if_id_valid_0,
    input  logic          if_id_valid_1,

    // ID/EX stage
    input  logic [4:0]    id_ex_rd,
    input  logic          id_ex_mem_read,
    input  logic          id_ex_valid,

    // Dual-issue conflict detection
    input  logic [4:0]    inst0_rd,
    input  logic [4:0]    inst1_rs1,
    input  logic [4:0]    inst1_rs2,
    input  logic          inst0_reg_write,
    input  logic          inst1_valid,

    // Control outputs
    output logic          stall,
    output logic          flush_if_id,
    output logic          dual_issue_conflict
);

    logic load_use_hazard_0;
    logic load_use_hazard_1;
    logic structural_hazard;

    // Detect load-use hazard for instruction 0
    always_comb begin
        load_use_hazard_0 = 1'b0;

        if (id_ex_mem_read && id_ex_valid && if_id_valid_0) begin
            if ((id_ex_rd != 5'b0) &&
                ((id_ex_rd == if_id_rs1_0) || (id_ex_rd == if_id_rs2_0))) begin
                load_use_hazard_0 = 1'b1;
            end
        end
    end

    // Detect load-use hazard for instruction 1 (dual-issue)
    always_comb begin
        load_use_hazard_1 = 1'b0;

        if (id_ex_mem_read && id_ex_valid && if_id_valid_1) begin
            if ((id_ex_rd != 5'b0) &&
                ((id_ex_rd == if_id_rs1_1) || (id_ex_rd == if_id_rs2_1))) begin
                load_use_hazard_1 = 1'b1;
            end
        end
    end

    // Detect RAW dependency between dual-issued instructions
    // If instruction 0 writes to a register that instruction 1 reads,
    // we cannot issue both in the same cycle
    always_comb begin
        dual_issue_conflict = 1'b0;

        if (if_id_valid_0 && if_id_valid_1 && inst0_reg_write) begin
            if ((inst0_rd != 5'b0) &&
                ((inst0_rd == inst1_rs1) || (inst0_rd == inst1_rs2))) begin
                dual_issue_conflict = 1'b1;
            end
        end
    end

    // Stall signal generation
    always_comb begin
        stall = load_use_hazard_0 || load_use_hazard_1;
        flush_if_id = stall;  // Insert bubble in IF/ID on stall
    end

endmodule : hazard_detection
