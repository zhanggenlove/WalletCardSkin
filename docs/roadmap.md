# 未来计划

## 国际化（i18n）

目前界面只提供简体中文：`Info.plist` 中 `CFBundleDevelopmentRegion` 为 `zh-Hans`，`CFBundleLocalizations` 只有 `zh-Hans`。这样无论系统是什么语言，系统自带的菜单项（隐藏、退出、窗口等）也都会显示中文，不会中英/中日混杂。

计划：

1. **把字符串集中起来**：在 `Package.swift` 中设置 `defaultLocalization: "zh-Hans"`，新增 `Resources/Localizable.xcstrings`（String Catalog）。SwiftUI 的 `Text("…")`、`Button("…")` 会自动作为本地化 key；`WalletError`、`DefaultFlashCoordinator` 等非视图代码里的文案改用 `String(localized:)`。
2. **先加英文**，再根据用户分布添加繁体中文、日文等。每加一种语言，都要同步更新 `CFBundleLocalizations`。
3. **需要特别审校的文案**：免责声明和隐私说明带有法律含义，翻译需要专人审校；修改免责声明内容时，记得把 `DisclaimerView.version` 加 1。
4. **Sparkle** 自带多语言界面，会跟随 App 的语言，不需要额外处理。
5. 注意中文排版与英文排版的长度差异，按钮和提示文字要预留伸缩空间。

## 自动更新（Sparkle）

Sparkle 2 已接入，菜单为「WalletBloom → 检查更新…」。在配置好下面几项之前，更新器不会启动，菜单项保持灰色。

1. 生成 EdDSA 签名密钥（私钥保存在你的钥匙串中，请妥善备份）：
   `.build/artifacts/sparkle/Sparkle/bin/generate_keys`
2. 在 `Resources/Info.plist` 中添加：
   - `SUFeedURL`：appcast.xml 的 HTTPS 地址
   - `SUPublicEDKey`：上一步输出的公钥
3. 每次发布：打包、公证后，用 `generate_appcast` 生成或更新 appcast，并上传到 `SUFeedURL` 对应的位置。
4. 已设置 `SUEnableSystemProfiling = false`：检查更新时不发送系统信息。这与隐私说明中“联网只用于检查更新，不会发送任何卡片或设备信息”保持一致。

## 发布前必须完成

- **开发者证书签名与公证**：现在是临时签名（ad-hoc），其他用户下载后会被 Gatekeeper 拦截。Sparkle 更新也要求签名一致。
- **去掉对系统 python3 的依赖**：刷入时调用 `/usr/bin/env python3`，没装命令行工具的 Mac 会弹出安装提示，导致刷入失败。后端只用到 Python 标准库，可以把 Python 运行时打包进 App，或者用 Swift 重写后端。
- **免责声明请专业人士审阅**：`DisclaimerView` 中的条款是产品层面的初稿。

## 功能

- **恢复原卡面**（暂不做）：目前在免责声明和应用前的确认弹窗中说明「无法在 App 内恢复，需在钱包中移除卡片后重新添加」，文案统一定义在 `RestoreNotice`。将来要做的话，需要在第一次写入前备份原卡面资源，并先确认后端能否读取这些文件。
- **裁剪参考线**：裁剪已完成，但没有标出钱包会叠加信息的区域——不同卡片类型叠加的位置还没有确认，等确认后再加，避免误导用户。
- **服务器皮肤库上线**：客户端已完成（清单格式见 `docs/skin-catalog.md`），需要搭建服务器并在 Info.plist 中配置 `WBSkinCatalogURL`。隐私说明会根据是否配置自动切换联网描述。
- **兼容性范围维护**：版本检查已完成（`SystemCompatibility`，iOS 18 起支持、已测试到 iOS 27）。AirCard 更新支持范围后同步修改其中的常量。
- **VoiceOver 与深色模式实机检查**：皮肤、卡片、翻页按钮已补充无障碍标签，界面颜色都使用系统语义色，但还没有用 VoiceOver 和深色模式实际走一遍。
