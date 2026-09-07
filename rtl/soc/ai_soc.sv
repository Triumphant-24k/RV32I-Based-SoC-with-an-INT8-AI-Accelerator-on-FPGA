// SPDX-License-Identifier: MIT
module ai_soc #(
    parameter ROM_HEX="firmware/hex/demo_rom.hex", RAM_HEX="firmware/hex/demo_ram.hex",
    parameter integer CLOCK_HZ=1000000, BAUD=100000, STALL_REQUESTS=0
)(input wire clk, input wire rst, output wire uart, output wire [2:0] led, input wire uart_rx_pin);
    wire iv,ir,ip,dv,dr,dw,dp;
    wire [31:0] ia,idata,da,wd,rd;
    wire [3:0] ws;
    wire trap_valid; wire [3:0] trap_cause; wire [31:0] trap_pc;
    wire [1:0] status;
    wire acc_busy;
    cpu_core cpu(.clk(clk),.rst(rst),.instr_req_valid(iv),.instr_req_ready(ir),
        .instr_req_addr(ia),.instr_rsp_valid(ip),.instr_rsp_data(idata),
        .data_req_valid(dv),.data_req_ready(dr),.data_req_write(dw),
        .data_req_addr(da),.data_req_wdata(wd),.data_req_wstrb(ws),
        .data_rsp_valid(dp),.data_rsp_rdata(rd),
        .trap_valid(trap_valid),.trap_cause(trap_cause),.trap_pc(trap_pc));
    soc_bus #(.ROM_HEX(ROM_HEX),.RAM_HEX(RAM_HEX),.CLOCK_HZ(CLOCK_HZ),
        .BAUD(BAUD),.STALL_REQUESTS(STALL_REQUESTS)) bus(
        .clk(clk),.rst(rst),.iv(iv),.ir(ir),.ia(ia),.ip(ip),.instruction_data(idata),
        .dv(dv),.dr(dr),.dw(dw),.da(da),.wd(wd),.ws(ws),.dp(dp),.rd(rd),
        .uart(uart),.demo_status(status),.acc_busy(acc_busy),.uart_rx_pin(uart_rx_pin));
    assign led = {trap_valid || status == 2, status == 1, acc_busy};
endmodule
