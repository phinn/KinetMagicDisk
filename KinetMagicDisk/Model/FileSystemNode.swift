import Foundation

/// 文件系统节点(扫描产物树)。class 便于 parent 上溯与就地删除。
final class FileSystemNode: Identifiable, @unchecked Sendable {
    let id: URL
    let name: String
    let isDirectory: Bool
    let depth: Int
    weak var parent: FileSystemNode?

    /// 直接子节点(目录的 children;文件为空)
    var children: [FileSystemNode] = []
    /// 子树聚合大小(bytes)。文件 = 自身逻辑大小
    var size: UInt64 = 0
    /// 子树文件数(不含目录自身)
    var itemCount: Int = 0
    /// 扫描时无法读取的条目数(权限/竞态)
    var errorCount: Int = 0

    init(url: URL, name: String, isDirectory: Bool, depth: Int) {
        self.id = url
        self.name = name
        self.isDirectory = isDirectory
        self.depth = depth
    }

    /// 从本节点到 scanRoot 的祖先链(含自身)
    var ancestorChain: [FileSystemNode] {
        var chain: [FileSystemNode] = []
        var cur: FileSystemNode? = self
        while let n = cur {
            chain.append(n)
            cur = n.parent
        }
        return chain.reversed()
    }
}
