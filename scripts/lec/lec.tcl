# =====================================================================
# lec.tcl : 등가성 검증 (Formality 대응)
#   목적      : RTL(reference)과 합성 netlist(implementation)가 같은 논리인지 증명
#   방식      : 이름이 같은 신호끼리 짝지은 뒤(match)
#               구조가 같은 부분은 먼저 병합, 남은 조합 로직은 SAT 로 증명,
#               레지스터 루프는 귀납법으로 증명 (verify)
#   실행 위치 : designs/<design>/RUN
#   출력      : ../RPT/lec_after_*.rpt (단계별), ../RPT/lec_status.rpt (최종)
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
#   read_verilog -I../RTL : RTL 파일 목록을 하나씩 읽음 (include 파일은 ../RTL 에서 찾음)
#   prep -flatten -top    : 비교 가능한 형태로 정리 (always 블록 → 논리, FF 인식)
#                           하위 모듈을 펼쳐서 한 덩어리로 (비교할 때만 펼침, netlist 파일은 계층 유지)
#   memory_map            : case 상수 표 등이 ROM(메모리 셀)으로 해석되면 SAT 증명 엔진이
#                           처리 못 하므로 일반 로직으로 변환 (합성의 synth 도 같은 변환을 수행)
#   yosys rename ... gold : netlist 와 구분하기 위해 이름을 gold 로 변경
#                           (Tcl 기본 명령 rename 과 이름이 겹쳐서 yosys 를 붙임)
#   design -stash gold    : gold 보관함에 저장 후 작업 공간 비우기 (다음 설계를 읽기 위해)
# =====================================================================
foreach f $RTL_FILES { read_verilog -I../RTL $f }
prep -flatten -top $TOP
memory_map
yosys rename $TOP gold
design -stash gold


# =====================================================================
# 2. Implementation = 합성 netlist   (Formality: read_db -i / read_verilog -i)
#
#   read_liberty          : netlist 셀(AND2_X1, DFF_X1 등)이 어떤 논리인지 알기 위해
#                           lib 의 셀 기능 정의를 로드 (-lib 없이 읽어야 논리 기능까지 로드됨)
#   -ignore_miss_func     : 기능 정의를 해석할 수 없는 셀(CLKGATETST_X1)은 제외
#                           → 해당 셀이 netlist 에서 사용되지 않음을 확인한 뒤 적용
#   read_verilog          : 합성 netlist 읽기
#   prep -flatten -top    : RTL 과 같은 방식으로 정리 + 펼치기
#   yosys rename ... gate : 이름을 gate 로 변경
#   design -stash gate    : gate 보관함에 저장
# =====================================================================
read_liberty -ignore_miss_func $lib
read_verilog ../OUT/$TOP.netlist.v
prep -flatten -top $TOP
yosys rename $TOP gate
design -stash gate


# =====================================================================
# 3. 비교   (Formality: match + verify)
#
#   design -copy-from     : 보관함의 gold / gate 를 한 작업 공간으로 불러옴
#   equiv_make            : 이름이 같은 신호끼리 짝짓기 (= match), 비교용 모듈 equiv 생성
#                           → lec_after_make.rpt : 처음 비교 지점 수 (전체 compare point)
#   hierarchy -top        : 비교용 모듈 equiv 를 top 으로 지정
#   equiv_struct          : 양쪽 구조가 똑같은 부분은 SAT 없이 먼저 병합 (가속)
#   opt_clean             : 병합되어 필요 없어진 비교 셀 정리
#                           → lec_after_struct.rpt : 남은 비교 지점 수
#   equiv_simple          : 남은 조합 로직을 SAT 로 증명
#   equiv_induct -seq 5   : 위에서 못 푼 레지스터 루프를 귀납법으로 증명
#                           (현재 상태가 같으면 다음 상태도 같은가 → reset 없는 레지스터도 증명 가능)
#   equiv_status          : proven / unproven 개수를 리포트로 저장
#   equiv_status -assert  : 증명 안 된 항목이 있으면 에러로 종료 (= verify FAIL)
# =====================================================================
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
equiv_make gold gate equiv
hierarchy -top equiv
tee -o ../RPT/lec_after_make.rpt equiv_status

equiv_struct
opt_clean
tee -o ../RPT/lec_after_struct.rpt equiv_status

equiv_simple
tee -o ../RPT/lec_after_simple.rpt equiv_status

equiv_induct -seq 5
tee -o ../RPT/lec_after_induct.rpt equiv_status

tee -o ../RPT/lec_status.rpt equiv_status
equiv_status -assert
