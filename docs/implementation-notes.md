# UI v2 实现记录

对应设计稿：`mockups/ui-v2.html`。本文记录落地过程中的决策、已修复的问题和尚未处理的问题。

## 决策

| 项目 | 决定 | 原因 |
| --- | --- | --- |
| 最低系统版本 | macOS 13 → **14** | 空状态页使用系统 `ContentUnavailableView`，另外用到 `symbolEffect`、`.buttonBorderShape(.circle)`，都需要 14 |
| Mock 模式 | **移除**（`MockWallet.swift`、示例卡片、`Device.mock`） | 按需求去掉假数据；没有工具链时显示故障页并说明原因 |
| 开发时运行 | 新增 `AIR_CARD_ROOT` 回退 | 没有 mock 以后，`swift run` / Xcode 需要能找到 AirCard 工具链 |
| 窗口 | `WindowGroup` → 单窗口 `Window`，关闭窗口即退出 | 全局只有一个 store，多开窗口会共享状态，行为反常 |
| 皮肤数据 | `Skin.Artwork`：`gradient` / `localImage` / `remoteImage` + `SkinCatalog` 协议 | 渐变先占位，接入服务器时实现一个 `RemoteSkinCatalog` 即可，刷入前会自动下载 |
| 本地数据 | 保存在 `~/Library/Application Support/WalletBloom/`（`library.json` + `Skins/`） | **只读** AirCard 的 `~/.aircard_cards.json`，不写入，避免再次污染 AirCard 的数据 |
| 设备断开 | 自动回到引导页 | 按需求调整；扫描、同步或同步结果弹窗打开时暂不跳转，关闭弹窗后再跳转 |
| 同步皮肤 | 模态弹窗显示真实进度，同步期间窗口不可操作；⌘Q 会先弹确认 | 按需求调整；进度来自 backend 上报的步骤 |
| 卡片名称 | 默认「卡片 N」（按列表顺序），右键可重命名，名称保存在 `library.json` 的 `cardNames` | 旧的「Wallet Card · ••••5sI=」会让人误以为是卡号后四位，其实只是文件标识的末尾 |
| 卡面预览 | 只显示皮肤图片 + 左下角卡片名称；内置皮肤渲染时不再写入任何文字 | 预览应与写入 iPhone 的图片一致，卡片名称是唯一的例外 |
| 免责声明 | 首次启动必须同意（`@AppStorage` 记录已同意的版本号），之后在「帮助」菜单查看 | 条款变更时把 `DisclaimerView.version` 加 1，用户会被要求重新确认 |
| 菜单 | 「检查更新…」放在 App 菜单「关于」下方，而不是单独一个顶层菜单 | 这是 macOS 和 Sparkle 的惯例位置，用户会优先去这里找 |
| 界面语言 | `CFBundleLocalizations` 只保留 `zh-Hans` | 不固定的话，系统自带菜单项会跟随系统语言（开发机是日文），和中文界面混在一起 |
| 主界面 v3 | 按 `stitch_macos_app_redesign/` 重做：卡面展台、5 列皮肤网格 + 「制作专属卡面」、隐私提示条、悬浮操作栏、页脚 | 设计稿中的假银行信息（行名、芯片、卡号、VISA）和「AI 绘图」没有实现：前者违背“不使用银行标识、预览与实际一致”，后者没有对应功能；字体沿用系统字体 |
| 皮肤来源 | 只保留内置示例（`Resources/BuiltInSkins/` 中的图片 + 渐变）和用户导入；移除搜索、分类、收藏和服务器皮肤库 | 产品方向是让用户使用自己的图片；服务器皮肤库的实现在提交 668e59b 中，需要时可以找回 |
| 脱离 Python 环境 | 内嵌 python-build-standalone（3.12，arm64 + x86_64）到 `Contents/Resources/python-<arch>`，由 `scripts/fetch_python.sh` 下载、`package_app.sh` 嵌入并裁剪 | 没装 python3 的 Mac 也能用；保留 AirCard 验证过的后端代码，风险最低。放 Resources 而非 Frameworks 是因为 Python 的 include/tcl 子目录会让 codesign 误判为 bundle |
| 技术支持 | `SupportContact.email = support@example.com` | 占位，上线前替换 |

