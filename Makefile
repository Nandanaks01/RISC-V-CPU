# RISC-V CPU Core Makefile
# Supports ModelSim simulation and Yosys synthesis

# Directories
RTL_DIR = rtl
TB_DIR = tb
PROG_DIR = programs
SIM_DIR = sim
SYNTH_DIR = synth

# RTL source files
RTL_SRCS = $(RTL_DIR)/riscv_pkg.sv \
           $(RTL_DIR)/alu.sv \
           $(RTL_DIR)/decoder.sv \
           $(RTL_DIR)/register_file.sv \
           $(RTL_DIR)/branch_predictor.sv \
           $(RTL_DIR)/forwarding_unit.sv \
           $(RTL_DIR)/hazard_detection.sv \
           $(RTL_DIR)/pipeline_regs.sv \
           $(RTL_DIR)/stage_if.sv \
           $(RTL_DIR)/stage_id.sv \
           $(RTL_DIR)/stage_ex.sv \
           $(RTL_DIR)/stage_mem.sv \
           $(RTL_DIR)/stage_wb.sv \
           $(RTL_DIR)/instruction_memory.sv \
           $(RTL_DIR)/data_memory.sv \
           $(RTL_DIR)/riscv_core.sv

# Testbench files
TB_SRCS = $(TB_DIR)/riscv_soc.sv \
          $(TB_DIR)/riscv_tb.sv

# Test programs
TEST_PROG = $(PROG_DIR)/test_program.hex
SIMPLE_PROG = $(PROG_DIR)/simple_test.hex

# Simulation tools
VSIM = vsim
VLOG = vlog
VLIB = vlib

# Synthesis tools
YOSYS = yosys

# ModelSim work library
WORK_LIB = work

# Top-level testbench
TOP_TB = riscv_tb

# Waveform file
VCD_FILE = riscv_core.vcd

.PHONY: all clean sim compile synthesis view help

# Default target
all: help

# Help
help:
	@echo "RISC-V CPU Core Build System"
	@echo "============================="
	@echo "Available targets:"
	@echo "  compile      - Compile RTL and testbench with ModelSim"
	@echo "  sim          - Run simulation with ModelSim"
	@echo "  sim-gui      - Run simulation with ModelSim GUI"
	@echo "  sim-simple   - Run simulation with simple test program"
	@echo "  synthesis    - Synthesize design with Yosys"
	@echo "  view         - View waveform with GTKWave"
	@echo "  clean        - Clean generated files"
	@echo "  help         - Show this help message"

# Create directories
$(SIM_DIR):
	mkdir -p $(SIM_DIR)

$(SYNTH_DIR):
	mkdir -p $(SYNTH_DIR)

# Compile RTL and testbench
compile: $(SIM_DIR)
	@echo "Compiling RTL sources..."
	cd $(SIM_DIR) && $(VLIB) $(WORK_LIB)
	cd $(SIM_DIR) && $(VLOG) -sv -work $(WORK_LIB) $(addprefix ../,$(RTL_SRCS))
	cd $(SIM_DIR) && $(VLOG) -sv -work $(WORK_LIB) $(addprefix ../,$(TB_SRCS))
	@echo "Compilation complete!"

# Run simulation (command-line)
sim: compile
	@echo "Running simulation..."
	cd $(SIM_DIR) && $(VSIM) -c -do "run -all; quit" $(TOP_TB)
	@echo "Simulation complete!"

# Run simulation (GUI mode)
sim-gui: compile
	@echo "Starting ModelSim GUI..."
	cd $(SIM_DIR) && $(VSIM) -gui $(TOP_TB)

# Run simulation with simple test program
sim-simple: compile
	@echo "Running simulation with simple test program..."
	cp $(SIMPLE_PROG) $(PROG_DIR)/test_program.hex
	cd $(SIM_DIR) && $(VSIM) -c -do "run -all; quit" $(TOP_TB)
	@echo "Simulation complete!"

# Synthesis with Yosys
synthesis: $(SYNTH_DIR)
	@echo "Synthesizing design with Yosys..."
	$(YOSYS) -p "read_verilog -sv $(RTL_SRCS); \
	            synth -top riscv_core; \
	            write_verilog $(SYNTH_DIR)/riscv_core_synth.v; \
	            stat"
	@echo "Synthesis complete! Output: $(SYNTH_DIR)/riscv_core_synth.v"

# View waveform
view:
	@echo "Opening waveform viewer..."
	gtkwave $(VCD_FILE) &

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	rm -rf $(SIM_DIR)
	rm -rf $(SYNTH_DIR)
	rm -f $(VCD_FILE)
	rm -f transcript
	rm -f vsim.wlf
	rm -f *.log
	@echo "Clean complete!"

# Lint check (if verilator is available)
lint:
	@echo "Running lint check..."
	verilator --lint-only -Wall -Wno-fatal $(RTL_SRCS)
	@echo "Lint check complete!"
