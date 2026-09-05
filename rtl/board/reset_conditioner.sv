// SPDX-License-Identifier: MIT
// Asynchronous assertion, synchronized and debounced release. Active-high input.
module reset_conditioner #(parameter integer RELEASE_CYCLES=1000)(
    input wire clk,input wire external_reset,output reg reset
);
    localparam integer CW=RELEASE_CYCLES<2?1:$clog2(RELEASE_CYCLES);
    localparam integer LAST_COUNT=RELEASE_CYCLES-1;
    (* ASYNC_REG="TRUE" *) reg [1:0] sync_reset;
    reg [CW-1:0] stable_count;
    always @(posedge clk or posedge external_reset) begin
        if(external_reset)sync_reset<=2'b11;
        else sync_reset<={sync_reset[0],1'b0};
    end
    always @(posedge clk or posedge external_reset) begin
        if(external_reset)begin reset<=1;stable_count<=0;end
        else if(sync_reset[1])begin reset<=1;stable_count<=0;end
        else if(stable_count==LAST_COUNT[CW-1:0])reset<=0;
        else begin stable_count<=stable_count+1'b1;reset<=1;end
    end
`ifndef SYNTHESIS
    initial if(RELEASE_CYCLES<1)$fatal(1,"Invalid reset debounce length");
`endif
endmodule
