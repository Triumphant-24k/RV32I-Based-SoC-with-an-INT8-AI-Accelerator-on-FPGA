# TEMPLATE ONLY. No board/part/pin/voltage is confirmed.
# Make a board-specific copy; replace this error only after checking the schematic.
error "Unconfigured board: verified PACKAGE_PIN and IOSTANDARD values required"
# Required fpga_top ports: clk, external_reset, uart_tx_pin, led[0], led[1], led[2].
# Example SYNTAX ONLY (not a pin recommendation):
# set_property PACKAGE_PIN <verified_package_pin> [get_ports <port_name>]
# set_property IOSTANDARD <verified_io_standard> [get_ports <port_name>]
# scripts/vivado_prepare.tcl creates the clock from the confirmed CLOCK_HZ.
# Add justified input/output timing and asynchronous reset constraints specific
# to the board. Do not blanket-disable DRCs or unconstrained-path reporting.
