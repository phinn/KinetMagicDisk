import SwiftUI

/// 轻量 i18n:直接读 bundle 本地化表
enum I18n {
    private static var bundle: Bundle = .main

    static func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, bundle: bundle, comment: ""), arguments: args)
    }
}

/// 文件列表行
struct FileRow: View {
    let node: FileSystemNode
    /// 祖先链中的 size 占比(0-1),用于画比例条
    let fraction: Double
    var onTrash: (FileSystemNode) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: FileKind(node: node).symbolName)
                .foregroundStyle(node.isDirectory ? Color.blue : Color.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(size: 12, weight: node.isDirectory ? .medium : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.12))
                        Capsule()
                            .fill(LinearGradient(colors: [.blue, .cyan],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(min(fraction, 1)))
                    }
                }
                .frame(height: 3)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.bytes(node.size))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(I18n.t("list.items", Fmt.itemCount(node.itemCount)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            // 悬停显形的"移到废纸篓"按钮(可发现性 + 辅助功能可达)
            Button {
                onTrash(node)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(I18n.t("action.moveToTrash")))
            .help(I18n.t("action.moveToTrash"))
            .opacity(hover ? 1 : 0.25)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
    @State private var hover = false
}

/// 右侧:当前焦点子项列表(按大小降序)
struct FileListView: View {
    let focus: FileSystemNode
    var onPick: (FileSystemNode) -> Void
    var onTrash: (FileSystemNode) -> Void = { _ in }

    private var sorted: [FileSystemNode] {
        focus.children.sorted { $0.size > $1.size }
    }

    var body: some View {
        List {
            ForEach(sorted, id: \.id) { child in
                FileRow(node: child, fraction: focus.size > 0 ? Double(child.size) / Double(focus.size) : 0, onTrash: onTrash)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    .contentShape(Rectangle())
                    .onTapGesture { onPick(child) }
                    .contextMenu {
                        Button(I18n.t("action.revealInFinder")) {
                            NSWorkspace.shared.activateFileViewerSelecting([child.id])
                        }
                        Button(I18n.t("action.moveToTrash"), role: .destructive) {
                            onTrash(child)
                        }
                        Divider()
                        Button(I18n.t("action.focus")) { onPick(child) }
                    }
            }
        }
        .listStyle(.inset)
        .overlay {
            if focus.children.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text(I18n.t("list.empty.title"))
                        .font(.headline)
                    Text(I18n.t("list.empty.desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
