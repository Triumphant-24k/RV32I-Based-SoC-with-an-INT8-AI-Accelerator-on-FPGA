// SPDX-License-Identifier: MIT
module led_test_top #(parameter integer CLOCK_HZ=1000000, RELEASE_CYCLES=1000)(
    input wire clk,input wire external_reset,output reg led
);
    localparam integer HALF_PERIOD=CLOCK_HZ/2;
    localparam integer CW=HALF_PERIOD<2?1:$clog2(HALF_PERIOD);
    localparam integer LAST_COUNT=HALF_PERIOD-1;
    reg[CW-1:0]ticks;wire rst;
    reset_conditioner #(.RELEASE_CYCLES(RELEASE_CYCLES)) reset_i(clk,external_reset,rst);
    always @(posedge clk or posedge rst)begin
        if(rst)begin ticks<=0;led<=0;end
        else if(ticks==LAST_COUNT[CW-1:0])begin ticks<=0;led<=!led;end
        else ticks<=ticks+1'b1;
    end
endmodule
