# Batch Vivado flow: Synthesis -> Place & Route -> Timing Analysis -> Bitstream Generation
# Usage:
#   vivado -mode batch -source scripts/vivado_build_bitstream.tcl -tclargs boards/arty_a7_35t.tcl
#   (or boards/arty_a7_100t.tcl)

if {$argc != 1} { error "Usage: vivado -mode batch -source scripts/vivado_build_bitstream.tcl -tclargs <board_config.tcl>" }
source [lindex $argv 0]

foreach required {PART CLOCK_HZ BAUD RELEASE_CYCLES PIN_XDC TOP DEMO} {
    if {![info exists $required]} { error "Missing board setting: $required" }
}

set divisor [expr {int($CLOCK_HZ / $BAUD)}]
if {$divisor < 4} { error "UART requires at least 4 clocks per baud tick" }
set actual_baud [expr {double($CLOCK_HZ) / $divisor}]
if {abs($actual_baud - $BAUD) / $BAUD > 0.02} { error "UART divider error exceeds 2 percent" }

file mkdir build/vivado

puts "========================================================"
puts "  Target Part:       $PART"
puts "  Top Module:        $TOP"
puts "  Clock Frequency:   $CLOCK_HZ Hz"
puts "  UART Baud Rate:    $BAUD bps"
puts "  Demo Selection:    $DEMO"
puts "========================================================"

# Read CPU RTL
foreach f {alu branch_unit control_unit cpu_core immediate_generator load_store_unit register_file} {
    read_verilog -sv rtl/$f.v
}
# Read SoC & Board RTL
read_verilog -sv [glob rtl/soc/*.sv]
read_verilog -sv [glob rtl/board/*.sv]

# Read Constraints
read_xdc $PIN_XDC

# Configure Top-Level Generics
set generics [list CLOCK_HZ=$CLOCK_HZ RELEASE_CYCLES=$RELEASE_CYCLES]
if {$TOP ne "led_test_top"} { lappend generics BAUD=$BAUD }
if {$TOP eq "fpga_top" && $DEMO eq "cpu"} {
    lappend generics ROM_HEX=firmware/hex/cpu_rom.hex RAM_HEX=firmware/hex/cpu_ram.hex
}

# 1. Synthesis
puts "\n>>> Starting Synthesis..."
synth_design -top $TOP -part $PART -generic $generics

# Constraint: Create primary clock
create_clock -name soc_clock -period [expr {1.0e9 / $CLOCK_HZ}] [get_ports clk]

# Verify all physical ports have pin assignments
foreach port [get_ports] {
    if {[get_property PACKAGE_PIN $port] eq "" || [get_property IOSTANDARD $port] eq "DEFAULT"} {
        error "Unconfigured physical port: $port"
    }
}

report_utilization -file build/vivado/utilization_synth.txt
write_checkpoint -force build/vivado/synth.dcp

# 2. Logic Optimization
puts "\n>>> Starting Logic Optimization..."
opt_design

# 3. Placement
puts "\n>>> Starting Placement..."
place_design
report_clock_utilization -file build/vivado/clock_util.txt
write_checkpoint -force build/vivado/placed.dcp

# 4. Routing
puts "\n>>> Starting Routing..."
route_design
report_drc -file build/vivado/drc_route.txt
report_timing_summary -report_unconstrained -file build/vivado/timing_route.txt
report_utilization -file build/vivado/utilization_route.txt
write_checkpoint -force build/vivado/routed.dcp

# Check Timing Closure
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "Worst Negative Slack (WNS): $wns ns"

# 5. Generate Bitstream
puts "\n>>> Writing Bitstream..."
write_bitstream -force build/vivado/ai_soc.bit

puts "\n========================================================"
puts "  BUILD COMPLETED SUCCESSFULLY!"
puts "  Bitstream:  build/vivado/ai_soc.bit"
puts "  Timing:     build/vivado/timing_route.txt"
puts "  Reports:    build/vivado/utilization_route.txt"
puts "========================================================"
