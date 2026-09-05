module simulation_memory #(
    parameter IMEM_WORDS=1024, parameter DMEM_BYTES=4096,
    parameter PROGRAM_HEX="", parameter INSTR_DELAY=0, parameter DATA_DELAY=0,
    parameter RANDOM_DELAYS=0, parameter MAX_RANDOM_DELAY=5,
    parameter REQUEST_BACKPRESSURE=0
)(
    input wire clk, input wire rst,
    input wire instr_req_valid, output wire instr_req_ready,
    input wire [31:0] instr_req_addr,
    output wire instr_rsp_valid, output wire [31:0] instr_rsp_data,
    input wire data_req_valid, output wire data_req_ready,
    input wire data_req_write, input wire [31:0] data_req_addr,
    input wire [31:0] data_req_wdata, input wire [3:0] data_req_wstrb,
    output wire data_rsp_valid, output wire [31:0] data_rsp_rdata
);
    reg [31:0] instruction_memory[0:IMEM_WORDS-1];
    reg [7:0] data_memory[0:DMEM_BYTES-1];
    reg [15:0] lfsr;
    reg instr_pending, data_pending;
    reg [31:0] instr_pending_addr, data_pending_addr;
    reg [7:0] instr_count, data_count;
    reg instr_rsp_reg, data_rsp_reg;
    reg [31:0] instr_data_reg, data_data_reg;
    integer index;

    wire fixed_instr_zero=(INSTR_DELAY==0)&&(RANDOM_DELAYS==0);
    wire fixed_data_zero=(DATA_DELAY==0)&&(RANDOM_DELAYS==0);
    wire requests_allowed=!REQUEST_BACKPRESSURE||lfsr[0];
    wire [31:0] aligned_data_addr={data_req_addr[31:2],2'b00};
    wire [31:0] pending_aligned_data_addr={data_pending_addr[31:2],2'b00};

    assign instr_req_ready=!instr_pending&&requests_allowed;
    assign data_req_ready=!data_pending&&requests_allowed;
    assign instr_rsp_valid=fixed_instr_zero ? (instr_req_valid&&instr_req_ready) : instr_rsp_reg;
    assign instr_rsp_data=fixed_instr_zero ? instruction_memory[instr_req_addr[31:2]] : instr_data_reg;
    assign data_rsp_valid=fixed_data_zero ?
        (data_req_valid&&data_req_ready&&!data_req_write) : data_rsp_reg;
    assign data_rsp_rdata=fixed_data_zero ? {
        data_memory[aligned_data_addr+3],data_memory[aligned_data_addr+2],
        data_memory[aligned_data_addr+1],data_memory[aligned_data_addr]
    } : data_data_reg;

    initial begin
        for(index=0;index<IMEM_WORDS;index=index+1) instruction_memory[index]=32'h00000013;
        for(index=0;index<DMEM_BYTES;index=index+1) data_memory[index]=0;
        if(PROGRAM_HEX!="") $readmemh(PROGRAM_HEX,instruction_memory);
    end

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            lfsr<=16'h1ace; instr_pending<=0; data_pending<=0;
            instr_count<=0; data_count<=0; instr_rsp_reg<=0; data_rsp_reg<=0;
            instr_data_reg<=0; data_data_reg<=0;
        end else begin
            lfsr<={lfsr[14:0],lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
            instr_rsp_reg<=0; data_rsp_reg<=0;

            if(instr_req_valid&&instr_req_ready&&!fixed_instr_zero) begin
                instr_pending<=1; instr_pending_addr<=instr_req_addr;
                instr_count<=RANDOM_DELAYS ? (lfsr[7:0]%(MAX_RANDOM_DELAY+1)) : INSTR_DELAY;
            end
            if(instr_pending) begin
                if(instr_count==0) begin
                    instr_rsp_reg<=1; instr_data_reg<=instruction_memory[instr_pending_addr[31:2]];
                    instr_pending<=0;
                end else instr_count<=instr_count-1'b1;
            end

            if(data_req_valid&&data_req_ready) begin
                if(data_req_write) begin
                    if(data_req_wstrb[0]) data_memory[aligned_data_addr]<=data_req_wdata[7:0];
                    if(data_req_wstrb[1]) data_memory[aligned_data_addr+1]<=data_req_wdata[15:8];
                    if(data_req_wstrb[2]) data_memory[aligned_data_addr+2]<=data_req_wdata[23:16];
                    if(data_req_wstrb[3]) data_memory[aligned_data_addr+3]<=data_req_wdata[31:24];
                end else if(!fixed_data_zero) begin
                    data_pending<=1; data_pending_addr<=data_req_addr;
                    data_count<=RANDOM_DELAYS ? (lfsr[15:8]%(MAX_RANDOM_DELAY+1)) : DATA_DELAY;
                end
            end
            if(data_pending) begin
                if(data_count==0) begin
                    data_rsp_reg<=1;
                    data_data_reg<={data_memory[pending_aligned_data_addr+3],
                        data_memory[pending_aligned_data_addr+2],
                        data_memory[pending_aligned_data_addr+1],
                        data_memory[pending_aligned_data_addr]};
                    data_pending<=0;
                end else data_count<=data_count-1'b1;
            end
        end
    end
endmodule
