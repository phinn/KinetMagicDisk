import SwiftUI

/// 主窗口:工具栏 + 旭日图 + 文件列表 + 状态栏
struct ContentView: View {
    @StateObject private var vm = ScanViewModel()

    var body: some View {
        VStack(spacing: 0) {
            breadcrumbBar
            Divider()
            HSplitView {
                sunburstPane
                    .frame(minWidth: 380, maxWidth: 620, maxHeight: .infinity)
                    .padding(12)
                filePane
                    .frame(minWidth: 340, idealWidth: 420, maxHeight: .infinity)
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 1280, idealWidth: 1280, maxWidth: .infinity, minHeight: 768, idealHeight: 768, maxHeight: .infinity)
        .background(taskbarBackground)
        .overlay { idleOverlay }
        .navigationTitle("KinetMagicDisk")
        .onReceive(NotificationCenter.default.publisher(for: .kmdScanHome)) { _ in
            if let url = SourcePicker.restoreRoot() {
                vm.scan(url: url)
            } else if let url = SourcePicker.pickDirectory() {
                vm.scan(url: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .kmdPickFolder)) { _ in
            if let url = SourcePicker.pickDirectory() {
                vm.scan(url: url)
            }
        }
    }

    // MARK: - 面包屑

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if vm.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text(I18n.t("status.scanning", vm.scannedItemsText))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let crumbs = vm.breadcrumbs as [FileSystemNode]?, !crumbs.isEmpty {
                    ForEach(Array(crumbs.enumerated()), id: \.element.id) { idx, node in
                        if idx > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Button {
                            vmFocus(node)
                        } label: {
                            Text(node.name.isEmpty ? "/" : node.name)
                                .font(.system(size: 12, weight: idx == crumbs.count - 1 ? .semibold : .regular))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .disabled(idx == crumbs.count - 1)
                    }
                }
                Spacer()
                if vm.focusStack.count > 1 {
                    Button {
                        vm.drillUp()
                    } label: {
                        Label(I18n.t("action.up"), systemImage: "chevron.up.circle")
                    }
                    .buttonStyle(.borderless)
                }
                if vm.focusStack.count > 1 {
                    Button {
                        vm.jumpToRoot()
                    } label: {
                        Label(I18n.t("action.top"), systemImage: "arrow.up.to.line")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - 旭日图区

    private var sunburstPane: some View {
        ZStack {
            if let focus = vm.focus {
                SunburstView(focus: focus) { node in
                    vm.drillDown(to: node)
                }
            } else {
                Color.clear
            }
        }
    }

    // MARK: - 列表区

    private var filePane: some View {
        Group {
            if let focus = vm.focus {
                FileListView(focus: focus) { node in
                    vm.drillDown(to: node)
                } onTrash: { node in
                    vm.removeNode(node)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text(I18n.t("idle.title"))
                        .font(.headline)
                    Text(I18n.t("idle.desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        HStack(spacing: 12) {
            if let focus = vm.focus {
                Image(systemName: FileKind(node: focus).symbolName)
                    .foregroundStyle(.secondary)
                Text(focus.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Fmt.bytes(focus.size))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if focus.errorCount > 0 {
                    Label(String(focus.errorCount), systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help(I18n.t("status.permissionErrors"))
                }
            }
            Spacer()
            Button {
                revealFocusInFinder()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .disabled(vm.focus == nil)
            .accessibilityLabel(Text(I18n.t("action.revealInFinder")))
            .help(I18n.t("action.revealInFinder"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - 空闲遮罩(选择来源)

    private var idleOverlay: some View {
        Group {
            if vm.root == nil {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    VStack(spacing: 20) {
                        Image(systemName: "opticaldisc.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.linearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
                        Text(I18n.t("idle.big"))
                            .font(.title2.weight(.semibold))
                        Text(I18n.t("idle.sub"))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button {
                                if let url = SourcePicker.restoreRoot() {
                                    vm.scan(url: url)
                                } else if let url = SourcePicker.pickDirectory() {
                                    vm.scan(url: url)
                                }
                            } label: {
                                Label(SourcePicker.restoreRoot() != nil ?
                                      I18n.t("idle.rescan") : I18n.t("idle.scanHome"),
                                      systemImage: "house")
                            }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)

                            Button {
                                if let url = SourcePicker.pickDirectory() {
                                    vm.scan(url: url)
                                }
                            } label: {
                                Label(I18n.t("idle.pickFolder"), systemImage: "folder.badge.plus")
                            }
                            .buttonStyle(.bordered)
                        }
                        // 快捷入口:打开授权面板并定位到对应真实目录
                        HStack(spacing: 8) {
                            ForEach(SourcePicker.quickRoots(), id: \.url) { root in
                                Button {
                                    if let url = SourcePicker.pickDirectory(startAt: root.url) {
                                        vm.scan(url: url)
                                    }
                                } label: {
                                    Label(I18n.t(root.labelKey), systemImage: "folder")
                                        .font(.callout)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(40)
                }
            }
        }
    }

    private var taskbarBackground: some View {
        Color(nsColor: .windowBackgroundColor)
    }

    // MARK: - 动作

    private func vmFocus(_ node: FileSystemNode) {
        if let idx = vm.focusStack.firstIndex(where: { $0.id == node.id }) {
            vm.focusStack = Array(vm.focusStack[...idx])
        }
    }

    private func revealFocusInFinder() {
        guard let f = vm.focus else { return }
        NSWorkspace.shared.activateFileViewerSelecting([f.id])
    }
}

extension ScanViewModel {
    var scannedItemsText: String {
        if case .scanning(let items, _) = phase {
            return Fmt.itemCount(items)
        }
        return "0"
    }
}
