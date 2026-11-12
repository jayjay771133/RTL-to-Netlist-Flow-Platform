# Debug Log

Issues found while building the flow, with root cause and fix.
Each entry maps to the equivalent concept in commercial tools where relevant.

---

## Environment

### 1. CUDD build fails: `aclocal-1.14: command not found`
- **Cause**: Pre-generated autotools files expect a specific automake version.
- **Fix**: Regenerate with `autoreconf -fi`, then configure / make.

---

## Lint (Verilator)

### 2. Lint stops with `BADVLTPRAGMA` errors on gcd
- **Cause**: The RTL is generator-produced (PyMTL) and contains `// verilator ...` comments,
  which Verilator parses as tool pragmas.
- **Fix**: Waived the pragma check; reviewed remaining 17 warnings by type.

### 3. `LATCH` warnings (2) in the controller
- **Check**: Cross-checked with synthesis — no latch cells in the netlist (DFF only).
- **Result**: Recorded as reviewed, not a functional issue.

---

## Synthesis (Yosys)

### 4. `check` reports 18 "used but has no driver" problems
- **Cause**: Library cell pin directions were unknown to the tool.
- **Fix**: `read_liberty -lib` before synthesis.
- **Equivalent**: `link_library` setup in DC.

### 5. Buffer explosion (413 BUF_X1, area 2x) after `insbuf`
- **Cause**: Buffer insertion while preserving names created a buffer per named wire.
- **Fix**: Removed `insbuf` — buffering and tie cells belong to P&R, not front-end synthesis.

---

## LEC

### 6. LEC fails 51/51 compare points (eqy)
- **Cause**: Synthesis re-encoded the FSM (binary → one-hot), so state registers no longer match RTL.
- **Fix**: `synth -nofsm`.
- **Equivalent**: Formality needs SVF guidance for FSM re-encoding.

### 7. LEC fails on register outputs after cleanup
- **Cause**: `opt_clean -purge` removed register output net names → compare points could not be matched.
- **Fix**: Use `opt_clean` without `-purge`.
- **Equivalent**: Name-based compare point matching in Formality.

### 8. False mismatches on registers without reset (eqy: 107/658 failing)
- **Cause**: eqy's SAT check unrolls from an initial state; reset-less data registers
  (gcd `a_reg`, `b_reg`) start unknown, producing false inequivalence.
- **Fix**: Switched to Yosys `equiv_*` flow — match by name, combinational proof,
  then induction (`equiv_induct`) for register loops.
- **Result**: 868 / 868 compare points proven.
- **Equivalent**: Formality's register-based matching + verification.

---

## Platform generalization (adding aes)

### 9. aes lint fails: `Cannot find include file: 'timescale.v'`
- **Cause**: RTL uses `` `include "timescale.v" ``; tools search includes relative to the run directory.
  gcd has no includes, so this was not visible.
- **Fix**: Added `-I../RTL` to lint / synthesis / LEC RTL reads.
- **Equivalent**: `+incdir+` (VCS), `search_path` (DC).
- **Regression**: Re-ran gcd after the change.

### 10. gcd synthesis broke after fix #9: `No filename given`
- **Cause**: Typo `read_verilog -I $f` — the RTL file was consumed as the include directory argument.
- **Fix**: `read_verilog -I../RTL $f`.
- **Found by**: Regression run on gcd.

### 11. aes LEC aborts: `No SAT model available for cell ... ($mem_v2)`
- **Cause**: When reading RTL for LEC, Yosys converted the `aes_rcon` constant `case` table into a
  ROM (memory cell). The SAT engine has no model for memory cells.
  The netlist side was fine — synthesis already maps memories to logic.
- **Fix**: `memory_map` on the reference (RTL) side before comparison.

### 12. LEC compare point count dropped from 868 to 90
- **Check**: Per-stage reports (`lec_after_make` / `lec_after_struct`).
- **Result**: 868 compare points matched; 778 merged by structural comparison (`equiv_struct`),
  remaining 90 proven by SAT / induction. Not a loss of coverage.

---

## Verification of the judgement logic

### 13. Error injection
| Test | Injection | Result |
|------|-----------|--------|
| Lint | Syntax error appended to gcd RTL | `[lint] FAIL`, flow stopped |
| LEC | One `NAND2_X1` swapped to `NOR2_X1` in netlist | 20 unproven, located at `a_reg` input cone |

---

## Git

### 14. Generated config files committed by mistake
- **Cause**: `.gitignore` pattern had a space (`design_cfg. *`).
- **Fix**: Corrected pattern, `git rm --cached`, amended the commit.
