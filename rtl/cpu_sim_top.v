module cpu_sim_top #(
    parameter PROGRAM_HEX="", parameter INSTR_DELAY=0, parameter DATA_DELAY=0,
    parameter RANDOM_DELAYS=0, parameter MAX_RANDOM_DELAY=5,
    parameter REQUEST_BACKPRESSURE=0
)(input wire clk,input wire rst,output wire trap_valid,
  output wire [3:0] trap_cause,output wire [31:0] trap_pc);
    wire instr_req_valid,instr_req_ready,instr_rsp_valid;
    wire [31:0] instr_req_addr,instr_rsp_data;
    wire data_req_valid,data_req_ready,data_req_write,data_rsp_valid;
    wire [31:0] data_req_addr,data_req_wdata,data_rsp_rdata;
    wire [3:0] data_req_wstrb;

    cpu_core core(.clk(clk),.rst(rst),
        .instr_req_valid(instr_req_valid),.instr_req_ready(instr_req_ready),
        .instr_req_addr(instr_req_addr),.instr_rsp_valid(instr_rsp_valid),
        .instr_rsp_data(instr_rsp_data),.data_req_valid(data_req_valid),
        .data_req_ready(data_req_ready),.data_req_write(data_req_write),
        .data_req_addr(data_req_addr),.data_req_wdata(data_req_wdata),
        .data_req_wstrb(data_req_wstrb),.data_rsp_valid(data_rsp_valid),
        .data_rsp_rdata(data_rsp_rdata),.trap_valid(trap_valid),
        .trap_cause(trap_cause),.trap_pc(trap_pc));
    simulation_memory #(.PROGRAM_HEX(PROGRAM_HEX),.INSTR_DELAY(INSTR_DELAY),
        .DATA_DELAY(DATA_DELAY),.RANDOM_DELAYS(RANDOM_DELAYS),
        .MAX_RANDOM_DELAY(MAX_RANDOM_DELAY),
        .REQUEST_BACKPRESSURE(REQUEST_BACKPRESSURE)) memory(.clk(clk),.rst(rst),
        .instr_req_valid(instr_req_valid),.instr_req_ready(instr_req_ready),
        .instr_req_addr(instr_req_addr),.instr_rsp_valid(instr_rsp_valid),
        .instr_rsp_data(instr_rsp_data),.data_req_valid(data_req_valid),
        .data_req_ready(data_req_ready),.data_req_write(data_req_write),
        .data_req_addr(data_req_addr),.data_req_wdata(data_req_wdata),
        .data_req_wstrb(data_req_wstrb),.data_rsp_valid(data_rsp_valid),
        .data_rsp_rdata(data_rsp_rdata));
endmodule
