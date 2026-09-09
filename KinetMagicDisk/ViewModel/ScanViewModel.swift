import SwiftUI
import Combine

/// 主 ViewModel:驱动扫描、聚焦栈、进度
@MainActor
final class ScanViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning(items: Int, path: String)
        case done
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var root: FileSystemNode?
    /// 焦点栈(支持返回上钻)
    @Published var focusStack: [FileSystemNode] = []

    var focus: FileSystemNode? { focusStack.last ?? root }
    var isScanning: Bool { if case .scanning = phase { true } else { false } }

    private var scanTask: Task<Void, Never>?
    private let scanner = DiskScanner()

    func scan(url: URL) {
        scanTask?.cancel()
        phase = .scanning(items: 0, path: url.path)
        root = nil
        focusStack = []

        scanTask = Task { [weak self] in
            guard let self else { return }
            let node = await self.scanner.scan(root: url) { progress in
                Task { @MainActor [weak self] in
                    guard let self, self.isScanning else { return }
                    self.phase = .scanning(items: progress.scannedItems, path: progress.currentPath)
                }
            }
            guard !Task.isCancelled else { return }
            self.root = node
            self.focusStack = [node]
            self.phase = .done
        }
    }

    func drillDown(to node: FileSystemNode) {
        guard node !== focus else { return }
        NSLog("KMD drillDown name=%@ isDir=%d stack=%d", node.name, node.isDirectory ? 1 : 0, focusStack.count)
        if node.isDirectory {
            focusStack.append(node)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([node.id])
        }
    }

    func drillUp() {
        guard focusStack.count > 1 else { return }
        focusStack.removeLast()
    }

    /// 返回扫描根
    func jumpToRoot() {
        guard let root else { return }
        focusStack = [root]
    }

    /// 增量摘除已删除节点:从父 children 移除,沿祖先链回滚 size/itemCount(免全量重扫)
    func removeNode(_ node: FileSystemNode) {
        guard TrashService.move(node: node) else { return }
        var cur = node
        while let p = cur.parent {
            p.children.removeAll { $0 === cur }
            p.size -= cur.size
            p.itemCount = max(0, p.itemCount - max(cur.itemCount, 1))
            cur = p
        }
        // 焦点在被删节点上则退回父级;root 引用刷新触发视图重算
        focusStack.removeAll { $0 === node }
        if root === node { root = nil }
        root = root // 触发 @Published
        objectWillChange.send()
    }

    /// 祖先链面包屑
    var breadcrumbs: [FileSystemNode] {
        focus?.ancestorChain ?? []
    }
}
