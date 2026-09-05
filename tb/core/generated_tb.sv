`timescale 1ns/1ps
module generated_tb;
    localparam TESTS=300; localparam INITIAL_SEED=32'h52a1c0de;
    reg clk,rst; integer seed,n,kind,op,cycles;
    reg [31:0] a,b,inst,expected; reg [31:0] imem[0:3];
    wire iv,ir,ip; wire [31:0] ia,id;
    wire dv,dr,dw,dp; wire [31:0] da,dd,qr; wire [3:0] ds;
    wire tv; wire [3:0] tc; wire [31:0] tp;
    assign ir=1;assign ip=iv;assign id=imem[ia[3:2]];
    assign dr=1;assign dp=dv&&!dw;assign qr=0;
    cpu_core dut(.clk(clk),.rst(rst),.instr_req_valid(iv),.instr_req_ready(ir),
        .instr_req_addr(ia),.instr_rsp_valid(ip),.instr_rsp_data(id),
        .data_req_valid(dv),.data_req_ready(dr),.data_req_write(dw),
        .data_req_addr(da),.data_req_wdata(dd),.data_req_wstrb(ds),
        .data_rsp_valid(dp),.data_rsp_rdata(qr),.trap_valid(tv),.trap_cause(tc),.trap_pc(tp));
    always #5 clk=~clk;
    function automatic [31:0] enc_r(input [6:0] f7,input [2:0] f3);
        enc_r={f7,5'd2,5'd1,f3,5'd5,7'b0110011};endfunction
    function automatic [31:0] enc_i(input [11:0] imm,input [2:0] f3);
        enc_i={imm,5'd1,f3,5'd5,7'b0010011};endfunction
    task fail(input [255:0] why);begin
        $display("FAIL seed=%08x test=%0d instruction=%08x a=%08x b=%08x expected=%08x got=%08x",
            INITIAL_SEED,n,inst,a,b,expected,dut.register_file_i.registers[5]);
        $fatal(1,"%0s",why);
    end endtask
    initial begin
        clk=0;rst=1;seed=INITIAL_SEED;imem[1]=32'h00000073;
        for(n=0;n<TESTS;n=n+1) begin
            a=$random(seed);b=$random(seed);kind=$random(seed)&1;
            if(kind==0) begin
                op=($random(seed)&32'h7fffffff)%10;
                case(op)
                    0:begin inst=enc_r(0,0);expected=a+b;end
                    1:begin inst=enc_r(7'b0100000,0);expected=a-b;end
                    2:begin inst=enc_r(0,1);expected=a<<b[4:0];end
                    3:begin inst=enc_r(0,2);expected=($signed(a)<$signed(b));end
                    4:begin inst=enc_r(0,3);expected=(a<b);end
                    5:begin inst=enc_r(0,4);expected=a^b;end
                    6:begin inst=enc_r(0,5);expected=a>>b[4:0];end
                    7:begin inst=enc_r(7'b0100000,5);expected=$signed(a)>>>b[4:0];end
                    8:begin inst=enc_r(0,6);expected=a|b;end
                    default:begin inst=enc_r(0,7);expected=a&b;end
                endcase
            end else begin
                op=($random(seed)&32'h7fffffff)%9;
                case(op)
                    0:begin inst=enc_i(b[11:0],0);expected=a+{{20{b[11]}},b[11:0]};end
                    1:begin inst=enc_i(b[11:0],2);expected=($signed(a)<$signed({{20{b[11]}},b[11:0]}));end
                    2:begin inst=enc_i(b[11:0],3);expected=(a<{{20{b[11]}},b[11:0]});end
                    3:begin inst=enc_i(b[11:0],4);expected=a^{{20{b[11]}},b[11:0]};end
                    4:begin inst=enc_i(b[11:0],6);expected=a|{{20{b[11]}},b[11:0]};end
                    5:begin inst=enc_i(b[11:0],7);expected=a&{{20{b[11]}},b[11:0]};end
                    6:begin inst=enc_i({7'b0,b[4:0]},1);expected=a<<b[4:0];end
                    7:begin inst=enc_i({7'b0,b[4:0]},5);expected=a>>b[4:0];end
                    default:begin inst=enc_i({7'b0100000,b[4:0]},5);expected=$signed(a)>>>b[4:0];end
                endcase
            end
            imem[0]=inst;rst=1;#1;@(negedge clk);rst=0;
            dut.register_file_i.registers[1]=a;dut.register_file_i.registers[2]=b;
            cycles=0;while(!tv&&cycles<20)begin @(posedge clk);#1;cycles=cycles+1;end
            if(!tv||tc!==11)fail("execution did not reach terminal ECALL");
            if(dut.register_file_i.registers[5]!==expected)fail("architectural result mismatch");
        end
        $display("PASS: generated differential regression (%0d tests, seed %08x)",TESTS,INITIAL_SEED);
        $finish;
    end
endmodule
