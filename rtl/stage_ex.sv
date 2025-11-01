// Execute (EX) Stage
// Performs ALU operations, branch resolution, and address calculation

import riscv_pkg::*;

module stage_ex (
    // Inputs from ID/EX register
    input  logic [PC_WIDTH-1:0]  pc,
    input  logic [XLEN-1:0]      rs1_data,
    input  logic [XLEN-1:0]      rs2_data,
    input  logic [XLEN-1:0]      imm,
    input  logic [4:0]           rs1_addr,
    input  logic [4:0]           rs2_addr,
    input  logic [4:0]           rd_addr,
    input  control_t             ctrl,
    input  logic                 valid,
    input  logic [PC_WIDTH-1:0]  pc_plus_4,
    input  logic                 predicted_taken,
    input  logic [PC_WIDTH-1:0]  predicted_target,
    input  logic [2:0]           funct3,

    // Forwarding inputs
    input  logic [XLEN-1:0]      ex_mem_alu_result,
    input  logic [XLEN-1:0]      mem_wb_wb_data,
    input  forward_e             forward_a,
    input  forward_e             forward_b,

    // Outputs to EX/MEM register
    output logic [XLEN-1:0]      alu_result,
    output logic [XLEN-1:0]      rs2_data_out,
    output logic [4:0]           rd_addr_out,
    output logic                 reg_write,
    output logic                 mem_read,
    output logic                 mem_write,
    output wb_src_e              wb_src,
    output mem_op_e              mem_op,
    output logic                 valid_out,
    output logic [PC_WIDTH-1:0]  pc_plus_4_out,

    // Branch resolution outputs
    output logic                 branch_taken,
    output logic [PC_WIDTH-1:0]  branch_target,
    output logic                 branch_mispredicted,

    // Branch predictor update
    output logic                 bpu_update_en,
    output logic [PC_WIDTH-1:0]  bpu_update_pc,
    output logic                 bpu_actual_taken,
    output logic [PC_WIDTH-1:0]  bpu_actual_target
);

    // Forwarded operands
    logic [XLEN-1:0] operand_a;
    logic [XLEN-1:0] operand_b;
    logic [XLEN-1:0] operand_b_forwarded;

    // ALU inputs
    logic [XLEN-1:0] alu_src_a;
    logic [XLEN-1:0] alu_src_b;

    // ALU outputs
    logic [XLEN-1:0] alu_out;
    logic            alu_zero;
    logic            alu_negative;
    logic            alu_carry;
    logic            alu_overflow;

    // Apply forwarding for operand A
    always_comb begin
        case (forward_a)
            FWD_EX_MEM: operand_a = ex_mem_alu_result;
            FWD_MEM_WB: operand_a = mem_wb_wb_data;
            default:    operand_a = rs1_data;
        endcase
    end

    // Apply forwarding for operand B
    always_comb begin
        case (forward_b)
            FWD_EX_MEM: operand_b_forwarded = ex_mem_alu_result;
            FWD_MEM_WB: operand_b_forwarded = mem_wb_wb_data;
            default:    operand_b_forwarded = rs2_data;
        endcase
    end

    // Always forward operand_b for stores (used in MEM stage)
    assign operand_b = operand_b_forwarded;

    // Select ALU source A
    always_comb begin
        case (ctrl.alu_src_a)
            ALU_SRC_REG: alu_src_a = operand_a;
            ALU_SRC_PC:  alu_src_a = pc;
            ALU_SRC_IMM: alu_src_a = imm;
            default:     alu_src_a = operand_a;
        endcase
    end

    // Select ALU source B
    always_comb begin
        case (ctrl.alu_src_b)
            ALU_SRC_REG: alu_src_b = operand_b;
            ALU_SRC_IMM: alu_src_b = imm;
            ALU_SRC_PC:  alu_src_b = pc;
            default:     alu_src_b = operand_b;
        endcase
    end

    // Instantiate ALU
    alu alu_inst (
        .operand_a(alu_src_a),
        .operand_b(alu_src_b),
        .alu_op(ctrl.alu_op),
        .result(alu_out),
        .zero(alu_zero),
        .negative(alu_negative),
        .carry(alu_carry),
        .overflow(alu_overflow)
    );

    // Branch resolution
    logic branch_condition_met;

    always_comb begin
        branch_condition_met = 1'b0;

        if (ctrl.branch) begin
            case (funct3)
                FUNCT3_BEQ:  branch_condition_met = alu_zero;              // BEQ
                FUNCT3_BNE:  branch_condition_met = !alu_zero;             // BNE
                FUNCT3_BLT:  branch_condition_met = (alu_out == 32'd1);   // BLT (SLT result)
                FUNCT3_BGE:  branch_condition_met = (alu_out == 32'd0);   // BGE
                FUNCT3_BLTU: branch_condition_met = (alu_out == 32'd1);   // BLTU (SLTU result)
                FUNCT3_BGEU: branch_condition_met = (alu_out == 32'd0);   // BGEU
                default:     branch_condition_met = 1'b0;
            endcase
        end
    end

    // Calculate branch/jump target
    logic [PC_WIDTH-1:0] calculated_target;

    always_comb begin
        if (ctrl.jalr) begin
            // JALR: target = (rs1 + imm) & ~1
            calculated_target = (operand_a + imm) & ~32'h1;
        end else if (ctrl.jump || ctrl.branch) begin
            // JAL and Branch: target = PC + imm
            calculated_target = pc + imm;
        end else begin
            calculated_target = pc_plus_4;
        end
    end

    // Determine if branch is actually taken
    assign branch_taken = valid && ((ctrl.branch && branch_condition_met) ||
                                    ctrl.jump || ctrl.jalr);
    assign branch_target = calculated_target;

    // Branch misprediction detection
    assign branch_mispredicted = valid && ctrl.branch &&
                                (branch_condition_met != predicted_taken ||
                                (branch_condition_met && calculated_target != predicted_target));

    // Branch predictor update
    assign bpu_update_en     = valid && ctrl.branch;
    assign bpu_update_pc     = pc;
    assign bpu_actual_taken  = branch_condition_met;
    assign bpu_actual_target = calculated_target;

    // Outputs to EX/MEM register
    assign alu_result    = alu_out;
    assign rs2_data_out  = operand_b;  // Forwarded value for stores
    assign rd_addr_out   = rd_addr;
    assign reg_write     = ctrl.reg_write;
    assign mem_read      = ctrl.mem_read;
    assign mem_write     = ctrl.mem_write;
    assign wb_src        = ctrl.wb_src;
    assign mem_op        = ctrl.mem_op;
    assign valid_out     = valid;
    assign pc_plus_4_out = pc_plus_4;

endmodule : stage_ex
