#!/usr/bin/env bash
# =====================================================================


yosys -c ../../../scripts/syn/syn.tcl 2>&1 | tee ../LOG/syn.log
