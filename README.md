# 钱包卡片皮肤管家（WalletBloom）

一款 macOS 小工具：用数据线连接 iPhone，给 Apple 钱包里的卡片换上你喜欢的卡面。内置几款示例皮肤，更推荐导入你自己的图片制作专属卡面。

> 独立开发的第三方工具，与 Apple 及任何银行、发卡机构、卡组织均无关联。**只更换卡面显示图片，不接触任何支付信息、不联网上传任何数据、不影响刷卡。**

## 下载安装

1. 到 [Releases](https://github.com/zhanggenlove/WalletCardSkin/releases) 下载最新的 `WalletCardSkin.app.zip` 并解压。
2. 把 `钱包卡片皮肤管家.app` 拖到「应用程序」文件夹。
3. 这个 App 没有做 Apple 公证，macOS 的 Gatekeeper 默认会拦截。**按下面任一方法放行即可。**

### 放行被拦截的 App（Gatekeeper）

**方法一：去掉隔离标记（推荐，一步到位）**

打开「终端」，粘贴执行（按实际路径调整）：

```bash
xattr -dr com.apple.quarantine "/Applications/钱包卡片皮肤管家.app"
```

之后正常双击打开即可。

**方法二：右键打开**

在 App 上点右键 →「打开」→ 在弹窗里再点一次「打开」。若系统提示「无法打开」，用方法一或方法三。

**方法三：在系统设置里放行**

双击打开被拦后，到「系统设置 →『隐私与安全性』」，在底部找到关于本 App 的提示，点「仍要打开」。

> 这些步骤只是因为 App 未经 Apple 付费公证，并不代表有风险。源码完全公开，你可以自行审阅或自行编译。

## 使用

1. 用数据线把 iPhone 连到 Mac，在 iPhone 上点「信任此电脑」。
2. 打开 iPhone 的「钱包」App（或连按两下侧边按钮）。
3. 在本 App 里点「开始扫描卡片」，扫描到后进入主界面。
4. 选一款皮肤，或点「制作专属卡面」导入自己的图片并裁剪。
5. 点「应用到 iPhone」。完成后，**从后台关闭钱包 App 再重新打开**即可看到新卡面（仍是旧卡面时可重启 iPhone）。

**要求**：macOS 14 或更高；iPhone 为 iOS 18 及以上（已在 iOS 27 上测试）。

## 重要提示

- **无法在 App 内恢复原卡面。** 本工具不会备份卡片原来的卡面。如需恢复发卡机构的原始卡面，请在 iPhone 钱包中移除该卡片后重新添加（可能需要发卡机构重新验证）。
- 更新 iOS 或钱包重新同步卡片后，卡面可能被系统还原。
- 是否使用由你自行判断并自担风险。详见 App 内「帮助 → 免责声明」。

## 从源码编译

```bash
git clone https://github.com/zhanggenlove/WalletCardSkin.git
cd WalletCardSkin
swift build        # 编译
swift test         # 运行测试
```

与 iPhone 通信依赖 [AirCard](https://github.com/) 的辅助程序（`device_helper`、`airtraffic_host`）和 Python 后端。打包可用于真机的 App：

```bash
# 指向你的 AirCard 源码（含已编译的 build/device_helper 等）
AIR_CARD_ROOT=/path/to/AirCard-main scripts/package_app.sh
```

`package_app.sh` 会编译 release、嵌入 Sparkle、App 图标，并自动下载内嵌一份独立 Python 运行时（[python-build-standalone](https://github.com/astral-sh/python-build-standalone)，arm64 + x86_64），因此目标机器**无需安装 python3**。只给 Apple Silicon 使用时可 `WB_PYTHON_ARCHS=arm64 scripts/package_app.sh` 以减小体积。

把图片放进 `Resources/BuiltInSkins/`，打包时会作为内置示例皮肤显示（详见该目录下的 README）。

工程结构、设计决策和待办分别见 `docs/implementation-notes.md` 与 `docs/roadmap.md`。

## 工作原理

本 App 不直接调用任何私有框架。与设备通信的部分（私有 `MobileDevice.framework` / `AirTrafficHost.framework` 的调用）都封装在 AirCard 的辅助程序里，App 只调用这条已验证的边界：

```text
构建卡面资源 → 通过 AirCard 写入设备 → 刷新钱包缓存
```

卡片识别、皮肤同步全部通过数据线在本机完成；App 联网仅用于检查更新（Sparkle），不会发送任何卡片或设备信息。

## 致谢与许可

- 本项目基于 [MIT 许可](LICENSE) 开源。
- 设备通信依赖 [AirCard](https://github.com/)（MIT，© 2026 Johnny Franks）。
- 自动更新使用 [Sparkle](https://github.com/sparkle-project/Sparkle)；内嵌 Python 来自 [python-build-standalone](https://github.com/astral-sh/python-build-standalone)。

第三方组件的许可证全文见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
