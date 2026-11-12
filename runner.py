import os
import sys
import yaml
import subprocess



design = sys.argv[1]
d = "designs/" + design
run_dir = d + "/RUN"

# RUN / LOG / OUT / RPT 폴더가 없으면 만들기 (Git 에서 제외된 폴더라 새로 받으면 없음)
os.makedirs(d + "/RUN", exist_ok=True)
os.makedirs(d + "/LOG", exist_ok=True)
os.makedirs(d + "/OUT", exist_ok=True)
os.makedirs(d + "/RPT", exist_ok=True)


# =====================================================================
# 1. 설정 파일 생성 : design.yaml → design_cfg.tcl / design_cfg.sh
# =====================================================================

# 1-1. design.yaml 읽기
yaml_path = d + "/CFG/design.yaml"
f = open(yaml_path)
cfg = yaml.safe_load(f)
f.close()

# 1-2. 필요한 값 꺼내기
top = cfg["top"]
rtl_list = cfg["rtl_files"]
sdc = cfg["sdc"]
rtl = " ".join(rtl_list)

# 1-3. design_cfg.tcl 쓰기 (합성 / LEC / STA 용)
tcl_path = d + "/CFG/design_cfg.tcl"
f = open(tcl_path, "w")
f.write("set TOP       " + top + "\n")
f.write("set RTL_FILES { " + rtl + " }\n")
f.write("set SDC       " + sdc + "\n")
f.close()

# 1-4. design_cfg.sh 쓰기 (Lint 용)
sh_path = d + "/CFG/design_cfg.sh"
f = open(sh_path, "w")
f.write("TOP=" + top + "\n")
f.write('RTL_FILES="' + rtl + '"\n')
f.write("SDC=" + sdc + "\n")
f.close()

print("[cfg] config generated (top =", top, ")")


# =====================================================================
# 2. lint : 로그에 %Error 있으면 중단 / warning 개수 기록
# =====================================================================
print("[lint] running...")
lint_log = d + "/LOG/lint.log"

# 2-1. 지난 결과 지우기
if os.path.exists(lint_log):
    os.remove(lint_log)

# 2-2. 실행
subprocess.run(["bash", "../../../scripts/lint/run_lint.sh"], cwd=run_dir)

# 2-3. 로그 있는지 확인
if not os.path.exists(lint_log):
    print("[lint] FAIL : lint.log not found, stop")
    exit()

# 2-4. 로그 읽기
f = open(lint_log)
log = f.read()
f.close()

# 2-5. 값 꺼내기
n_warn = log.count("%Warning-")

# 2-6. 판정
if "%Error" in log:
    print("[lint] FAIL : error found, stop")
    exit()

print("[lint] PASS : warning", n_warn)


# =====================================================================
# 3. syn : 로그에 ERROR 있거나 netlist 없으면 중단
#          warning 개수 / check problems / 면적은 기록
#          (DC 방식 : Error 는 중단, check_design 결과와 면적은 기록 후 검토)
# =====================================================================
print("[syn] running...")
syn_log = d + "/LOG/syn.log"
syn_check = d + "/RPT/syn_check.rpt"
syn_area = d + "/RPT/syn_area.rpt"
netlist = d + "/OUT/" + top + ".netlist.v"

# 3-1. 지난 결과 지우기
if os.path.exists(syn_log):
    os.remove(syn_log)
if os.path.exists(syn_check):
    os.remove(syn_check)
if os.path.exists(syn_area):
    os.remove(syn_area)
if os.path.exists(netlist):
    os.remove(netlist)

# 3-2. 실행
subprocess.run(["bash", "../../../scripts/syn/run_syn.sh"], cwd=run_dir)

# 3-3. 로그 있는지 확인
if not os.path.exists(syn_log):
    print("[syn] FAIL : syn.log not found, stop")
    exit()

# 3-4. 로그 읽기 → ERROR 확인 / warning 개수
f = open(syn_log)
syn_text = f.read()
f.close()

