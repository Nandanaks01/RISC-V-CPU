// Memory (MEM) Stage
// Handles load and store operations with data memory

import riscv_pkg::*;

module stage_mem (
    input  logic                 clk,
    input  logic                 rst_n,

    // Inputs from EX/MEM register
    input  logic [XLEN-1:0]      alu_result,
    input  logic [XLEN-1:0]      rs2_data,
    input  logic [4:0]           rd_addr,
    input  logic                 reg_write,
    input  logic                 mem_read,
    input  logic                 mem_write,
    input  wb_src_e              wb_src,
    input  mem_op_e              mem_op,
    input  logic                 valid,
    input  logic [PC_WIDTH-1:0]  pc_plus_4,

    // Data memory interface
    output logic [ADDR_WIDTH-1:0] dmem_addr,
    output logic [DATA_WIDTH-1:0] dmem_wdata,
    output logic                  dmem_wen,
    output logic [3:0]            dmem_byte_en,
    input  logic [DATA_WIDTH-1:0] dmem_rdata,
    input  logic                  dmem_ready,

    // Outputs to MEM/WB register
    output logic [XLEN-1:0]      alu_result_out,
    output logic [XLEN-1:0]      mem_data,
    output logic [4:0]           rd_addr_out,
    output logic                 reg_write_out,
    output wb_src_e              wb_src_out,
    output logic                 valid_out,
    output logic [PC_WIDTH-1:0]  pc_plus_4_out
);

    // Memory address (from ALU result)
    assign dmem_addr = alu_result;

    // Memory write enable
    assign dmem_wen = mem_write && valid;

    // Generate byte enable and write data based on operation type
    logic [1:0] addr_offset;
    assign addr_offset = alu_result[1:0];

    // Write data alignment and byte enable generation
    always_comb begin
        dmem_wdata   = '0;
        dmem_byte_en = 4'b0000;

        if (mem_write) begin
            case (mem_op)
                MEM_BYTE: begin
                    // Byte store
                    case (addr_offset)
                        2'b00: begin
                            dmem_wdata   = {24'b0, rs2_data[7:0]};
                            dmem_byte_en = 4'b0001;
                        end
                        2'b01: begin
                            dmem_wdata   = {16'b0, rs2_data[7:0], 8'b0};
                            dmem_byte_en = 4'b0010;
                        end
                        2'b10: begin
                            dmem_wdata   = {8'b0, rs2_data[7:0], 16'b0};
                            dmem_byte_en = 4'b0100;
                        end
                        2'b11: begin
                            dmem_wdata   = {rs2_data[7:0], 24'b0};
                            dmem_byte_en = 4'b1000;
                        end
                    endcase
                end

                MEM_HALF: begin
                    // Halfword store
                    case (addr_offset[1])
                        1'b0: begin
                            dmem_wdata   = {16'b0, rs2_data[15:0]};
                            dmem_byte_en = 4'b0011;
                        end
                        1'b1: begin
                            dmem_wdata   = {rs2_data[15:0], 16'b0};
                            dmem_byte_en = 4'b1100;
                        end
                    endcase
                end

                MEM_WORD: begin
                    // Word store
                    dmem_wdata   = rs2_data;
                    dmem_byte_en = 4'b1111;
                end

                default: begin
                    dmem_wdata   = '0;
                    dmem_byte_en = 4'b0000;
                end
            endcase
        end
    end

    // Read data alignment and sign extension
    logic [XLEN-1:0] mem_read_data;

    always_comb begin
        mem_read_data = '0;

        if (mem_read) begin
            case (mem_op)
                MEM_BYTE: begin
                    // Signed byte load
                    case (addr_offset)
                        2'b00: mem_read_data = {{24{dmem_rdata[7]}}, dmem_rdata[7:0]};
                        2'b01: mem_read_data = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                        2'b10: mem_read_data = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                        2'b11: mem_read_data = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                    endcase
                end

                MEM_BYTEU: begin
                    // Unsigned byte load
                    case (addr_offset)
                        2'b00: mem_read_data = {24'b0, dmem_rdata[7:0]};
                        2'b01: mem_read_data = {24'b0, dmem_rdata[15:8]};
                        2'b10: mem_read_data = {24'b0, dmem_rdata[23:16]};
                        2'b11: mem_read_data = {24'b0, dmem_rdata[31:24]};
                    endcase
                end

                MEM_HALF: begin
                    // Signed halfword load
                    case (addr_offset[1])
                        1'b0: mem_read_data = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                        1'b1: mem_read_data = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                    endcase
                end

                MEM_HALFU: begin
                    // Unsigned halfword load
                    case (addr_offset[1])
                        1'b0: mem_read_data = {16'b0, dmem_rdata[15:0]};
                        1'b1: mem_read_data = {16'b0, dmem_rdata[31:16]};
                    endcase
                end

                MEM_WORD: begin
                    // Word load
                    mem_read_data = dmem_rdata;
                end

                default: begin
                    mem_read_data = '0;
                end
            endcase
        end
    end

    // Outputs to MEM/WB register
    assign alu_result_out = alu_result;
    assign mem_data       = mem_read_data;
    assign rd_addr_out    = rd_addr;
    assign reg_write_out  = reg_write;
    assign wb_src_out     = wb_src;
    assign valid_out      = valid;
    assign pc_plus_4_out  = pc_plus_4;

endmodule : stage_mem
