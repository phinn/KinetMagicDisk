#!/bin/bash
# 用法: kmd_shot_lang.sh <lang>  - 截图单语
set -e
LANG="$1"
PLIST=~/Library/Preferences/com.kitnet.magicdisk.plist
PLIST_CONTAINER=~/Library/Containers/com.kitnet.magicdisk/Data/Library/Preferences/com.kitnet.magicdisk.plist
APP=/tmp/kmd_nosb/Build/Products/Release/KinetMagicDisk.app
OUT_DIR=docs/asc/screenshots/$LANG

pkill -9 -f "MacOS/KinetMagicDisk" 2>/dev/null || true
sleep 2
killall cfprefsd 2>/dev/null || true
sleep 1
rm -f "$PLIST"
plutil -remove kmd.rootBookmark "$PLIST_CONTAINER" 2>/dev/null || true
defaults write NSGlobalDomain AppleLanguages -array "$LANG"

# 前台 launch (会卡但能看到)
"$APP/Contents/MacOS/KinetMagicDisk" > "/tmp/kmd_${LANG}.log" 2>&1 &
LAUNCH_PID=$!
disown
echo "[$LANG] launched PID $LAUNCH_PID"
sleep 8

# 按 Return
python3 -c "
import Quartz, time
e = Quartz.CGEventCreateKeyboardEvent(None, 0x24, True)
Quartz.CGEventPost(Quartz.kCGHIDEventTap, e)
time.sleep(0.1)
Quartz.CGEventPost(Quartz.kCGHIDEventTap, Quartz.CGEventCreateKeyboardEvent(None, 0x24, False))
"
sleep 4

# Choose
python3 -c "
import time
from ApplicationServices import *
from AppKit import NSRunningApplication
def val(el, attr):
    err, v = AXUIElementCopyAttributeValue(el, attr, None)
    return v if err == 0 else None
app = next(a for a in NSRunningApplication.runningApplicationsWithBundleIdentifier_('com.kitnet.magicdisk'))
ax = AXUIElementCreateApplication(app.processIdentifier())
wins = val(ax, kAXWindowsAttribute)
panel = next((w for w in wins if str(val(w, kAXTitleAttribute) or '') == 'Open'), None)
if panel:
    def find(el, role, title, d=0):
        if d > 14: return None
        if str(val(el, kAXRoleAttribute) or '') == role and str(val(el, kAXTitleAttribute) or '') == title:
            return el
        for k in val(el, kAXChildrenAttribute) or []:
            r = find(k, role, title, d+1)
            if r: return r
        return None
    btn = find(panel, 'AXButton', 'Choose')
    if btn:
        print('Choose:', AXUIElementPerformAction(btn, 'AXPress'))
"
echo "[$LANG] Choose pressed"
