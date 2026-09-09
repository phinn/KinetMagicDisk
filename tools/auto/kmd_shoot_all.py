#!/usr/bin/env python3
"""
用法: tools/auto/kmd_shoot_all.py
为 KinetMagicDisk 截 4 张 ASC 截图(en/ja/zh-Hans/zh-Hant),通过非沙盒 build + AUTOSHOT 环境
要求: entitlements 已临时去掉 app-sandbox,ContentView frame 已设 1280x768,代码加 print 日志
"""
import subprocess, time, os, sys, signal

LANGS = [
    ("en", "Scan Home", "File"),
    ("ja", "ホームをスキャン", "ファイル"),
    ("zh-Hans", "扫描个人目录", "文件"),
    ("zh-Hant", "掃描個人目錄", "檔案"),
]
APP = "/tmp/kmd_nosb/Build/Products/Debug/KinetMagicDisk.app"  # AUTOSHOT 仅 Debug 生效
OUT_DIR = "/Users/phinn/Documents/kinet/KinetMagicDisk/docs/asc/screenshots"

def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)

def reset_prefs():
    run(["pkill", "-9", "-f", "MacOS/KinetMagicDisk"])
    time.sleep(2)
    run(["killall", "cfprefsd"])
    time.sleep(1)
    home = os.path.expanduser("~")
    plist = f"{home}/Library/Preferences/com.kitnet.magicdisk.plist"
    plist2 = f"{home}/Library/Containers/com.kitnet.magicdisk/Data/Library/Preferences/com.kitnet.magicdisk.plist"
    try: os.remove(plist)
    except FileNotFoundError: pass
    subprocess.run(["plutil", "-remove", "kmd.rootBookmark", plist2], capture_output=True)

def menu_click_scan(item_name="Scan Home", menu_name="File"):
    """用 System Events 点 File > Scan Home 菜单项(实测唯一可靠触发路径;SwiftUI idle 大按钮 AXPress 无 actions、坐标点击被 splitter/侧栏吞)"""
    script = f'''
tell application "System Events"
    tell process "KinetMagicDisk"
        set frontmost to true
        delay 0.5
        click menu item "{item_name}" of menu "{menu_name}" of menu bar item "{menu_name}" of menu bar 1
    end tell
end tell
'''
    r = run(["osascript", "-e", script])
    if r.returncode == 0:
        return True
    print(f"  menu click failed: {r.stderr.strip()}")
    return False


def rows_count():
    r = run(["python3", "/tmp/kmd_rows_once.py"])
    for line in r.stdout.splitlines():
        if "rows" in line:
            try:
                return int(line.split(":")[-1].strip())
            except ValueError:
                return -1
    return -1

def wait_scan_done(pid, limit=900):
    """扫描完成判定:rows>50 且(两隔 15s 的 itemCount 快照相同)。Chrome 缓存等 IO 慢目录会让 CPU 长期不涨,不能用 CPU 判定"""
    stable_rows = 0
    last_rows = -99
    for i in range(limit // 5):
        time.sleep(5)
        rows = rows_count()
        try:
            cpu = run(["ps", "-o", "cputime=", "-p", str(pid)]).stdout.strip()
        except Exception:
            cpu = "?"
        sys.stdout.write(f"  t={i*5}s rows={rows} cpu={cpu}\n")
        sys.stdout.flush()
        if rows > 50:
            if rows == last_rows:
                stable_rows += 1
                if stable_rows >= 3:
                    sys.stdout.write(f"  STABLE rows={rows}\n")
                    return True
            else:
                stable_rows = 0
            last_rows = rows
    return False

def shoot(out_path):
    import Quartz
    from AppKit import NSWorkspace
    wl = Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionAll, Quartz.kCGNullWindowID)
    for w in wl:
        if (str(w.get("kCGWindowOwnerName", "")) == "KinetMagicDisk" 
            and w.get("kCGWindowName") == "KinetMagicDisk"
            and w.get("kCGWindowLayer") == 0):
            wid = int(w["kCGWindowNumber"])
            tmp = f"/tmp/kmd_{os.path.basename(out_path)}"
            subprocess.run(["screencapture", "-x", "-o", "-l", str(wid), tmp])
            os.makedirs(os.path.dirname(out_path), exist_ok=True)
            subprocess.run(["sips", "--matchTo", "/System/Library/ColorSync/Profiles/sRGB Profile.icc",
                            tmp, "--out", out_path], capture_output=True)
            info = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "space", out_path],
                                  capture_output=True, text=True).stdout
            return info
    return None

for lang, btn_text, menu_name in LANGS:
    print(f"\n=== {lang} ===")
    reset_prefs()
    run(["launchctl", "setenv", "KMD_AUTOSHOT", "1"])
    run(["defaults", "write", "NSGlobalDomain", "AppleLanguages", "-array", lang])
    run(["open", "-n", APP])
    time.sleep(12)
    pid = int(run(["pgrep", "-f", "MacOS/KinetMagicDisk"]).stdout.strip().split("\n")[0])
    print(f"  PID={pid}")
    # wait idle
    time.sleep(3)
    if not menu_click_scan(btn_text, menu_name):
        continue
    print(f"  scanning...")
    if not wait_scan_done(pid):
        print(f"  ! {lang} scan timeout")
        continue
    out = f"{OUT_DIR}/{lang}/01-main.png"
    info = shoot(out)
    print(f"  saved {out}: {info}")

print("\n=== DONE ===")
