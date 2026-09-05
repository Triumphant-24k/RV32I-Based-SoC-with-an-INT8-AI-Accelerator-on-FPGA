`timescale 1ns/1ps
module core_tb;
    reg clk,rst;
    wire instr_req_valid,instr_req_ready,instr_rsp_valid;
    wire [31:0] instr_req_addr,instr_rsp_data;
    wire data_req_valid,data_req_ready,data_req_write,data_rsp_valid;
    wire [31:0] data_req_addr,data_req_wdata,data_rsp_rdata;
    wire [3:0] data_req_wstrb;
    wire trap_valid; wire [3:0] trap_cause; wire [31:0] trap_pc;
    reg [31:0] imem[0:255]; reg [7:0] dmem[0:1023];
    integer i,checks,instruction_checks,store_accepts;
    reg [3:0] last_store_strobe; reg [31:0] last_store_data,last_store_addr;
    reg prior_instr_wait,prior_data_wait;
    reg [31:0] prior_instr_addr,prior_data_addr,prior_data_wdata;
    reg [3:0] prior_data_wstrb; reg prior_data_write;

    assign instr_req_ready=1'b1;
    assign instr_rsp_valid=instr_req_valid;
    assign instr_rsp_data=imem[instr_req_addr[9:2]];
    assign data_req_ready=1'b1;
    assign data_rsp_valid=data_req_valid&&!data_req_write;
    assign data_rsp_rdata={dmem[{data_req_addr[9:2],2'b00}+3],
        dmem[{data_req_addr[9:2],2'b00}+2],dmem[{data_req_addr[9:2],2'b00}+1],
        dmem[{data_req_addr[9:2],2'b00}]};

    cpu_core dut(.clk(clk),.rst(rst),.instr_req_valid(instr_req_valid),
        .instr_req_ready(instr_req_ready),.instr_req_addr(instr_req_addr),
        .instr_rsp_valid(instr_rsp_valid),.instr_rsp_data(instr_rsp_data),
        .data_req_valid(data_req_valid),.data_req_ready(data_req_ready),
        .data_req_write(data_req_write),.data_req_addr(data_req_addr),
        .data_req_wdata(data_req_wdata),.data_req_wstrb(data_req_wstrb),
        .data_rsp_valid(data_rsp_valid),.data_rsp_rdata(data_rsp_rdata),
        .trap_valid(trap_valid),.trap_cause(trap_cause),.trap_pc(trap_pc));

    always #5 clk=~clk;
    always @(posedge clk) if(data_req_valid&&data_req_ready&&data_req_write) begin
        store_accepts=store_accepts+1; last_store_strobe=data_req_wstrb;
        last_store_data=data_req_wdata; last_store_addr=data_req_addr;
        if(data_req_wstrb[0]) dmem[{data_req_addr[9:2],2'b00}]=data_req_wdata[7:0];
        if(data_req_wstrb[1]) dmem[{data_req_addr[9:2],2'b00}+1]=data_req_wdata[15:8];
        if(data_req_wstrb[2]) dmem[{data_req_addr[9:2],2'b00}+2]=data_req_wdata[23:16];
        if(data_req_wstrb[3]) dmem[{data_req_addr[9:2],2'b00}+3]=data_req_wdata[31:24];
    end

    function automatic [31:0] enc_r(input [6:0] f7,input [4:0] r2,input [4:0] r1,
        input [2:0] f3,input [4:0] rd,input [6:0] op); enc_r={f7,r2,r1,f3,rd,op}; endfunction
    function automatic [31:0] enc_i(input integer imm,input [4:0] r1,input [2:0] f3,
        input [4:0] rd,input [6:0] op); enc_i={imm[11:0],r1,f3,rd,op}; endfunction
    function automatic [31:0] enc_s(input integer imm,input [4:0] r2,input [4:0] r1,
        input [2:0] f3); enc_s={imm[11:5],r2,r1,f3,imm[4:0],7'b0100011}; endfunction
    function automatic [31:0] enc_b(input integer imm,input [4:0] r2,input [4:0] r1,
        input [2:0] f3); enc_b={imm[12],imm[10:5],r2,r1,f3,imm[4:1],imm[11],7'b1100011}; endfunction
    function automatic [31:0] enc_u(input [19:0] imm,input [4:0] rd,input [6:0] op);
        enc_u={imm,rd,op}; endfunction
    function automatic [31:0] enc_j(input integer imm,input [4:0] rd);
        enc_j={imm[20],imm[10:1],imm[11],imm[19:12],rd,7'b1101111}; endfunction

    task clear_model; begin
        for(i=0;i<256;i=i+1) imem[i]=32'h00000013;
        for(i=0;i<1024;i=i+1) dmem[i]=0;
        store_accepts=0; last_store_strobe=0; last_store_data=0; last_store_addr=0;
    end endtask
    task start_case(input [31:0] inst); begin
        rst=1; clear_model(); imem[0]=inst; imem[1]=32'h00000073;
        @(negedge clk); rst=0;
    end endtask
    task set_reg(input integer n,input [31:0] value); begin
        dut.register_file_i.registers[n]=value;
    end endtask
    task wait_trap(input integer cycles); integer n; begin
        n=0; while(!trap_valid&&n<cycles) begin @(posedge clk); #1; n=n+1; end
        if(!trap_valid) $fatal(1,"timeout PC=%08x state=%0d",dut.pc,dut.state);
    end endtask
    task check32(input [31:0] got,input [31:0] expected,input [255:0] name); begin
        checks=checks+1; if(got!==expected) $fatal(1,"%0s got=%08x expected=%08x",name,got,expected);
    end endtask
    task check1(input got,input expected,input [255:0] name); begin
        checks=checks+1; if(got!==expected) $fatal(1,"%0s got=%b expected=%b",name,got,expected);
    end endtask
    task test_write(input [31:0] inst,input integer r1,input [31:0] v1,
        input integer r2,input [31:0] v2,input integer rd,input [31:0] expected,
        input [255:0] name); begin
        start_case(inst); set_reg(r1,v1); set_reg(r2,v2); wait_trap(20);
        check32(dut.register_file_i.registers[rd],expected,name);
        check32(trap_cause,11,{name," terminal ECALL"}); instruction_checks=instruction_checks+1;
    end endtask
    task test_branch(input [2:0] f3,input [31:0] a,input [31:0] b,input taken,
        input [255:0] name); begin
        rst=1; clear_model(); imem[0]=enc_b(8,2,1,f3);
        imem[1]=enc_i(1,0,3'b000,30,7'b0010011);
        imem[2]=enc_i(2,0,3'b000,31,7'b0010011); imem[3]=32'h00000073;
        @(negedge clk); rst=0; set_reg(1,a); set_reg(2,b); wait_trap(30);
        check32(dut.register_file_i.registers[30],taken?0:1,{name," path"});
        check32(dut.register_file_i.registers[31],2,{name," target"});
        instruction_checks=instruction_checks+1;
    end endtask
    task test_load(input [2:0] f3,input integer offset,input [31:0] word,
        input [31:0] expected,input [255:0] name); begin
        start_case(enc_i(offset,1,f3,5,7'b0000011)); set_reg(1,32'h100);
        dmem[256]=word[7:0];dmem[257]=word[15:8];dmem[258]=word[23:16];dmem[259]=word[31:24];
        wait_trap(25); check32(dut.register_file_i.registers[5],expected,name);
        instruction_checks=instruction_checks+1;
    end endtask
    task test_store(input [2:0] f3,input integer offset,input [31:0] value,
        input [3:0] strobe,input [31:0] expected_word,input [255:0] name); begin
        start_case(enc_s(offset,2,1,f3)); set_reg(1,32'h100);set_reg(2,value);
        dmem[256]=8'h11;dmem[257]=8'h22;dmem[258]=8'h33;dmem[259]=8'h44;
        wait_trap(25); check32(store_accepts,1,{name," accepted once"});
        check32({28'd0,last_store_strobe},{28'd0,strobe},{name," strobe"});
        check32({dmem[259],dmem[258],dmem[257],dmem[256]},expected_word,{name," bytes"});
        instruction_checks=instruction_checks+1;
    end endtask
    task test_fault(input [31:0] inst,input [3:0] cause,input [255:0] name); begin
        start_case(inst); set_reg(1,32'h100);set_reg(2,32'ha5a5a5a5);set_reg(5,32'hfeedface);
        dmem[256]=8'h11;dmem[257]=8'h22;dmem[258]=8'h33;dmem[259]=8'h44;
        wait_trap(15);check32(trap_cause,cause,{name," cause"});check32(trap_pc,0,{name," PC"});
        check32(dut.register_file_i.registers[5],32'hfeedface,{name," no register change"});
        check32(store_accepts,0,{name," no store"});
        check32({dmem[259],dmem[258],dmem[257],dmem[256]},32'h44332211,{name," memory stable"});
    end endtask

    always @(posedge clk) if(!rst) begin
        if(dut.register_file_i.registers[0]!==0) $fatal(1,"x0 changed");
        if(!trap_valid&&dut.pc[1:0]!==0) $fatal(1,"normal PC misaligned");
        if(data_req_wstrb!=0&&!(data_req_valid&&data_req_write)) $fatal(1,"strobe without store");
        if(prior_instr_wait&&(!instr_req_valid||instr_req_addr!==prior_instr_addr)) $fatal(1,"instruction request changed while stalled");
        if(prior_data_wait&&(!data_req_valid||data_req_addr!==prior_data_addr||
           data_req_write!==prior_data_write||data_req_wdata!==prior_data_wdata||
           data_req_wstrb!==prior_data_wstrb)) $fatal(1,"data request changed while stalled");
        prior_instr_wait=instr_req_valid&&!instr_req_ready;prior_instr_addr=instr_req_addr;
        prior_data_wait=data_req_valid&&!data_req_ready;prior_data_addr=data_req_addr;
        prior_data_write=data_req_write;prior_data_wdata=data_req_wdata;prior_data_wstrb=data_req_wstrb;
    end

    initial begin
        clk=0;rst=1;checks=0;instruction_checks=0;prior_instr_wait=0;prior_data_wait=0;
        clear_model();
        test_write(enc_r(0,2,1,0,5,7'b0110011),1,32'h7fffffff,2,1,5,32'h80000000,"ADD overflow");
        test_write(enc_r(7'b0100000,2,1,0,5,7'b0110011),1,0,2,1,5,32'hffffffff,"SUB wrap");
        test_write(enc_r(0,2,1,1,5,7'b0110011),1,1,2,31,5,32'h80000000,"SLL 31");
        test_write(enc_r(0,2,1,1,5,7'b0110011),1,1,2,63,5,32'h80000000,"SLL low five bits");
        test_write(enc_r(0,2,1,2,5,7'b0110011),1,32'h80000000,2,0,5,1,"SLT signed");
        test_write(enc_r(0,2,1,3,5,7'b0110011),1,32'h80000000,2,0,5,0,"SLTU unsigned");
        test_write(enc_r(0,2,1,4,5,7'b0110011),1,32'hffff0000,2,32'h0f0f0f0f,5,32'hf0f00f0f,"XOR");
        test_write(enc_r(0,2,1,5,5,7'b0110011),1,32'h80000000,2,31,5,1,"SRL 31");
        test_write(enc_r(0,2,1,5,5,7'b0110011),1,32'h80000000,2,32,5,32'h80000000,"SRL low five bits");
        test_write(enc_r(7'b0100000,2,1,5,5,7'b0110011),1,32'h80000000,2,31,5,32'hffffffff,"SRA 31");
        test_write(enc_r(7'b0100000,2,1,5,5,7'b0110011),1,32'h80000000,2,32,5,32'h80000000,"SRA low five bits");
        test_write(enc_r(0,2,1,6,5,7'b0110011),1,32'hf0000000,2,32'h0f0f0f0f,5,32'hff0f0f0f,"OR");
        test_write(enc_r(0,2,1,7,5,7'b0110011),1,32'hf0f0f0f0,2,32'h0ff00ff0,5,32'h00f000f0,"AND");
        test_write(enc_i(-2048,1,0,5,7'b0010011),1,32'h800,0,0,5,0,"ADDI min immediate");
        test_write(enc_i(2047,1,2,5,7'b0010011),1,32'h80000000,0,0,5,1,"SLTI max immediate");
        test_write(enc_i(-1,1,3,5,7'b0010011),1,0,0,0,5,1,"SLTIU negative immediate");
        test_write(enc_i(-1,1,4,5,7'b0010011),1,32'h0f0f0f0f,0,0,5,32'hf0f0f0f0,"XORI negative");
        test_write(enc_i(12'h055,1,6,5,7'b0010011),1,32'h100,0,0,5,32'h155,"ORI");
        test_write(enc_i(12'h0ff,1,7,5,7'b0010011),1,32'h12345678,0,0,5,32'h78,"ANDI");
        test_write(enc_i(31,1,1,5,7'b0010011),1,1,0,0,5,32'h80000000,"SLLI 31");
        test_write(enc_i(31,1,5,5,7'b0010011),1,32'h80000000,0,0,5,1,"SRLI 31");
        test_write(enc_i(12'h41f,1,5,5,7'b0010011),1,32'h80000000,0,0,5,32'hffffffff,"SRAI 31");
        test_load(0,0,32'h80ff7f01,32'h1,"LB offset 0");
        test_load(0,1,32'h80ff7f01,32'h7f,"LB offset 1");
        test_load(0,2,32'h80ff7f01,32'hffffffff,"LB offset 2");
        test_load(0,3,32'h80ff7f01,32'hffffff80,"LB offset 3");
        test_load(1,0,32'h80ff7f01,32'h7f01,"LH positive");
        test_load(1,2,32'h80ff7f01,32'hffff80ff,"LH negative");
        test_load(2,0,32'h80ff7f01,32'h80ff7f01,"LW"); test_load(4,3,32'h80ff7f01,32'h80,"LBU");
        test_load(4,0,32'h80ff7f01,32'h1,"LBU offset 0");
        test_load(4,1,32'h80ff7f01,32'h7f,"LBU offset 1");
        test_load(4,2,32'h80ff7f01,32'hff,"LBU offset 2");
        test_load(5,0,32'h80ff7f01,32'h7f01,"LHU lower");
        test_load(5,2,32'h80ff7f01,32'h80ff,"LHU upper");
        test_store(0,0,32'haa,4'b0001,32'h443322aa,"SB offset 0");
        test_store(0,1,32'haa,4'b0010,32'h4433aa11,"SB offset 1");
        test_store(0,2,32'haa,4'b0100,32'h44aa2211,"SB offset 2");
        test_store(0,3,32'haa,4'b1000,32'haa332211,"SB offset 3");
        test_store(1,0,32'ha1b2,4'b0011,32'h4433a1b2,"SH lower");
        test_store(1,2,32'ha1b2,4'b1100,32'ha1b22211,"SH upper");
        test_store(2,0,32'ha1b2c3d4,4'b1111,32'ha1b2c3d4,"SW");
        test_branch(0,5,5,1,"BEQ taken");test_branch(0,5,6,0,"BEQ not taken");
        test_branch(1,5,6,1,"BNE taken");test_branch(1,5,5,0,"BNE not taken");
        test_branch(4,32'hffffffff,1,1,"BLT taken");test_branch(4,1,32'hffffffff,0,"BLT not taken");
        test_branch(5,1,32'hffffffff,1,"BGE taken");test_branch(5,32'hffffffff,1,0,"BGE not taken");
        test_branch(6,1,32'hffffffff,1,"BLTU taken");test_branch(6,32'hffffffff,1,0,"BLTU not taken");
        test_branch(7,32'hffffffff,1,1,"BGEU taken");test_branch(7,1,32'hffffffff,0,"BGEU not taken");
        test_write(enc_u(20'habcde,5,7'b0110111),0,0,0,0,5,32'habcde000,"LUI");
        test_write(enc_u(20'h12345,5,7'b0010111),0,0,0,0,5,32'h12345000,"AUIPC PC zero");
        rst=1;clear_model();imem[0]=enc_j(8,5);imem[1]=32'hffffffff;imem[2]=32'h00000073;
        @(negedge clk);rst=0;wait_trap(20);check32(dut.register_file_i.registers[5],4,"JAL link");instruction_checks++;
        rst=1;clear_model();imem[0]=enc_i(0,1,0,5,7'b1100111);imem[2]=32'h00000073;
        @(negedge clk);rst=0;set_reg(1,9);wait_trap(20);check32(dut.register_file_i.registers[5],4,"JALR link/bit zero");instruction_checks++;
        start_case(32'h0000000f);wait_trap(20);check32(trap_cause,11,"FENCE safe");instruction_checks++;
        start_case(32'h00000073);wait_trap(10);check32(trap_cause,11,"ECALL");instruction_checks++;
        start_case(32'h00100073);wait_trap(10);check32(trap_cause,3,"EBREAK");instruction_checks++;

        test_fault(32'hffffffff,2,"illegal opcode");
        test_fault(32'h00003003,2,"invalid load funct3");
        test_fault(enc_r(7'b0000001,2,1,0,5,7'b0110011),2,"invalid funct7");
        test_fault(enc_i(12'h020,1,1,5,7'b0010011),2,"invalid SLLI encoding");
        test_fault(enc_i(12'h220,1,5,5,7'b0010011),2,"invalid SRLI/SRAI encoding");
        test_fault(enc_i(1,1,1,5,7'b0000011),4,"misaligned LH");
        test_fault(enc_i(1,1,2,5,7'b0000011),4,"misaligned LW");
        test_fault(enc_s(1,2,1,1),6,"misaligned SH");
        test_fault(enc_s(1,2,1,2),6,"misaligned SW");
        test_fault(enc_j(2,5),0,"misaligned JAL no link");
        test_fault(enc_i(2,1,0,5,7'b1100111),0,"misaligned JALR no link");
        rst=1;clear_model();imem[0]=enc_b(2,1,1,3'b000);@(negedge clk);rst=0;
        set_reg(1,7);wait_trap(10);check32(trap_cause,0,"taken misaligned branch traps");
        rst=1;clear_model();imem[0]=enc_b(2,2,1,3'b000);imem[1]=32'h00000073;
        @(negedge clk);rst=0;set_reg(1,7);set_reg(2,8);wait_trap(15);
        check32(trap_cause,11,"not-taken nominally misaligned branch is safe");
        rst=1;clear_model();imem[0]=enc_j(8,0);imem[1]=enc_i(0,0,0,1,7'b0010011);
        imem[2]=enc_b(-4,0,1,3'b001);imem[3]=32'h00000073;
        @(negedge clk);rst=0;set_reg(1,1);wait_trap(25);
        check32(dut.register_file_i.registers[1],0,"backward branch target executed");
        test_write(enc_i(123,0,0,0,7'b0010011),0,0,0,0,0,0,"x0 write ignored");
        test_write(32'h00000013,0,0,0,0,0,0,"NOP");

        start_case(enc_i(5,0,0,5,7'b0010011));repeat(2)@(posedge clk);rst=1;#1;
        check32(dut.pc,0,"reset PC");check32(dut.register_file_i.registers[5],0,"reset state");rst=0;
        start_case(32'h00000073);wait_trap(10);i=dut.pc;repeat(3)@(posedge clk);#1;check32(dut.pc,i,"terminal trap PC stable");
        if(instruction_checks<40) $fatal(1,"not all 40 RV32I instructions were checked");
        $display("PASS: directed core regression (%0d checks, %0d instructions)",checks,instruction_checks);
        $finish;
    end
endmodule
