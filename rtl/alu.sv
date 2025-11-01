// Arithmetic Logic Unit (ALU)
// Supports all RV32I arithmetic and logical operations

import riscv_pkg::*;

module alu (
    input  logic [XLEN-1:0]   operand_a,
    input  logic [XLEN-1:0]   operand_b,
    input  alu_op_e           alu_op,
    output logic [XLEN-1:0]   result,
    output logic              zero,
    output logic              negative,
    output logic              carry,
    output logic              overflow
);

    logic [XLEN-1:0] add_sub_result;
    logic [XLEN:0]   add_result_extended;
    logic [XLEN:0]   sub_result_extended;
    logic [4:0]      shift_amount;

    // Extract shift amount (lower 5 bits for 32-bit shifts)
    assign shift_amount = operand_b[4:0];

    // Extended addition and subtraction for carry/overflow detection
    assign add_result_extended = {1'b0, operand_a} + {1'b0, operand_b};
    assign sub_result_extended = {1'b0, operand_a} - {1'b0, operand_b};

    // Main ALU operations
    always_comb begin
        result   = '0;
        zero     = 1'b0;
        negative = 1'b0;
        carry    = 1'b0;
        overflow = 1'b0;

        case (alu_op)
            ALU_ADD: begin
                result   = operand_a + operand_b;
                carry    = add_result_extended[XLEN];
                overflow = (operand_a[XLEN-1] == operand_b[XLEN-1]) &&
                          (result[XLEN-1] != operand_a[XLEN-1]);
            end

            ALU_SUB: begin
                result   = operand_a - operand_b;
                carry    = sub_result_extended[XLEN];
                overflow = (operand_a[XLEN-1] != operand_b[XLEN-1]) &&
                          (result[XLEN-1] != operand_a[XLEN-1]);
            end

            ALU_SLL: begin
                result = operand_a << shift_amount;
            end

            ALU_SLT: begin
                // Signed comparison
                result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;
            end

            ALU_SLTU: begin
                // Unsigned comparison
                result = (operand_a < operand_b) ? 32'd1 : 32'd0;
            end

            ALU_XOR: begin
                result = operand_a ^ operand_b;
            end

            ALU_SRL: begin
                // Logical right shift
                result = operand_a >> shift_amount;
            end

            ALU_SRA: begin
                // Arithmetic right shift (sign-extended)
                result = $signed(operand_a) >>> shift_amount;
            end

            ALU_OR: begin
                result = operand_a | operand_b;
            end

            ALU_AND: begin
                result = operand_a & operand_b;
            end

            ALU_COPY: begin
                // Pass through operand A (used for LUI, AUIPC)
                result = operand_a;
            end

            default: begin
                result = '0;
            end
        endcase

        // Status flags
        zero     = (result == '0);
        negative = result[XLEN-1];
    end

endmodule : alu
