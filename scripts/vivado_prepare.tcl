# Run only after allocation, from the repository root:
# vivado -mode batch -source scripts/vivado_prepare.tcl -tclargs boards/confirmed.tcl
# This prepares a synthesized checkpoint and reports. It never programs a board.
if {$argc != 1} { error "Pass one completed board configuration Tcl file" }
source [lindex $argv 0]
foreach required {PART CLOCK_HZ BAUD RELEASE_CYCLES PIN_XDC TOP DEMO} {
    if {![info exists $required]} { error "Missing board setting $required" }
}
if {$PART eq "" || $CLOCK_HZ <= 0 || $BAUD <= 0 || $RELEASE_CYCLES <= 0} {
    error "Part, clock, baud, and reset release settings must be confirmed"
}
if {![file isfile $PIN_XDC]} { error "Missing verified pin constraints" }
if {$TOP ni {fpga_top led_test_top uart_test_top}} { error "Unsupported demonstration top" }
if {$DEMO ni {integrated cpu}} { error "DEMO must be integrated or cpu" }
set divisor [expr {int($CLOCK_HZ / $BAUD)}]
if {$divisor < 4} { error "UART needs >=4 clocks/bit" }
set actual_baud [expr {double($CLOCK_HZ)/$divisor}]
if {abs($actual_baud-$BAUD)/$BAUD > 0.02} { error "UART divider error exceeds 2 percent" }
file mkdir build/vivado
foreach f {alu branch_unit control_unit cpu_core immediate_generator load_store_unit register_file} {
    read_verilog -sv rtl/$f.v
}
read_verilog -sv [glob rtl/soc/*.sv]
read_verilog -sv [glob rtl/board/*.sv]
read_xdc $PIN_XDC
set generics [list CLOCK_HZ=$CLOCK_HZ RELEASE_CYCLES=$RELEASE_CYCLES]
if {$TOP ne "led_test_top"} { lappend generics BAUD=$BAUD }
if {$TOP eq "fpga_top" && $DEMO eq "cpu"} {
    lappend generics ROM_HEX=firmware/hex/cpu_rom.hex RAM_HEX=firmware/hex/cpu_ram.hex
}
synth_design -top $TOP -part $PART -generic $generics
create_clock -name soc_clock -period [expr {1.0e9/$CLOCK_HZ}] [get_ports clk]
foreach port [get_ports] {
    if {[get_property PACKAGE_PIN $port] eq "" || [get_property IOSTANDARD $port] eq "DEFAULT"} {
        error "Unconfigured physical port $port"
    }
}
report_drc -file build/vivado/drc.txt
check_timing -verbose -file build/vivado/check_timing.txt
report_timing_summary -report_unconstrained -file build/vivado/timing_synth.txt
report_utilization -file build/vivado/utilization_synth.txt
write_checkpoint -force build/vivado/synth.dcp
puts "Synthesis preparation complete. Inspect all reports; placement, routing and timing closure are still required."