syn_warn = syn_text.count("Warning:")

if "ERROR:" in syn_text:
    print("[syn] FAIL : ERROR in syn.log, stop")
    exit()

# 3-5. netlist 생성 확인
if not os.path.exists(netlist):
    print("[syn] FAIL : netlist not generated, stop")
    exit()

# 3-6. check 리포트 읽기 → problems 꺼내기 (기록용)
#      "Found and reported 0 problems."
#        0     1   2        3  4          ← 단어 번호
problems = -1
if os.path.exists(syn_check):
    f = open(syn_check)
    check_text = f.read()
    f.close()
    check_lines = check_text.splitlines()
    for line in check_lines:
        if "Found and reported" in line:
            words = line.split()
            problems = int(words[3])

# 3-7. area 리포트 읽기 → 면적 꺼내기 (기록용)
#      "Chip area for top module '\gcd': 465.766000"
#       ':' 로 나눈 마지막 조각 = " 465.766000"
area = "?"
if os.path.exists(syn_area):
    f = open(syn_area)
    area_text = f.read()
    f.close()
    area_lines = area_text.splitlines()
    for line in area_lines:
        if "Chip area for top module" in line:
            parts = line.split(":")
            last = parts[-1]
            area = last.strip()

# 3-8. 결과 출력 (check problems 가 0 이 아니면 경고로 표시)
if problems != 0:
    print("[syn] PASS (check WARN) : area", area, ", warning", syn_warn, ", check problems", problems)
else:
    print("[syn] PASS : area", area, ", warning", syn_warn, ", check problems 0")


# =====================================================================
# 4. lec : unproven 있으면 중단
# =====================================================================
print("[lec] running...")
lec_rpt = d + "/RPT/lec_status.rpt"

# 4-1. 지난 결과 지우기
if os.path.exists(lec_rpt):
    os.remove(lec_rpt)

# 4-2. 실행
subprocess.run(["bash", "../../../scripts/lec/run_lec.sh"], cwd=run_dir)

# 4-3. 리포트 있는지 확인
if not os.path.exists(lec_rpt):
    print("[lec] FAIL : lec_status.rpt not found, stop")
    exit()

# 4-4. 리포트 읽기 → proven / unproven 꺼내기
#      "Of those cells 868 are proven and 0 are unproven."
#        0  1     2     3   4   5      6   7 8   9        ← 단어 번호
f = open(lec_rpt)
lec_text = f.read()
f.close()
lec_lines = lec_text.splitlines()

proven = -1
unproven = -1
for line in lec_lines:
    if "are proven and" in line:
        words = line.split()
        proven = int(words[3])
        unproven = int(words[7])

# 4-5. 판정
if unproven != 0:
    print("[lec] FAIL : unproven", unproven, ", stop")
    exit()

print("[lec] PASS : proven", proven, ", unproven 0")


# =====================================================================
# 5. sta : WNS / TNS 기록, 위반 경로 분류 (위반이어도 중단하지 않음)
# =====================================================================
print("[sta] running...")
sta_summary = d + "/RPT/sta_summary.rpt"
sta_viol = d + "/RPT/sta_violators.rpt"

# 5-1. 지난 결과 지우기
if os.path.exists(sta_summary):
    os.remove(sta_summary)
if os.path.exists(sta_viol):
    os.remove(sta_viol)

# 5-2. 실행
subprocess.run(["bash", "../../../scripts/sta/run_sta.sh"], cwd=run_dir)

# 5-3. 리포트 있는지 확인
if not os.path.exists(sta_summary):
    print("[sta] FAIL : sta_summary.rpt not found, stop")
    exit()
if not os.path.exists(sta_viol):
    print("[sta] FAIL : sta_violators.rpt not found, stop")
    exit()

# 5-4. summary 읽기 → WNS / TNS 꺼내기
#      "wns max -0.571"  → 마지막 단어 = -0.571
f = open(sta_summary)
summary_text = f.read()
f.close()
summary_lines = summary_text.splitlines()

