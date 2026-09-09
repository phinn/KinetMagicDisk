import SwiftUI

// MARK: - 大小格式化

enum Fmt {
    static func bytes(_ n: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file)
    }

    static func itemCount(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic))
    }
}

// MARK: - 文件类型分类

enum FileKind: Equatable {
    case folder, image, video, audio, archive, code, document, other

    init(node: FileSystemNode) {
        guard !node.isDirectory else { self = .folder; return }
        let ext = node.id.pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "bmp", "webp", "svg", "raw", "dng", "psd":
            self = .image
        case "mp4", "mov", "mkv", "avi", "m4v", "webm":
            self = .video
        case "mp3", "aac", "wav", "flac", "m4a", "aiff", "ogg":
            self = .audio
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar", "dmg", "pkg":
            self = .archive
        case "swift", "ts", "js", "py", "c", "h", "cpp", "hpp", "m", "mm", "rs", "go", "java", "kt", "rb", "sh", "json", "yaml", "yml", "toml", "html", "css":
            self = .code
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "txt", "md", "rtf":
            self = .document
        default:
            self = .other
        }
    }

    var symbolName: String {
        switch self {
        case .folder: return "folder.fill"
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "music.note"
        case .archive: return "doc.zipper"
        case .code: return "curlybraces"
        case .document: return "doc.text"
        case .other: return "doc"
        }
    }
}

// MARK: - Sunburst 配色(名称 → 稳定色相)

enum SunburstColor {
    /// 名称哈希 → [0,1) 稳定色相
    static func hueOffset(for name: String) -> Double {
        var h: UInt64 = 1469598103934665603 // FNV-1a offset
        for b in name.utf8 {
            h ^= UInt64(b)
            h = h &* 1099511628211
        }
        return Double(h % 1000) / 1000.0
    }
}
