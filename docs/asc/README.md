# KinetMagicDisk — App Store 材料包(ASC Metadata)

> Bundle ID: `com.kitnet.magicdisk` · Category: Utilities · macOS 13+
> 版本 1.0.0 · 四语:en / ja / zh-Hans / zh-Hant

## 1. App 信息(四语)

### Name(App 名称,30 字符内)
| 语言 | 值 |
|---|---|
| en | KinetMagicDisk — Disk Space Analyzer |
| ja | KinetMagicDisk — ディスク容量 analyzer |
| zh-Hans | KinetMagicDisk - 磁盘空间分析 |
| zh-Hant | KinetMagicDisk - 磁碟空間分析 |

> 实测字符数:en=37 超限!ASC Name 硬限 30。
> 精简后:**en: "KinetMagicDisk"**(14);ja/zh 同名(品牌名不译)。Subtitle 承载描述。

### Subtitle(30 字符内)
| 语言 | 值 | 字符数 |
|---|---|---|
| en | Visualize disk usage in seconds | 31 → **See what fills your disk** (26) |
| ja | ディスクの容量をひと目で把握 | 14 |
| zh-Hans | 一目了然,看清磁盘去哪了 | 12 |
| zh-Hant | 一目瞭然,看清磁碟去哪了 | 12 |

### Promotional Text(170 字符内,可随时更新)
| 语言 | 值 |
|---|---|
| en | Scan any folder or your whole Home, explore an interactive sunburst map, and free up space by moving files straight to the Trash. Private by design — no network, ever. |
| ja | フォルダやホーム全体をスキャンし、サンバースト図で可視化。ファイルを直接ゴミ箱へ移して容量を解放。完全ローカル処理、ネットワーク通信なし。 |
| zh-Hans | 一键扫描任意文件夹或整个 Home,用旭日图探索磁盘空间,随手把大文件移入废纸篓。纯本地运行,永不联网。 |
| zh-Hant | 一鍵掃描任意資料夾或整個 Home,用旭日圖探索磁碟空間,隨手把大檔案移入垃圾桶。純本地執行,永不連網。 |

### Description(4000 字符内)
见 `description/{lang}.txt`(四语全文)

### Keywords(100 字符内,逗号分隔,禁与 App 名重复)
见 `keywords/{lang}.txt`(四语)

## 2. 截图规格(macOS)

- **必须 16:10 比例**,合法档:`1280×800`、`1440×900`、`2560×1600`、`2880×1800`(Retina 2x)
- 采用 **2560×1600**(MacBook Air 13" 逻辑 2x)
- 色彩空间 **sRGB IEC61966-2.1**(已显式写入 profile,防 P3 色偏被 ASC 拒)
- 格式 PNG / JPEG,≤ 1 张最少,推荐 3–5 张
- 输出目录:`screenshots/{en,ja,zh-Hans,zh-Hant}/`

## 3. Privacy Policy URL

- 页面源文件:`docs/privacy/index.html`(本仓库)
- 上线 URL(仓库发布 GitHub Pages 后):`https://phinn.github.io/KinetMagicDisk/`
- 数据收集声明:**不收集任何数据、零网络权限** — 与 entitlements 一致,审核可自查

## 4. 权限说明(Review Notes 附)

App Sandbox + user-selected read-write(用户主动选择文件夹授权)+
app-scoped bookmark 持久化。删除仅调用系统 trashItem(进废纸篓,可恢复)。
无任何 network/AppleScript/automation 权限。

## 5. 分级与合规

- 年龄分级:4+
- 加密合规:ITSAppUsesNonExemptEncryption=false(Info.plist 已声明)
- 版权:Copyright © 2026 Kinet
