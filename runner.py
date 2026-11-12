import yaml
import subprocess

design = "gcd"
d = "designs/" + design

# ① YAML 읽기
cfg = yaml.safe_load(open(d + "/CFG/design.yaml"))

# ② RTL 목록을 띄어쓰기로 이어 붙이기
rtl = " ".join(cfg["rtl_files"])

# ③ design_cfg.tcl 쓰기
f = open(d + "/CFG/design_cfg.tcl", "w")
f.write("set TOP       " + cfg["top"] + "\n")
f.write("set RTL_FILES { " + rtl + " }\n")
f.write("set SDC       " + cfg["sdc"] + "\n")
f.close()

# ④ design_cfg.sh 쓰기
f = open(d + "/CFG/design_cfg.sh", "w")
f.write("TOP=" + cfg["top"] + "\n")
f.write('RTL_FILES="' + rtl + '"\n')
f.write("SDC=" + cfg["sdc"] + "\n")
f.close()

print("설정 파일 생성 완료")


# ⑤ 4개 stage 순서대로 실행
#    = cd designs/gcd/RUN 후 bash run_xxx.sh
#    cwd : 이 폴더에서 실행 (cd 역할)
run_dir = d + "/RUN"

print("lint 실행 중...")
subprocess.run(["bash", "../../../scripts/lint/run_lint.sh"], cwd=run_dir)

print("syn 실행 중...")
subprocess.run(["bash", "../../../scripts/syn/run_syn.sh"], cwd=run_dir)

print("lec 실행 중...")
subprocess.run(["bash", "../../../scripts/lec/run_lec.sh"], cwd=run_dir)

print("sta 실행 중...")
subprocess.run(["bash", "../../../scripts/sta/run_sta.sh"], cwd=run_dir)

print("전체 완료")
