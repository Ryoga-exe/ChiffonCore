# simulation.tcl - Create simulation project

# --- Project settings ----------------------------------
set project_dir "./simulation"
set project_name "simulation"
set part "xczu3eg-sbva484-1-i"

set script_dir [file dirname [file normalize [info script]]]

# create (or overwrite) project
create_project $project_name $project_dir -part $part -force
set_property BOARD_PART avnet.com:ultra96v2:part0:1.2 [current_project]

# --- Add RTL Sources -----------------------------------
add_files -fileset sources_1 [glob target/*.sv]
add_files -fileset sources_1 target/top.v
update_compile_order -fileset sources_1

# --- Add Testbench -------------------------------------
add_files -fileset sim_1 [glob test/tb/*.sv]
add_files -fileset sim_1 [glob test/hex/*hex]

# --- Create Block Design: top + axi_vip ----------------
set design_name "design_1"
create_bd_design $design_name

# BD ports
set ACLK    [create_bd_port -dir I ACLK]
set ARESETN [create_bd_port -dir I ARESETN]

set UART_RX [create_bd_port -dir I UART_RX]
set UART_TX [create_bd_port -dir O UART_TX]

# regbus
set WRADDR [create_bd_port -dir I -from 15 -to 0 WRADDR]
set BYTEEN [create_bd_port -dir I -from 3  -to 0 BYTEEN]
set WREN   [create_bd_port -dir I WREN]
set WDATA  [create_bd_port -dir I -from 31 -to 0 WDATA]
set RDADDR [create_bd_port -dir I -from 15 -to 0 RDADDR]
set RDEN   [create_bd_port -dir I RDEN]
set RDATA  [create_bd_port -dir O -from 31 -to 0 RDATA]

set DEBUG  [create_bd_port -dir O -from 31 -to 0 DEBUG]

# axi_vip (slave)
set axi_vip_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vip:1.1 axi_vip_0]
set_property CONFIG.INTERFACE_MODE {SLAVE} $axi_vip_0

# top module reference
set block_name top
set block_cell_name top_0
set top_0 [create_bd_cell -type module -reference $block_name $block_cell_name]

# interface connection (Vivado infers M_AXI interface from M_AXI_* signals)
connect_bd_intf_net -intf_net top_0_M_AXI [get_bd_intf_pins axi_vip_0/S_AXI] [get_bd_intf_pins top_0/M_AXI]

# clock/reset
connect_bd_net [get_bd_ports ACLK]    [get_bd_pins top_0/ACLK]    [get_bd_pins axi_vip_0/aclk]
connect_bd_net [get_bd_ports ARESETN] [get_bd_pins top_0/ARESETN] [get_bd_pins axi_vip_0/aresetn]

# regbus
connect_bd_net [get_bd_ports WRADDR] [get_bd_pins top_0/WRADDR]
connect_bd_net [get_bd_ports BYTEEN] [get_bd_pins top_0/BYTEEN]
connect_bd_net [get_bd_ports WREN]   [get_bd_pins top_0/WREN]
connect_bd_net [get_bd_ports WDATA]  [get_bd_pins top_0/WDATA]
connect_bd_net [get_bd_ports RDADDR] [get_bd_pins top_0/RDADDR]
connect_bd_net [get_bd_ports RDEN]   [get_bd_pins top_0/RDEN]
connect_bd_net [get_bd_ports RDATA]  [get_bd_pins top_0/RDATA]

# uart
connect_bd_net [get_bd_ports UART_RX] [get_bd_pins top_0/UART_RX]
connect_bd_net [get_bd_ports UART_TX] [get_bd_pins top_0/UART_TX]

# debug
connect_bd_net [get_bd_ports DEBUG] [get_bd_pins top_0/DEBUG]

# Address segment (required by IPI; not used by slv_mem agent behavior in TB)
assign_bd_address -offset 0x00000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces top_0/M_AXI] [get_bd_addr_segs axi_vip_0/S_AXI/Reg] -force

validate_bd_design
save_bd_design

# --- Generate BD wrapper and add it --------------------
generate_target all [get_files ${design_name}.bd]
set wrapper_file [make_wrapper -files [get_files ${design_name}.bd] -top]
add_files -norecurse $wrapper_file

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "DONE: Project created at: $project_dir"
puts "Next: In GUI, Flow Navigator > Run Simulation > Run Behavioral Simulation"
