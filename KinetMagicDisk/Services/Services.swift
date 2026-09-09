import AppKit
import UniformTypeIdentifiers

/// 垃圾桶服务:沙盒下用 trashItem(系统回收站,无需额外权限)
enum TrashService {
    @discardableResult
    static func move(node: FileSystemNode) -> Bool {
        do {
            try FileManager.default.trashItem(at: node.id, resultingItemURL: nil)
            return true
        } catch {
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

    /// 沙盒默认可读的三个用户目录(无需弹窗)
    static func preauthorizedRoots() -> [(url: URL, labelKey: String)] {
        let fm = FileManager.default
        var roots: [(URL, String)] = []
        for (key, label) in [(FileManager.SearchPathDirectory.desktopDirectory, "root.desktop"),
                             (FileManager.SearchPathDirectory.documentDirectory, "root.documents"),
                             (FileManager.SearchPathDirectory.downloadsDirectory, "root.downloads")] {
            if let url = fm.urls(for: key, in: .userDomainMask).first {
                roots.append((url, label))
            }
        }
        return roots
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
    static func pickDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = I18n.t("picker.message")
        panel.prompt = I18n.t("picker.choose")
        // 默认定位到真实 Home(展示用)
        panel.directoryURL = URL(fileURLWithPath: realHomePath())
        let resp = panel.runModal()
        guard resp == .OK, let url = panel.url else { return nil }
        saveRoot(url)
        return url
    }
}
