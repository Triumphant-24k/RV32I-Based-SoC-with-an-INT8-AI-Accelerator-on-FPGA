`timescale 1ns/1ps
module accelerator_tb;
    reg clk=0, rst=1, we=0;
    reg [7:0] addr=0; reg [31:0] wd=0; reg [3:0] ws=15;
    wire [31:0] rd,cycles; wire busy,done; wire signed [31:0] result;
    reg [31:0] vectors [0:266*17-1];
    integer c,i,t,abort_age,checks=0;
    reg [31:0] old_result;
    int8_accelerator dut(clk,rst,we,addr,wd,ws,rd,busy,done,result,cycles);
    always #5 clk=~clk;
    task check(input condition,input string why);
        begin checks=checks+1; if(condition !== 1'b1) $fatal(1,"%s case=%0d cycle=%0d",why,c,t); end
    endtask
    task write_reg(input [7:0] offset,input [31:0] value,input [3:0] strobe);
        begin @(negedge clk);addr=offset;wd=value;ws=strobe;we=1;
            @(posedge clk);#1;we=0;end
    endtask
    task read_check(input [7:0] offset,input [31:0] expected);
        begin addr=offset;#1;check(rd===expected,"MMIO readback");end
    endtask
    task reset_dut;
        begin @(negedge clk);rst=1;we=0;repeat(2)@(posedge clk);
            @(negedge clk);rst=0;#1;check(!busy&&!done&&result==0&&cycles==0,"reset state");end
    endtask
    initial begin
        $readmemh("verification/vectors/cases.hex",vectors);
        reset_dut();
        for(c=0;c<266;c=c+1) begin
            old_result=result;
            for(i=0;i<8;i=i+1) begin
                write_reg(8'h20+8'(4*i),vectors[c*17+i],15);
                read_check(8'h20+8'(4*i),vectors[c*17+i]);
                write_reg(8'h40+8'(4*i),vectors[c*17+8+i],15);
                read_check(8'h40+8'(4*i),vectors[c*17+8+i]);
            end
            // Unsupported strobes, unaligned writes, read-only and holes have no effects.
            write_reg(8'h20,123,1); write_reg(8'h21,456,15);
            write_reg(8'h04,0,15);write_reg(8'h08,0,15);write_reg(8'h0c,99,15);
            write_reg(8'h1c,55,15);read_check(8'h1c,0);
            read_check(8'h20,vectors[c*17]);read_check(8'h08,old_result);
            write_reg(0,1,1);check(!busy,"partial start ignored");
            write_reg(0,0,15);check(!busy,"zero start ignored");
            write_reg(0,1,15);check(busy&&!done&&cycles==0,"accepted start");
            for(t=1;t<=8;t=t+1) begin
                @(negedge clk);
                // Attempt both kinds of forbidden write, including the last compute edge.
                we=1;ws=15;addr=(t%3==0)?8'h40:((t%2==0)?8'h20:8'h00);wd=1;
                @(posedge clk);#1;we=0;
                check(cycles==32'(t),"cycle counter");
                if(t<8) check(busy&&!done&&result===old_result,"no premature completion");
                else check(!busy&&done&&result===vectors[c*17+16],"final signed sum");
            end
            read_check(8'h20,vectors[c*17]);read_check(8'h40,vectors[c*17+8]);
            read_check(8'h05,2);read_check(8'h08,vectors[c*17+16]);read_check(8'h0c,8);
            repeat(3) begin @(posedge clk);#1;check(done&&!busy&&result===vectors[c*17+16],"persistence");end
        end
        // Reset at every possible in-flight age; an aborted operation must never complete.
        for(abort_age=0;abort_age<8;abort_age=abort_age+1) begin
            write_reg(0,1,15);
            repeat(abort_age)@(posedge clk);
            reset_dut();
            repeat(10) begin @(posedge clk);#1;check(!done&&!busy&&result==0,"aborted operation resurrected");end
            for(i=0;i<8;i=i+1)begin read_check(8'h20+8'(i*4),0);read_check(8'h40+8'(i*4),0);end
        end
        // A fresh operation after abort must still complete.
        write_reg(8'h3c,-128,15);write_reg(8'h5c,127,15);write_reg(0,1,15);
        repeat(8)@(posedge clk);#1;check(done&&result==-16256,"post-reset restart");
        reset_dut();
        $display("PASS: accelerator 266 vectors, all reset ages, busy writes, MMIO, %0d checks",checks);
        $finish;
    end
    initial begin #2000000;$fatal(1,"accelerator test timeout");end
endmodule
