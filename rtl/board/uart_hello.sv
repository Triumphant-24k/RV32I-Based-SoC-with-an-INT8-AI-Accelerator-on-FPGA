// SPDX-License-Identifier: MIT
// Standalone smoke test; repeats Hello + CR/LF once per second without a CPU.
module uart_hello #(parameter integer CLOCK_HZ=100000000, BAUD=115200)(
    input wire clk,input wire rst,output wire tx
);
    localparam integer CW=CLOCK_HZ<2?1:$clog2(CLOCK_HZ);
    localparam integer PAUSE_LAST=CLOCK_HZ-1;
    reg [CW-1:0] pause_count;
    reg [2:0] index;
    reg wait_busy;
    reg [7:0] data;
    wire busy;
    wire start=pause_count==0 && !busy && !wait_busy;
    always @* case(index)
        0:data="H";1:data="e";2:data="l";3:data="l";4:data="o";
        5:data=8'h0d;default:data=8'h0a;
    endcase
    uart_tx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) tx_i(clk,rst,start,data,tx,busy);
    always @(posedge clk or posedge rst)begin
        if(rst)begin pause_count<=0;index<=0;wait_busy<=0;end
        else if(pause_count!=0)pause_count<=pause_count-1'b1;
        else if(start)wait_busy<=1;
        else if(wait_busy && !busy)begin
            wait_busy<=0;
            if(index==6)begin index<=0;pause_count<=PAUSE_LAST[CW-1:0];end
            else index<=index+1'b1;
        end
    end
endmodule
