// SPDX-License-Identifier: MIT
// Repeated ASCII U gives a recognizable 01010101 pattern on a scope/terminal.
module uart_test_top #(parameter integer CLOCK_HZ=1000000, BAUD=100000, RELEASE_CYCLES=1000)(
    input wire clk,input wire external_reset,output wire uart_tx_pin
);
    wire rst,busy;
    reset_conditioner #(.RELEASE_CYCLES(RELEASE_CYCLES)) reset_i(clk,external_reset,rst);
    uart_tx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) transmitter(
        .clk(clk),.rst(rst),.start(!busy),.data(8'h55),.tx(uart_tx_pin),.busy(busy));
endmodule