## 已修复的问题

1. **每次刷入成功都被当成失败**：backend 成功时最后一行输出是 `{"type": "success", …}`，里面没有 `ok` 字段，但旧代码要求 `ok == true`。所以成功后界面会显示 “Successfully updated …”，旁边却是转圈或失败图标。现在 `type == success` 或 `ok == true` 都算成功。
2. **扫描会误识别卡片**：宽松正则（任何 “27 个字符 + `=`”）会把 `apsd`、`cloudd`、`identityservicesd` 等进程日志里的 base64 token 当成卡片（这条正则 AirCard Python 版也有）。现在宽松匹配只采信来源为 Wallet 相关进程的日志行（进程名或库名包含 pass、wallet、nfc、seserviced、stockholm）；`…/Passes/Cards/<hash>.pkpass` 这种路径形式仍然对所有进程采信。
3. **输出较多时进程会卡死**：旧的 `AirliftProcess.run` 等进程退出后才读管道，输出超过缓冲区（约 64 KB）时子进程会阻塞。现在边运行边读取。已用 400 KB 输出测试。
4. **扫描读取输出有数据竞争**：`runForOutput` 在其他线程追加 `chunks`，没有加锁，还用 `Thread.sleep` 占住一个线程 20 秒。现在和刷入共用同一个带锁、基于 continuation 的运行器。
5. **扫描不能取消**：扫描页新增“取消扫描”按钮（Esc），会终止日志进程。如果扫描期间拔掉 iPhone，会直接回到引导页。
6. **扫描到的卡片不会保存**：现在保存在 WalletBloom 自己的 `library.json` 中。卡片可以右键“从列表中移除”，以后读取和扫描都会忽略它。
7. **“已应用”状态不会保存**：现在按 card hash 保存到 `library.json`，重启后依然显示。
8. **导入的图片只记录原路径**：现在导入时会复制到 `Skins/` 目录，重启后保留，原文件被删除也不受影响。导入的皮肤可以右键删除。
9. **刷入进度不刷新**：旧的 `DetailView` 不观察 coordinator。现在由同步弹窗直接观察 coordinator。
10. **内置皮肤在 Retina 屏上输出 2 倍尺寸**：改为固定像素的 `NSBitmapImageRep`，已测试输出为 1536×969。
11. **同一张卡的 id 不稳定**：统一用 `WalletCard.detected(hash:)` 生成。

以上 1–4、8、10 都有单元测试覆盖（`swift test`，共 15 个，含旧版 library.json 的兼容性测试）。

> 事故记录：第一版 v2 实现把扫描结果写回 `~/.aircard_cards.json`，当时正则尚未修复，结果 6 个误识别的 hash 被永久保存。写回逻辑已经撤回，该文件已恢复为原来的两张卡（被污染的版本另有备份）。现在 WalletBloom 只读这个文件。

## 尚未处理 / 需要确认

1. **Wallet 进程白名单需要用真实日志验证**：唯一一次抓日志时钱包没有打开，日志里没有任何卡片 hash，所以还没确认真卡 hash 一定出现在 Wallet 进程的日志行里。如果修复后扫描不到你的两张卡，说明白名单过窄，需要在打开钱包的情况下抓一次日志来调整。
2. **默认编号会随移除而变化**：「卡片 N」按当前顺序编号，移除一张后后面的卡会重新编号；自定义名称不受影响。
3. ~~被移除的卡片没有入口恢复~~：已新增「卡片 → 恢复已移除的卡片」，一次恢复全部（卡片之间没有可读的区分方式，逐个恢复反而难以辨认）。
4. **设备轮询**：每 2 秒调用一次 `device_helper list`（扫描、同步期间暂停）。helper 没有插拔事件接口，暂时保留轮询。
5. **同步进度的粒度**：backend 只上报 3 个步骤，其中第 1 步（写入卡面）耗时最长，进度条会在这一步停留一段时间。要更细的进度，需要 backend 在批量写入时上报每个文件。
6. **卡片列表不区分设备**：多台 iPhone 时可以在工具栏切换写入目标，但卡片列表是所有设备共用的（AirCard 的 `~/.aircard_cards.json` 本身就不记录设备）。写入另一台设备上不存在的卡片会失败并提示。
