# =====================================================================
# sta.tcl : Pre-layout STA
#   툴        : OpenSTA (오픈소스 STA 엔진, PrimeTime 대응)
#               명령 체계는 PT 와 유사 (read_liberty / link_design / read_sdc / report_checks)
#   방식      : 합성 netlist + Liberty(.lib) + SDC 로 분석
#               SPEF 없음, wire load model 미설정 → 배선 cap 0
#               (셀 지연 + fanout 입력 핀 cap 만 반영)
#   라이브러리: Nangate45 Open Cell Library (교육용 45nm, typical 코너 1개)
#
#   lib_setup.tcl  : 라이브러리 설정 ($lib)
#   design_cfg.tcl : 디자인 설정 ($TOP, $SDC)
# =====================================================================

source ../../../scripts/common/lib_setup.tcl
source ../CFG/design_cfg.tcl


# =====================================================================
# 1. 읽기   (PT: link_library / read_verilog / link_design / read_sdc)
#
#   read_liberty : 셀 타이밍 정보 로드
#   read_verilog : 합성 netlist 로드
#   link_design  : top 기준으로 계층 연결
#   read_sdc     : 타이밍 제약 로드
# =====================================================================

read_liberty $lib
read_verilog ../OUT/$TOP.netlist.v
link_design  $TOP
read_sdc     $SDC


# =====================================================================
# 2. 제약 점검   (PT: check_timing -verbose)
#    no clock, unconstrained endpoint, loop 등을 한 번에 점검
#    리포트가 비어 있으면 문제 없음
# =====================================================================


check_setup -verbose > ../RPT/sta_check_setup.rpt

# =====================================================================
# 3. 타이밍 리포트   (PT: report_timing -max_paths N -nworst 1 / report_qor)
#    클럭 그룹별로 endpoint 마다 최악 경로 1 개씩 상세 출력 (그룹당 최대 100 개)
#    WNS / TNS 요약
# =====================================================================
report_checks -path_delay max -group_path_count 100 -endpoint_path_count 1 -digits 3 > ../RPT/sta_setup.rpt
report_checks -path_delay min -group_path_count 100 -endpoint_path_count 1 -digits 3 > ../RPT/sta_hold.rpt
report_wns -digits 3  > ../RPT/sta_summary.rpt
report_tns -digits 3 >> ../RPT/sta_summary.rpt


# =====================================================================
# 4. 위반 경로 목록   (PT: report_timing -max_paths N -nworst 1 -slack_lesser_than 0)
#    위반 경로만 Startpoint / Endpoint / Slack 한 줄씩 → Python 이 CSV 로 정리
# =====================================================================
report_checks -path_delay max -group_path_count 1000 -endpoint_path_count 1 -slack_max 0 -format summary > ../RPT/sta_violators.rpt
