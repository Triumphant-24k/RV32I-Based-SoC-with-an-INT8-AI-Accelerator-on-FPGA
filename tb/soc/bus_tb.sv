`timescale 1ns/1ps
module bus_tb;
    reg clk=0,rst=1,iv=0,dv=0,dw=0;
    reg[31:0]ia=0,da=0,wd=0;reg[3:0]ws=0;
    wire ir,ip,dr,dp,uart,acc_busy;wire[31:0]idata,rd;wire[1:0]status;
    integer accepts=0,starts=0,checks=0,i,old_accepts;reg[31:0]value,t0,t1;
    soc_bus #(.STALL_REQUESTS(1)) dut(clk,rst,iv,ir,ia,ip,idata,dv,dr,dw,da,wd,ws,dp,rd,uart,status,acc_busy);
    always #5 clk=~clk;
    always @(posedge clk)if(!rst)begin
        if(dv&&dr)accepts=accepts+1;
        if(dut.accelerator.accepted_start)starts=starts+1;
    end
    task check(input condition,input string why);
        begin checks=checks+1;if(condition!==1'b1)$fatal(1,"bus %s",why);end
    endtask
    task transaction(input write_flag,input[31:0]address,data,input[3:0]strobe,output[31:0]response);
        integer waits;
        begin
            @(negedge clk);dv=1;dw=write_flag;da=address;wd=data;ws=strobe;
            waits=0;@(posedge clk);
            while(!dr)begin waits=waits+1;if(waits>100)$fatal(1,"bus request timeout");@(posedge clk);end
            #1;dv=0;response=0;
            if(!write_flag)begin check(dp,"registered response missing");response=rd;end
        end
    endtask
    task write32(input[31:0]address,data,input[3:0]strobe);
        reg[31:0]dummy;begin transaction(1,address,data,strobe,dummy);end
    endtask
    task read32(input[31:0]address,expected);
        reg[31:0]got;begin transaction(0,address,0,0,got);check(got===expected,"read mismatch");end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=0;
        read32(32'h40000004,0);read32(32'h4000010c,0);
        write32(32'h10000,32'h11223344,15);
        write32(32'h10001,32'haaaaaaaa,2);read32(32'h10000,32'h1122aa44);
        write32(32'h10002,32'hbbbbbbbb,12);read32(32'h10003,32'hbbbbaa44);
        write32(32'h13ffc,32'h01234567,15);read32(32'h13ffc,32'h01234567);
        write32(32'h14000,32'hdeadbeef,15);read32(32'h14000,0);read32(32'h10000,32'hbbbbaa44);
        transaction(0,0,0,0,value);write32(0,32'hffffffff,15);read32(0,value);
        @(negedge clk);iv=1;ia=0;@(posedge clk);while(!ir)@(posedge clk);
        #1;iv=0;check(ip&&idata===value,"synchronous instruction ROM");
        @(negedge clk);iv=1;ia=32'h4000;@(posedge clk);while(!ir)@(posedge clk);
        #1;iv=0;check(ip&&idata===32'hffffffff,"out-of-range instruction must trap");
        write32(32'h40000020,32'h80,15);read32(32'h40000020,32'hffffff80);
        write32(32'h40000040,32'h7f,15);read32(32'h40000041,32'h7f);
        write32(32'h40000020,55,1);write32(32'h40000021,55,15);read32(32'h40000020,32'hffffff80);
        write32(32'h40000008,55,15);write32(32'h40000004,55,15);read32(32'h40000008,0);
        write32(32'h40000060,55,15);read32(32'h40000060,0);
        write32(32'h40000200,55,15);read32(32'h40000200,0);
        read32(32'h10000,32'hbbbbaa44); // no peripheral access aliases RAM
        // Explicit held request under backpressure; it cannot start before acceptance.
        @(negedge clk);force dut.allow_request=0;
        dv=1;dw=1;da=32'h40000000;wd=1;ws=15;old_accepts=accepts;
        repeat(5)begin @(posedge clk);#1;check(!dut.acc_busy&&starts==0&&accepts==old_accepts,"stalled request side effect");end
        @(negedge clk);release dut.allow_request;
        @(posedge clk);while(!dr)@(posedge clk);#1;dv=0;
        repeat(10)@(posedge clk);#1;check(starts==1&&dut.acc_done,"single accepted start");
        read32(32'h40000008,32'hffffc080);read32(32'h4000000c,8);read32(32'h40000004,2);
        read32(32'h10000,32'hbbbbaa44);
        write32(32'h4000010c,1,1);read32(32'h4000010c,0);
        write32(32'h4000010c,1,15);read32(32'h4000010c,1);
        transaction(0,32'h40000100,0,0,t0);transaction(0,32'h40000100,0,0,t1);
        check(t1>t0,"counter not advancing");
        @(negedge clk);dut.clock_count=32'hfffffffe;
        repeat(3)@(posedge clk);#1;check(dut.clock_count==1,"counter wrap");
        @(negedge clk);rst=1;repeat(2)@(negedge clk);rst=0;
        read32(32'h4000010c,0);read32(32'h40000004,0);read32(32'h10000,32'hbbbbaa44);
        $display("PASS: bus isolation, synchronous ROM/RAM, strobes, holes, stalls, counter wrap, reset; %0d checks",checks);$finish;
    end
    initial begin #100000;$fatal(1,"bus test timeout");end
endmodule
