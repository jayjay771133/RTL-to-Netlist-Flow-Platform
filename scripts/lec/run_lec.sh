#!/usr/bin/env bash
# =====================================================================

yosys -c ../../../scripts/lec/lec.tcl 2>&1 | tee ../LOG/lec.log
