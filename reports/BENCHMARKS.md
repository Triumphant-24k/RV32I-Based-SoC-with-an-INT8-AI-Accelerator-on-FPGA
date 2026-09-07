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
| 0 | zeros | 0 | 2230 | 8 | 387 | 278.75x | 5.76x |
| 1 | positive | 120 | 2230 | 8 | 387 | 278.75x | 5.76x |
| 2 | negative | -204 | 2254 | 8 | 387 | 281.75x | 5.82x |
| 3 | cancel | 0 | 2242 | 8 | 387 | 280.25x | 5.79x |
| 4 | max_positive | 131072 | 2230 | 8 | 387 | 278.75x | 5.76x |
| 5 | max_negative | -130048 | 2254 | 8 | 387 | 281.75x | 5.82x |
| 6 | positive_extreme | 129032 | 2230 | 8 | 387 | 278.75x | 5.76x |
| 7 | last_only | -16256 | 2233 | 8 | 387 | 279.12x | 5.77x |
| 8 | mixed | -34181 | 2251 | 8 | 387 | 281.38x | 5.82x |
| 9 | both_negative | 168 | 2230 | 8 | 387 | 278.75x | 5.76x |
| 10 | random_000 | -27959 | 2245 | 8 | 387 | 280.62x | 5.80x |
| 11 | random_001 | 26325 | 2236 | 8 | 387 | 279.50x | 5.78x |
| 12 | random_002 | -12173 | 2242 | 8 | 387 | 280.25x | 5.79x |
| 13 | random_003 | -4138 | 2242 | 8 | 387 | 280.25x | 5.79x |
| 14 | random_004 | -8899 | 2242 | 8 | 387 | 280.25x | 5.79x |
| 15 | random_005 | -5166 | 2245 | 8 | 387 | 280.62x | 5.80x |
| 16 | random_006 | 5578 | 2239 | 8 | 387 | 279.88x | 5.79x |
| 17 | random_007 | 10051 | 2236 | 8 | 387 | 279.50x | 5.78x |
| 18 | random_008 | 16943 | 2239 | 8 | 387 | 279.88x | 5.79x |
| 19 | random_009 | -2866 | 2242 | 8 | 387 | 280.25x | 5.79x |
| 20 | random_010 | 2593 | 2239 | 8 | 387 | 279.88x | 5.79x |
| 21 | random_011 | 5051 | 2245 | 8 | 387 | 280.62x | 5.80x |
| 22 | random_012 | -9127 | 2242 | 8 | 387 | 280.25x | 5.79x |
| 23 | random_013 | 12751 | 2242 | 8 | 387 | 280.25x | 5.79x |
| 24 | random_014 | -24613 | 2245 | 8 | 387 | 280.62x | 5.80x |
| 25 | random_015 | 3182 | 2236 | 8 | 387 | 279.50x | 5.78x |

Ratio of summed measured cycles: CPU/ACC **280.00x**, CPU/E2E **5.79x**.
These ratios describe only these 26 vectors, this CPU, firmware, and memory configuration.

## Synchronous memory with seeded request backpressure

Back-to-back counter-read delta: **6 cycles**.

| ID | Case | Signed result | CPU | ACC | E2E | CPU/ACC | CPU/E2E |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | zeros | 0 | 3017 | 8 | 544 | 377.12x | 5.55x |
| 1 | positive | 120 | 2995 | 8 | 524 | 374.38x | 5.72x |
| 2 | negative | -204 | 2962 | 8 | 541 | 370.25x | 5.48x |
| 3 | cancel | 0 | 3086 | 8 | 530 | 385.75x | 5.82x |
| 4 | max_positive | 131072 | 2968 | 8 | 501 | 371.00x | 5.92x |
| 5 | max_negative | -130048 | 3038 | 8 | 528 | 379.75x | 5.75x |
| 6 | positive_extreme | 129032 | 2971 | 8 | 556 | 371.38x | 5.34x |
| 7 | last_only | -16256 | 3003 | 8 | 572 | 375.38x | 5.25x |
| 8 | mixed | -34181 | 2993 | 8 | 526 | 374.12x | 5.69x |
| 9 | both_negative | 168 | 2981 | 8 | 532 | 372.62x | 5.60x |
| 10 | random_000 | -27959 | 2994 | 8 | 515 | 374.25x | 5.81x |
| 11 | random_001 | 26325 | 2902 | 8 | 533 | 362.75x | 5.44x |
| 12 | random_002 | -12173 | 3052 | 8 | 553 | 381.50x | 5.52x |
| 13 | random_003 | -4138 | 2963 | 8 | 551 | 370.38x | 5.38x |
| 14 | random_004 | -8899 | 2999 | 8 | 529 | 374.88x | 5.67x |
| 15 | random_005 | -5166 | 2939 | 8 | 539 | 367.38x | 5.45x |
| 16 | random_006 | 5578 | 3106 | 8 | 517 | 388.25x | 6.01x |
| 17 | random_007 | 10051 | 3030 | 8 | 530 | 378.75x | 5.72x |
| 18 | random_008 | 16943 | 3016 | 8 | 528 | 377.00x | 5.71x |
| 19 | random_009 | -2866 | 2981 | 8 | 547 | 372.62x | 5.45x |
| 20 | random_010 | 2593 | 3033 | 8 | 507 | 379.12x | 5.98x |
| 21 | random_011 | 5051 | 2998 | 8 | 540 | 374.75x | 5.55x |
| 22 | random_012 | -9127 | 3009 | 8 | 544 | 376.12x | 5.53x |
| 23 | random_013 | 12751 | 3015 | 8 | 532 | 376.88x | 5.67x |
| 24 | random_014 | -24613 | 3060 | 8 | 583 | 382.50x | 5.25x |
| 25 | random_015 | 3182 | 2954 | 8 | 517 | 369.25x | 5.71x |

Ratio of summed measured cycles: CPU/ACC **375.31x**, CPU/E2E **5.61x**.
These ratios describe only these 26 vectors, this CPU, firmware, and memory configuration.

