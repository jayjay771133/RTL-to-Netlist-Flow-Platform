#!/usr/bin/env bash
# =====================================================================

source ~/Desktop/backflow/env.sh

yosys -c ../../../scripts/syn/syn.tcl 2>&1 | tee ../LOG/syn.log
