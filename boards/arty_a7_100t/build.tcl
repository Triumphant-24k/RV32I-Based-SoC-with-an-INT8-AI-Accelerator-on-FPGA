# Non-project flow. Run with Vivado, or --check-only with a Tcl interpreter.
# Official command references: https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands
set root [file normalize [file join [file dirname [info script]] ../..]]
cd $root
set demo integrated
set part xc7a100tcsg324-1
set check_only 0
while {[llength $argv]} {
    set option [lindex $argv 0];set argv [lrange $argv 1 end]
    switch -- $option {
        --check-only {set check_only 1}
        --demo - --part {
            if {![llength $argv]} {error "Missing value for $option"}
            set value [lindex $argv 0];set argv [lrange $argv 1 end]
            if {$option eq "--demo"} {set demo $value} else {set part $value}
        }
        default {error "Unknown build argument $option"}
    }
}
if {$demo ni {integrated cpu uart led}} {error "Demo must be integrated, cpu, uart, or led"}
if {![regexp {^xc7a100t[a-z0-9-]+$} $part]} {error "Part is not an Arty A7-100 device: $part"}
set top arty_a7_top
set mode [dict get {integrated 0 cpu 0 uart 1 led 2} $demo]
set stem [expr {$demo eq "cpu" ? "board_cpu" : "board"}]
set rom build/firmware/${stem}_rom.hex
set ram build/firmware/${stem}_ram.hex
set xdc boards/arty_a7_100t/arty_a7_100t.xdc
set sources {
    rtl/alu.v rtl/branch_unit.v rtl/control_unit.v rtl/cpu_core.v
    rtl/immediate_generator.v rtl/load_store_unit.v rtl/register_file.v
    rtl/soc/int8_accelerator.sv rtl/soc/uart_tx.sv rtl/soc/soc_bus.sv rtl/soc/ai_soc.sv
    rtl/board/reset_conditioner.sv rtl/board/uart_hello.sv
    boards/arty_a7_100t/arty_a7_top.sv
}
foreach path [concat $sources [list $xdc]] {
    if {![file isfile $path] || [file size $path]==0} {error "Required source/constraint missing or empty: $path"}
}
proc validate_memory {path is_program} {
    if {![file isfile $path]} {error "Missing $path; build firmware with python3 scripts/build_firmware.py"}
    set f [open $path r];set lines [split [string trimright [read $f] "\r\n"] \n];close $f
    if {[llength $lines]!=4096} {error "Malformed memory image $path: expected 4096 words"}
    set meaningful 0
    foreach line $lines {
        set line [string trimright $line \r]
        if {![regexp {^[0-9a-fA-F]{8}$} $line]} {error "Malformed memory word in $path"}
        scan $line %x word
        if {$word!=0 && $word!=19} {set meaningful 1}
    }
    scan [lindex $lines 0] %x entry
    if {$is_program && (!$meaningful || ($entry & 3)!=3)} {error "No RV32I program at reset vector in $path"}
}
if {$mode==0} {validate_memory $rom 1;validate_memory $ram 0}
if {$check_only} {
    puts "PASS: Tcl preflight demo=$demo part=$part; sources, constraints and selected images exist"
    return
}
if {![llength [info commands synth_design]]} {error "Vivado is unavailable: launch this script inside Vivado batch mode"}
if {[llength [get_parts $part]]!=1} {error "Install Vivado support for part $part"}
set out build/vivado/arty_a7_100t/$demo
file mkdir $out
# Source paths and image generics are relative to root, including when the root has spaces.
# Synthesis consumes the validated image files via the RTL's $readmemh calls.
foreach path $sources {read_verilog -sv $path}
read_xdc $xdc
set generics [list CLOCK_HZ=100000000 BAUD=115200 RELEASE_CYCLES=1000000 MODE=$mode]
if {$mode==0} {lappend generics "ROM_HEX=\"$rom\"" "RAM_HEX=\"$ram\""}
synth_design -top $top -part $part -generic $generics
set expected_ports [lsort {clk reset_n uart_rx uart_tx led[0] led[1] led[2] led[3]}]
if {[lsort [get_ports]] ne $expected_ports} {error "Synthesized top does not match the eight constrained physical ports"}
foreach port [get_ports] {
    if {[get_property PACKAGE_PIN $port] eq "" || [get_property IOSTANDARD $port] ne "LVCMOS33"} {
        error "Missing/wrong pin standard on $port"
    }
}
if {[llength [get_clocks]]!=1 || [get_property PERIOD [get_clocks soc_clock]]!=10.0} {
    error "Expected exactly one 100 MHz soc_clock"
}
report_utilization -file $out/utilization_synth.txt
write_checkpoint -force $out/synth.dcp
opt_design
place_design
phys_opt_design
route_design
report_route_status -file $out/route_status.txt
report_utilization -file $out/utilization_route.txt
report_timing_summary -delay_type min_max -report_unconstrained -file $out/timing_summary.txt
report_clock_interaction -file $out/clock_interaction.txt
report_cdc -file $out/cdc.txt
report_drc -file $out/drc.txt
set timing_checks [check_timing -verbose -return_string]
set f [open $out/check_timing.txt w];puts $f $timing_checks;close $f
# Fail closed if a version's check_timing format is unrecognized. No warning is downgraded.
set counts [regexp -all -inline {checking\s+([[:alnum:]_]+)\s+\(([0-9]+)\)} $timing_checks]
if {![llength $counts]} {error "Cannot parse check_timing; inspect $out/check_timing.txt before generating a bitstream"}
foreach {match check count} $counts {
    if {$count!=0} {error "Timing check $check has $count issue(s); see $out/check_timing.txt"}
}
foreach delay {max min} {
    set paths [get_timing_paths -delay_type $delay -max_paths 1]
    if {![llength $paths]} {error "Missing $delay timing paths"}
    set slack [get_property SLACK [lindex $paths 0]]
    if {![string is double -strict $slack] || $slack<0} {error "$delay timing failed, slack=$slack"}
}
foreach rule [get_drc_checks -filter {SEVERITY == "Error" || SEVERITY == "Critical Warning"}] {
    if {[llength [get_drc_violations -of_objects $rule]]} {error "Blocking DRC $rule; see $out/drc.txt"}
}
write_checkpoint -force $out/routed.dcp
# write_bitstream performs its own final routing/DRC checks as well; errors propagate.
write_bitstream -force $out/$top.bit
puts "PASS: Vivado implementation and guarded bitstream generation completed: $out/$top.bit"
