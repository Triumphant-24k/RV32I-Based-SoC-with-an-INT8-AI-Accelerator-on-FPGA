`timescale 1ns/1ps
module uart_tb;
    parameter integer CLOCK_HZ=1000, BAUD=100;
    localparam integer DIVISOR=CLOCK_HZ/BAUD;
    reg clk=0,rst=1,start=0;reg[7:0]data=0;
    wire tx,busy;integer bit_no,tick_no,byte_no;
    reg [9:0] expected;
    uart_tx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) dut(clk,rst,start,data,tx,busy);
    always #5 clk=~clk;
    initial begin
        repeat(2)@(negedge clk);rst=0;
        for(byte_no=0;byte_no<256;byte_no=byte_no+1)begin
            @(negedge clk);start=1;data=8'(byte_no);expected={1'b1,data,1'b0};
            @(posedge clk);#1;start=0;
            for(bit_no=0;bit_no<10;bit_no=bit_no+1)begin
                for(tick_no=0;tick_no<DIVISOR;tick_no=tick_no+1)begin
                    if(tx!==expected[bit_no]||!busy)$fatal(1,"UART timing byte=%0d bit=%0d tick=%0d",byte_no,bit_no,tick_no);
                    @(negedge clk);start=(bit_no==3);data=~8'(byte_no);
                    @(posedge clk);#1;
                end
            end
            start=0;if(busy||!tx)$fatal(1,"UART frame length/idle");
        end
        @(negedge clk);start=1;@(posedge clk);#1;start=0;
        @(negedge clk);rst=1;#1;if(busy||!tx)$fatal(1,"UART reset abort");
        $display("PASS: UART all 256 bytes, exact 8N1 timing, busy writes and reset");$finish;
    end
    initial begin repeat(256*12*DIVISOR+1000)@(posedge clk);$fatal(1,"UART test timeout");end
endmodule
