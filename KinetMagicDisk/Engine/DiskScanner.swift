import Foundation

/// [KMD-DBG] 直接落盘日志(沙盒下 /tmp 不可写时静默跳过)
func kmdDbg(_ msg: String) {
    #if DEBUG
    let line = "\(Date()) \(msg)\n"
    let path = "/tmp/kmd_dbg.log"
    if let fh = FileHandle(forWritingAtPath: path) {
        fh.seekToEndOfFile()
        fh.write(line.data(using: .utf8)!)
        fh.closeFile()
    } else {
        try? line.write(toFile: path, atomically: true, encoding: .utf8)
    }
    #endif
}

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

    /// [KMD-DBG] 独立采样计数器:约每 512 次调用返回一次 true(与 add 的进度上报节流互不干扰)
    func sampleTick() -> Bool {
        lock.lock(); defer { lock.unlock() }
        sampleTickCounter += 1
        if sampleTickCounter >= 512 { sampleTickCounter = 0; return true }
        return false
    }

    private var sampleTickCounter = 0

    func reset() {
        lock.lock(); defer { lock.unlock() }
        count = 0
        tick = 0
    }
}

/// [KMD-FIX3] 枚举竞速结果盒
private final class DirEnumBox {
    let lock = NSLock()
    var items: [URL] = []
    var done = false
}

/// [KMD-FIX5] 全局枚举并发闸(信号量)。
/// TCC/云盘慢目录的 open 会占死 GCD 线程直到内核超时(分钟级)。若不设闸,32 个 TaskGroup
/// 窗口全落在慢目录上时,GCD 池被占满,watchdog block 也拿不到线程 → 竞速失效、扫描假死。
/// 闸宽 8:最坏只占 8 个线程,watchdog 队列永远有线程可用;非慢目录吞吐不受影响。
/// [KMD-FIX6] wait/signal 均在 enumQueue 的 GCD block 内(GCD 线程可扩容,等待不占
/// Swift cooperative 池),watchdog 独立队列零竞争。
private let enumGate = DispatchSemaphore(value: 8)

/// [KMD-FIX5] 已确认僵死的目录前缀缓存(学习式跳过)。
/// 同一容器/卷内一旦出现 open 挂死,同前缀目录大概率同样挂死,直接短路,不再浪费竞速周期。
private final class StuckPrefixCache {
    static let shared = StuckPrefixCache()
    private let lock = NSLock()
    private var prefixes: Set<String> = []
    /// 判定粒度:容器目录(/Library/Containers/<id>)或卷根前 3 级
    func key(for url: URL) -> String? {
        let p = url.path
        if let r = p.range(of: "/Library/Containers/") {
            let rest = p[r.upperBound...]
            if let slash = rest.firstIndex(of: "/") { return "/Library/Containers/" + rest[..<slash] }
            return nil
        }
        if let r = p.range(of: "/Library/Group Containers/") {
            let rest = p[r.upperBound...]
            if let slash = rest.firstIndex(of: "/") { return "/Library/Group Containers/" + rest[..<slash] }
            return nil
        }
        return nil
    }
    func isStuck(_ url: URL) -> Bool {
        guard let k = key(for: url) else { return false }
        lock.lock(); defer { lock.unlock() }
        return prefixes.contains(k)
    }
    func markStuck(_ url: URL) {
        guard let k = key(for: url) else { return }
        lock.lock(); defer { lock.unlock() }
        prefixes.insert(k)
    }
}

/// [KMD-FIX3] 竞速完成旗标(先到者 resume,后到者丢弃)
private final class RaceState {
    let lock = NSLock()
    var finished = false
}

/// [KMD-FIX3] 枚举专用并发队列
private let enumQueue = DispatchQueue(label: "com.kinnet.magicdisk.enum", qos: .userInitiated, attributes: .concurrent)
/// [KMD-FIX4] 看门狗专用串行队列:与 race block 隔离。
/// 若 watchdog 与积压的枚举 block 同队列,海量慢目录会把 watchdog 压在队尾,竞速永远输 → 扫描假死。
/// 串行 timer 队列上只有 watchdog block,到期即执行,绝不排队。
private let watchdogQueue = DispatchQueue(label: "com.kinnet.magicdisk.watchdog", qos: .userInitiated)

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
        kmdDbg("engine scan entry url=\(root.path)")
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

        // [KMD-FIX] 云盘(File Provider)与废纸篓目录 open() 会阻塞在网络 IO(Errno 60,分钟级超时):
        // OneDrive/.Trash 实测让 10 个并发线程全卡死。按"存在但不可深入"处理:不枚举、不计入 errorCount。
        if scanName == ".Trash" || scanURL.path.contains("/Library/CloudStorage/") {
            return node
        }

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey,
            .fileSizeKey, .totalFileAllocatedSizeKey
        ]
        // [KMD-FIX2] 慢目录(容器 TCC 检查/云盘占位/网盘 .Trash)的 open 可能阻塞 60s~数分钟(Errno 60)。
        // 内核阻塞不可中断 → 竞速:枚举任务 vs 5s 计时任务,先到先得;
        // 输掉的枚举线程自然耗尽后回收(数量受 TaskGroup 窗口限制,不会雪崩)。
        let dirURL = scanURL
        // [KMD-FIX3] 两个 race participant 都跑在 GCD(不受 cooperative pool 限制,防 sleep 饥饿):
        // 卡死的 open 线程困在 GCD 池(GCD 可扩容),Swift 并发池只挂轻量 continuation。
        // [KMD-FIX5] 学习式跳过:同容器/同卷曾出现 open 挂死,本目录直接按"存在但不可深入"处理
        if StuckPrefixCache.shared.isStuck(scanURL) {
            node.errorCount += 1
            return node
        }
        // [KMD-FIX6] 信号量限流移入 GCD block 内:cooperative 池只挂 continuation 永不阻塞;
        // 名额等待发生在 GCD 线程(可扩容),watchdog 独立队列不受影响 → 无死锁、无协作池饿死。
        let raced: [URL]? = await withCheckedContinuation { outer in
            let box = DirEnumBox()
            let state = RaceState()
            let finish: (Bool, [URL]) -> Void = { done, urls in
                state.lock.lock()
                let already = state.finished
                state.finished = true
                state.lock.unlock()
                guard !already else { return }
                box.lock.lock(); box.items = urls; box.lock.unlock()
                outer.resume(returning: done ? urls : nil)
            }
            watchdogQueue.asyncAfter(deadline: .now() + 5) { finish(false, []) }
            enumQueue.async {
                // [KMD-FIX5] 慢目录限宽:最坏 8 个 open 挂死,余下名额给 watchdog 与正常枚举
                enumGate.wait()
                defer { enumGate.signal() }
                let urls = (try? FileManager.default.contentsOfDirectory(
                    at: dirURL, includingPropertiesForKeys: Array(keys), options: [])) ?? []
                finish(true, urls)
            }
        }
        guard let items = raced, !items.isEmpty || FileManager.default.isReadableFile(atPath: dirURL.path) else {
            // 看门狗超时:标记该目录所属容器/卷为僵死区,后续同前缀目录全部短路
            StuckPrefixCache.shared.markStuck(dirURL)
            kmdDbg("enum TIMEOUT \(dirURL.path)")
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

        _ = counter.add(files.count)

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
        // [KMD-DBG] 采样落盘,避免热路径 IO 拖慢扫描
        if counter.sampleTick() {
            kmdDbg("scanTree done url=\(url.path) items=\(node.itemCount)")
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
