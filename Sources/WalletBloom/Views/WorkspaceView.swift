import SwiftUI
import UniformTypeIdentifiers

/// 主界面（参照 stitch_macos_app_redesign）：顶部卡面展台、皮肤网格、悬浮操作栏和页脚。
struct WorkspaceView: View {
    @ObservedObject var store: WalletBloomStore
    @ObservedObject var coordinator: DefaultFlashCoordinator
    @AppStorage(WalletBloomStore.suppressRestoreWarningKey) private var suppressRestoreWarning = false

    var body: some View {
        VStack(spacing: 0) {
            CardStage(store: store)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GalleryHeader()
                    SkinGallery(store: store)
                    InfoStrip { store.infoSheet = .privacy }
                }
                .padding(.horizontal, 32)
                .padding(.top, 4)
                // 给悬浮操作栏（约 56pt 高，距底部 14pt）留出空间，页面最底部的内容不会被遮住。
                .padding(.bottom, 100)
            }
        }
        .overlay(alignment: .bottom) {
            ActionDeck(store: store)
                // 状态提示浮在操作栏上方，不参与布局，避免撑高操作栏区域、遮住页面内容。
                .overlay(alignment: .top) {
                    StatusCapsule(store: store)
                        .fixedSize()
                        .alignmentGuide(.top) { $0[.bottom] + 10 }
                }
                .padding(.bottom, 14)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { FooterBar() }
        .fileImporter(isPresented: $store.isImporterPresented, allowedContentTypes: [.png, .jpeg, .heic, .tiff]) { result in
            if case .success(let url) = result { store.beginImport(from: url) }
        }
        .confirmationDialog(RestoreNotice.title, isPresented: $store.isConfirmingApply) {
            Button("应用到 iPhone") {
                // 等确认框完全收起后再弹出同步进度，避免两个弹窗同时出现时后者被系统忽略。
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    await store.applySelectedSkin()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(RestoreNotice.detail)
        }
        .dialogSuppressionToggle("不再提示", isSuppressed: $suppressRestoreWarning)
        // 同步期间以模态弹窗展示进度，窗口其余部分（包括关闭按钮）都不可操作。
        .sheet(isPresented: Binding(get: { coordinator.activeJob != nil }, set: { if !$0 { coordinator.dismiss() } })) {
            SyncSheet(coordinator: coordinator) {
                Task { await store.applySelectedSkin() }
            }
        }
    }
}

// MARK: - Card stage

/// 卡面展台：居中展示当前卡片，两侧悬浮圆形翻页按钮，下方页码。
private struct CardStage: View {
    @ObservedObject var store: WalletBloomStore
    @GestureState private var dragOffset: CGFloat = 0
    @State private var draftName = ""
    @Environment(\.colorScheme) private var colorScheme

    private let cardWidth: CGFloat = 380

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ForEach(Array(store.cards.enumerated()), id: \.element.id) { index, card in
                    CardFace(card: card, skin: store.skin(for: card))
                        .frame(width: cardWidth)
                        // 展台上的卡片带一层蓝色投影，模拟钱包卡片的悬浮感。
                        .shadow(color: Color.accentColor.opacity(0.22), radius: 24, y: 18)
                        .modifier(StagePlacement(offset: index - store.selectedCardIndex, dragOffset: dragOffset))
                        .onTapGesture { store.selectCard(card.id) }
                        .contextMenu { menu(for: card) }
                        .help("右键可重命名卡片，或移除误识别的卡片")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(card.title)
                        .accessibilityValue(card.id == store.selectedCardID ? "当前卡片" : "")
                        .accessibilityHidden(card.id != store.selectedCardID)
                }
            }
            .frame(width: cardWidth, height: cardWidth / WalletCard.artworkAspectRatio)
            .contentShape(Rectangle())
            .gesture(swipeGesture)
            .animation(.spring(response: 0.5, dampingFraction: 0.84), value: store.selectedCardID)

            PageIndicator(count: store.cards.count, index: store.selectedCardIndex)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .padding(.bottom, 26)
        .overlay {
            HStack {
                ChevronButton(systemImage: "chevron.left", key: .leftArrow, label: "上一张卡片") { store.selectCard(offset: -1) }
                Spacer()
                ChevronButton(systemImage: "chevron.right", key: .rightArrow, label: "下一张卡片") { store.selectCard(offset: 1) }
            }
            .padding(.horizontal, 24)
            .disabled(store.cards.count < 2)
        }
        .background {
            // 展台柔光：浅色模式下是一片白色光晕，深色模式下只轻微提亮。
            RadialGradient(colors: [Color.white.opacity(colorScheme == .dark ? 0.06 : 0.9), .clear], center: .center, startRadius: 40, endRadius: 520)
        }
        .onChange(of: store.renamingCard) { _, card in
            if let card { draftName = store.hasCustomName(card) ? card.title : "" }
        }
        .alert("重命名卡片", isPresented: Binding(get: { store.renamingCard != nil }, set: { if !$0 { store.renamingCard = nil } }), presenting: store.renamingCard) { card in
            TextField("例如：招行信用卡", text: $draftName)
            Button("取消", role: .cancel) {}
            Button("存储") { store.renameCard(card, to: draftName) }
        } message: { _ in
            Text("名称只保存在这台 Mac 上，留空则恢复为默认名称。")
        }
    }

    @ViewBuilder
    private func menu(for card: WalletCard) -> some View {
        Button("重命名…", systemImage: "pencil") { store.renamingCard = card }
        if store.hasCustomName(card) {
            Button("恢复默认名称", systemImage: "arrow.uturn.backward") { store.renameCard(card, to: "") }
        }
        Divider()
        Button("从列表中移除", systemImage: "minus.circle", role: .destructive) { store.removeCard(card) }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragOffset) { value, state, _ in state = value.translation.width }
            .onEnded { value in
                if value.translation.width < -60 { store.selectCard(offset: 1) }
                if value.translation.width > 60 { store.selectCard(offset: -1) }
            }
    }
}

