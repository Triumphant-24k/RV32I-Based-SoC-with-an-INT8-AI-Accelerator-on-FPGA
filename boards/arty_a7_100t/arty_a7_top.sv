// SPDX-License-Identifier: MIT
// Board shell only: CPU, accelerator, memory map and transaction timing are unchanged.
module arty_a7_top #(
    parameter integer CLOCK_HZ=100000000, BAUD=115200,
    parameter integer RELEASE_CYCLES=1000000, HEARTBEAT_CYCLES=CLOCK_HZ/2,
    parameter integer ACTIVITY_CYCLES=CLOCK_HZ/20,
    // 0: real SoC; 1: standalone UART greeting; 2: standalone heartbeat/reset.
    parameter integer MODE=0,
    parameter ROM_HEX="build/firmware/board_rom.hex",
    parameter RAM_HEX="build/firmware/board_ram.hex"
)(input wire clk, input wire reset_btn, input wire uart_rx,
  output wire uart_tx, output wire [3:0] led);
    localparam integer HW=HEARTBEAT_CYCLES<2?1:$clog2(HEARTBEAT_CYCLES);
    localparam integer AW=ACTIVITY_CYCLES<2?1:$clog2(ACTIVITY_CYCLES+1);
    localparam integer HEARTBEAT_LAST=HEARTBEAT_CYCLES-1;
    reg [HW-1:0] heartbeat_count;
    reg [AW-1:0] activity_count;
    reg heartbeat;
    // FPGA configuration initializes this shift register; no free-running derived clock.
    reg [3:0] power_on=4'hf;
    // BTN0/D9 is low at rest and high when pressed. Configuration starts power_on
    // high; the conditioner then holds CPU/UART reset for a stable 10 ms release.
    // Only assertion is asynchronous; reset deassertion is clock synchronized.
    wire external_reset=reset_btn || (|power_on);
    wire conditioned_reset;
    // Keep reset known high even before the first clock initializes the conditioner.
    wire rst=external_reset || conditioned_reset;
    (* ASYNC_REG="TRUE" *) reg [1:0] rx_sync;
    wire [2:0] soc_led;
    always @(posedge clk) power_on<={power_on[2:0],1'b0};
    reset_conditioner #(.RELEASE_CYCLES(RELEASE_CYCLES)) reset_i(clk,external_reset,conditioned_reset);
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            rx_sync<=2'b11; heartbeat_count<=0; heartbeat<=0; activity_count<=0;
        end else begin
            rx_sync<={rx_sync[0],uart_rx};
            if(heartbeat_count==HEARTBEAT_LAST[HW-1:0])begin
                heartbeat_count<=0;heartbeat<=!heartbeat;
            end else heartbeat_count<=heartbeat_count+1'b1;
            // Integrated mode stretches the accelerator's eight-clock busy pulse
            // for 50 ms at defaults. Smoke modes retain the tested RX/TX indicator.
            // RX never controls CPU/accelerator state or implements a command port.
            if(MODE==0 ? soc_led[0] : (!rx_sync[1] || !uart_tx))
                activity_count<=ACTIVITY_CYCLES[AW-1:0];
            else if(activity_count!=0)activity_count<=activity_count-1'b1;
        end
    end
    generate
        if(MODE==0)begin: integrated
            ai_soc #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD),.ROM_HEX(ROM_HEX),.RAM_HEX(RAM_HEX))
                soc(clk,rst,uart_tx,soc_led);
        end else if(MODE==1)begin: serial_smoke
            uart_hello #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) greeting(clk,rst,uart_tx);
            assign soc_led=0;
        end else begin: led_smoke
            assign uart_tx=1'b1;
            assign soc_led=0;
        end
    endgenerate
    // LED0 heartbeat; LED1 reset or accelerator busy/recent activity; LED2 PASS;
    // LED3 FAIL/trap. Standalone smoke modes use LED1 for reset/UART activity.
    assign led={soc_led[2],soc_led[1],rst || soc_led[0] || activity_count!=0,heartbeat};
`ifndef SYNTHESIS
    initial if(MODE<0 || MODE>2 || HEARTBEAT_CYCLES<1 || ACTIVITY_CYCLES<1)
        $fatal(1,"Invalid Arty wrapper parameters");
`endif
endmodule
