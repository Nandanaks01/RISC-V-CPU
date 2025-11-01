// RISC-V Dual-Issue Pipelined CPU Core
// Top-level integration of all pipeline stages

import riscv_pkg::*;

module riscv_core (
    input  logic                  clk,
    input  logic                  rst_n,

    // Instruction memory interface
    output logic [ADDR_WIDTH-1:0] imem_addr,
    input  logic [ILEN-1:0]       imem_data_0,
    input  logic [ILEN-1:0]       imem_data_1,
    input  logic                  imem_ready,

    // Data memory interface
    output logic [ADDR_WIDTH-1:0] dmem_addr,
    output logic [DATA_WIDTH-1:0] dmem_wdata,
    output logic                  dmem_wen,
    output logic [3:0]            dmem_byte_en,
    input  logic [DATA_WIDTH-1:0] dmem_rdata,
    input  logic                  dmem_ready
);

    // ========== Pipeline Register Signals ==========

    // IF/ID Pipeline Register
    if_id_reg_t if_id_reg_in_0, if_id_reg_out_0;
    if_id_reg_t if_id_reg_in_1, if_id_reg_out_1;

    // ID/EX Pipeline Register
    id_ex_reg_t id_ex_reg_in_0, id_ex_reg_out_0;
    id_ex_reg_t id_ex_reg_in_1, id_ex_reg_out_1;

    // EX/MEM Pipeline Register
    ex_mem_reg_t ex_mem_reg_in_0, ex_mem_reg_out_0;
    ex_mem_reg_t ex_mem_reg_in_1, ex_mem_reg_out_1;

    // MEM/WB Pipeline Register
    mem_wb_reg_t mem_wb_reg_in_0, mem_wb_reg_out_0;
    mem_wb_reg_t mem_wb_reg_in_1, mem_wb_reg_out_1;

    // ========== Control Signals ==========
    logic stall;
    logic flush_if_id;
    logic flush_id_ex;
    logic flush_ex_mem;
    logic branch_taken_0, branch_taken_1;
    logic [PC_WIDTH-1:0] branch_target_0, branch_target_1;
    logic branch_mispredicted_0, branch_mispredicted_1;
    logic dual_issue_conflict;

    // Branch taken (either instruction)
    logic branch_taken;
    logic [PC_WIDTH-1:0] branch_target;

    assign branch_taken = branch_taken_0 || branch_taken_1;
    assign branch_target = branch_taken_0 ? branch_target_0 : branch_target_1;

    // Flush on branch misprediction or taken
    assign flush_id_ex = branch_taken || branch_mispredicted_0 || branch_mispredicted_1;

    // ========== Register File Signals ==========
    logic [4:0]      rf_rs1_addr_0, rf_rs2_addr_0;
    logic [4:0]      rf_rs1_addr_1, rf_rs2_addr_1;
    logic [XLEN-1:0] rf_rs1_data_0, rf_rs2_data_0;
    logic [XLEN-1:0] rf_rs1_data_1, rf_rs2_data_1;
    logic            rf_wen_0, rf_wen_1;
    logic [4:0]      rf_waddr_0, rf_waddr_1;
    logic [XLEN-1:0] rf_wdata_0, rf_wdata_1;

    // ========== Branch Predictor Signals ==========
    logic [PC_WIDTH-1:0] bpu_pc;
    logic                bpu_is_branch;
    logic                bpu_predict_taken;
    logic [PC_WIDTH-1:0] bpu_predict_target;
    logic                bpu_update_en_0, bpu_update_en_1;
    logic [PC_WIDTH-1:0] bpu_update_pc_0, bpu_update_pc_1;
    logic                bpu_actual_taken_0, bpu_actual_taken_1;
    logic [PC_WIDTH-1:0] bpu_actual_target_0, bpu_actual_target_1;

    // ========== Forwarding Signals ==========
    forward_e forward_a_0, forward_b_0;
    forward_e forward_a_1, forward_b_1;

    // ========== Stage Outputs ==========

    // IF Stage outputs
    logic [PC_WIDTH-1:0] if_pc_0, if_pc_1;
    logic [ILEN-1:0]     if_instruction_0, if_instruction_1;
    logic                if_valid_0, if_valid_1;
    logic [PC_WIDTH-1:0] if_pc_plus_4_0, if_pc_plus_4_1;
    logic                if_predicted_taken;
    logic [PC_WIDTH-1:0] if_predicted_target;

    // ID Stage outputs
    logic [PC_WIDTH-1:0] id_pc_0, id_pc_1;
    logic [XLEN-1:0]     id_rs1_data_0, id_rs2_data_0;
    logic [XLEN-1:0]     id_rs1_data_1, id_rs2_data_1;
    logic [XLEN-1:0]     id_imm_0, id_imm_1;
    logic [4:0]          id_rs1_addr_0, id_rs2_addr_0, id_rd_addr_0;
    logic [4:0]          id_rs1_addr_1, id_rs2_addr_1, id_rd_addr_1;
    control_t            id_ctrl_0, id_ctrl_1;
    logic                id_valid_0, id_valid_1;
    logic [PC_WIDTH-1:0] id_pc_plus_4_0, id_pc_plus_4_1;
    logic                id_predicted_taken_0;
    logic [PC_WIDTH-1:0] id_predicted_target_0;
    logic [2:0]          id_funct3_0, id_funct3_1;

    // EX Stage outputs
    logic [XLEN-1:0]     ex_alu_result_0, ex_alu_result_1;
    logic [XLEN-1:0]     ex_rs2_data_0, ex_rs2_data_1;
    logic [4:0]          ex_rd_addr_0, ex_rd_addr_1;
    logic                ex_reg_write_0, ex_reg_write_1;
    logic                ex_mem_read_0, ex_mem_read_1;
    logic                ex_mem_write_0, ex_mem_write_1;
    wb_src_e             ex_wb_src_0, ex_wb_src_1;
    mem_op_e             ex_mem_op_0, ex_mem_op_1;
    logic                ex_valid_0, ex_valid_1;
    logic [PC_WIDTH-1:0] ex_pc_plus_4_0, ex_pc_plus_4_1;

    // MEM Stage outputs
    logic [XLEN-1:0]     mem_alu_result_0, mem_alu_result_1;
    logic [XLEN-1:0]     mem_data_0, mem_data_1;
    logic [4:0]          mem_rd_addr_0, mem_rd_addr_1;
    logic                mem_reg_write_0, mem_reg_write_1;
    wb_src_e             mem_wb_src_0, mem_wb_src_1;
    logic                mem_valid_0, mem_valid_1;
    logic [PC_WIDTH-1:0] mem_pc_plus_4_0, mem_pc_plus_4_1;

    // WB Stage outputs - already defined in register file signals

    // ========== Instantiate Branch Predictor ==========
    branch_predictor bpu (
        .clk(clk),
        .rst_n(rst_n),
        .pc(bpu_pc),
        .is_branch(bpu_is_branch),
        .predict_taken(bpu_predict_taken),
        .predict_target(bpu_predict_target),
        .update_en(bpu_update_en_0 || bpu_update_en_1),
        .update_pc(bpu_update_en_0 ? bpu_update_pc_0 : bpu_update_pc_1),
        .actual_taken(bpu_update_en_0 ? bpu_actual_taken_0 : bpu_actual_taken_1),
        .actual_target(bpu_update_en_0 ? bpu_actual_target_0 : bpu_actual_target_1)
    );

    // ========== Instantiate IF Stage ==========
    stage_if if_stage (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .imem_addr(imem_addr),
        .imem_data_0(imem_data_0),
        .imem_data_1(imem_data_1),
        .imem_ready(imem_ready),
        .bpu_pc(bpu_pc),
        .bpu_is_branch(bpu_is_branch),
        .bpu_predict_taken(bpu_predict_taken),
        .bpu_predict_target(bpu_predict_target),
        .pc_out_0(if_pc_0),
        .pc_out_1(if_pc_1),
        .instruction_0(if_instruction_0),
        .instruction_1(if_instruction_1),
        .valid_0(if_valid_0),
        .valid_1(if_valid_1),
        .pc_plus_4_0(if_pc_plus_4_0),
        .pc_plus_4_1(if_pc_plus_4_1),
        .predicted_taken(if_predicted_taken),
        .predicted_target(if_predicted_target)
    );

    // ========== IF/ID Pipeline Registers ==========
    // Populate IF/ID input
    assign if_id_reg_in_0.pc              = if_pc_0;
    assign if_id_reg_in_0.instruction     = if_instruction_0;
    assign if_id_reg_in_0.valid           = if_valid_0;
    assign if_id_reg_in_0.pc_plus_4       = if_pc_plus_4_0;
    assign if_id_reg_in_0.predicted_taken = if_predicted_taken;
    assign if_id_reg_in_0.predicted_target= if_predicted_target;

    assign if_id_reg_in_1.pc              = if_pc_1;
    assign if_id_reg_in_1.instruction     = if_instruction_1;
    assign if_id_reg_in_1.valid           = if_valid_1;
    assign if_id_reg_in_1.pc_plus_4       = if_pc_plus_4_1;
    assign if_id_reg_in_1.predicted_taken = 1'b0;
    assign if_id_reg_in_1.predicted_target= '0;

    if_id_reg if_id_0 (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .flush(flush_if_id || branch_taken),
        .if_id_in(if_id_reg_in_0),
        .if_id_out(if_id_reg_out_0)
    );

    if_id_reg if_id_1 (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .flush(flush_if_id || branch_taken),
        .if_id_in(if_id_reg_in_1),
        .if_id_out(if_id_reg_out_1)
    );

    // ========== Instantiate Register File ==========
    register_file regfile (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr_0(rf_rs1_addr_0),
        .rs2_addr_0(rf_rs2_addr_0),
        .rs1_data_0(rf_rs1_data_0),
        .rs2_data_0(rf_rs2_data_0),
        .rs1_addr_1(rf_rs1_addr_1),
        .rs2_addr_1(rf_rs2_addr_1),
        .rs1_data_1(rf_rs1_data_1),
        .rs2_data_1(rf_rs2_data_1),
        .wr_en_0(rf_wen_0),
        .rd_addr_0(rf_waddr_0),
        .rd_data_0(rf_wdata_0),
        .wr_en_1(rf_wen_1),
        .rd_addr_1(rf_waddr_1),
        .rd_data_1(rf_wdata_1)
    );

    // ========== Instantiate Hazard Detection ==========
    hazard_detection hazard_unit (
        .if_id_rs1_0(rf_rs1_addr_0),
        .if_id_rs2_0(rf_rs2_addr_0),
        .if_id_rs1_1(rf_rs1_addr_1),
        .if_id_rs2_1(rf_rs2_addr_1),
        .if_id_valid_0(if_id_reg_out_0.valid),
        .if_id_valid_1(if_id_reg_out_1.valid),
        .id_ex_rd(id_ex_reg_out_0.rd_addr),
        .id_ex_mem_read(id_ex_reg_out_0.ctrl.mem_read),
        .id_ex_valid(id_ex_reg_out_0.valid),
        .inst0_rd(id_rd_addr_0),
        .inst1_rs1(rf_rs1_addr_1),
        .inst1_rs2(rf_rs2_addr_1),
        .inst0_reg_write(id_ctrl_0.reg_write),
        .inst1_valid(if_id_reg_out_1.valid),
        .stall(stall),
        .flush_if_id(flush_if_id),
        .dual_issue_conflict(dual_issue_conflict)
    );

    // ========== Instantiate ID Stage ==========
    stage_id id_stage (
        .clk(clk),
        .rst_n(rst_n),
        .pc_0(if_id_reg_out_0.pc),
        .pc_1(if_id_reg_out_1.pc),
        .instruction_0(if_id_reg_out_0.instruction),
        .instruction_1(if_id_reg_out_1.instruction),
        .valid_0(if_id_reg_out_0.valid),
        .valid_1(if_id_reg_out_1.valid),
        .pc_plus_4_0(if_id_reg_out_0.pc_plus_4),
        .pc_plus_4_1(if_id_reg_out_1.pc_plus_4),
        .predicted_taken(if_id_reg_out_0.predicted_taken),
        .predicted_target(if_id_reg_out_0.predicted_target),
        .rf_rs1_addr_0(rf_rs1_addr_0),
        .rf_rs2_addr_0(rf_rs2_addr_0),
        .rf_rs1_data_0(rf_rs1_data_0),
        .rf_rs2_data_0(rf_rs2_data_0),
        .rf_rs1_addr_1(rf_rs1_addr_1),
        .rf_rs2_addr_1(rf_rs2_addr_1),
        .rf_rs1_data_1(rf_rs1_data_1),
        .rf_rs2_data_1(rf_rs2_data_1),
        .dual_issue_conflict(dual_issue_conflict),
        .id_ex_pc_0(id_pc_0),
        .id_ex_rs1_data_0(id_rs1_data_0),
        .id_ex_rs2_data_0(id_rs2_data_0),
        .id_ex_imm_0(id_imm_0),
        .id_ex_rs1_addr_0(id_rs1_addr_0),
        .id_ex_rs2_addr_0(id_rs2_addr_0),
        .id_ex_rd_addr_0(id_rd_addr_0),
        .id_ex_ctrl_0(id_ctrl_0),
        .id_ex_valid_0(id_valid_0),
        .id_ex_pc_plus_4_0(id_pc_plus_4_0),
        .id_ex_predicted_taken_0(id_predicted_taken_0),
        .id_ex_predicted_target_0(id_predicted_target_0),
        .id_ex_funct3_0(id_funct3_0),
        .id_ex_pc_1(id_pc_1),
        .id_ex_rs1_data_1(id_rs1_data_1),
        .id_ex_rs2_data_1(id_rs2_data_1),
        .id_ex_imm_1(id_imm_1),
        .id_ex_rs1_addr_1(id_rs1_addr_1),
        .id_ex_rs2_addr_1(id_rs2_addr_1),
        .id_ex_rd_addr_1(id_rd_addr_1),
        .id_ex_ctrl_1(id_ctrl_1),
        .id_ex_valid_1(id_valid_1),
        .id_ex_pc_plus_4_1(id_pc_plus_4_1),
        .id_ex_funct3_1(id_funct3_1)
    );

    // ========== ID/EX Pipeline Registers ==========
    assign id_ex_reg_in_0.pc              = id_pc_0;
    assign id_ex_reg_in_0.rs1_data        = id_rs1_data_0;
    assign id_ex_reg_in_0.rs2_data        = id_rs2_data_0;
    assign id_ex_reg_in_0.imm             = id_imm_0;
    assign id_ex_reg_in_0.rs1_addr        = id_rs1_addr_0;
    assign id_ex_reg_in_0.rs2_addr        = id_rs2_addr_0;
    assign id_ex_reg_in_0.rd_addr         = id_rd_addr_0;
    assign id_ex_reg_in_0.ctrl            = id_ctrl_0;
    assign id_ex_reg_in_0.valid           = id_valid_0;
    assign id_ex_reg_in_0.pc_plus_4       = id_pc_plus_4_0;
    assign id_ex_reg_in_0.predicted_taken = id_predicted_taken_0;
    assign id_ex_reg_in_0.predicted_target= id_predicted_target_0;
    assign id_ex_reg_in_0.funct3          = id_funct3_0;

    assign id_ex_reg_in_1.pc              = id_pc_1;
    assign id_ex_reg_in_1.rs1_data        = id_rs1_data_1;
    assign id_ex_reg_in_1.rs2_data        = id_rs2_data_1;
    assign id_ex_reg_in_1.imm             = id_imm_1;
    assign id_ex_reg_in_1.rs1_addr        = id_rs1_addr_1;
    assign id_ex_reg_in_1.rs2_addr        = id_rs2_addr_1;
    assign id_ex_reg_in_1.rd_addr         = id_rd_addr_1;
    assign id_ex_reg_in_1.ctrl            = id_ctrl_1;
    assign id_ex_reg_in_1.valid           = id_valid_1;
    assign id_ex_reg_in_1.pc_plus_4       = id_pc_plus_4_1;
    assign id_ex_reg_in_1.predicted_taken = 1'b0;
    assign id_ex_reg_in_1.predicted_target= '0;
    assign id_ex_reg_in_1.funct3          = id_funct3_1;

    id_ex_reg id_ex_0 (
        .clk(clk),
        .rst_n(rst_n),
        .stall(1'b0),
        .flush(flush_id_ex),
        .id_ex_in(id_ex_reg_in_0),
        .id_ex_out(id_ex_reg_out_0)
    );

    id_ex_reg id_ex_1 (
        .clk(clk),
        .rst_n(rst_n),
        .stall(1'b0),
        .flush(flush_id_ex),
        .id_ex_in(id_ex_reg_in_1),
        .id_ex_out(id_ex_reg_out_1)
    );

    // ========== Instantiate Forwarding Units ==========
    forwarding_unit fwd_unit_0 (
        .id_ex_rs1(id_ex_reg_out_0.rs1_addr),
        .id_ex_rs2(id_ex_reg_out_0.rs2_addr),
        .id_ex_valid(id_ex_reg_out_0.valid),
        .ex_mem_rd(ex_mem_reg_out_0.rd_addr),
        .ex_mem_reg_write(ex_mem_reg_out_0.reg_write),
        .ex_mem_valid(ex_mem_reg_out_0.valid),
        .mem_wb_rd(mem_wb_reg_out_0.rd_addr),
        .mem_wb_reg_write(mem_wb_reg_out_0.reg_write),
        .mem_wb_valid(mem_wb_reg_out_0.valid),
        .forward_a(forward_a_0),
        .forward_b(forward_b_0)
    );

    forwarding_unit fwd_unit_1 (
        .id_ex_rs1(id_ex_reg_out_1.rs1_addr),
        .id_ex_rs2(id_ex_reg_out_1.rs2_addr),
        .id_ex_valid(id_ex_reg_out_1.valid),
        .ex_mem_rd(ex_mem_reg_out_1.rd_addr),
        .ex_mem_reg_write(ex_mem_reg_out_1.reg_write),
        .ex_mem_valid(ex_mem_reg_out_1.valid),
        .mem_wb_rd(mem_wb_reg_out_1.rd_addr),
        .mem_wb_reg_write(mem_wb_reg_out_1.reg_write),
        .mem_wb_valid(mem_wb_reg_out_1.valid),
        .forward_a(forward_a_1),
        .forward_b(forward_b_1)
    );

    // ========== Instantiate EX Stages ==========
    stage_ex ex_stage_0 (
        .pc(id_ex_reg_out_0.pc),
        .rs1_data(id_ex_reg_out_0.rs1_data),
        .rs2_data(id_ex_reg_out_0.rs2_data),
        .imm(id_ex_reg_out_0.imm),
        .rs1_addr(id_ex_reg_out_0.rs1_addr),
        .rs2_addr(id_ex_reg_out_0.rs2_addr),
        .rd_addr(id_ex_reg_out_0.rd_addr),
        .ctrl(id_ex_reg_out_0.ctrl),
        .valid(id_ex_reg_out_0.valid),
        .pc_plus_4(id_ex_reg_out_0.pc_plus_4),
        .predicted_taken(id_ex_reg_out_0.predicted_taken),
        .predicted_target(id_ex_reg_out_0.predicted_target),
        .funct3(id_ex_reg_out_0.funct3),
        .ex_mem_alu_result(ex_mem_reg_out_0.alu_result),
        .mem_wb_wb_data(rf_wdata_0),
        .forward_a(forward_a_0),
        .forward_b(forward_b_0),
        .alu_result(ex_alu_result_0),
        .rs2_data_out(ex_rs2_data_0),
        .rd_addr_out(ex_rd_addr_0),
        .reg_write(ex_reg_write_0),
        .mem_read(ex_mem_read_0),
        .mem_write(ex_mem_write_0),
        .wb_src(ex_wb_src_0),
        .mem_op(ex_mem_op_0),
        .valid_out(ex_valid_0),
        .pc_plus_4_out(ex_pc_plus_4_0),
        .branch_taken(branch_taken_0),
        .branch_target(branch_target_0),
        .branch_mispredicted(branch_mispredicted_0),
        .bpu_update_en(bpu_update_en_0),
        .bpu_update_pc(bpu_update_pc_0),
        .bpu_actual_taken(bpu_actual_taken_0),
        .bpu_actual_target(bpu_actual_target_0)
    );

    stage_ex ex_stage_1 (
        .pc(id_ex_reg_out_1.pc),
        .rs1_data(id_ex_reg_out_1.rs1_data),
        .rs2_data(id_ex_reg_out_1.rs2_data),
        .imm(id_ex_reg_out_1.imm),
        .rs1_addr(id_ex_reg_out_1.rs1_addr),
        .rs2_addr(id_ex_reg_out_1.rs2_addr),
        .rd_addr(id_ex_reg_out_1.rd_addr),
        .ctrl(id_ex_reg_out_1.ctrl),
        .valid(id_ex_reg_out_1.valid),
        .pc_plus_4(id_ex_reg_out_1.pc_plus_4),
        .predicted_taken(id_ex_reg_out_1.predicted_taken),
        .predicted_target(id_ex_reg_out_1.predicted_target),
        .funct3(id_ex_reg_out_1.funct3),
        .ex_mem_alu_result(ex_mem_reg_out_1.alu_result),
        .mem_wb_wb_data(rf_wdata_1),
        .forward_a(forward_a_1),
        .forward_b(forward_b_1),
        .alu_result(ex_alu_result_1),
        .rs2_data_out(ex_rs2_data_1),
        .rd_addr_out(ex_rd_addr_1),
        .reg_write(ex_reg_write_1),
        .mem_read(ex_mem_read_1),
        .mem_write(ex_mem_write_1),
        .wb_src(ex_wb_src_1),
        .mem_op(ex_mem_op_1),
        .valid_out(ex_valid_1),
        .pc_plus_4_out(ex_pc_plus_4_1),
        .branch_taken(branch_taken_1),
        .branch_target(branch_target_1),
        .branch_mispredicted(branch_mispredicted_1),
        .bpu_update_en(bpu_update_en_1),
        .bpu_update_pc(bpu_update_pc_1),
        .bpu_actual_taken(bpu_actual_taken_1),
        .bpu_actual_target(bpu_actual_target_1)
    );

    // ========== EX/MEM Pipeline Registers ==========
    assign ex_mem_reg_in_0.alu_result    = ex_alu_result_0;
    assign ex_mem_reg_in_0.rs2_data      = ex_rs2_data_0;
    assign ex_mem_reg_in_0.rd_addr       = ex_rd_addr_0;
    assign ex_mem_reg_in_0.reg_write     = ex_reg_write_0;
    assign ex_mem_reg_in_0.mem_read      = ex_mem_read_0;
    assign ex_mem_reg_in_0.mem_write     = ex_mem_write_0;
    assign ex_mem_reg_in_0.wb_src        = ex_wb_src_0;
    assign ex_mem_reg_in_0.mem_op        = ex_mem_op_0;
    assign ex_mem_reg_in_0.valid         = ex_valid_0;
    assign ex_mem_reg_in_0.pc_plus_4     = ex_pc_plus_4_0;
    assign ex_mem_reg_in_0.branch_taken  = branch_taken_0;
    assign ex_mem_reg_in_0.branch_target = branch_target_0;

    assign ex_mem_reg_in_1.alu_result    = ex_alu_result_1;
    assign ex_mem_reg_in_1.rs2_data      = ex_rs2_data_1;
    assign ex_mem_reg_in_1.rd_addr       = ex_rd_addr_1;
    assign ex_mem_reg_in_1.reg_write     = ex_reg_write_1;
    assign ex_mem_reg_in_1.mem_read      = ex_mem_read_1;
    assign ex_mem_reg_in_1.mem_write     = ex_mem_write_1;
    assign ex_mem_reg_in_1.wb_src        = ex_wb_src_1;
    assign ex_mem_reg_in_1.mem_op        = ex_mem_op_1;
    assign ex_mem_reg_in_1.valid         = ex_valid_1;
    assign ex_mem_reg_in_1.pc_plus_4     = ex_pc_plus_4_1;
    assign ex_mem_reg_in_1.branch_taken  = branch_taken_1;
    assign ex_mem_reg_in_1.branch_target = branch_target_1;

    ex_mem_reg ex_mem_0 (
        .clk(clk),
        .rst_n(rst_n),
        .stall(1'b0),
        .flush(1'b0),
        .ex_mem_in(ex_mem_reg_in_0),
        .ex_mem_out(ex_mem_reg_out_0)
    );

    ex_mem_reg ex_mem_1 (
        .clk(clk),
        .rst_n(rst_n),
        .stall(1'b0),
        .flush(1'b0),
        .ex_mem_in(ex_mem_reg_in_1),
        .ex_mem_out(ex_mem_reg_out_1)
    );

    // ========== Instantiate MEM Stage ==========
    // Note: Only one memory port, so prioritize instruction 0
    logic [ADDR_WIDTH-1:0] dmem_addr_0, dmem_addr_1;
    logic [DATA_WIDTH-1:0] dmem_wdata_0, dmem_wdata_1;
    logic                  dmem_wen_0, dmem_wen_1;
    logic [3:0]            dmem_byte_en_0, dmem_byte_en_1;

    stage_mem mem_stage_0 (
        .clk(clk),
        .rst_n(rst_n),
        .alu_result(ex_mem_reg_out_0.alu_result),
        .rs2_data(ex_mem_reg_out_0.rs2_data),
        .rd_addr(ex_mem_reg_out_0.rd_addr),
        .reg_write(ex_mem_reg_out_0.reg_write),
        .mem_read(ex_mem_reg_out_0.mem_read),
        .mem_write(ex_mem_reg_out_0.mem_write),
        .wb_src(ex_mem_reg_out_0.wb_src),
        .mem_op(ex_mem_reg_out_0.mem_op),
        .valid(ex_mem_reg_out_0.valid),
        .pc_plus_4(ex_mem_reg_out_0.pc_plus_4),
        .dmem_addr(dmem_addr_0),
        .dmem_wdata(dmem_wdata_0),
        .dmem_wen(dmem_wen_0),
        .dmem_byte_en(dmem_byte_en_0),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        .alu_result_out(mem_alu_result_0),
        .mem_data(mem_data_0),
        .rd_addr_out(mem_rd_addr_0),
        .reg_write_out(mem_reg_write_0),
        .wb_src_out(mem_wb_src_0),
        .valid_out(mem_valid_0),
        .pc_plus_4_out(mem_pc_plus_4_0)
    );

    stage_mem mem_stage_1 (
        .clk(clk),
        .rst_n(rst_n),
        .alu_result(ex_mem_reg_out_1.alu_result),
        .rs2_data(ex_mem_reg_out_1.rs2_data),
        .rd_addr(ex_mem_reg_out_1.rd_addr),
        .reg_write(ex_mem_reg_out_1.reg_write),
        .mem_read(ex_mem_reg_out_1.mem_read),
        .mem_write(ex_mem_reg_out_1.mem_write),
        .wb_src(ex_mem_reg_out_1.wb_src),
        .mem_op(ex_mem_reg_out_1.mem_op),
        .valid(ex_mem_reg_out_1.valid),
        .pc_plus_4(ex_mem_reg_out_1.pc_plus_4),
        .dmem_addr(dmem_addr_1),
        .dmem_wdata(dmem_wdata_1),
        .dmem_wen(dmem_wen_1),
        .dmem_byte_en(dmem_byte_en_1),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        .alu_result_out(mem_alu_result_1),
        .mem_data(mem_data_1),
        .rd_addr_out(mem_rd_addr_1),
        .reg_write_out(mem_reg_write_1),
        .wb_src_out(mem_wb_src_1),
        .valid_out(mem_valid_1),
        .pc_plus_4_out(mem_pc_plus_4_1)
    );

    // Memory arbitration (prioritize instruction 0)
    assign dmem_addr    = dmem_wen_0 || ex_mem_reg_out_0.mem_read ? dmem_addr_0 : dmem_addr_1;
    assign dmem_wdata   = dmem_wen_0 ? dmem_wdata_0 : dmem_wdata_1;
    assign dmem_wen     = dmem_wen_0 || dmem_wen_1;
    assign dmem_byte_en = dmem_wen_0 ? dmem_byte_en_0 : dmem_byte_en_1;

    // ========== MEM/WB Pipeline Registers ==========
    assign mem_wb_reg_in_0.alu_result = mem_alu_result_0;
    assign mem_wb_reg_in_0.mem_data   = mem_data_0;
    assign mem_wb_reg_in_0.rd_addr    = mem_rd_addr_0;
    assign mem_wb_reg_in_0.reg_write  = mem_reg_write_0;
    assign mem_wb_reg_in_0.wb_src     = mem_wb_src_0;
    assign mem_wb_reg_in_0.valid      = mem_valid_0;
    assign mem_wb_reg_in_0.pc_plus_4  = mem_pc_plus_4_0;

    assign mem_wb_reg_in_1.alu_result = mem_alu_result_1;
    assign mem_wb_reg_in_1.mem_data   = mem_data_1;
    assign mem_wb_reg_in_1.rd_addr    = mem_rd_addr_1;
    assign mem_wb_reg_in_1.reg_write  = mem_reg_write_1;
    assign mem_wb_reg_in_1.wb_src     = mem_wb_src_1;
    assign mem_wb_reg_in_1.valid      = mem_valid_1;
    assign mem_wb_reg_in_1.pc_plus_4  = mem_pc_plus_4_1;

    mem_wb_reg mem_wb_0 (
        .clk(clk),
        .rst_n(rst_n),
        .stall(1'b0),
        .flush(1'b0),
        .mem_wb_in(mem_wb_reg_in_0),
        .mem_wb_out(mem_wb_reg_out_0)
    );

    mem_wb_reg mem_wb_1 (
        .clk(clk),
        .rst_n(rst_n),
        .stall(1'b0),
        .flush(1'b0),
        .mem_wb_in(mem_wb_reg_in_1),
        .mem_wb_out(mem_wb_reg_out_1)
    );

    // ========== Instantiate WB Stages ==========
    stage_wb wb_stage_0 (
        .alu_result(mem_wb_reg_out_0.alu_result),
        .mem_data(mem_wb_reg_out_0.mem_data),
        .rd_addr(mem_wb_reg_out_0.rd_addr),
        .reg_write(mem_wb_reg_out_0.reg_write),
        .wb_src(mem_wb_reg_out_0.wb_src),
        .valid(mem_wb_reg_out_0.valid),
        .pc_plus_4(mem_wb_reg_out_0.pc_plus_4),
        .rf_wen(rf_wen_0),
        .rf_waddr(rf_waddr_0),
        .rf_wdata(rf_wdata_0)
    );

    stage_wb wb_stage_1 (
        .alu_result(mem_wb_reg_out_1.alu_result),
        .mem_data(mem_wb_reg_out_1.mem_data),
        .rd_addr(mem_wb_reg_out_1.rd_addr),
        .reg_write(mem_wb_reg_out_1.reg_write),
        .wb_src(mem_wb_reg_out_1.wb_src),
        .valid(mem_wb_reg_out_1.valid),
        .pc_plus_4(mem_wb_reg_out_1.pc_plus_4),
        .rf_wen(rf_wen_1),
        .rf_waddr(rf_waddr_1),
        .rf_wdata(rf_wdata_1)
    );

endmodule : riscv_core