/// 当前卡片居中；切换时相邻卡片从两侧滑入、淡入，拖动时当前卡片随手势轻微倾斜。
private struct StagePlacement: ViewModifier {
    let offset: Int
    let dragOffset: CGFloat

    func body(content: Content) -> some View {
        let isCurrent = offset == 0
        let direction = CGFloat(offset.signum())
        content
            .rotation3DEffect(.degrees(isCurrent ? Double(dragOffset) / 18 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .scaleEffect(isCurrent ? 1 : 0.9)
            .offset(x: isCurrent ? dragOffset * 0.4 : direction * 90)
            .opacity(isCurrent ? 1 : 0)
            .zIndex(isCurrent ? 1 : 0)
            .allowsHitTesting(isCurrent)
    }
}

private struct ChevronButton: View {
    let systemImage: String
    let key: KeyEquivalent
    let label: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: Circle())
                .overlay { Circle().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
        .keyboardShortcut(key, modifiers: [])
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct PageIndicator: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { page in
                Capsule()
                    .fill(page == index ? Color.accentColor : Color.primary.opacity(0.2))
                    .frame(width: page == index ? 16 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: index)
        .accessibilityElement()
        .accessibilityLabel("第 \(index + 1) 张，共 \(count) 张")
    }
}

// MARK: - Skin gallery

private struct GalleryHeader: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("选择皮肤")
                .font(.title.weight(.bold))
            Text("点击皮肤即时预览到卡面 · 授人以鱼不如授人以渔，用你自己的图片制作专属卡面")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

private struct SkinGallery: View {
    @ObservedObject var store: WalletBloomStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(store.skins) { skin in
                SkinTile(
                    skin: skin,
                    isSelected: store.selectedSkin?.id == skin.id,
                    isApplied: store.selectedCard?.currentSkinID == skin.id
                ) {
                    store.selectSkin(skin)
                }
                .contextMenu {
                    if store.isImported(skin) {
                        Button("删除皮肤", systemImage: "trash", role: .destructive) {
                            store.deleteImportedSkin(skin)
                        }
                    }
                }
            }
            CreateSkinTile { store.isImporterPresented = true }
        }
        // 裁剪弹窗挂在皮肤网格上，避免和挂在主界面上的同步弹窗共用同一个视图。
        .sheet(item: $store.pendingImport) { pending in
            ImageCropView(pending: pending) {
                store.pendingImport = nil
            } onConfirm: { cropRect in
                store.finishImport(pending, cropRect: cropRect)
            }
        }
    }
}

/// 皮肤格子的公共骨架：上方 2:1 的图案区，下方固定高度的文字区，保证所有格子等高。
private enum TileMetrics {
    static let cornerRadius: CGFloat = 14
    static let artworkAspectRatio: CGFloat = 2
    static let labelHeight: CGFloat = 58
    static let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
}

