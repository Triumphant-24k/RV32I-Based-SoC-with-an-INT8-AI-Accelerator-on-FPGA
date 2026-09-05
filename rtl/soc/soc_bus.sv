// SPDX-License-Identifier: MIT
module soc_bus #(
    parameter ROM_HEX="firmware/hex/demo_rom.hex",
    parameter RAM_HEX="firmware/hex/demo_ram.hex",
    parameter integer CLOCK_HZ=1000000, BAUD=100000, STALL_REQUESTS=0
)(
    input wire clk, input wire rst,
    input wire iv, output wire ir, input wire [31:0] ia,
    output reg ip, output wire [31:0] instruction_data,
    input wire dv, output wire dr, input wire dw,
    input wire [31:0] da, input wire [31:0] wd, input wire [3:0] ws,
    output reg dp, output wire [31:0] rd,
    output wire uart, output reg [1:0] demo_status
);
    (* ram_style = "block" *) reg [31:0] rom [0:4095];
    (* ram_style = "block" *) reg [31:0] ram [0:4095];
    reg [31:0] instruction_q, rom_q, ram_q, io_q;
    reg instruction_in_range;
    reg [1:0] read_select;
    reg [31:0] clock_count;
    reg [15:0] lfsr;
    wire allow_request = STALL_REQUESTS == 0 || lfsr[0];
    assign ir = !rst && !ip && allow_request;
    assign dr = !rst && !dp && allow_request;
    wire iaccept = iv && ir;
    wire daccept = dv && dr;
    wire rom_selected = da[31:14] == 0;
    wire ram_selected = da[31:14] == 18'h00004;
    wire acc_selected = da[31:8] == 24'h400000;
    wire full_write = daccept && dw && da[1:0] == 0 && ws == 4'hf;
    wire [31:0] aligned_da = {da[31:2],2'b00};
    wire [31:0] acc_read;
    wire acc_busy, acc_done;
    wire signed [31:0] acc_result;
    wire [31:0] acc_cycles;
    wire uart_busy;
    wire uart_start = full_write && da == 32'h40000104;

    assign instruction_data = instruction_in_range ? instruction_q : 32'hffffffff;
    assign rd = read_select == 0 ? rom_q : read_select == 1 ? ram_q : io_q;
    initial begin
        if (ROM_HEX != '0) $readmemh(ROM_HEX,rom);
        if (RAM_HEX != '0) $readmemh(RAM_HEX,ram);
    end
    // Deliberately no reset on the arrays or RAM/ROM data output registers.
    // Both ROM ports and the RAM read port are synchronous.
    always @(posedge clk) begin
        if (iaccept) instruction_q <= rom[ia[13:2]];
        if (daccept && !dw && rom_selected) rom_q <= rom[da[13:2]];
        if (daccept && !dw && ram_selected) ram_q <= ram[da[13:2]];
        if (daccept && dw && ram_selected) begin
            if (ws[0]) ram[da[13:2]][7:0] <= wd[7:0];
            if (ws[1]) ram[da[13:2]][15:8] <= wd[15:8];
            if (ws[2]) ram[da[13:2]][23:16] <= wd[23:16];
            if (ws[3]) ram[da[13:2]][31:24] <= wd[31:24];
        end
    end
    int8_accelerator accelerator(.clk(clk),.rst(rst),
        .write_en(daccept && dw && acc_selected),.address(da[7:0]),
        .write_data(wd),.write_strobe(ws),.read_data(acc_read),
        .busy(acc_busy),.done(acc_done),.result(acc_result),.cycles(acc_cycles));
    uart_tx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) transmitter(
        .clk(clk),.rst(rst),.start(uart_start),.data(wd[7:0]),.tx(uart),.busy(uart_busy));

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ip<=0; dp<=0; read_select<=2; io_q<=0; clock_count<=0;
            lfsr<=16'h1ace; demo_status<=0; instruction_in_range<=0;
        end else begin
            clock_count <= clock_count + 1;
            lfsr <= {lfsr[14:0],lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
            ip <= iaccept; dp <= daccept && !dw;
            if (iaccept) instruction_in_range <= ia[31:14] == 0 && ia[1:0] == 0;
            if (daccept && !dw) begin
                read_select <= rom_selected ? 0 : ram_selected ? 1 : 2;
                io_q <= 0;
                if (acc_selected) io_q <= acc_read;
                else case (aligned_da)
                    32'h40000100: io_q <= clock_count;
                    32'h40000108: io_q <= {31'd0,uart_busy};
                    32'h4000010c: io_q <= {30'd0,demo_status};
                    default: io_q <= 0;
                endcase
            end
            if (full_write && da == 32'h4000010c) demo_status <= wd[1:0];
        end
    end
endmodule
