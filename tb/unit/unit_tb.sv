`timescale 1ns/1ps
module unit_tb;
    reg [31:0] a, b, instruction, store_value, read_data;
    reg [3:0] operation;
    reg [2:0] immediate_select, funct3;
    reg [1:0] offset;
    reg is_load, is_store;
    wire [31:0] result, immediate, load_value, write_data;
    wire [3:0] write_strobe;
    wire misaligned;
    wire branch_taken;
    wire [3:0] decoded_alu;
    wire [2:0] decoded_imm;
    wire [1:0] decoded_wb;
    wire decoded_alu_imm, decoded_alu_pc, decoded_reg_write, decoded_mem_read, decoded_mem_write;
    wire decoded_branch, decoded_jump, decoded_jalr, decoded_upper, decoded_fence;
    wire decoded_ecall, decoded_ebreak, decoded_illegal;
    integer checks, lane;

    alu alu_i(.a(a), .b(b), .operation(operation), .result(result));
    immediate_generator immediate_i(.instruction(instruction), .immediate_select(immediate_select), .immediate(immediate));
    load_store_unit lsu_i(.funct3(funct3), .address_offset(offset), .store_value(store_value),
        .memory_read_data(read_data), .is_load(is_load), .is_store(is_store),
        .load_value(load_value), .memory_write_data(write_data),
        .memory_write_strobe(write_strobe), .misaligned(misaligned));
    branch_unit branch_i(.operand_a(a), .operand_b(b), .funct3(funct3), .taken(branch_taken));
    control_unit control_i(.instruction(instruction), .alu_operation(decoded_alu),
        .immediate_select(decoded_imm), .writeback_select(decoded_wb),
        .alu_source_immediate(decoded_alu_imm), .alu_source_pc(decoded_alu_pc),
        .register_write(decoded_reg_write), .memory_read(decoded_mem_read),
        .memory_write(decoded_mem_write), .branch(decoded_branch), .jump(decoded_jump),
        .jump_register(decoded_jalr), .upper_immediate(decoded_upper), .fence(decoded_fence),
        .ecall(decoded_ecall), .ebreak(decoded_ebreak), .illegal_instruction(decoded_illegal));

    task check32(input [31:0] got, input [31:0] expected, input [255:0] name);
        begin checks = checks + 1; if (got !== expected) $fatal(1, "%0s: got %08x expected %08x", name, got, expected); end
    endtask
    task check1(input got, input expected, input [255:0] name);
        begin checks = checks + 1; if (got !== expected) $fatal(1, "%0s: got %b expected %b", name, got, expected); end
    endtask

    initial begin
        checks = 0; a = 0; b = 0; operation = 0; instruction = 0; immediate_select = 0;
        funct3 = 0; offset = 0; store_value = 0; read_data = 0; is_load = 0; is_store = 0;
        #1;
        a=32'h7fffffff; b=1; operation=0; #1; check32(result,32'h80000000,"ADD");
        a=5; b=7; operation=1; #1; check32(result,32'hfffffffe,"SUB");
        a=1; b=31; operation=2; #1; check32(result,32'h80000000,"SLL 31");
        b=0; #1; check32(result,1,"SLL 0");
        a=32'hffffffff; b=1; operation=3; #1; check32(result,1,"SLT signed");
        operation=4; #1; check32(result,0,"SLTU unsigned");
        operation=5; #1; check32(result,32'hfffffffe,"XOR");
        a=32'h80000000; b=31; operation=6; #1; check32(result,1,"SRL 31");
        operation=7; #1; check32(result,32'hffffffff,"SRA 31");
        a=32'hf0000000; b=32'h0f0f0f0f; operation=8; #1; check32(result,32'hff0f0f0f,"OR");
        operation=9; #1; check32(result,0,"AND");

        instruction=32'hfff00013; immediate_select=0; #1; check32(immediate,32'hffffffff,"I immediate");
        instruction=32'hfe000fa3; immediate_select=1; #1; check32(immediate,32'hffffffff,"S immediate");
        instruction=32'hfe000ee3; immediate_select=2; #1; check32(immediate,32'hfffffffc,"B immediate");
        instruction=32'habcde037; immediate_select=3; #1; check32(immediate,32'habcde000,"U immediate");
        instruction=32'hffdff06f; immediate_select=4; #1; check32(immediate,32'hfffffffc,"J immediate");

        read_data=32'h80ff7f01; is_load=1; funct3=0; offset=3; #1; check32(load_value,32'hffffff80,"LB offset 3");
        offset=0; #1; check32(load_value,32'h00000001,"LB offset 0");
        offset=1; #1; check32(load_value,32'h0000007f,"LB offset 1");
        offset=2; #1; check32(load_value,32'hffffffff,"LB offset 2");
        funct3=4; offset=3; #1; check32(load_value,32'h00000080,"LBU offset 3");
        offset=0; #1; check32(load_value,32'h00000001,"LBU offset 0");
        offset=1; #1; check32(load_value,32'h0000007f,"LBU offset 1");
        offset=2; #1; check32(load_value,32'h000000ff,"LBU offset 2");
        funct3=1; offset=2; #1; check32(load_value,32'hffff80ff,"LH offset 2"); check1(misaligned,0,"LH aligned");
        funct3=5; #1; check32(load_value,32'h000080ff,"LHU offset 2");
        funct3=2; offset=1; #1; check1(misaligned,1,"LW misaligned");
        is_load=0; is_store=1; store_value=32'h123456a5; funct3=0; offset=2; #1;
        check32(write_data,32'ha5a5a5a5,"SB data lanes"); check32({28'd0,write_strobe},4'b0100,"SB strobe");
        funct3=1; offset=2; #1; check32(write_data,32'h56a556a5,"SH data lanes"); check32({28'd0,write_strobe},4'b1100,"SH strobe");
        funct3=2; offset=0; #1; check32(write_data,store_value,"SW data"); check32({28'd0,write_strobe},4'b1111,"SW strobe");
        funct3=0;
        for(lane=0;lane<4;lane=lane+1) begin
            offset=lane[1:0]; #1; check32({28'd0,write_strobe},(32'd1<<lane),"SB every byte offset");
        end
        is_store=0; a=32'hffffffff; b=1;
        funct3=3'b100; #1; check1(branch_taken,1,"BLT signed");
        funct3=3'b110; #1; check1(branch_taken,0,"BLTU unsigned");
        instruction=32'h02001013; #1; check1(decoded_illegal,1,"invalid SLLI funct7"); check1(decoded_reg_write,0,"illegal disables register write");
        instruction=32'h00003003; #1; check1(decoded_illegal,1,"invalid load funct3"); check1(decoded_mem_read,0,"illegal disables load");
        instruction=32'h00000073; #1; check1(decoded_ecall,1,"ECALL decode");
        instruction=32'h00100073; #1; check1(decoded_ebreak,1,"EBREAK decode");
        $display("PASS: unit regression (%0d checks)", checks);
        $finish;
    end
endmodule
