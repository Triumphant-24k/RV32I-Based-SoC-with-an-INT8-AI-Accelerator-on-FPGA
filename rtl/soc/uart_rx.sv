// SPDX-License-Identifier: MIT
// Single-clock 8N1 receiver. FIFO keeps bytes stable until consumed. Sticky errors
// are write-one-to-clear at the bus; a new error wins over a simultaneous clear.
module uart_rx #(parameter integer CLOCK_HZ=100000000, BAUD=115200)(
    input wire clk, rst, rx, consume,
    input wire [1:0] clear_errors,
    output wire [7:0] data,
    output wire valid,
    output reg framing_error, overrun
);
    localparam integer DIVISOR=CLOCK_HZ/BAUD;
    localparam integer CW=$clog2(DIVISOR);
    localparam integer RELOAD=DIVISOR-1, HALF=DIVISOR/2-1;
    localparam [2:0] IDLE=0, START=1, BITS=2, STOP=3, RECOVER=4;
    (* ASYNC_REG="TRUE" *) reg [1:0] sync_rx;
    reg [2:0] state, bit_index;
    reg [CW-1:0] ticks;
    reg [7:0] shift;
    reg [7:0] fifo [0:31];
    reg [4:0] head, tail;
    reg [5:0] count;
    wire pop=consume && valid;
    wire received=state==STOP && ticks==0 && sync_rx[1];
    wire push=received && (count<32 || pop);
    assign valid=count!=0;
    assign data=valid ? fifo[head] : 8'd0;
    always @(posedge clk or posedge rst) begin
        if(rst) sync_rx<=2'b11;
        else sync_rx<={sync_rx[0],rx};
    end
    // No reset on FIFO contents; count gates all reads after reset.
    always @(posedge clk) if(push && !rst) fifo[tail]<=shift;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=IDLE; bit_index<=0; ticks<=0; shift<=0;
            head<=0; tail<=0; count<=0; framing_error<=0; overrun<=0;
        end else begin
            if(clear_errors[0]) framing_error<=0;
            if(clear_errors[1]) overrun<=0;
            if(pop) head<=head+1'b1;
            if(push) tail<=tail+1'b1;
            case({push,pop})
                2'b10: count<=count+1'b1;
                2'b01: count<=count-1'b1;
                default: ;
            endcase
            if(received && !push) overrun<=1;
            case(state)
                IDLE: if(!sync_rx[1]) begin state<=START; ticks<=HALF[CW-1:0]; end
                START: if(ticks!=0) ticks<=ticks-1'b1;
                    else if(sync_rx[1]) state<=IDLE;
                    else begin state<=BITS; ticks<=RELOAD[CW-1:0]; bit_index<=0; end
                BITS: if(ticks!=0) ticks<=ticks-1'b1;
                    else begin
                        shift[bit_index]<=sync_rx[1]; ticks<=RELOAD[CW-1:0];
                        if(bit_index==7) state<=STOP;
                        else bit_index<=bit_index+1'b1;
                    end
                STOP: if(ticks!=0) ticks<=ticks-1'b1;
                    else if(!sync_rx[1]) begin framing_error<=1; state<=RECOVER; end
                    else state<=IDLE;
                RECOVER: if(sync_rx[1]) state<=IDLE;
                default: state<=IDLE;
            endcase
        end
    end
`ifndef SYNTHESIS
    initial if(BAUD<=0 || DIVISOR<4) $fatal(1,"UART RX requires >=4 clocks per bit");
`endif
endmodule
