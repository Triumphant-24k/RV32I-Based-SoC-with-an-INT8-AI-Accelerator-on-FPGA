// SPDX-License-Identifier: MIT
module int8_accelerator (
    input wire clk, input wire rst,
    input wire write_en, input wire [7:0] address,
    input wire [31:0] write_data, input wire [3:0] write_strobe,
    output reg [31:0] read_data,
    output reg busy, output reg done,
    output reg signed [31:0] result, output reg [31:0] cycles
);
    reg signed [7:0] vector_a [0:7];
    reg signed [7:0] vector_b [0:7];
    reg [2:0] index;
    reg signed [31:0] accumulator;
    wire signed [15:0] product = vector_a[index] * vector_b[index];
    wire signed [31:0] extended_product = {{16{product[15]}}, product};
    wire signed [31:0] next_sum = accumulator + extended_product;
    wire legal_write = write_en && address[1:0] == 0 && write_strobe == 4'hf;
    wire accepted_start = legal_write && address == 8'h00 && write_data[0] && !busy;
    integer n;

    always @* begin
        read_data = 0;
        case ({address[7:2],2'b00})
            8'h04: read_data = {30'd0,done,busy};
            8'h08: read_data = result;
            8'h0c: read_data = cycles;
            default: begin
                if (address[7:5] == 3'b001)
                    read_data = {{24{vector_a[address[4:2]][7]}},vector_a[address[4:2]]};
                if (address[7:5] == 3'b010)
                    read_data = {{24{vector_b[address[4:2]][7]}},vector_b[address[4:2]]};
            end
        endcase
    end

    // busy encodes the two-state IDLE/RUN FSM.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy <= 0; done <= 0; result <= 0; cycles <= 0;
            index <= 0; accumulator <= 0;
            for (n=0;n<8;n=n+1) begin vector_a[n]<=0; vector_b[n]<=0; end
        end else if (busy) begin
            accumulator <= next_sum;
            cycles <= cycles + 1;
            if (index == 7) begin
                result <= next_sum; // includes the final product, not the old accumulator
                busy <= 0; done <= 1;
            end else index <= index + 1'b1;
        end else begin
            if (legal_write && address[7:5] == 3'b001)
                vector_a[address[4:2]] <= write_data[7:0];
            if (legal_write && address[7:5] == 3'b010)
                vector_b[address[4:2]] <= write_data[7:0];
            if (accepted_start) begin
                busy <= 1; done <= 0; cycles <= 0; index <= 0; accumulator <= 0;
            end
        end
    end

`ifdef SIM_ASSERT
    // Immediate SystemVerilog assertions executed by Icarus; no SVA dependency.
    reg monitor_valid = 0;
    reg prev_busy, prev_done, prev_start, prev_reset;
    reg [2:0] prev_index;
    reg [31:0] prev_result;
    always @(posedge clk) begin
        if (monitor_valid) begin
            if (prev_reset) begin
                assert (!busy && !done && result == 0 && cycles == 0)
                    else $fatal(1,"reset did not abort accelerator");
            end else if (!rst) begin
                assert (!(busy && done)) else $fatal(1,"busy and done overlap");
                if (prev_start) assert (busy && !done && cycles == 0)
                    else $fatal(1,"start transition");
                if (prev_busy && prev_index < 7)
                    assert (busy && !done && index == prev_index+1'b1)
                        else $fatal(1,"premature completion/index");
                if (prev_busy && prev_index == 7)
                    assert (!busy && done && cycles == 8)
                        else $fatal(1,"bounded completion");
                if (!(prev_busy && prev_index == 7))
                    assert (result == prev_result) else $fatal(1,"result changed early");
                if (prev_done && !prev_start)
                    assert (done) else $fatal(1,"done not sticky");
                if (busy) assert (cycles < 8 && {29'd0,index} == cycles)
                    else $fatal(1,"index out of bounds");
            end
        end
        monitor_valid <= 1; prev_busy <= busy; prev_done <= done;
        prev_start <= accepted_start; prev_index <= index;
        prev_result <= result; prev_reset <= rst;
    end
`endif
endmodule
