`timescale 1ns/1ps
module uart_monitor #(parameter integer DIVISOR=10)(
    input wire clk,input wire rst,input wire tx,
    output reg byte_valid=0,output reg [7:0] byte_data=0
);
    integer bit_number;
    initial forever begin
        @(negedge tx);
        if(!rst) begin
            repeat(DIVISOR/2)@(posedge clk);#1;
            if(tx!==0)$fatal(1,"UART bad start bit");
            for(bit_number=0;bit_number<8;bit_number=bit_number+1)begin
                repeat(DIVISOR)@(posedge clk);#1;byte_data[bit_number]=tx;
            end
            repeat(DIVISOR)@(posedge clk);#1;
            if(tx!==1)$fatal(1,"UART bad stop bit");
            byte_valid=1;
            @(posedge clk);#1;byte_valid=0;
        end
    end
endmodule
