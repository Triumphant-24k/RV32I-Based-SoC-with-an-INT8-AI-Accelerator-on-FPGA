// SPDX-License-Identifier: MIT
module uart_tx #(parameter integer CLOCK_HZ=1000000, BAUD=100000)(
    input wire clk, input wire rst, input wire start, input wire [7:0] data,
    output wire tx, output wire busy
);
    localparam integer DIVISOR = CLOCK_HZ / BAUD;
    localparam integer CW = (DIVISOR < 2) ? 1 : $clog2(DIVISOR);
    localparam integer RELOAD = DIVISOR-1;
    reg [CW-1:0] ticks;
    reg [3:0] remaining;
    reg [9:0] frame;
    assign busy = remaining != 0;
    assign tx = busy ? frame[0] : 1'b1;
    always @(posedge clk or posedge rst) begin
        if (rst) begin ticks<=0; remaining<=0; frame<=10'h3ff; end
        else if (!busy) begin
            if (start) begin
                frame <= {1'b1,data,1'b0}; remaining<=10; ticks<=RELOAD[CW-1:0];
            end
        end else if (ticks == 0) begin
            frame <= {1'b1,frame[9:1]}; remaining <= remaining-1'b1;
            ticks <= RELOAD[CW-1:0];
        end else ticks <= ticks-1'b1;
    end
`ifndef SYNTHESIS
    initial if (BAUD <= 0 || CLOCK_HZ < BAUD*4)
        $fatal(1,"UART requires at least four clock ticks per bit");
`endif
endmodule
