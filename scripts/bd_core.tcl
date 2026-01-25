# pynq_core_bd.tcl - Patch an existing design_1 BD (created by bd_base.tcl)
# Adds:
#   - module-ref core (module name: top) as core_0
#   - SmartConnect to route core_0 M_AXI to PS S_AXI_HP1_FPD
#   - regbus wiring: core shares regbus control plane at 0x1000.. (RDATA_OPT0)
#   - LED wiring: core LED[1:0] drives BD port LED (2 bits) via xlslice
#
# This expects the following cells to exist (from pynq_draw.tcl):
#   - zynq_ultra_ps_e_0
#   - regbus_0
#   - rst_ps8_0_125M
#   - LED BD port (2-bit)
#
# If your base BD uses different names, adjust get_bd_* selectors below.

# Ensure we are on design_1
current_bd_design [get_bd_designs design_1]

# --------------------------------------------------------
# 1) Add core as module reference
# --------------------------------------------------------
if {[llength [get_bd_cells -quiet core_0]] == 0} {
    set core_0 [create_bd_cell -type module -reference top core_0]
} else {
    set core_0 [get_bd_cells core_0]
}

# --------------------------------------------------------
# 2) SmartConnect for core M_AXI -> PS HP1
# --------------------------------------------------------
if {[llength [get_bd_cells -quiet smartconnect_core]] == 0} {
    set smartconnect_core [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_core]
    set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $smartconnect_core
} else {
    set smartconnect_core [get_bd_cells smartconnect_core]
}

# Interface connections
# core_0 M_AXI -> smartconnect_core S00_AXI
connect_bd_intf_net -quiet \
  [get_bd_intf_pins core_0/M_AXI] \
  [get_bd_intf_pins smartconnect_core/S00_AXI]

# smartconnect_core M00_AXI -> PS HP1
connect_bd_intf_net -quiet \
  [get_bd_intf_pins smartconnect_core/M00_AXI] \
  [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP1_FPD]

# Clock / reset
connect_bd_net -quiet \
  [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
  [get_bd_pins core_0/ACLK] \
  [get_bd_pins smartconnect_core/aclk]

connect_bd_net -quiet \
  [get_bd_pins rst_ps8_0_125M/peripheral_aresetn] \
  [get_bd_pins core_0/ARESETN] \
  [get_bd_pins smartconnect_core/aresetn]

# --------------------------------------------------------
# 3) regbus wiring (bootctrl plane)
#    We map core RDATA into regbus_0/RDATA_OPT0 (0x1000..0x1FFF in your notebooks)
# --------------------------------------------------------
# Common control signals (broadcast)
foreach {sig} {BYTEEN RDADDR RDEN WDATA WRADDR WREN} {
    # regbus_0/<sig> -> core_0/<sig>
    connect_bd_net -quiet \
      [get_bd_pins regbus_0/$sig] \
      [get_bd_pins core_0/$sig]
}

# Disconnect regbus_0/RDATA_OPT0 from xlconstant_0 (if connected)
# In your generated BD, xlconstant_0_dout drives multiple RDATA_* including OPT0.
set opt0_pin [get_bd_pins regbus_0/RDATA_OPT0]
set opt0_net [get_bd_nets -quiet -of_objects $opt0_pin]
if {$opt0_net ne ""} {
    # detach OPT0 from its current driver net
    disconnect_bd_net -quiet $opt0_net $opt0_pin
}

# Connect core RDATA -> regbus OPT0
connect_bd_net -quiet \
  [get_bd_pins core_0/RDATA] \
  [get_bd_pins regbus_0/RDATA_OPT0]

# --------------------------------------------------------
# 4) LED wiring: core_0/LED[1:0] -> BD port LED[1:0]
#    Base design uses LED for fifo flags; we re-route for CPU bring-up.
# --------------------------------------------------------
# Detach existing LED connection if any
set led_port [get_bd_ports LED]
set led_net  [get_bd_nets -quiet -of_objects $led_port]
if {$led_net ne ""} {
    disconnect_bd_net -quiet $led_net $led_port
}

# Create xlslice to take LED[1:0] out of core_0 LED[7:0]
if {[llength [get_bd_cells -quiet xlslice_core_led]] == 0} {
    set xlslice_core_led [create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_core_led]
    set_property -dict [list \
        CONFIG.DIN_WIDTH {8} \
        CONFIG.DIN_FROM  {1} \
        CONFIG.DIN_TO    {0} \
        CONFIG.DOUT_WIDTH {2} \
    ] $xlslice_core_led
} else {
    set xlslice_core_led [get_bd_cells xlslice_core_led]
}

connect_bd_net -quiet \
  [get_bd_pins core_0/LED] \
  [get_bd_pins xlslice_core_led/Din]

connect_bd_net -quiet \
  [get_bd_pins xlslice_core_led/Dout] \
  $led_port

# --------------------------------------------------------
# 5) Tie-off UART_RX if core_0 has it (optional)
#    (your current top.v drives UART_TX to 1'b1 anyway; RX is unused)
# --------------------------------------------------------
if {[llength [get_bd_pins -quiet core_0/UART_RX]] != 0} {
    if {[llength [get_bd_cells -quiet xlconstant_uart_rx]] == 0} {
        set xlconstant_uart_rx [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_uart_rx]
        set_property -dict [list CONFIG.CONST_VAL {1} CONFIG.CONST_WIDTH {1}] $xlconstant_uart_rx
    } else {
        set xlconstant_uart_rx [get_bd_cells xlconstant_uart_rx]
    }
    connect_bd_net -quiet \
      [get_bd_pins xlconstant_uart_rx/dout] \
      [get_bd_pins core_0/UART_RX]
}

# Done
validate_bd_design
