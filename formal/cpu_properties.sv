module cpu_properties;
    (* gclk *) reg clk;
    reg rst=1'b1;
    (* anyseq *) reg instr_req_ready,instr_rsp_valid;
    (* anyseq *) reg [31:0] instr_rsp_data;
    (* anyseq *) reg data_req_ready,data_rsp_valid;
    (* anyseq *) reg [31:0] data_rsp_rdata;
    wire instr_req_valid;wire [31:0] instr_req_addr;
    wire data_req_valid,data_req_write;wire [31:0] data_req_addr,data_req_wdata;
    wire [3:0] data_req_wstrb;wire trap_valid;wire [3:0] trap_cause;wire [31:0] trap_pc;

    cpu_core dut(.clk(clk),.rst(rst),.instr_req_valid(instr_req_valid),
        .instr_req_ready(instr_req_ready),.instr_req_addr(instr_req_addr),
        .instr_rsp_valid(instr_rsp_valid),.instr_rsp_data(instr_rsp_data),
        .data_req_valid(data_req_valid),.data_req_ready(data_req_ready),
        .data_req_write(data_req_write),.data_req_addr(data_req_addr),
        .data_req_wdata(data_req_wdata),.data_req_wstrb(data_req_wstrb),
        .data_rsp_valid(data_rsp_valid),.data_rsp_rdata(data_rsp_rdata),
        .trap_valid(trap_valid),.trap_cause(trap_cause),.trap_pc(trap_pc));

    reg past_valid=0;
    always @(posedge clk) begin
        past_valid<=1;
        if(!past_valid) assume(rst); else assume(!rst);
    end
endmodule
