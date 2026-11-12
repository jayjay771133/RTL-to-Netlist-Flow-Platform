#!/usr/bin/env bash

# =====================================================================

# EDA 환경
source ~/Desktop/backflow/env.sh        

# 디자인 설정 (TOP, RTL_FILES)
source ../CFG/design_cfg.sh            


# Verilator lint 실행
#   --lint-only          : 시뮬레이션 모델은 만들지 않고 문법·코딩 규칙 검사만
#   -Wall                : 모든 Warning 종류 켜기 (스타일 규칙 포함)
#   -Wno-fatal           : Warning 이 있어도 중단하지 않음 (Error 일 때만 중단)
#   --top-module "$TOP"  : top 모듈 지정 (design_cfg.sh 의 TOP)
#   $RTL_FILES           : 검사할 RTL 파일 목록 (design_cfg.sh 의 RTL_FILES)
#                          ※ 따옴표 없이 씀 → "a.v b.v" 가 파일 2개로 나뉘어 들어감
#   2>&1                 : Verilator 는 Warning/Error 를 에러 출력(2)으로 내보내므로
#                          일반 출력(1)과 합쳐서 함께 넘김
#   | tee ../LOG/lint.log: 화면에도 보여주고 로그 파일에도 저장

verilator --lint-only -Wall -Wno-fatal --top-module "$TOP" $RTL_FILES 2>&1 | tee ../LOG/lint.log
