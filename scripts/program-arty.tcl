# Manual, volatile JTAG programming only. Never sourced by the build/regression.
# AMD commands: https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands/program_hw_devices
# Without --program this only checks the selected bitstream and opens no hardware.
set root [file normalize [file join [file dirname [info script]] ..]]
set demo integrated
set program 0
while {[llength $argv]} {
    set option [lindex $argv 0];set argv [lrange $argv 1 end]
    switch -- $option {
        --program {set program 1}
        --demo {
            if {![llength $argv]} {error "Missing demo name"}
            set demo [lindex $argv 0];set argv [lrange $argv 1 end]
        }
        default {error "Unknown argument $option; use --demo integrated|cpu|uart|led and optional --program"}
    }
}
if {$demo ni {integrated cpu uart led}} {error "Unknown demo $demo"}
set bit [file join $root build vivado arty_a7_100t $demo arty_a7_top.bit]
if {![file isfile $bit] || [file size $bit]==0} {error "Missing/empty bitstream: $bit; complete a successful Vivado build first"}
if {!$program} {
    puts "PASS: bitstream exists: $bit. Hardware was not opened; add --program only when ready to program the confirmed Arty board."
    return
}
if {![llength [info commands open_hw_manager]]} {error "Run programming inside Vivado batch mode"}
open_hw_manager
set failed [catch {
    connect_hw_server -url localhost:3121
    set targets [get_hw_targets]
    if {[llength $targets]!=1} {error "Expected one connected programming target; use Hardware Manager to select explicitly: $targets"}
    current_hw_target [lindex $targets 0]
    open_hw_target
    set devices [get_hw_devices]
    if {[llength $devices]!=1} {error "Expected one FPGA; select explicitly in Hardware Manager: $devices"}
    set device [lindex $devices 0]
    if {![string match xc7a100t* [string tolower [get_property PART $device]]]} {
        error "Connected device is not an XC7A100T; refusing to program"
    }
    # JTAG identifies the FPGA die, not the development board or its pinout.
    # The operator must confirm the Arty A7-100T board before invoking --program.
    current_hw_device $device
    refresh_hw_device $device
    set_property PROGRAM.FILE $bit $device
    program_hw_devices $device
    refresh_hw_device $device
    puts "JTAG programming command completed. Open the UART terminal and press BTN0; firmware/hardware behavior still needs observation."
} message options]
close_hw_manager
if {$failed} {return -options $options $message}
