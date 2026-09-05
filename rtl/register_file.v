module register_file (
    input  wire        clk,
    input  wire        rst,
    input  wire        write_enable,
    input  wire [4:0]  read_address_1,
    input  wire [4:0]  read_address_2,
    input  wire [4:0]  write_address,
    input  wire [31:0] write_data,
    output wire [31:0] read_data_1,
    output wire [31:0] read_data_2
);
    reg [31:0] registers [0:31];
    integer index;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (index = 0; index < 32; index = index + 1)
                registers[index] <= 32'd0;
        end else begin
            if (write_enable && (write_address != 5'd0))
                registers[write_address] <= write_data;
            registers[0] <= 32'd0;
        end
    end

    assign read_data_1 = (read_address_1 == 5'd0) ? 32'd0 : registers[read_address_1];
    assign read_data_2 = (read_address_2 == 5'd0) ? 32'd0 : registers[read_address_2];

`ifdef FORMAL
    reg formal_past_valid = 1'b0;
    always @(posedge clk) begin
        formal_past_valid <= 1'b1;
        if (formal_past_valid && !rst)
            assert(registers[0] == 32'd0);
    end
`endif
endmodule
