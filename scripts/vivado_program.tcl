# Automated JTAG FPGA Programming Script for Arty A7
# Usage: vivado -mode batch -source scripts/vivado_program.tcl

set BITFILE "build/vivado/ai_soc.bit"
if {![file isfile $BITFILE]} {
    error "Bitstream file not found: $BITFILE. Please run vivado_build_bitstream.tcl first."
}

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set device [lindex [get_hw_devices xc7a*] 0]
if {$device eq ""} {
    error "No Artix-7 device detected on connected JTAG chain. Please verify USB connection and Digilent cable drivers."
}

puts ">>> Programming device $device with $BITFILE..."
set_property PROGRAM.FILE $BITFILE $device
program_hw_devices $device
refresh_hw_device $device

puts "\n>>> SUCCESS: FPGA successfully programmed!"
close_hw_target
disconnect_hw_server
close_hw_manager
