# Dist — ASC 分发产物与导出配置

## 产物
- `KinetMagicDisk-1.0.0.pkg` — App Store Connect 分发包(2026-09-09 导出)
  - Installer 签名:3rd Party Mac Developer Installer: JUNJIE SHEN (M92UKS6NA2)
  - 包内 app:Apple Distribution 重签 + embedded.provisionprofile(MAS)注入
  - 校验:`pkgutil --check-signature KinetMagicDisk-1.0.0.pkg`

## 复现命令(从 archive 出 pkg)
```bash
xcodebuild -exportArchive \
  -archivePath /tmp/kmd_final6.xcarchive \
  -exportOptionsPlist release/dist/ExportOptions-appstore.plist \
  -exportPath /tmp/kmd_export \
  -allowProvisioningUpdates      # 自动创建/更新 MAS profile
# 产物: /tmp/kmd_export/KinetMagicDisk.pkg
```

## 上传 ASC(二选一)
- Transporter app:拖入 .pkg → Deliver
- 命令行:
  ```bash
  xcrun altool --store-type onboarded \
    --upload-package release/dist/KinetMagicDisk-1.0.0.pkg \
    --api-key-id <KEYID> --api-issuer <ISSUER>
  ```
- 或 Xcode Organizer:Window → Organizer → 选 archive → Distribute App →
  App Store Connect → Upload(内部同样走 exportArchive,与本目录配置等价)

## 注意
- archive 本身用 Apple Development 签名是**正常的**:exportArchive 阶段自动
  re-sign 成 Apple Distribution 并打 pkg。不必纠结 archive 的 identity。
- `-allowProvisioningUpdates` 需要 Xcode 已登录 ASC 账号(本机已登录 M92UKS6NA2)。
