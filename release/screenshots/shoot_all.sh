#!/bin/bash
# =============================================================================
# KinetMagicDisk — ASC 四语截图一键重摄
# 用法: bash release/screenshots/shoot_all.sh
#
# 流程:Debug 包(仅 Debug 有 KMD_AUTOSHOT 跳授权面板)→ 逐语言重置偏好 →
#       -AppleLanguages 切语言 → AX 点「扫描」→ 等扫描完成 → 2560x1600 sRGB 截图
# 产物: release/screenshots/{en,ja,zh-Hans,zh-Hant}/01-main.png
# 前置: xcodebuild -project KinetMagicDisk.xcodeproj -scheme KinetMagicDisk \
#         -configuration Debug -derivedDataPath /tmp/kmd_nosb \
#         -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
#       codesign --force --sign - /tmp/kmd_nosb/Build/Products/Debug/KinetMagicDisk.app
# =============================================================================
set -u
APP="/tmp/kmd_nosb/Build/Products/Debug/KinetMagicDisk.app"
OUT="$(cd "$(dirname "$0")" && pwd)"
LOG=/tmp/kmd_dbg.log

# 语言 → AX 扫描按钮描述(与 Localizable.xcstrings 一致)。用 bash 3 兼容写法(避免 declare -A)。
# 可用 KMD_LANGS="zh-Hans zh-Hant" 覆盖默认全量四语:
LANGS=(${KMD_LANGS:-en ja zh-Hans zh-Hant})
btn_for() {
  case "$1" in
    en) echo "Scan Home" ;;
    ja) echo "ホームをスキャン" ;;
    zh-Hans) echo "扫描个人目录" ;;
    zh-Hant) echo "掃描個人目錄" ;;
  esac
}

reset_state() {
  pkill -9 -f "MacOS/KinetMagicDisk" 2>/dev/null; sleep 2
  killall cfprefsd 2>/dev/null; sleep 1
  rm -f ~/Library/Preferences/com.kitnet.magicdisk.plist "$LOG"
  # 沙盒容器内偏好(若用沙盒 Debug 包):
  rm -f ~/Library/Containers/com.kitnet.magicdisk/Data/Library/Preferences/com.kitnet.magicdisk.plist
}

press_scan() {  # $1=按钮 AXDescription
python3 - "$1" <<'PYEOF'
import sys
from ApplicationServices import *
from AppKit import NSWorkspace
desc = sys.argv[1]
app = next(a for a in NSWorkspace.sharedWorkspace().runningApplications()
           if a.bundleIdentifier() == "com.kitnet.magicdisk")
ax = AXUIElementCreateApplication(app.processIdentifier())
def val(el, attr):
    err, v = AXUIElementCopyAttributeValue(el, attr, None)
    return v if err == 0 else None
def find(el, d=0):
    if d > 14: return None
    if str(val(el, "AXDescription") or "") == desc: return el
    for k in val(el, kAXChildrenAttribute) or []:
        r = find(k, d+1)
        if r: return r
wins = val(ax, kAXWindowsAttribute) or []
btn = None
for w in wins:
    btn = find(w)
    if btn: break
if not btn: sys.exit(2)
sys.exit(AXUIElementPerformAction(btn, "AXPress"))
PYEOF
}

