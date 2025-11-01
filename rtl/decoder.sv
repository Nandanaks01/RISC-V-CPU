// Instruction Decoder and Control Unit
// Decodes RV32I instructions and generates control signals

import riscv_pkg::*;

module decoder (
    input  logic [ILEN-1:0]    instruction,
    output logic [4:0]         rs1_addr,
    output logic [4:0]         rs2_addr,
    output logic [4:0]         rd_addr,
    output logic [XLEN-1:0]    imm,
    output control_t           ctrl,
    output logic [6:0]         opcode,
    output logic [2:0]         funct3,
    output logic [6:0]         funct7,
    output logic               valid
);

    // Instruction fields
    assign opcode   = instruction[6:0];
    assign rd_addr  = instruction[11:7];
    assign funct3   = instruction[14:12];
    assign rs1_addr = instruction[19:15];
    assign rs2_addr = instruction[24:20];
    assign funct7   = instruction[31:25];

    // Immediate generation
    logic [XLEN-1:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    // I-type immediate (sign-extended)
    assign imm_i = {{20{instruction[31]}}, instruction[31:20]};

    // S-type immediate (sign-extended)
    assign imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

    // B-type immediate (sign-extended)
    assign imm_b = {{19{instruction[31]}}, instruction[31], instruction[7],
                    instruction[30:25], instruction[11:8], 1'b0};

    // U-type immediate
    assign imm_u = {instruction[31:12], 12'b0};

    // J-type immediate (sign-extended)
    assign imm_j = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                    instruction[20], instruction[30:21], 1'b0};

    // Control signal generation
    always_comb begin
        // Default values
        ctrl.reg_write   = 1'b0;
        ctrl.mem_read    = 1'b0;
        ctrl.mem_write   = 1'b0;
        ctrl.branch      = 1'b0;
        ctrl.jump        = 1'b0;
        ctrl.jalr        = 1'b0;
        ctrl.alu_op      = ALU_ADD;
        ctrl.alu_src_a   = ALU_SRC_REG;
        ctrl.alu_src_b   = ALU_SRC_REG;
        ctrl.wb_src      = WB_SRC_ALU;
        ctrl.mem_op      = MEM_NOP;
        ctrl.is_unsigned = 1'b0;
        imm              = '0;
        valid            = 1'b1;

        case (opcode)
            OP_LUI: begin
                // LUI: Load Upper Immediate
                ctrl.reg_write = 1'b1;
                ctrl.alu_op    = ALU_COPY;
                ctrl.alu_src_a = ALU_SRC_IMM;
                ctrl.wb_src    = WB_SRC_ALU;
                imm            = imm_u;
            end

            OP_AUIPC: begin
                // AUIPC: Add Upper Immediate to PC
                ctrl.reg_write = 1'b1;
                ctrl.alu_op    = ALU_ADD;
                ctrl.alu_src_a = ALU_SRC_PC;
                ctrl.alu_src_b = ALU_SRC_IMM;
                ctrl.wb_src    = WB_SRC_ALU;
                imm            = imm_u;
            end

            OP_JAL: begin
                // JAL: Jump and Link
                ctrl.reg_write = 1'b1;
                ctrl.jump      = 1'b1;
                ctrl.wb_src    = WB_SRC_PC4;
                imm            = imm_j;
            end

            OP_JALR: begin
                // JALR: Jump and Link Register
                ctrl.reg_write = 1'b1;
                ctrl.jalr      = 1'b1;
                ctrl.wb_src    = WB_SRC_PC4;
                ctrl.alu_op    = ALU_ADD;
                ctrl.alu_src_a = ALU_SRC_REG;
                ctrl.alu_src_b = ALU_SRC_IMM;
                imm            = imm_i;
            end

            OP_BRANCH: begin
                // Branch operations
                ctrl.branch    = 1'b1;
                ctrl.alu_src_a = ALU_SRC_REG;
                ctrl.alu_src_b = ALU_SRC_REG;
                imm            = imm_b;

                case (funct3)
                    FUNCT3_BEQ:  ctrl.alu_op = ALU_SUB;  // BEQ
                    FUNCT3_BNE:  ctrl.alu_op = ALU_SUB;  // BNE
                    FUNCT3_BLT:  ctrl.alu_op = ALU_SLT;  // BLT
                    FUNCT3_BGE:  ctrl.alu_op = ALU_SLT;  // BGE
                    FUNCT3_BLTU: ctrl.alu_op = ALU_SLTU; // BLTU
                    FUNCT3_BGEU: ctrl.alu_op = ALU_SLTU; // BGEU
                    default:     valid = 1'b0;
                endcase
            end

            OP_LOAD: begin
                // Load operations
                ctrl.reg_write = 1'b1;
                ctrl.mem_read  = 1'b1;
                ctrl.alu_op    = ALU_ADD;
                ctrl.alu_src_a = ALU_SRC_REG;
                ctrl.alu_src_b = ALU_SRC_IMM;
                ctrl.wb_src    = WB_SRC_MEM;
                imm            = imm_i;

                case (funct3)
                    FUNCT3_LB: begin
                        ctrl.mem_op      = MEM_BYTE;
                        ctrl.is_unsigned = 1'b0;
                    end
                    FUNCT3_LH: begin
                        ctrl.mem_op      = MEM_HALF;
                        ctrl.is_unsigned = 1'b0;
                    end
                    FUNCT3_LW: begin
                        ctrl.mem_op      = MEM_WORD;
                        ctrl.is_unsigned = 1'b0;
                    end
                    FUNCT3_LBU: begin
                        ctrl.mem_op      = MEM_BYTEU;
                        ctrl.is_unsigned = 1'b1;
                    end
                    FUNCT3_LHU: begin
                        ctrl.mem_op      = MEM_HALFU;
                        ctrl.is_unsigned = 1'b1;
                    end
                    default: valid = 1'b0;
                endcase
            end

            OP_STORE: begin
                // Store operations
                ctrl.mem_write = 1'b1;
                ctrl.alu_op    = ALU_ADD;
                ctrl.alu_src_a = ALU_SRC_REG;
                ctrl.alu_src_b = ALU_SRC_IMM;
                imm            = imm_s;

                case (funct3)
                    FUNCT3_SB: ctrl.mem_op = MEM_BYTE;
                    FUNCT3_SH: ctrl.mem_op = MEM_HALF;
                    FUNCT3_SW: ctrl.mem_op = MEM_WORD;
                    default:   valid = 1'b0;
                endcase
            end

            OP_ALUI: begin
                // ALU immediate operations
                ctrl.reg_write = 1'b1;
                ctrl.alu_src_a = ALU_SRC_REG;
                ctrl.alu_src_b = ALU_SRC_IMM;
                ctrl.wb_src    = WB_SRC_ALU;
                imm            = imm_i;

                case (funct3)
                    3'b000: ctrl.alu_op = ALU_ADD;  // ADDI
                    3'b010: ctrl.alu_op = ALU_SLT;  // SLTI
                    3'b011: ctrl.alu_op = ALU_SLTU; // SLTIU
                    3'b100: ctrl.alu_op = ALU_XOR;  // XORI
                    3'b110: ctrl.alu_op = ALU_OR;   // ORI
                    3'b111: ctrl.alu_op = ALU_AND;  // ANDI
                    3'b001: ctrl.alu_op = ALU_SLL;  // SLLI
                    3'b101: begin
                        if (funct7[5] == 1'b0)
                            ctrl.alu_op = ALU_SRL;  // SRLI
                        else
                            ctrl.alu_op = ALU_SRA;  // SRAI
                    end
                    default: valid = 1'b0;
                endcase
            end

            OP_ALU: begin
                // ALU register operations
                ctrl.reg_write = 1'b1;
                ctrl.alu_src_a = ALU_SRC_REG;
                ctrl.alu_src_b = ALU_SRC_REG;
                ctrl.wb_src    = WB_SRC_ALU;

                case (funct3)
                    3'b000: begin
                        if (funct7[5] == 1'b0)
                            ctrl.alu_op = ALU_ADD;  // ADD
                        else
                            ctrl.alu_op = ALU_SUB;  // SUB
                    end
                    3'b001: ctrl.alu_op = ALU_SLL;  // SLL
                    3'b010: ctrl.alu_op = ALU_SLT;  // SLT
                    3'b011: ctrl.alu_op = ALU_SLTU; // SLTU
                    3'b100: ctrl.alu_op = ALU_XOR;  // XOR
                    3'b101: begin
                        if (funct7[5] == 1'b0)
                            ctrl.alu_op = ALU_SRL;  // SRL
                        else
                            ctrl.alu_op = ALU_SRA;  // SRA
                    end
                    3'b110: ctrl.alu_op = ALU_OR;   // OR
                    3'b111: ctrl.alu_op = ALU_AND;  // AND
                    default: valid = 1'b0;
                endcase
            end

            OP_FENCE: begin
                // FENCE: treated as NOP for now
                valid = 1'b1;
            end

            OP_SYSTEM: begin
                // SYSTEM: ECALL, EBREAK treated as NOP for now
                valid = 1'b1;
            end

            default: begin
                valid = 1'b0;
            end
        endcase
    end

endmodule : decoder
