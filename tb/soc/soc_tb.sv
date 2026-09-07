`timescale 1ns/1ps
module soc_tb;
    parameter integer STALL_REQUESTS=0, CPU_ONLY=0;
    parameter ROM_HEX="firmware/hex/demo_rom.hex", RAM_HEX="firmware/hex/demo_ram.hex";
    reg clk=0,rst=1;wire uart;wire[2:0]led;
    wire byte_valid;wire[7:0]byte_data;
    integer fd,clocks=0,starts=0,pass_writes=0;
    string filename;
    ai_soc #(.ROM_HEX(ROM_HEX),.RAM_HEX(RAM_HEX),
        .STALL_REQUESTS(STALL_REQUESTS)) dut(clk,rst,uart,led,1'b1);
    uart_monitor monitor(clk,rst,uart,byte_valid,byte_data);
    always #5 clk=~clk;
    always @(posedge byte_valid) begin $fwrite(fd,"%c",byte_data);end
    always @(posedge clk) if(!rst) begin
        clocks=clocks+1;
        if(dut.trap_valid)$fatal(1,"CPU trap cause=%0d pc=%08x",dut.trap_cause,dut.trap_pc);
        if(dut.bus.accelerator.accepted_start)starts=starts+1;
        if(dut.dv&&dut.dr&&dut.dw&&dut.da==32'h4000010c)pass_writes=pass_writes+1;
        if(dut.cpu.register_file_i.registers[2] < 32'h13000 && dut.cpu.pc > 8)
            $fatal(1,"Stack outside reserved region");
    end
    initial begin
        if(!$value$plusargs("UART_LOG=%s",filename))filename="build/uart.txt";
        fd=$fopen(filename,"w");if(fd==0)$fatal(1,"Cannot open UART log");
        repeat(5)@(negedge clk);rst=0;
        wait(led[1]||led[2]);
        if(led[2])$fatal(1,"Firmware failure LED");
        repeat(30)@(posedge clk);#1;
        if(starts != (CPU_ONLY?0:26))$fatal(1,"Wrong accepted operation count: %0d",starts);
        if(pass_writes!=1)$fatal(1,"Duplicate/missing status transaction");
        if(!led[1]||led[2])$fatal(1,"Persistent status failed");
        $fclose(fd);
        $display("PASS: real CPU firmware CPU_ONLY=%0d STALL_REQUESTS=%0d clocks=%0d starts=%0d UART=%s",CPU_ONLY,STALL_REQUESTS,clocks,starts,filename);
        $finish;
    end
    initial begin repeat(5000000)@(posedge clk);$fatal(1,"SoC timeout PC=%08x",dut.cpu.pc);end
endmodule
