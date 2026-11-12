# BackFlow

**Front-end implementation flow automation — Lint → Synthesis → LEC → STA**

Open-source EDA flow structured after commercial tools (SpyGlass / DC / Formality / PrimeTime).
A new design needs only a YAML config; flow scripts contain no design-specific code.

- **One command per design** — runs all stages, judges each result, stops on failure
- **Same scripts, two designs** — gcd and aes differ only in `design.yaml`
- **Error injection tested** — injected RTL and netlist errors are caught by Lint and LEC

---

## Flow

<p align="center"><img src="docs/flow.svg" alt="BackFlow flow" width="760"></p>

`python runner.py <design>` reads `design.yaml`, runs the four stages in order, and writes
`results/summary_<design>.csv` (one row of metrics) and `results/violators_<design>.csv`
(every violating path: type, startpoint, endpoint, slack).

| Stage     | Stop on                  | Record                            |
|:----------|:-------------------------|:----------------------------------|
| Lint      | `%Error`                 | Warnings                          |
| Synthesis | `ERROR`, missing netlist | Area, warnings, check problems    |
| LEC       | Unproven compare points  | Proven count                      |
| STA       | Missing report           | WNS, TNS, violations by path type |

Tool errors stop the flow; quality metrics are recorded for review.
Old reports are cleared before each stage so a failed run is never judged from a stale file.

---

## Results

From [`results/summary_gcd.csv`](results/summary_gcd.csv) and [`results/summary_aes.csv`](results/summary_aes.csv).

| Design | Clock (ns) | Lint warn | Area (µm²) | LEC  | WNS (ns) | TNS (ns) |
|:-------|-----------:|----------:|-----------:|:----:|---------:|---------:|
| gcd    |       0.25 |        17 |      465.8 | PASS |   -0.571 |   -18.07 |
| aes    |       0.82 |         4 |   13,476.9 | PASS |   -0.326 |   -60.01 |

**Setup violations by path type**

| Design | Violations | r2r | i2r | r2o | i2o |
|:-------|-----------:|----:|----:|----:|----:|
| gcd    |         51 |  34 |   0 |  17 |   0 |
| aes    |        368 | 368 |   0 |   0 |   0 |

**Worst setup path**

| Design | From          | To            | Slack (ns) | Logic between                     |
|:-------|:--------------|:--------------|-----------:|:----------------------------------|
| gcd    | `dpath.b_reg` | `dpath.a_reg` |     -0.571 | 16-bit subtractor -> mux          |
| aes    | `sa32`        | `sa23`        |     -0.326 | One AES round (S-box, MixColumns) |

- **gcd** — 51 of 52 endpoints violate at 0.25 ns; output slack worsens with bit position
  (`resp_msg[1]` -0.044 → `resp_msg[15]` -0.487), following the subtractor borrow chain
- **aes** — all violations are register-to-register between state bytes (`sa00`–`sa33`);
  IO paths are constrained and met (`check_setup` reports no unconstrained endpoints)
- Clock targets are aggressive benchmark values; STA is pre-layout (see Limitations)

Per-path lists: [`violators_gcd.csv`](results/violators_gcd.csv), [`violators_aes.csv`](results/violators_aes.csv)

---

## Error Injection Test

Errors were intentionally injected to confirm that each check fails when it should.

| Test       | Injection                              | Result                             |
|:-----------|:---------------------------------------|:-----------------------------------|
| Lint       | Syntax error in RTL                    | `FAIL`, synthesis not started      |
| LEC        | One `NAND2_X1` -> `NOR2_X1` in netlist | 20 unproven at `a_reg` input cone  |
| Regression | gcd re-run after aes script changes    | Caught `read_verilog -I` typo      |

---

## Usage

```bash
cp env.sh.example env.sh  # edit tool and library paths for your machine
source env.sh
python runner.py gcd
python runner.py aes
```

Run from the repository root.

**Adding a design** — put RTL and SDC under `designs/<name>/`, write `CFG/design.yaml`, run `python runner.py <name>`.

```yaml
top: aes_cipher_top
rtl_files:
  - ../RTL/aes_sbox.v
  - ../RTL/aes_rcon.v
  - ../RTL/aes_key_expand_128.v
  - ../RTL/aes_cipher_top.v
sdc: ../SDC/constraint.sdc
```

---

## Tool Mapping

| Stage     | This project    | Industry        |
|:----------|:----------------|:----------------|
| Lint      | Verilator       | SpyGlass        |
| Synthesis | Yosys           | Design Compiler |
| LEC       | Yosys `equiv_*` | Formality       |
| STA       | OpenSTA         | PrimeTime       |

Command-level mapping, design decisions, and SDC review: [docs/design_notes.md](docs/design_notes.md)
Issues and fixes: [docs/debug_log.md](docs/debug_log.md)

---

## Limitations

- Pre-layout STA — no SPEF, no wire load model, ideal clocks (optimistic)
- Nangate45 educational library, typical corner only
- Synthesis is not timing-driven — results are for analysis, not closure
- Benchmark SDCs lack driving cell, load, and clock uncertainty

## References

Designs and SDCs from [OpenROAD-flow-scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts) ·
Tools: [Yosys](https://github.com/YosysHQ/yosys), [OpenSTA](https://github.com/The-OpenROAD-Project/OpenSTA), [Verilator](https://github.com/verilator/verilator) ·
Library: Nangate45 Open Cell Library
