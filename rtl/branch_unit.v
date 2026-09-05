module branch_unit (
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [2:0]  funct3,
    output reg         taken
);
    always @(*) begin
        case (funct3)
            3'b000: taken = (operand_a == operand_b);                  // BEQ
            3'b001: taken = (operand_a != operand_b);                  // BNE
            3'b100: taken = ($signed(operand_a) < $signed(operand_b)); // BLT
            3'b101: taken = ($signed(operand_a) >= $signed(operand_b));// BGE
            3'b110: taken = (operand_a < operand_b);                   // BLTU
            3'b111: taken = (operand_a >= operand_b);                  // BGEU
            default: taken = 1'b0;
        endcase
    end
endmodule
