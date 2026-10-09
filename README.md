<div align="center">

<img src="docs/assets/icon.png" width="128" alt="钱包卡片皮肤管家" />

# 钱包卡片皮肤管家

**给 Apple 钱包里的卡片，换上你喜欢的卡面**

一款 macOS 小工具：用数据线连接 iPhone，给钱包里的银行卡、交通卡换上精美卡面。内置示例皮肤，更推荐导入你自己的图片，制作独一无二的专属卡面。

[![Release](https://img.shields.io/github/v/release/zhanggenlove/WalletCardSkin?style=flat-square)](https://github.com/zhanggenlove/WalletCardSkin/releases)
[![Downloads](https://img.shields.io/github/downloads/zhanggenlove/WalletCardSkin/total?style=flat-square)](https://github.com/zhanggenlove/WalletCardSkin/releases)
[![License](https://img.shields.io/github/license/zhanggenlove/WalletCardSkin?style=flat-square)](LICENSE)
![Platform](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)

**简体中文** · [English](README.en.md) · [日本語](README.ja.md)

</div>

---

> 独立开发的第三方工具，与 Apple 及任何银行、发卡机构、卡组织均无关联。
> **只更换卡面显示图片 · 不接触任何支付信息 · 不联网上传任何数据 · 不影响刷卡。**

## 预览

<div align="center">
<img src="docs/assets/screenshot-mac.png" width="760" alt="Mac 主界面" />
</div>

<div align="center">
<table>
<tr>
<td align="center"><img src="docs/assets/screenshot-iphone-card.png" width="300" alt="iPhone 卡片详情" /><br/>iPhone 上的卡片详情</td>
<td align="center"><img src="docs/assets/screenshot-iphone-wallet.png" width="300" alt="iPhone 钱包列表" /><br/>钱包中的专属卡面</td>
</tr>
</table>
</div>

## ✨ 功能

- 🎴 **一键换肤**：扫描钱包中的卡片，选择皮肤，应用到 iPhone。
- 🖼️ **专属卡面**：导入自己的图片，拖动、缩放裁剪成卡面。
- 🎨 **内置示例**：附带多款示例皮肤，开箱即用。
- 🔒 **本地与隐私**：全程数据线本机完成，不联网上传，不接触支付信息。
- 🖥️ **原生体验**：SwiftUI 打造，贴合 macOS 设计；通用二进制，支持 Apple Silicon 与 Intel，**无需安装 Python**。

## 📦 下载安装

1. 到 [Releases](https://github.com/zhanggenlove/WalletCardSkin/releases) 下载最新的 `WalletCardSkin.app.zip` 并解压。
2. 把 `钱包卡片皮肤管家.app` 拖进「应用程序」文件夹。
3. 本 App 未做 Apple 公证，首次打开会被 Gatekeeper 拦截，按下面任一方法放行。

### 放行被拦截的 App

**方法一 · 去掉隔离标记（推荐）** — 打开「终端」执行（按实际路径调整）：

```bash
xattr -dr com.apple.quarantine "/Applications/钱包卡片皮肤管家.app"
```

**方法二 · 右键打开** — 在 App 上点右键 →「打开」→ 弹窗里再点一次「打开」。

**方法三 · 系统设置** — 双击被拦后，到「系统设置 →『隐私与安全性』」底部点「仍要打开」。

> 这些步骤只是因为未做 Apple 付费公证，并不代表有风险。源码完全公开，可自行审阅或编译。

## 🚀 使用

1. 用数据线把 iPhone 连到 Mac，在 iPhone 上点「信任此电脑」。
2. 打开 iPhone 的「钱包」App（或连按两下侧边按钮）。
3. 在本 App 里点「开始扫描卡片」，扫描到后进入主界面。
4. 选一款皮肤，或点「制作专属卡面」导入自己的图片并裁剪。
5. 点「应用到 iPhone」。完成后 **从后台关闭钱包 App 再重新打开**，即可看到新卡面（仍是旧卡面时可重启 iPhone）。

**环境要求**：macOS 14+；iPhone iOS 18+（已在 iOS 27 测试）。

## ⚠️ 重要提示

- **无法在 App 内恢复原卡面**：本工具不备份原卡面。如需恢复，请在 iPhone 钱包中移除该卡片后重新添加（可能需发卡机构重新验证）。
- 更新 iOS 或钱包重新同步卡片后，卡面可能被系统还原。
- 是否使用由你自行判断并自担风险。详见 App 内「帮助 → 免责声明」。

## 🛠️ 从源码编译

```bash
git clone https://github.com/zhanggenlove/WalletCardSkin.git
cd WalletCardSkin
swift build        # 编译
swift test         # 运行测试
```

与 iPhone 通信依赖 [AirCard](https://github.com/) 的辅助程序（`device_helper`、`airtraffic_host`）和 Python 后端。打包可用于真机的 App：

```bash
AIR_CARD_ROOT=/path/to/AirCard-main scripts/package_app.sh
```

脚本会编译 release、嵌入 Sparkle 与 App 图标，并自动下载内嵌一份独立 Python 运行时（[python-build-standalone](https://github.com/astral-sh/python-build-standalone)，arm64 + x86_64），因此目标机器无需安装 python3。只给 Apple Silicon 使用时可 `WB_PYTHON_ARCHS=arm64 scripts/package_app.sh` 减小体积。

把图片放进 `Resources/BuiltInSkins/`，打包时会作为内置示例皮肤显示。工程结构与待办见 `docs/`。

## 🔍 工作原理

本 App 不直接调用任何私有框架。与设备通信的部分都封装在 AirCard 的辅助程序里，App 只调用这条已验证的边界：

```text
构建卡面资源 → 通过 AirCard 写入设备 → 刷新钱包缓存
```

卡片识别、皮肤同步全部通过数据线在本机完成；App 联网仅用于检查更新（Sparkle），不发送任何卡片或设备信息。

## 🙏 致谢与许可

本项目基于 [MIT 许可](LICENSE) 开源。

- 设备通信依赖 [AirCard](https://github.com/)（MIT, © 2026 Johnny Franks）
- 自动更新使用 [Sparkle](https://github.com/sparkle-project/Sparkle)
- 内嵌 Python 来自 [python-build-standalone](https://github.com/astral-sh/python-build-standalone)

第三方组件许可证全文见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
