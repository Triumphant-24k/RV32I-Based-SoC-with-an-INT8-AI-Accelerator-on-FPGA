`timescale 1ns/1ps
module memory_case #(
    parameter INSTR_DELAY=0, parameter DATA_DELAY=0,
    parameter RANDOM_DELAYS=0, parameter REQUEST_BACKPRESSURE=0,
    parameter CASE_NAME="zero-wait"
)(input wire clk,input wire rst,output reg done);
    wire iv,ir,ip; wire [31:0] ia,id;
    wire dv,dr,dw,dp; wire [31:0] da,dd,qr; wire [3:0] ds;
    wire tv; wire [3:0] tc; wire [31:0] tp;
    integer cycles,stores;
    reg old_i_wait,old_d_wait; reg [31:0] old_ia,old_da,old_dd;
    reg old_dw; reg [3:0] old_ds;

    cpu_core core(.clk(clk),.rst(rst),.instr_req_valid(iv),.instr_req_ready(ir),
        .instr_req_addr(ia),.instr_rsp_valid(ip),.instr_rsp_data(id),
        .data_req_valid(dv),.data_req_ready(dr),.data_req_write(dw),
        .data_req_addr(da),.data_req_wdata(dd),.data_req_wstrb(ds),
        .data_rsp_valid(dp),.data_rsp_rdata(qr),.trap_valid(tv),.trap_cause(tc),.trap_pc(tp));
    simulation_memory #(.INSTR_DELAY(INSTR_DELAY),.DATA_DELAY(DATA_DELAY),
        .RANDOM_DELAYS(RANDOM_DELAYS),.MAX_RANDOM_DELAY(7),
        .REQUEST_BACKPRESSURE(REQUEST_BACKPRESSURE)) memory(.clk(clk),.rst(rst),
        .instr_req_valid(iv),.instr_req_ready(ir),.instr_req_addr(ia),
        .instr_rsp_valid(ip),.instr_rsp_data(id),.data_req_valid(dv),
        .data_req_ready(dr),.data_req_write(dw),.data_req_addr(da),
        .data_req_wdata(dd),.data_req_wstrb(ds),.data_rsp_valid(dp),.data_rsp_rdata(qr));

    always @(posedge clk) if(!rst) begin
        if(old_i_wait&&(!iv||ia!==old_ia)) $fatal(1,"%0s instruction request unstable",CASE_NAME);
        if(old_d_wait&&(!dv||da!==old_da||dw!==old_dw||dd!==old_dd||ds!==old_ds))
            $fatal(1,"%0s data request unstable",CASE_NAME);
        if(ds!=0&&!(dv&&dw)) $fatal(1,"%0s strobes outside store",CASE_NAME);
        if(dv&&dr&&dw) stores=stores+1;
        old_i_wait=iv&&!ir;old_ia=ia;old_d_wait=dv&&!dr;old_da=da;
        old_dw=dw;old_dd=dd;old_ds=ds;
    end

    initial begin
        done=0;cycles=0;stores=0;old_i_wait=0;old_d_wait=0;
        #1;
        memory.instruction_memory[0]=32'h10000093; // addi x1,x0,0x100
        memory.instruction_memory[1]=32'h05500113; // addi x2,x0,0x55
        memory.instruction_memory[2]=32'h0020a023; // sw x2,0(x1)
        memory.instruction_memory[3]=32'h0000a183; // lw x3,0(x1)
        memory.instruction_memory[4]=32'h00118213; // addi x4,x3,1
        memory.instruction_memory[5]=32'h00000073; // ecall
        wait(!rst);
        while(!tv&&cycles<500) begin @(posedge clk);#1;cycles=cycles+1;end
        if(!tv) $fatal(1,"%0s timeout",CASE_NAME);
        if(tc!==11||tp!==20) $fatal(1,"%0s trap mismatch cause=%0d pc=%0d",CASE_NAME,tc,tp);
        if(core.register_file_i.registers[3]!==32'h55) $fatal(1,"%0s delayed load failed",CASE_NAME);
        if(core.register_file_i.registers[4]!==32'h56) $fatal(1,"%0s resume failed",CASE_NAME);
        if(stores!==1) $fatal(1,"%0s store accepted %0d times",CASE_NAME,stores);
        if({memory.data_memory[259],memory.data_memory[258],memory.data_memory[257],memory.data_memory[256]}!==32'h55)
            $fatal(1,"%0s store data failed",CASE_NAME);
        $display("PASS: %0s memory mode (%0d cycles, one store)",CASE_NAME,cycles);
        done=1;
    end
endmodule

module memory_wait_tb;
    reg clk,rst; wire zero_done,fixed_done,random_done;
    always #5 clk=~clk;
    memory_case #(.CASE_NAME("zero-wait")) zero_case(clk,rst,zero_done);
    memory_case #(.INSTR_DELAY(3),.DATA_DELAY(4),.CASE_NAME("fixed-delay")) fixed_case(clk,rst,fixed_done);
    memory_case #(.RANDOM_DELAYS(1),.REQUEST_BACKPRESSURE(1),.CASE_NAME("random-delay/backpressure")) random_case(clk,rst,random_done);
    initial begin clk=0;rst=1;repeat(2)@(negedge clk);rst=0;
        wait(zero_done&&fixed_done&&random_done);
        $display("PASS: memory-wait regression (3 modes)");$finish;
    end
endmodule
