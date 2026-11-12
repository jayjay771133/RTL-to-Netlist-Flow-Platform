#!/usr/bin/env bash
# =====================================================================

source ~/Desktop/backflow/env.sh

sta -exit ../../../scripts/sta/sta.tcl 2>&1 | tee ../LOG/sta.log
