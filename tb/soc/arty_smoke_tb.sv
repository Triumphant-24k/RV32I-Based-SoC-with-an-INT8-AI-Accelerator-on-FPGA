`timescale 1ns/1ps
module arty_smoke_tb;
    reg clk=0,reset_n=1,rx=1;
    wire tx,led_tx;wire[3:0]led,led_only;
    wire bv;wire[7:0]bd;
    integer bytes=0,i;
    reg [55:0] greeting={"Hello",8'h0d,8'h0a};
    // UART uses the real Arty defaults: 100 MHz / 115200 = 868 clocks per bit.
    arty_a7_top #(.MODE(1),.RELEASE_CYCLES(4),.HEARTBEAT_CYCLES(10),.ACTIVITY_CYCLES(20))
        uart_dut(clk,reset_n,rx,tx,led);
    arty_a7_top #(.MODE(2),.RELEASE_CYCLES(4),.HEARTBEAT_CYCLES(10),.ACTIVITY_CYCLES(20))
        led_dut(clk,reset_n,rx,led_tx,led_only);
    uart_monitor #(.DIVISOR(868)) monitor(clk,uart_dut.rst,tx,bv,bd);
    always #5 clk=~clk;
    always @(posedge bv)begin
        if(bd!==greeting[55-8*(bytes%7)-:8])$fatal(1,"Standalone greeting byte %0d got=%02x",bytes,bd);
        bytes=bytes+1;
    end
    initial begin
        wait(led_dut.rst===0);
        for(i=0;i<10;i=i+1)begin @(posedge clk);#1;if(i<9&&led_only[0])$fatal(1,"Early heartbeat");end
        if(!led_only[0]||!led_tx||led_only[3:2]!=0)$fatal(1,"LED smoke output");
        @(negedge clk);rx=0;
        repeat(4)@(posedge clk);#1;if(!led_only[1])$fatal(1,"RX activity not synchronized");
        @(negedge clk);rx=1;
        repeat(25)@(posedge clk);#1;if(led_only[1])$fatal(1,"RX activity did not expire");
        wait(bytes==7);repeat(900)@(posedge clk);
        @(negedge clk);reset_n=0;#1;
        if(!led[1]||!led_only[1]||led_only[0])$fatal(1,"Reset indication");
        repeat(2)@(negedge clk);reset_n=1;
        wait(bytes==14);
        $display("PASS: Arty standalone LED/reset/RX activity and 2 decoded Hello messages at 100 MHz/115200 baud");$finish;
    end
    initial begin repeat(200000)@(posedge clk);$fatal(1,"Arty smoke timeout");end
endmodule
