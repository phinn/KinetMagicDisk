# KinetMagicDisk — App Store Connect 上架操作手册

> 目标:拿到 ASC 账号后,照本文**从上到下一次填完**,不留口头清单。
> Bundle ID: `com.kitnet.magicdisk` · 版本 1.0.0 (Build 1) · macOS 13+ · Universal (arm64 + x86_64)
> **ASC 要的是 .pkg 不是 archive**:`release/dist/KinetMagicDisk-1.0.0.pkg` 已就绪
> (Installer 签名 ✓ · 包内 Apple Distribution 重签 + embedded MAS profile ✓)。
> archive(/tmp/kmd_final6.xcarchive)仅是中间产物,/tmp 清空后按 §6.1 重出。

---

## 0. 前置:GitHub 仓库 + Privacy URL(一次)

```bash
cd ~/Documents/kinet/KinetMagicDisk
gh auth login                # 或浏览器登录 GitHub 后:
gh repo create KinetMagicDisk --public --source=. --push
```

开 Pages:**仓库 → Settings → Pages → Source: `main` 分支, `/ (root)` 目录 → Save**

- Privacy Policy URL(**ASC 表单里填这个**):
  `https://phinn.github.io/KinetMagicDisk/`(实际是 `…/docs/privacy/index.html`,根路径 404 时填完整路径)
- 页面为单文件 `docs/privacy/index.html`,无外部依赖,含 en/ja/zh-Hans/zh-Hant 四语锚点。
- Push 后 1~2 分钟生效,浏览器先自测一遍四语锚点都能打开。

> 若不想用 Pages,备选:Privacy URL 也可指向任意能公网访问的静态托管。ASC 表单该字段必填,不能留空。

---

## 1. App 信息(App Information 页)

| 字段 | 填写值 |
|---|---|
| Platform | macOS |
| Name | `KinetMagicDisk`(四语本地化名相同,见 docs/asc/name/) |
| Bundle ID | `com.kitnet.magicdisk`(下拉选择;若没有:先在 Developer 后台 Identifiers 注册,或在 Xcode Accounts 里同步) |
| SKU | `kinetmagicdisk100`(内部标识,任意唯一,不会展示) |
| Primary Language | Simplified Chinese(或 English,决定 ASC 后台默认展示语) |

**App Category:**

| 项 | 值 |
|---|---|
| Primary Category | **Utilities**(与 Info.plist `LSApplicationCategoryType=public.app-category.utilities` 一致) |
| Secondary Category | 留空(或 Productivity,非必填) |

---

## 2. 定价与销售范围(Pricing and Availability)

| 字段 | 填写值 |
|---|---|
| Price Schedule | 价格层级 **Tier 10 → $9.99 USD**(对标 DaisyDisk $9.99 同档) |
| 各区货币 | ASC 按层级自动换算(人民币 ≈ ¥68,日元 ≈ ¥1,500,由 Apple 汇率表生成,无需手填) |
| Availability | **All 175 regions**(全量;磁盘工具无地区限制理由) |
| Pre-orders | 不开 |
| Mac Catalyst / Apple silicon | 已是原生 Universal,无需勾选 iOS app 分发 |

> 定价依据:DaisyDisk 同类 $9.99 常青;本品类价格敏感度低、功能对齐,首版跟随同档即可。后续降价促销在 Pricing 页随时可改,不影响审核。

---

## 3. 版本信息(版本 1.0.0 页,四语逐一填写)

每处文案均已落盘在 `docs/asc/`,直接复制粘贴:

### 3.1 四语本地化(Add Localizations: en, ja, zh-Hans, zh-Hant)

