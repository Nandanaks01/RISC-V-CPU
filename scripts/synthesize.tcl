# Yosys Synthesis Script for RISC-V CPU Core
# Target: Xilinx Artix-7 FPGA

# Read design files
read_verilog -sv ../rtl/riscv_pkg.sv
read_verilog -sv ../rtl/alu.sv
read_verilog -sv ../rtl/decoder.sv
read_verilog -sv ../rtl/register_file.sv
read_verilog -sv ../rtl/branch_predictor.sv
read_verilog -sv ../rtl/forwarding_unit.sv
read_verilog -sv ../rtl/hazard_detection.sv
read_verilog -sv ../rtl/pipeline_regs.sv
read_verilog -sv ../rtl/stage_if.sv
read_verilog -sv ../rtl/stage_id.sv
read_verilog -sv ../rtl/stage_ex.sv
read_verilog -sv ../rtl/stage_mem.sv
read_verilog -sv ../rtl/stage_wb.sv
read_verilog -sv ../rtl/instruction_memory.sv
read_verilog -sv ../rtl/data_memory.sv
read_verilog -sv ../rtl/riscv_core.sv

# Hierarchy check
hierarchy -check -top riscv_core

# High-level synthesis
proc; opt; fsm; opt; memory; opt

# Technology mapping for Xilinx
synth_xilinx -top riscv_core -family xc7

# Optimization
opt -full

# Report statistics
stat

# Write synthesized netlist
write_verilog -noattr ../synth/riscv_core_synth.v

# Write EDIF for FPGA tools (if needed)
# write_edif ../synth/riscv_core.edif

# Write JSON for nextpnr (if using open-source flow)
write_json ../synth/riscv_core.json

# Print resource utilization
tee -o ../synth/synthesis_report.txt stat