wns = None
tns = None
for line in summary_lines:
    if line.startswith("wns"):
        words = line.split()
        wns = float(words[-1])
    if line.startswith("tns"):
        words = line.split()
        tns = float(words[-1])

# 5-5. violators 읽기 → 위반 경로 분류
#      "dpath/b_reg/_49_/Q (DFF_X1)   dpath/a_reg/_63_/D (DFF_X1)   -0.57"
#      - "----" 줄 아래부터가 실제 경로
#      - "(" 로 시작하는 단어 (DFF_X1) 는 셀 이름이라 제외
#      - 이름에 "/" 있으면 레지스터 핀, 없으면 포트
f = open(sta_viol)
viol_text = f.read()
f.close()
viol_lines = viol_text.splitlines()

viol = []
r2r = 0
i2r = 0
r2o = 0
i2o = 0
in_data = False

for line in viol_lines:

    # "----" 줄을 만나면 그 다음 줄부터 데이터
    if line.startswith("----"):
        in_data = True
        continue

    # 데이터 구간이 아니면 건너뜀
    if in_data == False:
        continue

    # 빈 줄이면 건너뜀
    if line.strip() == "":
        continue

    # 단어로 쪼개기
    words = line.split()

    # "(" 로 시작하는 단어는 빼고 이름만 모으기 → [출발, 도착, slack]
    names = []
    for w in words:
        if not w.startswith("("):
            names.append(w)

    start = names[0]
    end = names[1]
    slack = float(names[2])

    # 출발 / 도착이 레지스터인지 포트인지
    start_is_reg = "/" in start
    end_is_reg = "/" in end

    # 종류 정하기
    if start_is_reg and end_is_reg:
        kind = "r2r"
        r2r = r2r + 1
    elif (not start_is_reg) and end_is_reg:
        kind = "i2r"
        i2r = i2r + 1
    elif start_is_reg and (not end_is_reg):
        kind = "r2o"
        r2o = r2o + 1
    else:
        kind = "i2o"
        i2o = i2o + 1

    # 목록에 저장
    viol.append([kind, start, end, slack])

# 5-6. 판정 / 출력
if wns >= 0:
    print("[sta] MET      : wns", wns, ", tns", tns)
else:
    print("[sta] VIOLATED : wns", wns, ", tns", tns)

n_viol = len(viol)
print("[sta] violations", n_viol, ": r2r", r2r, ", i2r", i2r, ", r2o", r2o, ", i2o", i2o)


# =====================================================================
# 6. 결과 저장 : results/summary_<design>.csv
#    str() : 숫자 → 글자 (글자끼리만 + 로 이어 붙일 수 있어서)
# =====================================================================
os.makedirs("results", exist_ok=True)

csv_path = "results/summary_" + design + ".csv"
f = open(csv_path, "w")
f.write("design,lint_warn,syn_warn,check_problems,area,lec_proven,wns,tns,n_viol,r2r,i2r,r2o,i2o\n")
f.write(design + "," + str(n_warn) + "," + str(syn_warn) + "," + str(problems) + ","
        + area + "," + str(proven) + ","
        + str(wns) + "," + str(tns) + "," + str(n_viol) + ","
        + str(r2r) + "," + str(i2r) + "," + str(r2o) + "," + str(i2o) + "\n")
f.close()

print("[csv] saved :", csv_path)



# 6-2. 위반 경로 목록 : results/violators_<design>.csv
#      viol 의 한 줄 = [종류, 출발, 도착, slack]
viol_path = "results/violators_" + design + ".csv"
f = open(viol_path, "w")
f.write("type,startpoint,endpoint,slack\n")

for v in viol:
    kind = v[0]
    start = v[1]
    end = v[2]
    slack = v[3]
    f.write(kind + "," + start + "," + end + "," + str(slack) + "\n")

f.close()
print("[csv] saved :", viol_path)

# =====================================================================
# 7. 끝
# =====================================================================
print("[done] all stages finished")
