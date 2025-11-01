// RISC-V CPU Package
// Contains common definitions, types, and parameters

package riscv_pkg;

    // Data width parameters
    parameter int XLEN = 32;              // Register width
    parameter int ILEN = 32;              // Instruction width
    parameter int NUM_REGS = 32;          // Number of registers
    parameter int PC_WIDTH = 32;          // Program counter width
    parameter int ADDR_WIDTH = 32;        // Address width
    parameter int DATA_WIDTH = 32;        // Data width

    // Branch prediction parameters
    parameter int BPU_ENTRIES = 256;      // Number of BPU entries
    parameter int BPU_INDEX_BITS = 8;     // Index bits for BPU

    // Opcode definitions (RISC-V RV32I)
    typedef enum logic [6:0] {
        OP_LUI    = 7'b0110111,  // Load Upper Immediate
        OP_AUIPC  = 7'b0010111,  // Add Upper Immediate to PC
        OP_JAL    = 7'b1101111,  // Jump and Link
        OP_JALR   = 7'b1100111,  // Jump and Link Register
        OP_BRANCH = 7'b1100011,  // Branch operations
        OP_LOAD   = 7'b0000011,  // Load operations
        OP_STORE  = 7'b0100011,  // Store operations
        OP_ALUI   = 7'b0010011,  // ALU immediate operations
        OP_ALU    = 7'b0110011,  // ALU register operations
        OP_FENCE  = 7'b0001111,  // Fence operations
        OP_SYSTEM = 7'b1110011   // System operations
    } opcode_e;

    // Funct3 for branch instructions
    typedef enum logic [2:0] {
        FUNCT3_BEQ  = 3'b000,
        FUNCT3_BNE  = 3'b001,
        FUNCT3_BLT  = 3'b100,
        FUNCT3_BGE  = 3'b101,
        FUNCT3_BLTU = 3'b110,
        FUNCT3_BGEU = 3'b111
    } branch_funct3_e;

    // Funct3 for load instructions
    typedef enum logic [2:0] {
        FUNCT3_LB  = 3'b000,
        FUNCT3_LH  = 3'b001,
        FUNCT3_LW  = 3'b010,
        FUNCT3_LBU = 3'b100,
        FUNCT3_LHU = 3'b101
    } load_funct3_e;

    // Funct3 for store instructions
    typedef enum logic [2:0] {
        FUNCT3_SB = 3'b000,
        FUNCT3_SH = 3'b001,
        FUNCT3_SW = 3'b010
    } store_funct3_e;

    // ALU operations
    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_SLL  = 4'b0010,
        ALU_SLT  = 4'b0011,
        ALU_SLTU = 4'b0100,
        ALU_XOR  = 4'b0101,
        ALU_SRL  = 4'b0110,
        ALU_SRA  = 4'b0111,
        ALU_OR   = 4'b1000,
        ALU_AND  = 4'b1001,
        ALU_COPY = 4'b1010   // Pass through operand A
    } alu_op_e;

    // ALU source selection
    typedef enum logic [1:0] {
        ALU_SRC_REG = 2'b00,
        ALU_SRC_IMM = 2'b01,
        ALU_SRC_PC  = 2'b10
    } alu_src_e;

    // PC source selection
    typedef enum logic [1:0] {
        PC_SRC_NEXT   = 2'b00,  // PC + 4 or PC + 8 (dual issue)
        PC_SRC_BRANCH = 2'b01,  // Branch target
        PC_SRC_JUMP   = 2'b10,  // Jump target
        PC_SRC_JALR   = 2'b11   // JALR target
    } pc_src_e;

    // Write-back source selection
    typedef enum logic [1:0] {
        WB_SRC_ALU = 2'b00,
        WB_SRC_MEM = 2'b01,
        WB_SRC_PC4 = 2'b10
    } wb_src_e;

    // Memory operation type
    typedef enum logic [2:0] {
        MEM_NOP   = 3'b000,
        MEM_BYTE  = 3'b001,
        MEM_HALF  = 3'b010,
        MEM_WORD  = 3'b011,
        MEM_BYTEU = 3'b101,
        MEM_HALFU = 3'b110
    } mem_op_e;

    // Control signals structure
    typedef struct packed {
        logic        reg_write;      // Register write enable
        logic        mem_read;       // Memory read enable
        logic        mem_write;      // Memory write enable
        logic        branch;         // Branch instruction
        logic        jump;           // Jump instruction
        logic        jalr;           // JALR instruction
        alu_op_e     alu_op;         // ALU operation
        alu_src_e    alu_src_a;      // ALU source A select
        alu_src_e    alu_src_b;      // ALU source B select
        wb_src_e     wb_src;         // Write-back source select
        mem_op_e     mem_op;         // Memory operation type
        logic        is_unsigned;    // Unsigned operation
    } control_t;

    // IF/ID Pipeline Register
    typedef struct packed {
        logic [PC_WIDTH-1:0]   pc;
        logic [ILEN-1:0]       instruction;
        logic                  valid;
        logic [PC_WIDTH-1:0]   pc_plus_4;
        logic                  predicted_taken;
        logic [PC_WIDTH-1:0]   predicted_target;
    } if_id_reg_t;

    // ID/EX Pipeline Register
    typedef struct packed {
        logic [PC_WIDTH-1:0]   pc;
        logic [XLEN-1:0]       rs1_data;
        logic [XLEN-1:0]       rs2_data;
        logic [XLEN-1:0]       imm;
        logic [4:0]            rs1_addr;
        logic [4:0]            rs2_addr;
        logic [4:0]            rd_addr;
        control_t              ctrl;
        logic                  valid;
        logic [PC_WIDTH-1:0]   pc_plus_4;
        logic                  predicted_taken;
        logic [PC_WIDTH-1:0]   predicted_target;
        logic [2:0]            funct3;
    } id_ex_reg_t;

    // EX/MEM Pipeline Register
    typedef struct packed {
        logic [XLEN-1:0]       alu_result;
        logic [XLEN-1:0]       rs2_data;
        logic [4:0]            rd_addr;
        logic                  reg_write;
        logic                  mem_read;
        logic                  mem_write;
        wb_src_e               wb_src;
        mem_op_e               mem_op;
        logic                  valid;
        logic [PC_WIDTH-1:0]   pc_plus_4;
        logic                  branch_taken;
        logic [PC_WIDTH-1:0]   branch_target;
    } ex_mem_reg_t;

    // MEM/WB Pipeline Register
    typedef struct packed {
        logic [XLEN-1:0]       alu_result;
        logic [XLEN-1:0]       mem_data;
        logic [4:0]            rd_addr;
        logic                  reg_write;
        wb_src_e               wb_src;
        logic                  valid;
        logic [PC_WIDTH-1:0]   pc_plus_4;
    } mem_wb_reg_t;

    // Dual-issue instruction pair
    typedef struct packed {
        logic [ILEN-1:0]  inst0;
        logic [ILEN-1:0]  inst1;
        logic             issue_dual;  // Can issue both instructions
        logic             valid0;
        logic             valid1;
    } dual_issue_t;

    // Branch prediction table entry
    typedef struct packed {
        logic [1:0]           counter;     // 2-bit saturating counter
        logic [PC_WIDTH-1:0]  target;      // Branch target address
        logic                 valid;       // Entry is valid
    } bpu_entry_t;

    // Forwarding control
    typedef enum logic [1:0] {
        FWD_NONE   = 2'b00,
        FWD_EX_MEM = 2'b01,
        FWD_MEM_WB = 2'b10
    } forward_e;

endpackage : riscv_pkg
