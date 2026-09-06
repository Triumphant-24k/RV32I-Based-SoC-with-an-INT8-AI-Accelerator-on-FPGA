`timescale 1ns/1ps
module arty_tb;
    parameter integer CPU_ONLY=0;
    parameter ROM_HEX="build/firmware/board_rom.hex", RAM_HEX="build/firmware/board_ram.hex";
    reg clk=0,reset_n=1,rx=1;
    wire tx;wire [3:0]led;wire byte_valid;wire[7:0]byte_data;
    integer fd,clocks=0,starts=0,toggles=0;
    reg previous_heartbeat=0;
    string filename;
    // Actual 100 MHz clock. Baud/reset/LED intervals shortened for full firmware tests.
    arty_a7_top #(.CLOCK_HZ(100000000),.BAUD(10000000),.RELEASE_CYCLES(4),
        .HEARTBEAT_CYCLES(32),.ACTIVITY_CYCLES(20),.ROM_HEX(ROM_HEX),.RAM_HEX(RAM_HEX))
        dut(clk,reset_n,rx,tx,led);
    uart_monitor #(.DIVISOR(10)) monitor(clk,dut.rst,tx,byte_valid,byte_data);
    always #5 clk=~clk;
    always @(posedge byte_valid)$fwrite(fd,"%c",byte_data);
    always @(posedge clk)begin
        clocks=clocks+1;
        if(!dut.rst)begin
            if(dut.integrated.soc.trap_valid)$fatal(1,"Arty CPU trap");
            if(dut.integrated.soc.bus.accelerator.accepted_start)starts=starts+1;
            if(led[0]!=previous_heartbeat)toggles=toggles+1;
            previous_heartbeat=led[0];
        end
    end
    initial begin
        if(!$value$plusargs("UART_LOG=%s",filename))filename="build/arty_uart.txt";
        fd=$fopen(filename,"w");if(fd==0)$fatal(1,"Cannot open UART log");
        #2;if(dut.rst!==1 || led[1]!==1)$fatal(1,"Power-on reset missing");
        wait(!dut.rst);
        wait(led[2]||led[3]);
        if(led[3])$fatal(1,"Arty firmware failure");
        repeat(40)@(posedge clk);#1;
        if(!led[2]||toggles<2||starts!=(CPU_ONLY?0:26))$fatal(1,"Arty status/start/heartbeat failure");
        $fclose(fd);
        // The physical button clears persistent status and debounces release.
        @(negedge clk);reset_n=0;#1;
        if(!dut.rst || !led[1] || led[2] || led[3])$fatal(1,"Active-low button reset");
        repeat(2)@(negedge clk);reset_n=1;
        repeat(2)@(negedge clk);reset_n=0; // bounce
        @(negedge clk);reset_n=1;
        repeat(5)begin @(posedge clk);#1;if(!dut.rst)$fatal(1,"Early reset release");end
        @(posedge clk);#1;if(dut.rst)$fatal(1,"Reset stuck");
        $display("PASS: Arty wrapper real CPU CPU_ONLY=%0d, 26 cases, %0d accepted starts, %0d clocks; POR, reset, heartbeat, LEDs",CPU_ONLY,starts,clocks);
        $finish;
    end
    initial begin repeat(12000000)@(posedge clk);$fatal(1,"Arty firmware timeout");end
endmodule
