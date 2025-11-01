// Instruction Decode (ID) Stage
// Decodes instructions, reads registers, and determines dual-issue capability

import riscv_pkg::*;

module stage_id (
    input  logic                 clk,
    input  logic                 rst_n,

    // Input from IF/ID register
    input  logic [PC_WIDTH-1:0]  pc_0,
    input  logic [PC_WIDTH-1:0]  pc_1,
    input  logic [ILEN-1:0]      instruction_0,
    input  logic [ILEN-1:0]      instruction_1,
    input  logic                 valid_0,
    input  logic                 valid_1,
    input  logic [PC_WIDTH-1:0]  pc_plus_4_0,
    input  logic [PC_WIDTH-1:0]  pc_plus_4_1,
    input  logic                 predicted_taken,
    input  logic [PC_WIDTH-1:0]  predicted_target,

    // Register file read ports
    output logic [4:0]           rf_rs1_addr_0,
    output logic [4:0]           rf_rs2_addr_0,
    input  logic [XLEN-1:0]      rf_rs1_data_0,
    input  logic [XLEN-1:0]      rf_rs2_data_0,

    output logic [4:0]           rf_rs1_addr_1,
    output logic [4:0]           rf_rs2_addr_1,
    input  logic [XLEN-1:0]      rf_rs1_data_1,
    input  logic [XLEN-1:0]      rf_rs2_data_1,

    // Hazard detection inputs
    input  logic                 dual_issue_conflict,

    // Outputs to ID/EX register (Instruction 0)
    output logic [PC_WIDTH-1:0]  id_ex_pc_0,
    output logic [XLEN-1:0]      id_ex_rs1_data_0,
    output logic [XLEN-1:0]      id_ex_rs2_data_0,
    output logic [XLEN-1:0]      id_ex_imm_0,
    output logic [4:0]           id_ex_rs1_addr_0,
    output logic [4:0]           id_ex_rs2_addr_0,
    output logic [4:0]           id_ex_rd_addr_0,
    output control_t             id_ex_ctrl_0,
    output logic                 id_ex_valid_0,
    output logic [PC_WIDTH-1:0]  id_ex_pc_plus_4_0,
    output logic                 id_ex_predicted_taken_0,
    output logic [PC_WIDTH-1:0]  id_ex_predicted_target_0,
    output logic [2:0]           id_ex_funct3_0,

    // Outputs to ID/EX register (Instruction 1)
    output logic [PC_WIDTH-1:0]  id_ex_pc_1,
    output logic [XLEN-1:0]      id_ex_rs1_data_1,
    output logic [XLEN-1:0]      id_ex_rs2_data_1,
    output logic [XLEN-1:0]      id_ex_imm_1,
    output logic [4:0]           id_ex_rs1_addr_1,
    output logic [4:0]           id_ex_rs2_addr_1,
    output logic [4:0]           id_ex_rd_addr_1,
    output control_t             id_ex_ctrl_1,
    output logic                 id_ex_valid_1,
    output logic [PC_WIDTH-1:0]  id_ex_pc_plus_4_1,
    output logic [2:0]           id_ex_funct3_1
);

    // Decoder outputs for instruction 0
    logic [XLEN-1:0] imm_0;
    control_t        ctrl_0;
    logic [6:0]      opcode_0;
    logic [2:0]      funct3_0;
    logic [6:0]      funct7_0;
    logic            inst_valid_0;

    // Decoder outputs for instruction 1
    logic [XLEN-1:0] imm_1;
    control_t        ctrl_1;
    logic [6:0]      opcode_1;
    logic [2:0]      funct3_1;
    logic [6:0]      funct7_1;
    logic            inst_valid_1;

    // Dual-issue logic
    logic can_dual_issue;

    // Instantiate decoders
    decoder decoder_0 (
        .instruction(instruction_0),
        .rs1_addr(rf_rs1_addr_0),
        .rs2_addr(rf_rs2_addr_0),
        .rd_addr(id_ex_rd_addr_0),
        .imm(imm_0),
        .ctrl(ctrl_0),
        .opcode(opcode_0),
        .funct3(funct3_0),
        .funct7(funct7_0),
        .valid(inst_valid_0)
    );

    decoder decoder_1 (
        .instruction(instruction_1),
        .rs1_addr(rf_rs1_addr_1),
        .rs2_addr(rf_rs2_addr_1),
        .rd_addr(id_ex_rd_addr_1),
        .imm(imm_1),
        .ctrl(ctrl_1),
        .opcode(opcode_1),
        .funct3(funct3_1),
        .funct7(funct7_1),
        .valid(inst_valid_1)
    );

    // Dual-issue decision logic
    // Can issue both instructions if:
    // 1. Both instructions are valid
    // 2. No RAW dependency between them (checked by hazard detection)
    // 3. Not both memory operations (structural hazard)
    // 4. Not branches/jumps in the second instruction
    always_comb begin
        can_dual_issue = 1'b0;

        if (valid_0 && valid_1 && inst_valid_0 && inst_valid_1) begin
            // Check for structural hazards
            logic both_mem_ops = (ctrl_0.mem_read || ctrl_0.mem_write) &&
                                (ctrl_1.mem_read || ctrl_1.mem_write);

            logic has_branch_jump = ctrl_0.branch || ctrl_0.jump || ctrl_0.jalr ||
                                   ctrl_1.branch || ctrl_1.jump || ctrl_1.jalr;

            if (!both_mem_ops && !has_branch_jump && !dual_issue_conflict) begin
                can_dual_issue = 1'b1;
            end
        end
    end

    // Assign outputs for instruction 0
    assign id_ex_pc_0              = pc_0;
    assign id_ex_rs1_data_0        = rf_rs1_data_0;
    assign id_ex_rs2_data_0        = rf_rs2_data_0;
    assign id_ex_imm_0             = imm_0;
    assign id_ex_rs1_addr_0        = rf_rs1_addr_0;
    assign id_ex_rs2_addr_0        = rf_rs2_addr_0;
    assign id_ex_ctrl_0            = ctrl_0;
    assign id_ex_valid_0           = valid_0 && inst_valid_0;
    assign id_ex_pc_plus_4_0       = pc_plus_4_0;
    assign id_ex_predicted_taken_0 = predicted_taken;
    assign id_ex_predicted_target_0= predicted_target;
    assign id_ex_funct3_0          = funct3_0;

    // Assign outputs for instruction 1 (only valid if can dual issue)
    assign id_ex_pc_1              = pc_1;
    assign id_ex_rs1_data_1        = rf_rs1_data_1;
    assign id_ex_rs2_data_1        = rf_rs2_data_1;
    assign id_ex_imm_1             = imm_1;
    assign id_ex_rs1_addr_1        = rf_rs1_addr_1;
    assign id_ex_rs2_addr_1        = rf_rs2_addr_1;
    assign id_ex_ctrl_1            = ctrl_1;
    assign id_ex_valid_1           = can_dual_issue && inst_valid_1;
    assign id_ex_pc_plus_4_1       = pc_plus_4_1;
    assign id_ex_funct3_1          = funct3_1;

endmodule : stage_id
