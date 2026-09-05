// SPDX-License-Identifier: MIT
// Defaults are simulation settings, NOT a statement about an allocated board.
module fpga_top #(
    parameter integer CLOCK_HZ=1000000, BAUD=100000, RELEASE_CYCLES=1000,
    parameter ROM_HEX="firmware/hex/demo_rom.hex", RAM_HEX="firmware/hex/demo_ram.hex"
)(input wire clk,input wire external_reset,output wire uart_tx_pin,output wire[2:0]led);
    wire rst;
    reset_conditioner #(.RELEASE_CYCLES(RELEASE_CYCLES)) reset_i(clk,external_reset,rst);
    ai_soc #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD),.ROM_HEX(ROM_HEX),.RAM_HEX(RAM_HEX))
        soc(clk,rst,uart_tx_pin,led);
endmodule
