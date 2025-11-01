// Branch Prediction Unit (BPU)
// Uses 2-bit saturating counter predictor (local history)

import riscv_pkg::*;

module branch_predictor (
    input  logic                 clk,
    input  logic                 rst_n,

    // Prediction interface (IF stage)
    input  logic [PC_WIDTH-1:0]  pc,
    input  logic                 is_branch,
    output logic                 predict_taken,
    output logic [PC_WIDTH-1:0]  predict_target,

    // Update interface (EX stage - feedback)
    input  logic                 update_en,
    input  logic [PC_WIDTH-1:0]  update_pc,
    input  logic                 actual_taken,
    input  logic [PC_WIDTH-1:0]  actual_target
);

    // Branch prediction table
    bpu_entry_t bpt [0:BPU_ENTRIES-1];

    // Index into BPU table using PC bits
    logic [BPU_INDEX_BITS-1:0] predict_index;
    logic [BPU_INDEX_BITS-1:0] update_index;

    assign predict_index = pc[BPU_INDEX_BITS+1:2];        // Use PC[9:2] for 256 entries
    assign update_index  = update_pc[BPU_INDEX_BITS+1:2];

    // Prediction logic
    always_comb begin
        if (is_branch && bpt[predict_index].valid) begin
            // Predict taken if counter >= 2 (10 or 11 in 2-bit counter)
            predict_taken  = bpt[predict_index].counter[1];
            predict_target = bpt[predict_index].target;
        end else begin
            predict_taken  = 1'b0;
            predict_target = '0;
        end
    end

    // Update logic (2-bit saturating counter)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all entries
            for (int i = 0; i < BPU_ENTRIES; i++) begin
                bpt[i].counter <= 2'b01;  // Weakly not taken
                bpt[i].target  <= '0;
                bpt[i].valid   <= 1'b0;
            end
        end else if (update_en) begin
            // Update the entry
            bpt[update_index].valid  <= 1'b1;
            bpt[update_index].target <= actual_target;

            // 2-bit saturating counter update
            if (actual_taken) begin
                // Increment on taken (saturate at 11)
                if (bpt[update_index].counter != 2'b11) begin
                    bpt[update_index].counter <= bpt[update_index].counter + 2'b01;
                end
            end else begin
                // Decrement on not taken (saturate at 00)
                if (bpt[update_index].counter != 2'b00) begin
                    bpt[update_index].counter <= bpt[update_index].counter - 2'b01;
                end
            end
        end
    end

    // Performance monitoring (optional)
    logic [31:0] total_predictions;
    logic [31:0] correct_predictions;
    logic [31:0] incorrect_predictions;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_predictions     <= '0;
            correct_predictions   <= '0;
            incorrect_predictions <= '0;
        end else if (update_en) begin
            total_predictions <= total_predictions + 1;

            // Check if prediction was correct
            if ((bpt[update_index].counter[1] && actual_taken) ||
                (!bpt[update_index].counter[1] && !actual_taken)) begin
                correct_predictions <= correct_predictions + 1;
            end else begin
                incorrect_predictions <= incorrect_predictions + 1;
            end
        end
    end

endmodule : branch_predictor
