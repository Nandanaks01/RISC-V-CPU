# Timing Constraints for RISC-V CPU Core
# Target: Xilinx Artix-7 XC7A35T FPGA
# Target Frequency: 1 GHz (1 ns period)

# Create clock constraint
create_clock -period 1.000 -name clk -waveform {0.000 0.500} [get_ports clk]

# Input delay constraints (assuming external memory interface)
set_input_delay -clock clk -max 0.200 [get_ports {imem_data_0[*]}]
set_input_delay -clock clk -max 0.200 [get_ports {imem_data_1[*]}]
set_input_delay -clock clk -max 0.200 [get_ports {imem_ready}]
set_input_delay -clock clk -max 0.200 [get_ports {dmem_rdata[*]}]
set_input_delay -clock clk -max 0.200 [get_ports {dmem_ready}]

# Output delay constraints
set_output_delay -clock clk -max 0.200 [get_ports {imem_addr[*]}]
set_output_delay -clock clk -max 0.200 [get_ports {dmem_addr[*]}]
set_output_delay -clock clk -max 0.200 [get_ports {dmem_wdata[*]}]
set_output_delay -clock clk -max 0.200 [get_ports {dmem_wen}]
set_output_delay -clock clk -max 0.200 [get_ports {dmem_byte_en[*]}]

# Reset constraint (asynchronous)
set_false_path -from [get_ports rst_n]

# Clock uncertainty (for pessimistic analysis)
set_clock_uncertainty 0.050 [get_clocks clk]

# Maximum transition time
set_max_transition 0.100 [current_design]

# Maximum fanout
set_max_fanout 20 [current_design]

# Critical path optimization
# Prioritize timing on critical pipeline paths
set_multicycle_path -setup 1 -from [get_cells -hierarchical -filter {NAME =~ "*id_ex_reg*"}] -to [get_cells -hierarchical -filter {NAME =~ "*ex_mem_reg*"}]

# Register balancing for better timing
set_property ASYNC_REG TRUE [get_cells -hierarchical -filter {NAME =~ "*rst_n*"}]

# Note: For 1 GHz operation on Artix-7, aggressive optimizations may be needed
# This is an ambitious target and may require pipeline balancing or frequency reduction
# Realistic target for Artix-7 without extensive optimization: 100-300 MHz

# Alternative realistic constraint (100 MHz)
# create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]
