# A9.RADIO_LED0
set_property PACKAGE_PIN A9   [get_ports {LED[0]}];
# B9.RADIO_LED1
set_property PACKAGE_PIN B9   [get_ports {LED[1]}];

# UART
set_property PACKAGE_PIN F8   [get_ports {HD_GPIO_1}];  # "F8.HD_GPIO_1"
set_property PACKAGE_PIN F7   [get_ports {HD_GPIO_2}];  # "F7.HD_GPIO_2"

# Set the bank voltage for IO Bank 26 to 1.8V
set_property IOSTANDARD LVCMOS18 [get_ports -of_objects [get_iobanks 26]];

# ----------------------------------------------------------------------------
# Clock Constraints
# ----------------------------------------------------------------------------
# Prevent the critical warning "Multiple clock definitions for FCLK_CLK0"
# that occurs during synthesis by adding the -add option
create_clock -period 8.000 -name ACLK -add [get_nets design_1_i/zynq_ultra_ps_e_0_pl_clk0]

# Restrict timing constraints between clocks other than ACLK
set_clock_groups -asynchronous -group [get_clocks ACLK]
