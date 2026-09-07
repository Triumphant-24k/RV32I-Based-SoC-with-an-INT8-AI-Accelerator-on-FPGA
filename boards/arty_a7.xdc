## Digilent Arty A7 Board Constraints for RV32I SoC with INT8 Accelerator
## Ports: clk, external_reset, uart_tx_pin, led[0], led[1], led[2]

## 100 MHz Onboard Crystal Oscillator
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

## Reset: BTN0 (active-high button matches reset_conditioner.sv)
set_property PACKAGE_PIN D9 [get_ports external_reset]
set_property IOSTANDARD LVCMOS33 [get_ports external_reset]

## USB-UART Bridge: FPGA TX -> PC RX
set_property PACKAGE_PIN D10 [get_ports uart_tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]

## LEDs
# led[0]: Accelerator Busy (LD4 green LED)
set_property PACKAGE_PIN H5 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

# led[1]: Firmware PASS (LD5 green LED)
set_property PACKAGE_PIN J5 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

# led[2]: Firmware FAIL or CPU Trap (LD6 green LED)
set_property PACKAGE_PIN T9 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
