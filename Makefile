.PHONY: test baseline firmware lint-synth bitstream-35t bitstream-100t program
test:
	python3 scripts/regress.py
baseline:
	python3 scripts/baseline.py
firmware:
	python3 scripts/build_firmware.py
lint-synth:
	python3 scripts/check_rtl.py

# AMD Vivado Flows for Digilent Arty A7
bitstream-35t:
	vivado -mode batch -source scripts/vivado_build_bitstream.tcl -tclargs boards/arty_a7_35t.tcl
bitstream-100t:
	vivado -mode batch -source scripts/vivado_build_bitstream.tcl -tclargs boards/arty_a7_100t.tcl
program:
	vivado -mode batch -source scripts/vivado_program.tcl

