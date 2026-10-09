import SwiftUI
import UniformTypeIdentifiers

/// 主界面：顶部卡片堆叠、中间皮肤库、底部操作栏。
struct WorkspaceView: View {
    @ObservedObject var store: WalletBloomStore
    @ObservedObject var coordinator: DefaultFlashCoordinator
    @AppStorage(WalletBloomStore.suppressRestoreWarningKey) private var suppressRestoreWarning = false

    var body: some View {
        VStack(spacing: 0) {
            CardCarousel(store: store)
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .padding(.bottom, 16)
            Divider()
            SkinLibrary(store: store)
            BottomBar(store: store)
        }
        .searchable(text: $store.skinSearchText, placement: .toolbar, prompt: "搜索皮肤")
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

// MARK: - Sync sheet

private struct SyncSheet: View {
    @ObservedObject var coordinator: DefaultFlashCoordinator
    let onRetry: () -> Void

    var body: some View {
        if let job = coordinator.activeJob {
            VStack(spacing: 20) {
                CardFace(card: job.card, skin: job.skin)
                    .frame(width: 230)
                    .overlay(alignment: .topTrailing) { resultBadge(for: job.state) }
                    .padding(.top, 6)

                VStack(spacing: 6) {
                    Text(title(for: job.state))
                        .font(.title3.weight(.semibold))
                    Text(job.message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                switch job.state {
                case .preparing, .transferring:
                    VStack(spacing: 8) {
                        ProgressView(value: job.progress)
                            .animation(.easeInOut(duration: 0.4), value: job.progress)
                        HStack {
                            Text("同步期间请勿断开数据线或锁定 iPhone")
                            Spacer()
                            Text("\(Int(job.progress * 100))%").monospacedDigit()
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                case .completed:
                    VStack(spacing: 16) {
                        RefreshWalletTip()
                        Button("完成") { coordinator.dismiss() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                            .controlSize(.large)
                    }
                case .failed:
                    HStack(spacing: 12) {
                        Button("关闭") { coordinator.dismiss() }
                            .keyboardShortcut(.cancelAction)
                        Button("重试", action: onRetry)
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                    }
                    .controlSize(.large)
                }
            }
            .padding(28)
            .frame(width: 420)
            .interactiveDismissDisabled(job.isRunning)
            .animation(.smooth(duration: 0.3), value: job.state)
        }
    }

    private func title(for state: FlashJob.State) -> String {
        switch state {
        case .preparing, .transferring: return "正在同步到 iPhone"
        case .completed: return "同步完成"
        case .failed: return "同步失败"
        }
    }

    @ViewBuilder
    private func resultBadge(for state: FlashJob.State) -> some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .font(.system(size: 34))
                .offset(x: 12, y: -12)
                .transition(.scale.combined(with: .opacity))
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
                .font(.system(size: 34))
                .offset(x: 12, y: -12)
                .transition(.scale.combined(with: .opacity))
        case .preparing, .transferring:
            EmptyView()
        }
    }
}

/// 同步完成后提示用户重启钱包 App，否则钱包会继续显示内存中的旧卡面。
private struct RefreshWalletTip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("还差一步就能看到新卡面", systemImage: "lightbulb.fill")
                .font(.headline)
                .symbolRenderingMode(.multicolor)
            VStack(alignment: .leading, spacing: 4) {
                Text("1. 在 iPhone 上从屏幕底部上滑并停顿，打开后台 App 列表（有主屏幕按钮的机型：连按两下主屏幕按钮）")
                    .fixedSize(horizontal: false, vertical: true)
                Text("2. 找到「钱包」，向上滑动将其关闭")
                Text("3. 重新打开钱包，即可看到新卡面（仍是旧卡面时，可重启 iPhone）")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Card carousel

private struct CardCarousel: View {
    @ObservedObject var store: WalletBloomStore
    @GestureState private var dragOffset: CGFloat = 0
    @State private var draftName = ""

    private let cardWidth: CGFloat = 250

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                navigationButton("chevron.left", key: .leftArrow, help: "上一张卡片") { store.selectCard(offset: -1) }

                ZStack {
                    ForEach(Array(store.cards.enumerated()), id: \.element.id) { index, card in
                        CardFace(card: card, skin: store.skin(for: card))
                            .frame(width: cardWidth)
                            .modifier(StackPlacement(offset: index - store.selectedCardIndex, dragOffset: dragOffset))
                            .onTapGesture { store.selectCard(card.id) }
                            .contextMenu { menu(for: card) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(card.title)
                            .accessibilityValue(card.id == store.selectedCardID ? "当前卡片" : "")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHidden(abs(index - store.selectedCardIndex) > 2)
                            .help("右键可重命名卡片，或移除误识别的卡片")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: cardWidth / WalletCard.artworkAspectRatio + 16)
                .contentShape(Rectangle())
                .gesture(swipeGesture)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: store.selectedCardID)

                navigationButton("chevron.right", key: .rightArrow, help: "下一张卡片") { store.selectCard(offset: 1) }
            }

            PageIndicator(count: store.cards.count, index: store.selectedCardIndex)
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
                if value.translation.width < -50 { store.selectCard(offset: 1) }
                if value.translation.width > 50 { store.selectCard(offset: -1) }
            }
    }

    private func navigationButton(_ systemImage: String, key: KeyEquivalent, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage).fontWeight(.semibold)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .keyboardShortcut(key, modifiers: [])
        .disabled(store.cards.count < 2)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// 根据与当前卡片的距离计算堆叠位置：当前卡在最前，两侧的卡片缩小、压暗并露出一角。
private struct StackPlacement: ViewModifier {
    let offset: Int
    let dragOffset: CGFloat

    func body(content: Content) -> some View {
        let distance = abs(offset)
        let depth = CGFloat(min(distance, 2))
        let direction = CGFloat(offset.signum())
        content
            .scaleEffect(1 - depth * 0.07)
            .brightness(offset == 0 ? 0 : -0.12)
            .offset(x: direction * depth * 24 + (offset == 0 ? dragOffset * 0.35 : 0), y: depth * 8)
            .opacity(distance > 2 ? 0 : (offset == 0 ? 1 : 0.6))
            .zIndex(Double(100 - distance))
            .allowsHitTesting(distance <= 2)
    }
}

private struct PageIndicator: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { page in
                Capsule()
                    .fill(page == index ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: page == index ? 18 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: index)
        .accessibilityElement()
        .accessibilityLabel("第 \(index + 1) 张，共 \(count) 张")
    }
}

// MARK: - Skin library

private struct SkinLibrary: View {
    @ObservedObject var store: WalletBloomStore

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("选择皮肤").font(.headline)
                Spacer()
                Picker("分类", selection: $store.skinFilter) {
                    Text("全部").tag(WalletBloomStore.SkinFilter.all)
                    Label("收藏", systemImage: "star").tag(WalletBloomStore.SkinFilter.favorites)
                    ForEach(store.skinCategories, id: \.self) { category in
                        Text(category).tag(WalletBloomStore.SkinFilter.category(category))
                    }
                }
                .labelsHidden()
                .fixedSize()
                .help("按分类筛选皮肤")
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if store.visibleSkins.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.visibleSkins) { skin in
                            SkinTile(
                                skin: skin,
                                isSelected: store.selectedSkin?.id == skin.id,
                                isApplied: store.selectedCard?.currentSkinID == skin.id,
                                isFavorite: store.isFavorite(skin)
                            ) {
                                store.selectSkin(skin)
                            }
                            .contextMenu {
                                Button(store.isFavorite(skin) ? "取消收藏" : "收藏", systemImage: store.isFavorite(skin) ? "star.slash" : "star") {
                                    store.toggleFavorite(skin)
                                }
                                if store.isImported(skin) {
                                    Divider()
                                    Button("删除皮肤", systemImage: "trash", role: .destructive) {
                                        store.deleteImportedSkin(skin)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(maxHeight: .infinity)
        // 裁剪弹窗挂在皮肤库上，避免和挂在主界面上的同步弹窗共用同一个视图。
        .sheet(item: $store.pendingImport) { pending in
            ImageCropView(pending: pending) {
                store.pendingImport = nil
            } onConfirm: { cropRect in
                store.finishImport(pending, cropRect: cropRect)
            }
        }
    }
}

private extension SkinLibrary {
    @ViewBuilder
    var emptyState: some View {
        if !store.skinSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView.search(text: store.skinSearchText)
        } else if store.skinFilter == .favorites {
            ContentUnavailableView("还没有收藏的皮肤", systemImage: "star", description: Text("在皮肤上右键选择「收藏」，就能在这里快速找到。"))
        } else {
            ContentUnavailableView("这个分类下没有皮肤", systemImage: "square.grid.2x2")
        }
    }
}

private struct SkinTile: View {
    let skin: Skin
    let isSelected: Bool
    let isApplied: Bool
    let isFavorite: Bool
    let action: () -> Void
    @State private var isHovering = false

    private let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: 72)
                    .overlay { SkinArtworkView(artwork: skin.artwork) }
                    .clipped()
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(skin.name).font(.callout.weight(.semibold))
                        Spacer(minLength: 0)
                        if isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .help("已收藏")
                        }
                        if isApplied {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .help("当前卡片已应用该皮肤")
                        }
                    }
                    Text(skin.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2.5 : 0.5)
            }
            .shadow(color: isSelected ? Color.accentColor.opacity(0.25) : .black.opacity(0.06), radius: isSelected ? 8 : 3, y: 2)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .offset(y: isHovering ? -2 : 0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(skin.subtitle.isEmpty ? skin.name : "\(skin.name)，\(skin.subtitle)")
        .accessibilityValue([isSelected ? "正在预览" : nil, isApplied ? "已应用到当前卡片" : nil, isFavorite ? "已收藏" : nil].compactMap { $0 }.joined(separator: "，"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Bottom bar

private struct BottomBar: View {
    @ObservedObject var store: WalletBloomStore

    var body: some View {
        HStack(spacing: 10) {
            Button { store.isImporterPresented = true } label: {
                Label("导入图片", systemImage: "plus")
            }
            .help("使用自己的图片作为卡面")

            Button { store.startScan() } label: {
                Label("重新扫描", systemImage: "arrow.clockwise")
            }
            .help("重新扫描钱包中的卡片")

            status
                .frame(maxWidth: .infinity)

            Button { store.requestApply() } label: {
                Label("应用到 iPhone", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.canApply)
            .help("把当前皮肤写入 iPhone 钱包（⌘↩）")
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private var status: some View {
        if let message = store.compatibility.message {
            Label(message, systemImage: store.compatibility.isBlocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(store.compatibility.isBlocking ? .red : .orange)
                .lineLimit(1)
        } else if let notice = store.notice {
            Text(notice)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