private struct SkinTile: View {
    let skin: Skin
    let isSelected: Bool
    let isApplied: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .aspectRatio(TileMetrics.artworkAspectRatio, contentMode: .fit)
                    .overlay { SkinArtworkView(artwork: skin.artwork) }
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        if isApplied {
                            Label("当前选用", systemImage: "checkmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.regularMaterial, in: Capsule())
                                .padding(10)
                        }
                    }
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(skin.name)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(isApplied ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                        Text(skin.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                    if isApplied {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: TileMetrics.labelHeight)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(TileMetrics.shape)
            .overlay {
                TileMetrics.shape.strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            }
            // 选中时外圈一道浅蓝光晕。
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: TileMetrics.cornerRadius + 3, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 3)
                        .padding(-3)
                }
            }
            .shadow(color: .black.opacity(isHovering ? 0.1 : 0.04), radius: isHovering ? 12 : 4, y: isHovering ? 6 : 2)
            .contentShape(TileMetrics.shape)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.015 : 1)
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(skin.subtitle.isEmpty ? skin.name : "\(skin.name)，\(skin.subtitle)")
        .accessibilityValue([isSelected ? "正在预览" : nil, isApplied ? "已应用到当前卡片" : nil].compactMap { $0 }.joined(separator: "，"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// 网格最后一格：引导用户用自己的图片制作卡面。
private struct CreateSkinTile: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Color.clear.aspectRatio(TileMetrics.artworkAspectRatio, contentMode: .fit)
                Color.clear.frame(height: TileMetrics.labelHeight)
            }
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.tint)
                        .frame(width: 46, height: 46)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    Text("制作专属卡面")
                        .font(.callout.weight(.semibold))
                    Text("导入本地图片，裁剪成卡面")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("导入图片", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
            .background(Color.primary.opacity(isHovering ? 0.06 : 0.035), in: TileMetrics.shape)
            .overlay { TileMetrics.shape.strokeBorder(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [5, 4])) }
            .contentShape(TileMetrics.shape)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .onHover { isHovering = $0 }
        .help("导入本地图片作为卡面（⌘O）")
        .accessibilityLabel("制作专属卡面，导入本地图片")
    }
}

private struct InfoStrip: View {
    let onLearnMore: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.tint)
            Text("为 iPhone 钱包中的卡片更换皮肤。所有操作通过数据线在本机完成，不上传任何数据。")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Button(action: onLearnMore) {
                HStack(spacing: 3) {
                    Text("隐私与安全")
                    Image(systemName: "arrow.up.right")
                }
            }
            .buttonStyle(.link)
            .font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Floating action deck

/// 悬浮在窗口底部的胶囊操作栏。
private struct ActionDeck: View {
    @ObservedObject var store: WalletBloomStore

    var body: some View {
        HStack(spacing: 8) {
            Button { store.isImporterPresented = true } label: {
                HStack(spacing: 6) {
                    Label("导入图片", systemImage: "plus")
                    ShortcutHint("⌘O")
                }
            }
            .help("使用自己的图片作为卡面")

            Divider().frame(height: 20)

            Button { store.startScan() } label: {
                Label("重新扫描", systemImage: "arrow.clockwise")
            }
            .disabled(!store.canScan)
            .help("重新扫描钱包中的卡片（⌘R）")

            Button { store.requestApply() } label: {
                HStack(spacing: 6) {
                    Label("应用到 iPhone", systemImage: "square.and.arrow.down")
                    ShortcutHint("⌘↩", onAccent: true)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.canApply)
            .help("把当前皮肤写入 iPhone 钱包")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 1) }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }
}

private struct ShortcutHint: View {
    let text: String
    var onAccent = false

    init(_ text: String, onAccent: Bool = false) {
        self.text = text
        self.onAccent = onAccent
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(onAccent ? AnyShapeStyle(.white.opacity(0.7)) : AnyShapeStyle(.tertiary))
            .accessibilityHidden(true)
    }
}

/// 操作栏上方的轻提示：兼容性警告常驻，普通提示几秒后自动消失。
private struct StatusCapsule: View {
    @ObservedObject var store: WalletBloomStore

    var body: some View {
        Group {
            if let message = store.compatibility.message {
                Label(message, systemImage: store.compatibility.isBlocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(store.compatibility.isBlocking ? .red : .orange)
            } else if let notice = store.notice {
                Text(notice)
                    .foregroundStyle(.secondary)
                    .task(id: notice) {
                        try? await Task.sleep(for: .seconds(6))
                        store.clearNotice(notice)
                    }
            }
        }
        .font(.callout)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 1) }
        .opacity(store.compatibility.message == nil && store.notice == nil ? 0 : 1)
        .animation(.smooth(duration: 0.25), value: store.notice)
    }
}

private struct FooterBar: View {
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "—"
        let build = info["CFBundleVersion"] as? String ?? "—"
        return "版本 \(short)（\(build)）"
    }

    var body: some View {
        HStack {
            Text("\(AppInfo.displayName) · 独立开发的第三方工具，与 Apple 及任何发卡机构无关")
            Spacer()
            Text(version)
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
