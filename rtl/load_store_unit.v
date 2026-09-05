module load_store_unit (
    input  wire [2:0]  funct3,
    input  wire [1:0]  address_offset,
    input  wire [31:0] store_value,
    input  wire [31:0] memory_read_data,
    input  wire        is_load,
    input  wire        is_store,
    output reg  [31:0] load_value,
    output reg  [31:0] memory_write_data,
    output reg  [3:0]  memory_write_strobe,
    output reg         misaligned
);
    reg [7:0] selected_byte;
    reg [15:0] selected_halfword;

    always @(*) begin
        case (address_offset)
            2'd0: selected_byte = memory_read_data[7:0];
            2'd1: selected_byte = memory_read_data[15:8];
            2'd2: selected_byte = memory_read_data[23:16];
            default: selected_byte = memory_read_data[31:24];
        endcase
        selected_halfword = address_offset[1] ? memory_read_data[31:16] : memory_read_data[15:0];

        load_value = 32'd0;
        memory_write_data = 32'd0;
        memory_write_strobe = 4'b0000;
        misaligned = 1'b0;

        if (is_load) begin
            case (funct3)
                3'b000: load_value = {{24{selected_byte[7]}}, selected_byte}; // LB
                3'b001: begin // LH
                    misaligned = address_offset[0];
                    load_value = {{16{selected_halfword[15]}}, selected_halfword};
                end
                3'b010: begin // LW
                    misaligned = (address_offset != 2'b00);
                    load_value = memory_read_data;
                end
                3'b100: load_value = {24'd0, selected_byte}; // LBU
                3'b101: begin // LHU
                    misaligned = address_offset[0];
                    load_value = {16'd0, selected_halfword};
                end
                default: load_value = 32'd0;
            endcase
        end

        if (is_store) begin
            case (funct3)
                3'b000: begin // SB
                    memory_write_strobe = 4'b0001 << address_offset;
                    memory_write_data = {4{store_value[7:0]}};
                end
                3'b001: begin // SH
                    misaligned = address_offset[0];
                    memory_write_strobe = address_offset[1] ? 4'b1100 : 4'b0011;
                    memory_write_data = {2{store_value[15:0]}};
                end
                3'b010: begin // SW
                    misaligned = (address_offset != 2'b00);
                    memory_write_strobe = 4'b1111;
                    memory_write_data = store_value;
                end
                default: begin
                    memory_write_strobe = 4'b0000;
                    memory_write_data = 32'd0;
                end
            endcase
        end
    end
endmodule