| 字段(限长) | en | ja | zh-Hans | zh-Hant | 来源文件 |
|---|---|---|---|---|---|
| Promotional Text(170) | 167 字 | 69 字 | 52 字 | 52 字 | `docs/asc/promo/{lang}.txt` |
| Description(4000) | 1346 字 | 691 字 | 486 字 | 484 字 | `docs/asc/description/{lang}.txt` |
| Keywords(100) | 86 字 | 57 字 | 40 字 | 40 字 | `docs/asc/keywords/{lang}.txt` |
| Subtitle(30) | 24 字 | 14 字 | 12 字 | 12 字 | `docs/asc/subtitle/{lang}.txt` |
| Name(30) | 14 字 | 14 字 | 14 字 | 14 字 | `docs/asc/name/{lang}.txt` |
| What's New(4000) | — 首版留空即可(必填时填 "First release." 及对应译文) | | | | |

### 3.2 Screenshots(macOS 平台要求 2560×1600 或 1440×900 逻辑尺寸之一)

| 语言 | 文件 | 状态 |
|---|---|---|
| en | `docs/asc/screenshots/en/01-main.png` | 2560×1600 sRGB ✅ |
| ja | `docs/asc/screenshots/ja/01-main.png` | 2560×1600 sRGB ✅ |
| zh-Hans | `docs/asc/screenshots/zh-Hans/01-main.png` | 2560×1600 sRGB ✅ |
| zh-Hant | `docs/asc/screenshots/zh-Hant/01-main.png` | 2560×1600 sRGB ✅ |

- 每语言拖 1 张即可上架(macOS 最低要求 1 张);后续可补下钻/Trash 界面成 2~3 张。
- 截图均为扫描完成态(旭日图渲染完成),非 idle 占位图。

### 3.3 其他版本字段

| 字段 | 填写值 |
|---|---|
| Copyright | `© 2026 Kinet`(与 InfoPlist.strings 一致) |
| App Review Notes | 见 §5 |
| Release | **Manually release**(自动发布亦可;手动可控上架时机) |

---

## 4. App Privacy(App Privacy 页,问卷逐项答案)

数据收集声明总则:**不收集任何数据**。逐项如下:

| 问题 | 答案 |
|---|---|
| Do you collect data from this app? | **No** — "Data collection: None" |
| Third-party analytics / SDK | 无(应用零依赖第三方 SDK,零网络权限) |
| Tracking (ATT) | 无,无任何跨 app 追踪 |

> 若表单强制要求至少选一项 "Data Types Collected":选 **None**(应用确无收集)。我们的技术事实:
> - 无 `NSUserTrackingUsageDescription`,无 ATT 框架
> - 二进制无网络 API 调用,entitlements 无 `network.client`
> - 所有数据仅存沙盒容器(书签+偏好),不上传
> Privacy 页 (`docs/privacy/index.html`) 与此口径完全一致,审核可交叉验证。

---

## 5. App Review Information(App Review 页)

| 字段 | 填写值 |
|---|---|
| First Name / Last Name | 开发者本人(拼音) |
| Phone / Email | 真实可联系(审核员可能打) |
| Notes | 见下 |

**Review Notes(英文,直接粘贴):**

```
KinetMagicDisk is a local disk space analyzer.

On first launch the app shows an idle screen with quick-start buttons.
Please click "Scan Home Folder" (or pick any folder) — it visualizes
disk usage as a sunburst map. Click an arc to drill down; use the
breadcrumb to go back up. Right-click a row (or hover it and press the
trash icon) to move a folder to the Trash — deletion is reversible via
the Finder Trash.

The app requests folder access via the standard system open panel
(macOS sandbox, read-only until you grant access). No network access,
no account, no sign-in required. Nothing to configure.
```

| 字段 | 填写值 |
|---|---|
| Demo account | 不需要(无需登录的本地工具) |
| Contact URL | 留空或 `https://phinn.github.io/KinetMagicDisk/` |

---

## 6. 构建上传(App Store Connect → TestFlight/版本页)

### 6.1 重出 archive → pkg(如 /tmp 产物已丢失)

