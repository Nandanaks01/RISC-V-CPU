// Pipeline Registers
// Contains IF/ID, ID/EX, EX/MEM, and MEM/WB pipeline registers

import riscv_pkg::*;

// IF/ID Pipeline Register
module if_id_reg (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         stall,
    input  logic         flush,
    input  if_id_reg_t   if_id_in,
    output if_id_reg_t   if_id_out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_out <= '0;
        end else if (flush) begin
            if_id_out <= '0;
        end else if (!stall) begin
            if_id_out <= if_id_in;
        end
    end

endmodule : if_id_reg

// ID/EX Pipeline Register
module id_ex_reg (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         stall,
    input  logic         flush,
    input  id_ex_reg_t   id_ex_in,
    output id_ex_reg_t   id_ex_out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_out <= '0;
        end else if (flush) begin
            id_ex_out <= '0;
        end else if (!stall) begin
            id_ex_out <= id_ex_in;
        end
    end

endmodule : id_ex_reg

// EX/MEM Pipeline Register
module ex_mem_reg (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         stall,
    input  logic         flush,
    input  ex_mem_reg_t  ex_mem_in,
    output ex_mem_reg_t  ex_mem_out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_out <= '0;
        end else if (flush) begin
            ex_mem_out <= '0;
        end else if (!stall) begin
            ex_mem_out <= ex_mem_in;
        end
    end

endmodule : ex_mem_reg

// MEM/WB Pipeline Register
module mem_wb_reg (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         stall,
    input  logic         flush,
    input  mem_wb_reg_t  mem_wb_in,
    output mem_wb_reg_t  mem_wb_out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_out <= '0;
        end else if (flush) begin
            mem_wb_out <= '0;
        end else if (!stall) begin
            mem_wb_out <= mem_wb_in;
        end
    end

endmodule : mem_wb_reg
