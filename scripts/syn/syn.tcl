# syn.tcl : Yosys 합성 (DC 대응)
# =====================================================================


yosys -import

# 라이브러리 설정 ($lib)
source ../../../scripts/common/lib_setup.tcl

# 디자인 설정 ($TOP, $RTL_FILES)
source ../CFG/design_cfg.tcl            


# 1. 라이브러리 + RTL 읽기  (DC: link_library / analyze + elaborate)
read_liberty -lib $lib
foreach f $RTL_FILES { read_verilog -I../RTL $f }

# 2. 합성  (DC: compile 앞부분)
#    -nofsm : FSM 재인코딩 금지 (LEC 매칭 유지)
#    계층 유지 (-flatten 미사용)
synth -top $TOP -nofsm

# 3. lib 셀 매핑  (DC: compile 의 sequential / combinational mapping)
dfflibmap -liberty $lib
abc -liberty $lib

# 4. 정리  (-purge 미사용: 레지스터 이름 보존 → LEC 매칭)
opt_clean
# 자동 번호 셀 이름(_2522_)을 연결된 RTL 신호 이름 기반으로 변경
autoname

# 5. 리포트  (DC: report_area / check_design)
tee -o ../RPT/syn_area.rpt  stat -liberty $lib -top $TOP
tee -o ../RPT/syn_check.rpt check

# 6. netlist 출력  (DC: write -format verilog)
write_verilog -noattr -noexpr ../OUT/$TOP.netlist.v