```bash
cd ~/Documents/kinet/KinetMagicDisk
xcodegen generate   # 若 pbxproj 过期(新加过资源文件必须重新 generate)
xcodebuild -project KinetMagicDisk.xcodeproj -scheme KinetMagicDisk \
  -configuration Release -archivePath /tmp/kmd_final6.xcarchive \
  -destination 'generic/platform=macOS' -allowProvisioningUpdates archive
# 验证:codesign OK / universal / 四语 lproj / 无调试残留
APP=/tmp/kmd_final6.xcarchive/Products/Applications/KinetMagicDisk.app
codesign --verify --deep --strict "$APP" && lipo -info "$APP/Contents/MacOS/KinetMagicDisk"

# archive → ASC pkg(自动 re-sign 为 Apple Distribution + 注入 MAS profile):
xcodebuild -exportArchive -archivePath /tmp/kmd_final6.xcarchive \
  -exportPath /tmp/kmd_export \
  -exportOptionsPlist release/dist/ExportOptions-appstore.plist \
  -allowProvisioningUpdates
# 产物: /tmp/kmd_export/KinetMagicDisk.pkg
# 注:archive 显示 "Apple Development" 签名是正常的,export 阶段统一重签。
```

### 6.2 上传(三选一)

**A. Transporter(最省事):**Mac App Store 装 Transporter → 拖入 `.pkg` → Deliver。

**B. Xcode Organizer:**Window → Organizer → 选 archive → **Distribute App** →
App Store Connect → Upload(内部与本目录 ExportOptions 等价)。首次要求登录并选 Team(M92UKS6NA2)。

**C. altool(命令行,需 ASC API Key):**
```bash
xcrun altool --store-type onboarded \
  --upload-package /tmp/kmd_export/KinetMagicDisk.pkg \
  --api-key-id <KEYID> --api-issuer <ISSUER>
```

> ⚠️ MAS 直发**不需要** notarytool 公证(那是 Developer ID 分发用的)。
> 若走官网 dmg 分发才需要:`notarytool submit` + `stapler staple`。
> 已知问题:本机此前 `codesign --timestamp` 连不上 Apple 时间戳服务,重试/换网络即可。

### 6.3 exportOptions

已落盘 `release/dist/ExportOptions-appstore.plist`(method=app-store-connect,
teamID=M92UKS6NA2),直接用,无需手写。

### 6.4 ASC 版本页挂构建

上传完成后 5~15 分钟,版本页 "Build" 区出现绿色 + 号 → 选择刚上传的 1.0.0 (1) → 若弹出口令加密合规问题:选 **"No, app uses standard encryption only"**(Info.plist 已预置 `ITSAppUsesNonExemptEncryption=false`,大概率不再询问)。

---

## 7. 提交审核前 checklist(逐项打勾)

- [ ] GitHub 仓库已 push,Privacy URL 浏览器能打开四语锚点
- [ ] App Information:Bundle ID 选对、SKU、Category=Utilities
- [ ] Pricing:Tier 10 ($9.99),175 regions
- [ ] 年龄分级问卷照 release/review-notes.md「Age rating questionnaire」11 问逐条勾 → 4+
- [ ] 版本页四语 Name/Subtitle/Promo/Description/Keywords 全部粘贴完(数字与 §3.1 对得上)
- [ ] 四语截图各 1 张已拖入对应本地化
- [ ] App Privacy:None
- [ ] App Review Notes 已粘贴 release/review-notes.md 英文段
- [ ] Build 已挂上(上传 release/dist/KinetMagicDisk-1.0.0.pkg),加密合规已答
- [ ] **提交审核 (Submit for Review)**

## 8. 常见审核退回点(预判)

| 风险 | 对策(已内置) |
|---|---|
| Guideline 2.4.5 沙盒 | 已启用 App Sandbox,`user-selected read-write` + `bookmarks.app-scope`,合规 |
| 删除文件是"破坏性" | 只进废纸篓,可撤销,Review Notes 已说明 |
| 要求演示账号 | 无账号系统,Notes 说明 "No account required" |
| 隐私政策打不开 | 先自测 GitHub Pages 是否生效再提交 |
| 截图与实际不符 | 截图即真实完成态界面 |
