#!/usr/bin/env python3
# usage: python3 tools/auto/kmd_shot.py <en|ja|zh-Hans|zh-Hant>  — 带自动重试的四语截图脚本
# 策略:同进程第二刀(TCC 热缓存假说)→ 冷启动重来;截图用 -R 窗口 bounds 裁剪(不用 -l,防抓错窗口)
import sys, time, subprocess, os
import Quartz

LANG = sys.argv[1]
APP = "/tmp/kmd.xcarchive/Products/Applications/KinetMagicDisk.app"
OUT = f"/Users/phinn/Documents/kinet/KinetMagicDisk/docs/asc/screenshots/{LANG}/01-main.png"
BUTTON = {"en": "Rescan", "ja": "再スキャン", "zh-Hans": "重新扫描", "zh-Hant": "重新掃描"}[LANG]

def log(*a):
    print(f"[{time.strftime('%H:%M:%S')}]", *a, flush=True)

def kmd_bounds():
    wl = Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionAll, Quartz.kCGNullWindowID)
    for w in wl:
        if str(w.get("kCGWindowOwnerName", "")) == "KinetMagicDisk" and w.get("kCGWindowLayer") == 0:
            b = w["kCGWindowBounds"]
            return int(b["X"]), int(b["Y"]), int(b["Width"]), int(b["Height"])
    return None

def rows_count():
    try:
        out = subprocess.run(
            ["python3", "/tmp/kmd_rows_once.py"], capture_output=True, text=True, timeout=90
        ).stdout
    except subprocess.TimeoutExpired:
        return -1
    for line in out.splitlines():
        if "rows" in line:
            try:
                return int(line.split(":")[-1].strip())
            except ValueError:
                return -1
    return -1

def launch():
    subprocess.run(["pkill", "-9", "-f", "MacOS/KinetMagicDisk"], capture_output=True)
    time.sleep(3)
    subprocess.run(["open", "-n", APP, "--args", "-AppleLanguages", f'"({LANG})"'])
    time.sleep(14)

def press():
    r = subprocess.run(["python3", "/tmp/kmd_press.py", BUTTON], capture_output=True, text=True, timeout=90)
    log("press:", (r.stdout.strip() or r.stderr.strip())[:80])

def wait_rows(limit):
    t0 = time.time()
    last = -99
    while time.time() - t0 < limit:
        n = rows_count()
        if n != last:
            log(f"  t={time.time()-t0:.0f}s rows={n}")
            last = n
        if n > 5:
            return True
        time.sleep(4)
    return False

def shoot():
    b = kmd_bounds()
    if not b:
        log("no window!"); return False
    x, y, w, h = b
    log("bounds:", x, y, w, h)
    time.sleep(5)  # 等渲染稳定
    tmp = f"/tmp/kmd_shot_{LANG}.png"
    subprocess.run(["screencapture", "-x", "-o", f"-R{x},{y},{w},{h}", tmp])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    subprocess.run(["sips", "--matchTo", "/System/Library/ColorSync/Profiles/sRGB Profile.icc", tmp, "--out", OUT], capture_output=True)
    info = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", OUT], capture_output=True, text=True).stdout
    log("saved:", info.strip().replace("\n", " "))
    return "2560" in info and "1600" in info

def attempt(fresh, wait_limit, tag):
    if fresh:
        launch()
    press()
    ok = wait_rows(wait_limit)
    if ok:
        log(f"{tag}: rows OK")
        return shoot()
    log(f"{tag}: timeout, rows={rows_count()}")
    return False

launch()
for tag, fresh, limit in [
    ("A1", False, 100),   # 同进程第一刀
    ("A2", False, 160),   # 同进程第二刀(热缓存假说)
    ("B1", True, 160),    # 冷启动
    ("B2", False, 160),   # 冷启动后第二刀
]:
    if attempt(fresh, limit, tag):
        log("SUCCESS")
        sys.exit(0)
log("ALL ATTEMPTS FAILED")
sys.exit(1)
