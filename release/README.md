# KinetMagicDisk — Release 打包清单(v1.0.0, build 1)

> 交付目录 `release/` = 上架全部材料。逐项验收状态见下表,**全部 ✓**。
> Bundle ID `com.kitnet.magicdisk` · macOS 13+ · universal(arm64 + x86_64)· App Sandbox

## 1. ASC 元数据(四语 en / ja / zh-Hans / zh-Hant)

路径:`release/metadata/{lang}/`。字段与 ASC 填写框一一对应。

| 字段 | ASC 限制 | en | ja | zh-Hans | zh-Hant | 验收 |
|---|---|---|---|---|---|---|
| name.txt | 30 字符 | KinetMagicDisk(14) | 同左 | 同左 | 同左 | ✓ |
| subtitle.txt | 30 字符 | 26 | 14 | 12 | 12 | ✓ |
| promo.txt | 170 字符 | 168 | ✓ | ✓ | ✓ | ✓ |
| keywords.txt | 100 | 87 | **98 bytes**(压缩过,原 142 超限) | 97 | 97 | ✓ |
| description.txt | 4000 字符 | 1347 | 692 | 487 | 485 | ✓ |
| whatsnew.txt | 4000 字符 | ✓ | ✓ | ✓ | ✓ | ✓(1.0 首发) |

> keywords 乐观口径(字符数)与保守口径(UTF-8 bytes)均 ≤100,双保险。
> name 四语统一品牌名不翻译,描述由 subtitle 承载。

## 2. PrivacyInfo.xcprivacy

- 源:`Resources/PrivacyInfo.xcprivacy`(已入 git + 已验证进包)
- 包内位置:`KinetMagicDisk.app/Contents/Resources/PrivacyInfo.xcprivacy`(plutil -lint OK)
- 内容:NSPrivacyTracking=false、TrackingDomains=[]、CollectedDataTypes=[],
  UserDefaults 按 **CA92.1**(app 自身数据)声明 —— 与「零网络零收集」口径一致
- ⚠️ 流程教训:加入新资源后必须 `xcodegen generate` 再 archive(与 InfoPlist.strings 同坑)

## 3. 隐私政策 HTML(GitHub Pages 直接部署)

- `release/privacy/index.html` = `docs/privacy/index.html`(同源)
- 四语单页锚点:English / 日本語 / 简体中文 / 繁體中文
- 上线步骤(用户操作):
  ```bash
  gh repo create KinetMagicDisk --public --source=. --push   # 或网页建仓后 git push
  # GitHub → Settings → Pages → Deploy from branch → main /docs
  ```
- 生效 URL:`https://phinn.github.io/KinetMagicDisk/` → 填入 ASC Privacy Policy URL

## 4. 截图(四语 ×1,2560×1600 sRGB)

- 产物:`release/screenshots/{lang}/01-main.png`
- 规格:2560×1600(16:10)· sRGB IEC61966-2.1 · PNG ~520KB,ASC 合法档
- 内容:扫描完成态(旭日图 + 111 行列表),非 idle 空屏(彩色像素 912+ 实测)
- 四语 UI 均经 `-AppleLanguages` 实启验证,顶部 UI 指纹互异
- 重摄脚本:`release/screenshots/shoot_all.sh`(支持 `KMD_LANGS="zh-Hans"` 选语言)
  - 依赖 `/tmp/kmd_nosb` Debug 包(KMD_AUTOSHOT 仅 Debug 生效)
  - 已修三处:declare -A 改 bash3 兼容、AXPress 重试、窗口选择改「面积最大」不看 title

## 5. 审核备注(Review Notes)

- `release/review-notes.md` —— 英文主文贴 ASC Notes 区,中文备查
- 要点:60 秒复测路径、沙盒权限模型(user-selected + app-scope bookmark + trashItem)、
  无账号声明(演示账号栏填 not applicable)

## 6. 演示说明

- `release/demo-guide.md` —— 60 秒演示脚本 + 实测数据(1.6TB/330 万项/55s)+
  隐私叙事统一口径 + 与 DaisyDisk 差异表(内部参考)

## 7. 沙盒扫描权限过审方案(已实测)

| 环节 | 实现 | 实测 |
|---|---|---|
| 授权入口 | 系统统开面板(NSOpenPanel),无私有 API | ✓ AXDialog 实锤 |
| 持久授权 | app-scope security-scoped bookmark | ✓ 二次启动免授权 |
| 扫描范围 | 仅用户授权目录 + Home(经面板) | ✓ 沙盒包 111 行数据 |
| 删除 | FileManager.trashItem(可恢复) | ✓ 全链路实测 |
| 网络 | 无 network entitlement,物理离线 | ✓ entitlements 自查 |

沙盒 Release 包实测链路:启动(旧书签失效)→ 自动弹授权面板 → Cmd+Shift+G 选目录 →
扫描完成 → 列表 111 行。**审核员按 review-notes 的 60 秒路径可完整复现。**

## 8. Archive 状态

- 最新:`/tmp/kmd_final4.xcarchive`(含 xcprivacy,ARCHIVE SUCCEEDED)
- codesign --verify --deep --strict ✓ · universal ✓ · AUTOSHOT 调试残留 0 ✓
- 上传:Xcode Organizer → Distribute App → App Store Connect
  (或 `xcrun altool --upload-app` / notarytool 凭证,见 docs/RELEASE.md)

## 9. 待用户操作(本机无法代劳)

1. GitHub 建仓 + push + 开 Pages(privacy URL 生效后再填 ASC)
2. ASC 创建 App(四语 name/subtitle/promo/description/keywords/whatsnew 逐框粘贴)
3. 上传 `/tmp/kmd_final4.xcarchive`
4. Notes 区贴 `release/review-notes.md` 英文段
