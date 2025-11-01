// Instruction Fetch (IF) Stage
// Fetches instructions from memory and manages PC

import riscv_pkg::*;

module stage_if (
    input  logic                 clk,
    input  logic                 rst_n,

    // Control signals
    input  logic                 stall,
    input  logic                 branch_taken,
    input  logic [PC_WIDTH-1:0]  branch_target,

    // Instruction memory interface
    output logic [PC_WIDTH-1:0]  imem_addr,
    input  logic [ILEN-1:0]      imem_data_0,
    input  logic [ILEN-1:0]      imem_data_1,
    input  logic                 imem_ready,

    // Branch predictor interface
    output logic [PC_WIDTH-1:0]  bpu_pc,
    output logic                 bpu_is_branch,
    input  logic                 bpu_predict_taken,
    input  logic [PC_WIDTH-1:0]  bpu_predict_target,

    // Output to IF/ID register
    output logic [PC_WIDTH-1:0]  pc_out_0,
    output logic [PC_WIDTH-1:0]  pc_out_1,
    output logic [ILEN-1:0]      instruction_0,
    output logic [ILEN-1:0]      instruction_1,
    output logic                 valid_0,
    output logic                 valid_1,
    output logic [PC_WIDTH-1:0]  pc_plus_4_0,
    output logic [PC_WIDTH-1:0]  pc_plus_4_1,
    output logic                 predicted_taken,
    output logic [PC_WIDTH-1:0]  predicted_target
);

    // Program counter
    logic [PC_WIDTH-1:0] pc;
    logic [PC_WIDTH-1:0] next_pc;
    logic [PC_WIDTH-1:0] pc_increment;

    // PC register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= '0;
        end else if (!stall) begin
            pc <= next_pc;
        end
    end

    // Determine opcode for branch detection
    logic [6:0] opcode_0;
    assign opcode_0 = imem_data_0[6:0];
    assign bpu_is_branch = (opcode_0 == OP_BRANCH);

    // Connect PC to branch predictor
    assign bpu_pc = pc;

    // Calculate next PC
    always_comb begin
        pc_plus_4_0 = pc + 32'd4;
        pc_plus_4_1 = pc + 32'd8;

        // Branch taken has highest priority
        if (branch_taken) begin
            next_pc = branch_target;
            pc_increment = 32'd4;  // Only one instruction issues after branch
        end
        // Check branch prediction
        else if (bpu_predict_taken && bpu_is_branch) begin
            next_pc = bpu_predict_target;
            pc_increment = 32'd4;  // Only one instruction issues on predicted branch
        end
        // Normal operation: dual issue (PC + 8) or single issue (PC + 4)
        else begin
            // For now, always try dual issue (PC + 8)
            // The ID stage will determine if both can actually issue
            next_pc = pc + 32'd8;
            pc_increment = 32'd8;
        end
    end

    // Fetch instructions
    assign imem_addr     = pc;
    assign pc_out_0      = pc;
    assign pc_out_1      = pc + 32'd4;
    assign instruction_0 = imem_data_0;
    assign instruction_1 = imem_data_1;

    // Valid signals
    always_comb begin
        valid_0 = imem_ready && !stall;

        // Second instruction valid only if we're not branching/jumping
        // and memory is ready
        valid_1 = imem_ready && !stall && !branch_taken &&
                  !(bpu_predict_taken && bpu_is_branch);
    end

    // Pass prediction info to next stage
    assign predicted_taken  = bpu_predict_taken && bpu_is_branch;
    assign predicted_target = bpu_predict_target;

endmodule : stage_if
