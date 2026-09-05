module control_unit (
    input  wire [31:0] instruction,
    output reg  [3:0]  alu_operation,
    output reg  [2:0]  immediate_select,
    output reg  [1:0]  writeback_select,
    output reg         alu_source_immediate,
    output reg         alu_source_pc,
    output reg         register_write,
    output reg         memory_read,
    output reg         memory_write,
    output reg         branch,
    output reg         jump,
    output reg         jump_register,
    output reg         upper_immediate,
    output reg         fence,
    output reg         ecall,
    output reg         ebreak,
    output reg         illegal_instruction
);
    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_SLL  = 4'd2;
    localparam ALU_SLT  = 4'd3;
    localparam ALU_SLTU = 4'd4;
    localparam ALU_XOR  = 4'd5;
    localparam ALU_SRL  = 4'd6;
    localparam ALU_SRA  = 4'd7;
    localparam ALU_OR   = 4'd8;
    localparam ALU_AND  = 4'd9;
    localparam IMM_I = 3'd0;
    localparam IMM_S = 3'd1;
    localparam IMM_B = 3'd2;
    localparam IMM_U = 3'd3;
    localparam IMM_J = 3'd4;
    localparam WB_ALU = 2'd0;
    localparam WB_LOAD = 2'd1;
    localparam WB_PC4 = 2'd2;

    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];

    always @(*) begin
        alu_operation = ALU_ADD;
        immediate_select = IMM_I;
        writeback_select = WB_ALU;
        alu_source_immediate = 1'b0;
        alu_source_pc = 1'b0;
        register_write = 1'b0;
        memory_read = 1'b0;
        memory_write = 1'b0;
        branch = 1'b0;
        jump = 1'b0;
        jump_register = 1'b0;
        upper_immediate = 1'b0;
        fence = 1'b0;
        ecall = 1'b0;
        ebreak = 1'b0;
        illegal_instruction = 1'b0;

        case (opcode)
            7'b0110011: begin // Register-register
                register_write = 1'b1;
                case (funct3)
                    3'b000: if (funct7 == 7'b0000000) alu_operation = ALU_ADD;
                            else if (funct7 == 7'b0100000) alu_operation = ALU_SUB;
                            else illegal_instruction = 1'b1;
                    3'b001: if (funct7 == 7'b0000000) alu_operation = ALU_SLL; else illegal_instruction = 1'b1;
                    3'b010: if (funct7 == 7'b0000000) alu_operation = ALU_SLT; else illegal_instruction = 1'b1;
                    3'b011: if (funct7 == 7'b0000000) alu_operation = ALU_SLTU; else illegal_instruction = 1'b1;
                    3'b100: if (funct7 == 7'b0000000) alu_operation = ALU_XOR; else illegal_instruction = 1'b1;
                    3'b101: if (funct7 == 7'b0000000) alu_operation = ALU_SRL;
                            else if (funct7 == 7'b0100000) alu_operation = ALU_SRA;
                            else illegal_instruction = 1'b1;
                    3'b110: if (funct7 == 7'b0000000) alu_operation = ALU_OR; else illegal_instruction = 1'b1;
                    3'b111: if (funct7 == 7'b0000000) alu_operation = ALU_AND; else illegal_instruction = 1'b1;
                    default: illegal_instruction = 1'b1;
                endcase
            end
            7'b0010011: begin // Immediate ALU
                register_write = 1'b1;
                alu_source_immediate = 1'b1;
                case (funct3)
                    3'b000: alu_operation = ALU_ADD;
                    3'b010: alu_operation = ALU_SLT;
                    3'b011: alu_operation = ALU_SLTU;
                    3'b100: alu_operation = ALU_XOR;
                    3'b110: alu_operation = ALU_OR;
                    3'b111: alu_operation = ALU_AND;
                    3'b001: if (funct7 == 7'b0000000) alu_operation = ALU_SLL; else illegal_instruction = 1'b1;
                    3'b101: if (funct7 == 7'b0000000) alu_operation = ALU_SRL;
                            else if (funct7 == 7'b0100000) alu_operation = ALU_SRA;
                            else illegal_instruction = 1'b1;
                    default: illegal_instruction = 1'b1;
                endcase
            end
            7'b0000011: begin // Loads
                immediate_select = IMM_I;
                alu_source_immediate = 1'b1;
                register_write = 1'b1;
                memory_read = 1'b1;
                writeback_select = WB_LOAD;
                if (!((funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b010) ||
                      (funct3 == 3'b100) || (funct3 == 3'b101)))
                    illegal_instruction = 1'b1;
            end
            7'b0100011: begin // Stores
                immediate_select = IMM_S;
                alu_source_immediate = 1'b1;
                memory_write = 1'b1;
                if (!((funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b010)))
                    illegal_instruction = 1'b1;
            end
            7'b1100011: begin // Branches
                immediate_select = IMM_B;
                branch = 1'b1;
                if (!((funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b100) ||
                      (funct3 == 3'b101) || (funct3 == 3'b110) || (funct3 == 3'b111)))
                    illegal_instruction = 1'b1;
            end
            7'b0110111: begin // LUI
                immediate_select = IMM_U;
                alu_source_immediate = 1'b1;
                upper_immediate = 1'b1;
                register_write = 1'b1;
            end
            7'b0010111: begin // AUIPC
                immediate_select = IMM_U;
                alu_source_immediate = 1'b1;
                alu_source_pc = 1'b1;
                register_write = 1'b1;
            end
            7'b1101111: begin // JAL
                immediate_select = IMM_J;
                register_write = 1'b1;
                writeback_select = WB_PC4;
                jump = 1'b1;
            end
            7'b1100111: begin // JALR
                immediate_select = IMM_I;
                register_write = 1'b1;
                writeback_select = WB_PC4;
                jump_register = 1'b1;
                if (funct3 != 3'b000) illegal_instruction = 1'b1;
            end
            7'b0001111: begin // FENCE; FENCE.I is outside base RV32I v2.1
                if (funct3 == 3'b000) fence = 1'b1;
                else illegal_instruction = 1'b1;
            end
            7'b1110011: begin
                if (instruction == 32'h00000073) ecall = 1'b1;
                else if (instruction == 32'h00100073) ebreak = 1'b1;
                else illegal_instruction = 1'b1;
            end
            default: illegal_instruction = 1'b1;
        endcase

        if (illegal_instruction) begin
            register_write = 1'b0;
            memory_read = 1'b0;
            memory_write = 1'b0;
            branch = 1'b0;
            jump = 1'b0;
            jump_register = 1'b0;
            fence = 1'b0;
            ecall = 1'b0;
            ebreak = 1'b0;
        end
    end
endmodule
