# Review Notes — KinetMagicDisk 1.0.0

> 粘贴到 ASC「App Review Information / Notes」(英文为审核主语言,其余语言可留空)

## English (paste into Notes)

KinetMagicDisk is a disk-space visualizer. It scans the file system and draws
an interactive sunburst map; users can drill into folders and move files to
the Trash.

**How to test in 60 seconds**

1. Launch the app. Press the big "Scan Home" button (or "Scan Folder…" to
   pick any folder).
2. A live sunburst map appears while scanning. When finished, the list on the
   right shows the largest folders.
3. Click any arc (or list row) to drill down; click the breadcrumb to go back.
4. Hover a list row and press the trash icon to move a folder to the Trash
   (macOS Trash — fully reversible). The map and list update instantly.

**Permissions model (important for review)**

- The app is fully sandboxed. It has NO network entitlements, no Apple Events,
  no automation. Nothing leaves the device — the Privacy Policy URL states the
  same, and `PrivacyInfo.xcprivacy` is bundled (no tracking, no collected data;
  UserDefaults access declared under reason CA92.1).
- File access uses the standard user-selected read-write entitlement: scanning
  requires the user to explicitly choose a folder in the system open panel
  ("Scan Folder…"), or to press "Scan Home" which triggers the same consent
  flow for the Home folder via the open panel. Access is persisted with
  app-scoped security-scoped bookmarks so users don't re-grant on every launch.
- Deletion uses only `FileManager.trashItem` (files go to the Trash and can be
  restored). The app never deletes permanently.

**Demo account**: not applicable — the app is fully offline with no accounts,
no server, no subscriptions.

If anything looks broken on your side, the fastest repro is: launch →
"Scan Folder…" → pick any folder with a few thousand files (e.g. /Applications).

---

## 中文(备查,可不填)

KinetMagicDisk 是磁盘空间可视化工具:扫描文件系统并绘制交互式旭日图,
可下钻目录、把文件移入废纸篓。

- 完全沙盒:无网络、无自动化权限;数据不出设备。
- 文件访问走标准 user-selected read-write:扫描必须由用户在系统面板中
  明确选择文件夹("Scan Folder…");"Scan Home" 同样经系统面板对 Home
  目录授权,并用 app-scope 书签持久化,避免每次重复授权。
- 删除仅调用系统 trashItem(进废纸篓,可恢复),绝不永久删除。
- 无账号/无服务器/无订阅,无需演示账号。

快速验证:启动 → "Scan Folder…" → 任选一个有几千个文件的文件夹
(如 /Applications)→ 点击弧形区块下钻 → hover 列表行点垃圾桶图标删除。
