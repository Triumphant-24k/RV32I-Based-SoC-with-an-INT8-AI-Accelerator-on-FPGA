# Measured simulation benchmarks

Generated from the CPU firmware UART stream, decoded from TX bits in Icarus Verilog.
All results were independently compared to Python integer arithmetic. No FPGA measurement is claimed.

## Measurement definitions

- CPU: cycle-counter delta around the runtime software dot product, including function/call/loop overhead.
- ACC: accepted start to completion; exactly eight subsequent clock edges, one signed product per edge.
- E2E: cycle-counter delta including all 16 input MMIO writes, start, polling, and result read.
- Input case preparation and all UART formatting/transmission are outside both timed regions.
- The 32-bit SoC counter increments every clock, including memory stalls. Unsigned subtraction handles one wrap.
- Deltas are raw: counter-read overhead is retained, not subtracted. Back-to-back reads are reported below.
- Compute-only ratio is CPU/ACC; end-to-end ratio is CPU/E2E. The former excludes data movement.
- The software baseline uses a bounded eight-round shift/add multiply for each signed byte pair. It is a reproducible reference, not a claim of optimal RV32I software.
- Testbench timing parameters are 1 MHz clock / 100 kbaud (10 clocks per UART bit), not an allocated board clock. Cycle ratios do not depend on UART printing.

## Synchronous memory, no request backpressure

Back-to-back counter-read delta: **5 cycles**.

| ID | Case | Signed result | CPU | ACC | E2E | CPU/ACC | CPU/E2E |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | zeros | 0 | 1870 | 8 | 385 | 233.75x | 4.86x |
| 1 | positive | 120 | 1909 | 8 | 385 | 238.62x | 4.96x |
| 2 | negative | -204 | 1933 | 8 | 385 | 241.62x | 5.02x |
| 3 | cancel | 0 | 2050 | 8 | 385 | 256.25x | 5.32x |
| 4 | max_positive | 131072 | 1894 | 8 | 385 | 236.75x | 4.92x |
| 5 | max_negative | -130048 | 2062 | 8 | 385 | 257.75x | 5.36x |
| 6 | positive_extreme | 129032 | 2038 | 8 | 385 | 254.75x | 5.29x |
| 7 | last_only | -16256 | 1894 | 8 | 385 | 236.75x | 4.92x |
| 8 | mixed | -34181 | 1954 | 8 | 385 | 244.25x | 5.08x |
| 9 | both_negative | 168 | 1942 | 8 | 385 | 242.75x | 5.04x |
| 10 | random_000 | -27959 | 1954 | 8 | 385 | 244.25x | 5.08x |
| 11 | random_001 | 26325 | 1954 | 8 | 385 | 244.25x | 5.08x |
| 12 | random_002 | -12173 | 1969 | 8 | 385 | 246.12x | 5.11x |
| 13 | random_003 | -4138 | 1966 | 8 | 385 | 245.75x | 5.11x |
| 14 | random_004 | -8899 | 1978 | 8 | 385 | 247.25x | 5.14x |
| 15 | random_005 | -5166 | 1960 | 8 | 385 | 245.00x | 5.09x |
| 16 | random_006 | 5578 | 1990 | 8 | 385 | 248.75x | 5.17x |
| 17 | random_007 | 10051 | 1957 | 8 | 385 | 244.62x | 5.08x |
| 18 | random_008 | 16943 | 1981 | 8 | 385 | 247.62x | 5.15x |
| 19 | random_009 | -2866 | 1960 | 8 | 385 | 245.00x | 5.09x |
| 20 | random_010 | 2593 | 1945 | 8 | 385 | 243.12x | 5.05x |
| 21 | random_011 | 5051 | 1969 | 8 | 385 | 246.12x | 5.11x |
| 22 | random_012 | -9127 | 1969 | 8 | 385 | 246.12x | 5.11x |
| 23 | random_013 | 12751 | 1963 | 8 | 385 | 245.38x | 5.10x |
| 24 | random_014 | -24613 | 1960 | 8 | 385 | 245.00x | 5.09x |
| 25 | random_015 | 3182 | 1951 | 8 | 385 | 243.88x | 5.07x |

Ratio of summed measured cycles: CPU/ACC **245.06x**, CPU/E2E **5.09x**.
These ratios describe only these 26 vectors, this CPU, firmware, and memory configuration.

## Synchronous memory with seeded request backpressure

Back-to-back counter-read delta: **6 cycles**.

| ID | Case | Signed result | CPU | ACC | E2E | CPU/ACC | CPU/E2E |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | zeros | 0 | 2530 | 8 | 555 | 316.25x | 4.56x |
| 1 | positive | 120 | 2586 | 8 | 513 | 323.25x | 5.04x |
| 2 | negative | -204 | 2614 | 8 | 525 | 326.75x | 4.98x |
| 3 | cancel | 0 | 2770 | 8 | 557 | 346.25x | 4.97x |
| 4 | max_positive | 131072 | 2523 | 8 | 504 | 315.38x | 5.01x |
| 5 | max_negative | -130048 | 2764 | 8 | 546 | 345.50x | 5.06x |
| 6 | positive_extreme | 129032 | 2683 | 8 | 517 | 335.38x | 5.19x |
| 7 | last_only | -16256 | 2534 | 8 | 548 | 316.75x | 4.62x |
| 8 | mixed | -34181 | 2697 | 8 | 512 | 337.12x | 5.27x |
| 9 | both_negative | 168 | 2603 | 8 | 519 | 325.38x | 5.02x |
| 10 | random_000 | -27959 | 2613 | 8 | 512 | 326.62x | 5.10x |
| 11 | random_001 | 26325 | 2608 | 8 | 504 | 326.00x | 5.17x |
| 12 | random_002 | -12173 | 2720 | 8 | 544 | 340.00x | 5.00x |
| 13 | random_003 | -4138 | 2575 | 8 | 503 | 321.88x | 5.12x |
| 14 | random_004 | -8899 | 2632 | 8 | 510 | 329.00x | 5.16x |
| 15 | random_005 | -5166 | 2604 | 8 | 530 | 325.50x | 4.91x |
| 16 | random_006 | 5578 | 2673 | 8 | 539 | 334.12x | 4.96x |
| 17 | random_007 | 10051 | 2620 | 8 | 514 | 327.50x | 5.10x |
| 18 | random_008 | 16943 | 2696 | 8 | 529 | 337.00x | 5.10x |
| 19 | random_009 | -2866 | 2633 | 8 | 531 | 329.12x | 4.96x |
| 20 | random_010 | 2593 | 2550 | 8 | 539 | 318.75x | 4.73x |
| 21 | random_011 | 5051 | 2759 | 8 | 497 | 344.88x | 5.55x |
| 22 | random_012 | -9127 | 2554 | 8 | 521 | 319.25x | 4.90x |
| 23 | random_013 | 12751 | 2609 | 8 | 531 | 326.12x | 4.91x |
| 24 | random_014 | -24613 | 2641 | 8 | 544 | 330.12x | 4.85x |
| 25 | random_015 | 3182 | 2568 | 8 | 516 | 321.00x | 4.98x |

Ratio of summed measured cycles: CPU/ACC **328.65x**, CPU/E2E **5.00x**.
These ratios describe only these 26 vectors, this CPU, firmware, and memory configuration.

