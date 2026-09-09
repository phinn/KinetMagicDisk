import Foundation

/// 扫描进度快照(跨并发边界传递)
struct ScanProgress: Sendable {
    let scannedItems: Int
    let currentPath: String
}

/// 线程安全的进度计数器(扫描工作线程共享)
final class ProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var tick = 0

    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }

    /// 累加并返回是否应上报(每 256 项上报一次,避免主线程被刷爆)
    func add(_ n: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        count += n
        tick += n
        if tick >= 256 { tick = 0; return true }
        return false
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        count = 0
        tick = 0
    }
}

/// 并发磁盘扫描引擎。
/// 设计:
/// - actor 隔离对外入口,内部递归为 nonisolated 纯函数(TaskGroup 并发,无共享可变状态)
/// - 目录级分批并发(窗口 32),防止几十万文件的 task 风暴
/// - 符号链接一律跳过(防环、防重复计大小)
/// - 沙盒下无权限的目录计入 errorCount,不中断扫描
/// - Bundle(.app 等)按单文件计大小,不深入
actor DiskScanner {

    private let counter = ProgressCounter()

    /// 扫描根目录,返回聚合完成的树
    func scan(root: URL, onProgress: @escaping @Sendable (ScanProgress) -> Void) async -> FileSystemNode {
        counter.reset()
        let isRootDir = (try? root.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if isRootDir {
            return await Self.scanTree(
                url: root,
                name: root.lastPathComponent.isEmpty ? root.path : root.lastPathComponent,
                depth: 0,
                counter: counter,
                onProgress: onProgress
            )
        } else {
            // 单文件
            let node = FileSystemNode(url: root, name: root.lastPathComponent, isDirectory: false, depth: 0)
            node.size = Self.logicalSize(of: root, values: nil)
            node.itemCount = 1
            return node
        }
    }

    // MARK: - 递归扫描(nonisolated 纯函数)

    private static let maxDepth = 24
    private static let concurrencyWindow = 32

    private static func scanTree(
        url: URL,
        name: String,
        depth: Int,
        counter: ProgressCounter,
        onProgress: @escaping @Sendable (ScanProgress) -> Void
    ) async -> FileSystemNode {
        // 沙盒容器 Desktop/Documents/Downloads 桥接 symlink:扫描前先解析到真实目标
        var scanURL = url
        var scanName = name
        if depth == 0, ["Desktop", "Documents", "Downloads"].contains(name),
           url.lastPathComponent == name,
           url.path.contains("/Library/Containers/"),
           let resolved = Self.resolveBridge(url) {
            scanURL = resolved
            scanName = resolved.lastPathComponent
        }
        let node = FileSystemNode(url: scanURL, name: scanName, isDirectory: true, depth: depth)
        guard depth < maxDepth, !Task.isCancelled else { return node }

        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey,
            .fileSizeKey, .totalFileAllocatedSizeKey
        ]
        let items: [URL]
        do {
            items = try fm.contentsOfDirectory(at: scanURL, includingPropertiesForKeys: Array(keys), options: [])
        } catch {
            node.errorCount += 1
            return node
        }

        var files: [(url: URL, size: UInt64)] = []
        var subdirs: [URL] = []

        for item in items {
            if Task.isCancelled { break }
            let values = try? item.resourceValues(forKeys: keys)
            let isSymlink = values?.isSymbolicLink ?? false
            // 沙盒容器对 Desktop/Documents/Downloads 的符号链接必须放行:
            // 系统对这三处有隐式读授权,链接是容器桥接,非用户数据环。
            let isSandboxBridge = isSymlink && depth == 0 &&
                ["Desktop", "Documents", "Downloads"].contains(item.lastPathComponent)
            if isSymlink && !isSandboxBridge { continue }
            let isDir: Bool
            if isSandboxBridge {
                // symlink 的 resourceValues 不带 isDirectory,按目录处理
                isDir = true
            } else {
                isDir = values?.isDirectory ?? false
            }
            if isDir && (isSandboxBridge || values?.isPackage != true) {
                subdirs.append(item)
            } else if !isSandboxBridge {
                files.append((item, logicalSize(of: item, values: values)))
            }
        }

        // 文件节点直接落树
        node.children.reserveCapacity(files.count + subdirs.count)
        for f in files {
            let child = FileSystemNode(url: f.url, name: f.url.lastPathComponent, isDirectory: false, depth: depth + 1)
            child.size = f.size
            child.itemCount = 1
            child.parent = node
            node.children.append(child)
        }
        node.size += files.reduce(0) { $0 + $1.size }
        node.itemCount += files.count

        counter.add(files.count)

        // 子目录分批并发(窗口 32)
        var index = 0
        while index < subdirs.count, !Task.isCancelled {
            let end = min(index + concurrencyWindow, subdirs.count)
            let batch = Array(subdirs[index..<end])
            index = end

            let subtrees = await withTaskGroup(of: FileSystemNode.self) { group in
                for sub in batch {
                    group.addTask {
                        await Self.scanTree(
                            url: sub,
                            name: sub.lastPathComponent,
                            depth: depth + 1,
                            counter: counter,
                            onProgress: onProgress
                        )
                    }
                }
                var out: [FileSystemNode] = []
                out.reserveCapacity(batch.count)
                for await r in group { out.append(r) }
                return out
            }

            for sub in subtrees {
                sub.parent = node
                node.children.append(sub)
                node.size += sub.size
                node.itemCount += sub.itemCount
                node.errorCount += sub.errorCount
            }
        }

        if counter.add(0), !Task.isCancelled {
            onProgress(ScanProgress(scannedItems: counter.value, currentPath: url.path))
        }
        return node
    }

    /// 解析沙盒容器桥接 symlink 到真实用户目录;非桥接场景返回 nil
    private static func resolveBridge(_ url: URL) -> URL? {
        let std = FileManager.default
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        // 只放行解析到 /Users/<name> 顶层目录的(防任意 symlink 穿越)
        let comps = resolved.pathComponents // ["/", "Users", "phinn", "Desktop"]
        guard comps.count > 2, comps[1] == "Users" else { return nil }
        var isDir: ObjCBool = false
        guard std.fileExists(atPath: resolved.path, isDirectory: &isDir), isDir.boolValue else { return nil }
        return resolved
    }

    /// 逻辑大小:fileSize 优先,回退 allocated
    private static func logicalSize(of url: URL, values: URLResourceValues?) -> UInt64 {
        if let v = values {
            if let s = v.fileSize, s > 0 { return UInt64(s) }
            if let s = v.totalFileAllocatedSize, s > 0 { return UInt64(s) }
        }
        if let v = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey]) {
            if let s = v.fileSize, s > 0 { return UInt64(s) }
            if let s = v.totalFileAllocatedSize, s > 0 { return UInt64(s) }
        }
        return 0
    }
}
