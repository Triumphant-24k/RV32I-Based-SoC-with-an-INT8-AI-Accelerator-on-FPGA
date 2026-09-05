module immediate_generator (
    input  wire [31:0] instruction,
    input  wire [2:0]  immediate_select,
    output reg  [31:0] immediate
);
    localparam IMM_I = 3'd0;
    localparam IMM_S = 3'd1;
    localparam IMM_B = 3'd2;
    localparam IMM_U = 3'd3;
    localparam IMM_J = 3'd4;

    always @(*) begin
        case (immediate_select)
            IMM_I: immediate = {{20{instruction[31]}}, instruction[31:20]};
            IMM_S: immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            IMM_B: immediate = {{19{instruction[31]}}, instruction[31], instruction[7],
                                instruction[30:25], instruction[11:8], 1'b0};
            IMM_U: immediate = {instruction[31:12], 12'd0};
            IMM_J: immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                                instruction[20], instruction[30:21], 1'b0};
            default: immediate = 32'd0;
        endcase
    end
endmodule
