# Unidentified Artix-7 backup board

This target is a placeholder. It has no pin constraints or functional build target.

The required board information is:

- Exact development-board model and board revision.
- Full FPGA part number, package, and speed grade.
- Oscillator frequency and clock input pin.
- Reset/button pin and active polarity.
- UART RX/TX pins (FPGA perspective), routing to the host, and voltage standard.
- Available LED pins and active polarities.
- Programming interface and required cable/drivers.
- Official schematic or manufacturer master constraint file.

An Artix-7 device alone does not establish any of these board-level connections.
The Arty XDC is specific to the Arty A7-100 and is not a fallback constraint file.
