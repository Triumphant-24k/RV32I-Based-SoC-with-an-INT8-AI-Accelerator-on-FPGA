`timescale 1ns/1ps
module board_tb;
    reg clk=0,ext=0;wire rst,led,tx;wire bv;wire[7:0]bd;
    integer i,toggles=0,bytes=0;reg last_led=0;
    always #5 clk=~clk;
    reset_conditioner #(.RELEASE_CYCLES(4)) rc(clk,ext,rst);
    led_test_top #(.CLOCK_HZ(20),.RELEASE_CYCLES(4)) lt(clk,ext,led);
    uart_test_top #(.CLOCK_HZ(1000),.BAUD(100),.RELEASE_CYCLES(4)) ut(clk,ext,tx);
    uart_monitor monitor(clk,rst,tx,bv,bd);
    always @(posedge bv)begin if(bd!==8'h55)$fatal(1,"UART bring-up pattern");bytes=bytes+1;end
    always @(negedge clk)if(!rst)begin if(led!=last_led)toggles=toggles+1;last_led=led;end
    initial begin
        #2;ext=1;#1;if(!rst)$fatal(1,"Reset did not assert asynchronously");
        repeat(2)@(negedge clk);ext=0;
        repeat(3)@(negedge clk);ext=1; // button bounce restarts release interval
        #1;if(!rst)$fatal(1,"Bounce not caught");
        @(negedge clk);ext=0;
        for(i=0;i<6;i=i+1)begin @(posedge clk);#1;if(i<5&&!rst)$fatal(1,"Early reset release");end
        if(rst)$fatal(1,"Reset failed to release");
        repeat(350)@(posedge clk);#1;
        if(toggles<30||bytes<3)$fatal(1,"Bring-up outputs inactive");
        $display("PASS: reset synchronization/debounce, LED and decoded UART bring-up");$finish;
    end
    initial begin #100000;$fatal(1,"board test timeout");end
endmodule
