# Design Notes

## Design Decisions

| Decision                          | Reason                                                 |
|:----------------------------------|:-------------------------------------------------------|
| Keep hierarchy in synthesis       | Hierarchical netlist; LEC flattens only for comparison |
| `synth -nofsm`                    | Re-encoded FSM registers cannot be matched to RTL      |
| `opt_clean` without `-purge`      | Keeps register names used as LEC compare points        |
| `autoname` after synthesis        | Readable cell names in STA reports                     |
| No buffer / tie-cell insertion    | Belongs to P&R, not front-end synthesis                |
| Name matching + induction for LEC | Avoids false mismatches on registers without reset     |
| `memory_map` on LEC reference     | SAT engine cannot model ROM cells from case tables     |
| `-I../RTL` on all RTL reads       | RTL uses include files; path stays out of RTL          |
| Generated config not tracked      | `design.yaml` is the source of truth                   |

## Command Mapping

| Purpose                 | This project                                   | Commercial                              |
|:------------------------|:-----------------------------------------------|:----------------------------------------|
| Library setup           | `read_liberty -lib`                            | DC `link_library`                       |
| Include path            | `read_verilog -I../RTL`                        | DC `search_path`, VCS `+incdir+`        |
| Synthesis               | `synth`, `dfflibmap`, `abc`                    | DC `compile`                            |
| Design check            | `check`                                        | DC `check_design`                       |
| Match                   | `equiv_make`                                   | Formality `match`                       |
| Prove                   | `equiv_struct`, `equiv_simple`, `equiv_induct` | Formality `verify`                      |
| Constraint check        | `check_setup -verbose`                         | PT `check_timing -verbose`              |
| Worst path per endpoint | `report_checks -endpoint_path_count 1`         | PT `report_timing -nworst 1`            |
| Violator list           | `report_checks -slack_max 0`                   | PT `report_timing -slack_lesser_than 0` |

## LEC Compare Points (gcd)

| Step                 | $equiv cells | Meaning                             |
|:---------------------|-------------:|:------------------------------------|
| After `equiv_make`   |          868 | All matched compare points          |
| After `equiv_struct` |           90 | 778 merged by structural match      |
| After `equiv_induct` |    90 proven | Remaining proven by SAT / induction |

## SDC Review (gcd)

| Item                    | Status  | Note                               |
|:------------------------|:-------:|:-----------------------------------|
| Clock on `clk`          |   OK    | 0.25 ns                            |
| Virtual clock for IO    |   OK    | `vclk_core_clock`                  |
| Input / output delay    |   OK    | 20% of period, all non-clock ports |
| Unconstrained endpoints |   OK    | None reported by `check_setup`     |
| Driving cell / load     | Missing | Optimistic                         |
| Clock uncertainty       | Missing | Optimistic                         |

Constraints were not loosened to remove violations; missing margins are listed as limitations.