wait_done() {  # $1=pid — rows>50 且 cputime 增量收敛(增量<3s 连续2次 → 视为扫描结束)
  local pid=$1 prev="" delta stable
  for i in $(seq 1 40); do
    sleep 12
    local rows cpu
    rows=$(python3 - "$pid" <<'PYEOF' 2>/dev/null
import sys
from ApplicationServices import *
from AppKit import NSWorkspace
app = next((a for a in NSWorkspace.sharedWorkspace().runningApplications()
            if a.bundleIdentifier() == "com.kitnet.magicdisk"), None)
if not app: print(0); raise SystemExit
ax = AXUIElementCreateApplication(app.processIdentifier())
def val(el, attr):
    err, v = AXUIElementCopyAttributeValue(el, attr, None)
    return v if err == 0 else None
n = 0
for w in val(ax, kAXWindowsAttribute) or []:
    def walk(el, d=0):
        global n
        if d > 14: return
        if str(val(el, kAXRoleAttribute) or "") == "AXOutline":
            rows = val(el, kAXRowsAttribute)
            n = max(n, len(rows) if rows else 0)
        for k in val(el, kAXChildrenAttribute) or []: walk(k, d+1)
    walk(w)
print(n)
PYEOF
)
    cpu=$(ps -o cputime= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -z "$cpu" ] && return 1
    if [ "$rows" -gt 50 ]; then
      # cputime "M:SS.hh" → 秒数
      secs=$(echo "$cpu" | awk -F'[:.]' '{ s=$1*60+$2; if ($3!="") s+=$3/100; print s }')
      if [ -n "$prev" ]; then
        delta=$(awk -v a="$secs" -v b="$prev" 'BEGIN{print a-b}')
        if awk -v d="$delta" 'BEGIN{exit !(d<3)}'; then
          stable=$((stable+1))
        else
          stable=0
        fi
        [ "$stable" -ge 1 ] && return 0
      fi
      prev=$secs
    fi
  done
  return 1
}

shoot() {  # $1=输出路径 — 选 owner 匹配、layer 0、面积最大的窗口(主窗),不看 title
python3 - "$1" <<'PYEOF'
import sys, subprocess, os
import Quartz
out = sys.argv[1]
best, best_area = None, 0
wl = Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID)
for w in wl:
    if str(w.get("kCGWindowOwnerName", "")) != "KinetMagicDisk":
        continue
    if w.get("kCGWindowLayer") != 0:
        continue
    b = w["kCGWindowBounds"]
    area = float(b["Width"]) * float(b["Height"])
    if area > best_area:
        best, best_area = w, area
if best is None:
    print("! 未找到 KinetMagicDisk 窗口")
    raise SystemExit(1)
wid = int(best["kCGWindowNumber"])
tmp = "/tmp/kmd_shot_tmp.png"
subprocess.run(["screencapture", "-x", "-o", "-l", str(wid), tmp], check=True)
os.makedirs(os.path.dirname(out), exist_ok=True)
subprocess.run(["sips", "--matchTo", "/System/Library/ColorSync/Profiles/sRGB Profile.icc",
                tmp, "--out", out], check=True, capture_output=True)
r = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", out],
                   capture_output=True, text=True).stdout
print(r.strip())
PYEOF
}

for lang in "${LANGS[@]}"; do
  echo "=== $lang ==="
  reset_state
  launchctl setenv KMD_AUTOSHOT 1
  defaults write NSGlobalDomain AppleLanguages -array "$lang"
  open -n "$APP"
  sleep 12
  pid=$(pgrep -f "MacOS/KinetMagicDisk" | head -1)
  [ -z "$pid" ] && { echo "  ! 启动失败"; continue; }
  sleep 3
  # AX 树就绪有竞态(ja→中文轮实测踩过),重试 3 次:
  pressed=""
  for try in 1 2 3; do
    if press_scan "$(btn_for "$lang")"; then pressed=1; break; fi
    echo "  press 重试 $try…"
    sleep 5
  done
  if [ -z "$pressed" ]; then echo "  ! AXPress 失败 ($(btn_for "$lang"))"; continue; fi
  echo "  scanning (pid=$pid)…"
  if ! wait_done "$pid"; then echo "  ! 扫描超时"; continue; fi
  shoot "$OUT/$lang/01-main.png"
  echo "  ✓ $lang 完成"
done

launchctl unsetenv KMD_AUTOSHOT
pkill -9 -f "MacOS/KinetMagicDisk" 2>/dev/null
echo "=== ALL DONE → $OUT ==="
