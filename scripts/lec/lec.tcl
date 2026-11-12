#   목적      : RTL(reference)과 합성 netlist(implementation)가 같은 논리인지 증명
#   방식      : 레지스터를 기준점으로 짝지은 뒤 그 사이 조합 로직을 비교,
#               레지스터 루프는 귀납법으로 증명
#
#   yosys -import    : Yosys 명령을 일반 Tcl 명령처럼 사용
#   lib_setup.tcl    : 라이브러리 설정 ($lib)
#   design_cfg.tcl   : 디자인 설정 ($TOP, $RTL_FILES)
# =====================================================================

yosys -import
source ../../../scripts/common/lib_setup.tcl
source ../CFG/design_cfg.tcl


# =====================================================================
# 1. Reference = RTL   (Formality: read_verilog -r / set_top r:/WORK/<top>)
#
#   read_verilog         : RTL 파일 목록을 하나씩 읽음
#   prep -flatten -top   : 비교 가능한 형태로 정리 (always 블록 → 논리, FF 인식)
#                          하위 모듈을 펼쳐서 한 덩어리로 (비교할 때만 펼침, netlist 파일은 계층 유지)
#   yosys rename ... gold: netlist 와 구분하기 위해 이름을 gold 로 변경
#                          (Tcl 기본 명령 rename 과 이름이 겹쳐서 yosys 를 붙임)
#   design -stash gold   : gold 보관함에 저장 후 작업 공간 비우기 (다음 설계를 읽기 위해)
# =====================================================================

foreach f $RTL_FILES { read_verilog $f }
prep -flatten -top $TOP
yosys rename $TOP gold
design -stash gold


# =====================================================================
# 2. Implementation = 합성 netlist   (Formality: read_db -i / read_verilog -i)
#
#   read_liberty         : netlist 셀(AND2_X1, DFF_X1 등)이 어떤 논리인지 알기 위해
#                          lib 의 셀 기능 정의를 로드 (-lib 없이 읽어야 논리 기능까지 로드됨)
#   -ignore_miss_func    : 기능 정의를 해석할 수 없는 셀(CLKGATETST_X1)은 제외
#                          → 해당 셀이 netlist 에서 사용되지 않음을 확인한 뒤 적용
#   read_verilog         : 합성 netlist 읽기
#   prep -flatten -top   : RTL 과 같은 방식으로 정리 + 펼치기
#   yosys rename ... gate: 이름을 gate 로 변경
#   design -stash gate   : gate 보관함에 저장
# =====================================================================

read_liberty -ignore_miss_func $lib
read_verilog ../OUT/$TOP.netlist.v
prep -flatten -top $TOP
yosys rename $TOP gate
design -stash gate


# =====================================================================
# 3. 비교   (Formality: match + verify)
#
#   design -copy-from    : 보관함의 gold / gate 를 한 작업 공간으로 불러옴
#   equiv_make           : 이름이 같은 신호끼리 짝짓기 (= match), 비교용 모듈 equiv 생성
#   hierarchy -top       : 비교용 모듈 equiv 를 top 으로 지정
#   equiv_simple -seq 5  : 기준점 사이의 조합 로직이 같은지 증명
#   equiv_induct -seq 5  : 레지스터 루프를 귀납법으로 증명
#                          (현재 상태가 같으면 다음 상태도 같은가 → reset 없는 레지스터도 증명 가능)
#   equiv_status         : proven / unproven 개수를 리포트로 저장
#   equiv_status -assert : 증명 안 된 항목이 있으면 에러로 종료 (= verify FAIL)
# =====================================================================

design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
equiv_make gold gate equiv
hierarchy -top equiv
equiv_simple -seq 5
equiv_induct -seq 5
tee -o ../RPT/lec_status.rpt equiv_status
equiv_status -assert
