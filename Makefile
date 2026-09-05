.PHONY: test baseline firmware lint-synth
test:
	python3 scripts/regress.py
baseline:
	python3 scripts/baseline.py
firmware:
	python3 scripts/build_firmware.py
lint-synth:
	python3 scripts/check_rtl.py
