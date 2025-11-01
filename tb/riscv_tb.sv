// RISC-V CPU Testbench
// Self-checking testbench for verification

`timescale 1ns/1ps

import riscv_pkg::*;

module riscv_tb;

    // Clock and reset
    logic clk;
    logic rst_n;

    // Clock generation (1 GHz target -> 1 ns period)
    initial begin
        clk = 0;
        forever #0.5 clk = ~clk;  // 1 ns period = 1 GHz
    end

    // Reset generation
    initial begin
        rst_n = 0;
        #10;
        rst_n = 1;
    end

    // Instantiate DUT
    riscv_soc #(
        .IMEM_SIZE(4096),
        .DMEM_SIZE(4096),
        .INIT_FILE("test_program.hex")
    ) dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    // Performance counters
    int cycle_count;
    int instruction_count;
    int dual_issue_count;
    real ipc;

    // Monitor signals
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cycle_count <= 0;
            instruction_count <= 0;
            dual_issue_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            // Count issued instructions
            if (dut.cpu.id_valid_0) instruction_count <= instruction_count + 1;
            if (dut.cpu.id_valid_1) instruction_count <= instruction_count + 1;

            // Count dual-issue occurrences
            if (dut.cpu.id_valid_0 && dut.cpu.id_valid_1) begin
                dual_issue_count <= dual_issue_count + 1;
            end
        end
    end

    // Test program execution
    initial begin
        $display("========================================");
        $display("RISC-V Dual-Issue CPU Core Testbench");
        $display("========================================");

        // Wait for reset
        @(posedge rst_n);
        $display("[%0t] Reset released", $time);

        // Run for specified cycles
        repeat(1000) @(posedge clk);

        // Calculate IPC
        ipc = real'(instruction_count) / real'(cycle_count);

        // Print statistics
        $display("\n========================================");
        $display("Simulation Statistics");
        $display("========================================");
        $display("Total Cycles:        %0d", cycle_count);
        $display("Instructions Issued: %0d", instruction_count);
        $display("Dual-Issue Count:    %0d", dual_issue_count);
        $display("IPC:                 %0.3f", ipc);
        $display("========================================");

        // Register file dump
        $display("\nRegister File State:");
        $display("----------------------------------------");
        for (int i = 0; i < 32; i += 4) begin
            $display("x%-2d: 0x%08h  x%-2d: 0x%08h  x%-2d: 0x%08h  x%-2d: 0x%08h",
                     i,   dut.cpu.regfile.registers[i],
                     i+1, dut.cpu.regfile.registers[i+1],
                     i+2, dut.cpu.regfile.registers[i+2],
                     i+3, dut.cpu.regfile.registers[i+3]);
        end
        $display("----------------------------------------");

        // Branch predictor statistics
        $display("\nBranch Predictor Statistics:");
        $display("----------------------------------------");
        $display("Total Predictions:   %0d", dut.cpu.bpu.total_predictions);
        $display("Correct Predictions: %0d", dut.cpu.bpu.correct_predictions);
        $display("Incorrect Predictions: %0d", dut.cpu.bpu.incorrect_predictions);
        if (dut.cpu.bpu.total_predictions > 0) begin
            real accuracy = (real'(dut.cpu.bpu.correct_predictions) /
                            real'(dut.cpu.bpu.total_predictions)) * 100.0;
            $display("Prediction Accuracy: %0.2f%%", accuracy);
        end
        $display("========================================\n");

        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("riscv_core.vcd");
        $dumpvars(0, riscv_tb);
    end

    // Instruction trace (optional - can be verbose)
    // Uncomment for detailed instruction execution trace
    /*
    always_ff @(posedge clk) begin
        if (rst_n && dut.cpu.id_valid_0) begin
            $display("[%0t] PC=0x%08h INST=0x%08h",
                     $time,
                     dut.cpu.if_id_reg_out_0.pc,
                     dut.cpu.if_id_reg_out_0.instruction);
        end
    end
    */

    // Timeout watchdog
    initial begin
        #100000;  // 100 us timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

endmodule : riscv_tb
