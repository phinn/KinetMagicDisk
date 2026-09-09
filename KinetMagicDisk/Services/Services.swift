import AppKit
import UniformTypeIdentifiers

/// 垃圾桶服务:沙盒下用 trashItem(系统回收站,无需额外权限)
enum TrashService {
    @discardableResult
    static func move(node: FileSystemNode) -> Bool {
        do {
            try FileManager.default.trashItem(at: node.id, resultingItemURL: nil)
            NSLog("KMD trash OK: %@", node.id.path)
            return true
        } catch {
            NSLog("KMD trash FAIL: %@ error=%@", node.id.path, error.localizedDescription)
            NSSound.beep()
            return false
        }
    }
}

/// 磁盘/目录选择服务
enum SourcePicker {
    /// 沙盒下 homeDirectoryForCurrentUser 返回容器假 Home,不能用。
    /// 真实用户目录 = 容器外的 getpwuid,仅用于展示路径;实际读取仍靠用户授权。
    static func realHomePath() -> String {
        if let pw = getpwuid(getuid()) {
            return String(cString: pw.pointee.pw_dir)
        }
        return NSHomeDirectory()
    }

    /// 快捷入口:真实用户目录路径(展示 + 面板初始目录)。
    /// 沙盒下 urls(for:) 返回容器假目录(扫出来是空的),必须用 getpwuid 的真实 Home 拼路径。
    /// 实际读取仍需 NSOpenPanel 授权,此处仅提供默认导航位置。
    static func quickRoots() -> [(url: URL, labelKey: String)] {
        let home = realHomePath()
        return [
            (URL(fileURLWithPath: home + "/Desktop"), "root.desktop"),
            (URL(fileURLWithPath: home + "/Documents"), "root.documents"),
            (URL(fileURLWithPath: home + "/Downloads"), "root.downloads"),
        ]
    }

    /// 持久化的用户授权目录书签
    private static let bookmarkKey = "kmd.rootBookmark"

    static func restoreRoot() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: data,
                              options: [.withSecurityScope],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            _ = url.startAccessingSecurityScopedResource()
            return url
        } catch {
            return nil
        }
    }

    static func saveRoot(_ url: URL) {
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        } catch {
            // 书签失败不致命,下次再选
        }
    }

    /// 打开目录选择面板(用户授权后获得该子树读权限)。NSOpenPanel 必须主线程配置+运行。
    @MainActor
    static func pickDirectory(startAt: URL? = nil) -> URL? {
        // [KMD-AUTOSHOT] 仅 Debug 包生效:KMD_AUTOSHOT=1 时跳过面板直接用默认目录(自动化截图用;Release 上架包物理隔离)
        #if DEBUG
        if ProcessInfo.processInfo.environment["KMD_AUTOSHOT"] == "1" {
            let url = startAt ?? URL(fileURLWithPath: realHomePath())
            saveRoot(url)
            return url
        }
        #endif
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = I18n.t("picker.message")
        panel.prompt = I18n.t("picker.choose")
        // 初始目录:显式指定 > 真实 Home(展示用)
        panel.directoryURL = startAt ?? URL(fileURLWithPath: realHomePath())
        let resp = panel.runModal()
        guard resp == .OK, let url = panel.url else { return nil }
        saveRoot(url)
        return url
    }
}
