module cpu_core (
    input wire clk, input wire rst,
    output wire instr_req_valid, input wire instr_req_ready,
    output wire [31:0] instr_req_addr,
    input wire instr_rsp_valid, input wire [31:0] instr_rsp_data,
    output wire data_req_valid, input wire data_req_ready,
    output wire data_req_write, output wire [31:0] data_req_addr,
    output wire [31:0] data_req_wdata, output wire [3:0] data_req_wstrb,
    input wire data_rsp_valid, input wire [31:0] data_rsp_rdata,
    output reg trap_valid, output reg [3:0] trap_cause, output reg [31:0] trap_pc
);
    localparam WB_PC4 = 2'd2;
    localparam FETCH_REQ=3'd0, FETCH_RSP=3'd1, EXECUTE=3'd2,
               DATA_REQ=3'd3, DATA_RSP=3'd4, TRAPPED=3'd5;
    localparam CAUSE_INSTR_MISALIGNED=4'd0, CAUSE_ILLEGAL=4'd2,
               CAUSE_BREAKPOINT=4'd3, CAUSE_LOAD_MISALIGNED=4'd4,
               CAUSE_STORE_MISALIGNED=4'd6, CAUSE_ECALL_M=4'd11;

    reg [2:0] state;
    reg [31:0] pc, instruction;
    reg pending_write;
    reg [31:0] pending_addr, pending_wdata;
    reg [3:0] pending_wstrb;
    reg [4:0] pending_rd;
    reg [2:0] pending_funct3;
    reg [1:0] pending_offset;

    wire [4:0] rd=instruction[11:7], rs1=instruction[19:15], rs2=instruction[24:20];
    wire [2:0] funct3=instruction[14:12];
    wire [31:0] rs1_value, rs2_value, immediate;
    wire [3:0] alu_operation;
    wire [2:0] immediate_select;
    wire [1:0] writeback_select;
    wire alu_source_immediate, alu_source_pc;
    wire decoded_register_write, decoded_memory_read, decoded_memory_write;
    wire decoded_branch, decoded_jump, decoded_jump_register;
    wire decoded_upper_immediate, decoded_fence, decoded_ecall, decoded_ebreak;
    wire illegal_instruction;
    wire [31:0] alu_a=alu_source_pc ? pc : rs1_value;
    wire [31:0] alu_b=alu_source_immediate ? immediate : rs2_value;
    wire [31:0] alu_result_raw;
    wire [31:0] alu_result=decoded_upper_immediate ? immediate : alu_result_raw;
    wire branch_taken;
    wire [31:0] pc_plus_4=pc+32'd4;
    wire [31:0] branch_target=pc+immediate;
    wire [31:0] jalr_target=(rs1_value+immediate)&32'hffff_fffe;
    wire [31:0] control_target=decoded_jump_register ? jalr_target :
                               decoded_jump ? branch_target : branch_target;
    wire control_transfer=decoded_jump || decoded_jump_register ||
                          (decoded_branch && branch_taken);
    wire instruction_misaligned=control_transfer && (control_target[1:0]!=2'b00);
    wire [31:0] decoded_store_data, response_load_value;
    wire [3:0] decoded_store_strobe;
    wire decoded_data_misaligned;
    wire [31:0] unused_load, unused_store;
    wire [3:0] unused_strobe;
    wire unused_misaligned;
    wire synchronous_trap=illegal_instruction || decoded_ecall || decoded_ebreak ||
                          instruction_misaligned || decoded_data_misaligned;
    wire execute_write=(state==EXECUTE) && decoded_register_write &&
                       !decoded_memory_read && !synchronous_trap && !trap_valid;
    wire load_response=!pending_write && data_rsp_valid &&
                       (((state==DATA_REQ)&&data_req_ready)||(state==DATA_RSP));
    wire register_write_enable=execute_write || load_response;
    wire [4:0] register_write_address=load_response ? pending_rd : rd;
    wire [31:0] execute_write_data=(writeback_select==WB_PC4) ? pc_plus_4 : alu_result;
    wire [31:0] register_write_data=load_response ? response_load_value : execute_write_data;

    assign instr_req_valid=(state==FETCH_REQ)&&!trap_valid;
    assign instr_req_addr=pc;
    assign data_req_valid=(state==DATA_REQ)&&!trap_valid;
    assign data_req_write=pending_write;
    assign data_req_addr=pending_addr;
    assign data_req_wdata=pending_wdata;
    assign data_req_wstrb=(data_req_valid&&pending_write)?pending_wstrb:4'b0000;

    control_unit control(
        .instruction(instruction),.alu_operation(alu_operation),
        .immediate_select(immediate_select),.writeback_select(writeback_select),
        .alu_source_immediate(alu_source_immediate),.alu_source_pc(alu_source_pc),
        .register_write(decoded_register_write),.memory_read(decoded_memory_read),
        .memory_write(decoded_memory_write),.branch(decoded_branch),.jump(decoded_jump),
        .jump_register(decoded_jump_register),.upper_immediate(decoded_upper_immediate),
        .fence(decoded_fence),.ecall(decoded_ecall),.ebreak(decoded_ebreak),
        .illegal_instruction(illegal_instruction));
    immediate_generator immediate_generator_i(.instruction(instruction),
        .immediate_select(immediate_select),.immediate(immediate));
    register_file register_file_i(.clk(clk),.rst(rst),.write_enable(register_write_enable),
        .read_address_1(rs1),.read_address_2(rs2),.write_address(register_write_address),
        .write_data(register_write_data),.read_data_1(rs1_value),.read_data_2(rs2_value));
    alu alu_i(.a(alu_a),.b(alu_b),.operation(alu_operation),.result(alu_result_raw));
    branch_unit branch_unit_i(.operand_a(rs1_value),.operand_b(rs2_value),
        .funct3(funct3),.taken(branch_taken));
    load_store_unit decoded_lsu(.funct3(funct3),.address_offset(alu_result_raw[1:0]),
        .store_value(rs2_value),.memory_read_data(32'd0),.is_load(decoded_memory_read),
        .is_store(decoded_memory_write),.load_value(unused_load),
        .memory_write_data(decoded_store_data),.memory_write_strobe(decoded_store_strobe),
        .misaligned(decoded_data_misaligned));
    load_store_unit response_lsu(.funct3(pending_funct3),.address_offset(pending_offset),
        .store_value(32'd0),.memory_read_data(data_rsp_rdata),.is_load(1'b1),.is_store(1'b0),
        .load_value(response_load_value),.memory_write_data(unused_store),
        .memory_write_strobe(unused_strobe),.misaligned(unused_misaligned));

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=FETCH_REQ; pc<=0; instruction<=32'h00000013;
            pending_write<=0; pending_addr<=0; pending_wdata<=0; pending_wstrb<=0;
            pending_rd<=0; pending_funct3<=0; pending_offset<=0;
            trap_valid<=0; trap_cause<=0; trap_pc<=0;
        end else case(state)
            FETCH_REQ: if(instr_req_ready) begin
                if(instr_rsp_valid) begin instruction<=instr_rsp_data; state<=EXECUTE; end
                else state<=FETCH_RSP;
            end
            FETCH_RSP: if(instr_rsp_valid) begin instruction<=instr_rsp_data; state<=EXECUTE; end
            EXECUTE: begin
                if(synchronous_trap) begin
                    trap_valid<=1; trap_pc<=pc; state<=TRAPPED;
                    if(instruction_misaligned) trap_cause<=CAUSE_INSTR_MISALIGNED;
                    else if(illegal_instruction) trap_cause<=CAUSE_ILLEGAL;
                    else if(decoded_ebreak) trap_cause<=CAUSE_BREAKPOINT;
                    else if(decoded_data_misaligned&&decoded_memory_read) trap_cause<=CAUSE_LOAD_MISALIGNED;
                    else if(decoded_data_misaligned&&decoded_memory_write) trap_cause<=CAUSE_STORE_MISALIGNED;
                    else trap_cause<=CAUSE_ECALL_M;
                end else if(decoded_memory_read||decoded_memory_write) begin
                    pending_write<=decoded_memory_write; pending_addr<=alu_result_raw;
                    pending_wdata<=decoded_store_data; pending_wstrb<=decoded_store_strobe;
                    pending_rd<=rd; pending_funct3<=funct3; pending_offset<=alu_result_raw[1:0];
                    state<=DATA_REQ;
                end else begin
                    pc<=control_transfer?control_target:pc_plus_4; state<=FETCH_REQ;
                end
            end
            DATA_REQ: if(data_req_ready) begin
                if(pending_write||data_rsp_valid) begin pc<=pc_plus_4; state<=FETCH_REQ; end
                else state<=DATA_RSP;
            end
            DATA_RSP: if(data_rsp_valid) begin pc<=pc_plus_4; state<=FETCH_REQ; end
            default: state<=TRAPPED;
        endcase
    end

`ifdef FORMAL
    reg formal_past_valid = 1'b0;
    always @(posedge clk) begin
        formal_past_valid <= 1'b1;
        if (formal_past_valid && !rst) begin
            assert(data_req_wstrb == 0 || (data_req_valid && data_req_write));
            if (state == EXECUTE && illegal_instruction) begin
                assert(!register_write_enable);
                assert(!data_req_valid);
            end
            if (state == EXECUTE && synchronous_trap) begin
                assert(!register_write_enable);
                assert(!data_req_valid);
            end
            if ($past(instr_req_valid && !instr_req_ready)) begin
                assert(instr_req_valid);
                assert(instr_req_addr == $past(instr_req_addr));
            end
            if ($past(data_req_valid && !data_req_ready)) begin
                assert(data_req_valid);
                assert(data_req_write == $past(data_req_write));
                assert(data_req_addr == $past(data_req_addr));
                assert(data_req_wdata == $past(data_req_wdata));
                assert(data_req_wstrb == $past(data_req_wstrb));
            end
            if ($past(data_req_valid && data_req_ready && data_req_write))
                assert(!(data_req_valid && data_req_write));
            if ($past(state == EXECUTE && synchronous_trap)) begin
                assert(pc == $past(pc));
                assert(trap_valid);
            end
        end
    end
`endif
endmodule
