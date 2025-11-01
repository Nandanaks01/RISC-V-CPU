// Write-Back (WB) Stage
// Selects write-back data source and generates register write signals

import riscv_pkg::*;

module stage_wb (
    // Inputs from MEM/WB register
    input  logic [XLEN-1:0]      alu_result,
    input  logic [XLEN-1:0]      mem_data,
    input  logic [4:0]           rd_addr,
    input  logic                 reg_write,
    input  wb_src_e              wb_src,
    input  logic                 valid,
    input  logic [PC_WIDTH-1:0]  pc_plus_4,

    // Outputs to register file
    output logic                 rf_wen,
    output logic [4:0]           rf_waddr,
    output logic [XLEN-1:0]      rf_wdata
);

    // Select write-back data
    logic [XLEN-1:0] wb_data;

    always_comb begin
        case (wb_src)
            WB_SRC_ALU: wb_data = alu_result;
            WB_SRC_MEM: wb_data = mem_data;
            WB_SRC_PC4: wb_data = pc_plus_4;
            default:    wb_data = alu_result;
        endcase
    end

    // Register file write signals
    assign rf_wen   = reg_write && valid && (rd_addr != 5'b0);  // Don't write to x0
    assign rf_waddr = rd_addr;
    assign rf_wdata = wb_data;

endmodule : stage_wb
