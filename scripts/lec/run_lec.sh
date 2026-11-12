#!/usr/bin/env bash
# =====================================================================
source ~/Desktop/backflow/env.sh

yosys -c ../../../scripts/lec/lec.tcl 2>&1 | tee ../LOG/lec.log
