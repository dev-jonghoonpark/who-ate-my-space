import SwiftUI

/// 파일 확장자를 카테고리로 분류하고 카테고리별 색상을 제공한다.
enum FileCategory: String, CaseIterable, Identifiable {
    case folder
    case image
    case video
    case audio
    case document
    case code
    case archive
    case app
    case disk
    case other

    var id: String { rawValue }

    /// 범례 등에 표시할 로컬라이즈된 이름.
    var displayName: String {
        switch self {
        case .folder:   return String(localized: "category.folder")
        case .image:    return String(localized: "category.image")
        case .video:    return String(localized: "category.video")
        case .audio:    return String(localized: "category.audio")
        case .document: return String(localized: "category.document")
        case .code:     return String(localized: "category.code")
        case .archive:  return String(localized: "category.archive")
        case .app:      return String(localized: "category.app")
        case .disk:     return String(localized: "category.disk")
        case .other:    return String(localized: "category.other")
        }
    }

    var color: Color {
        switch self {
        case .folder:   return Color(red: 0.55, green: 0.58, blue: 0.62)
        case .image:    return Color(red: 0.30, green: 0.69, blue: 0.49)
        case .video:    return Color(red: 0.85, green: 0.37, blue: 0.34)
        case .audio:    return Color(red: 0.55, green: 0.43, blue: 0.78)
        case .document: return Color(red: 0.31, green: 0.55, blue: 0.85)
        case .code:     return Color(red: 0.95, green: 0.70, blue: 0.27)
        case .archive:  return Color(red: 0.78, green: 0.55, blue: 0.32)
        case .app:      return Color(red: 0.40, green: 0.78, blue: 0.82)
        case .disk:     return Color(red: 0.62, green: 0.40, blue: 0.55)
        case .other:    return Color(red: 0.50, green: 0.52, blue: 0.55)
        }
    }

    private static let extensionMap: [String: FileCategory] = {
        var map: [String: FileCategory] = [:]
        func add(_ category: FileCategory, _ exts: [String]) {
            for e in exts { map[e] = category }
        }
        add(.image, ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "raw", "cr2", "nef", "svg", "psd", "ai"])
        add(.video, ["mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm", "mpg", "mpeg", "3gp", "prproj"])
        add(.audio, ["mp3", "wav", "aac", "flac", "m4a", "ogg", "aiff", "alac", "wma", "logicx"])
        add(.document, ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "md", "pages", "numbers", "key", "csv", "epub"])
        add(.code, ["swift", "c", "cpp", "h", "hpp", "m", "mm", "java", "kt", "py", "js", "ts", "jsx", "tsx", "go", "rs", "rb", "php", "html", "css", "json", "xml", "yml", "yaml", "sh", "sql"])
        add(.archive, ["zip", "tar", "gz", "bz2", "xz", "7z", "rar", "tgz", "zst", "lz", "jar"])
        add(.app, ["app", "exe", "dmg", "pkg", "deb", "appimage", "msi"])
        add(.disk, ["iso", "img", "sparseimage", "sparsebundle", "vmdk", "qcow2", "vdi"])
        return map
    }()

    static func category(for node: FileNode) -> FileCategory {
        if node.isDirectory { return .folder }
        let ext = (node.name as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return .other }
        // .app/.dmg는 disk 분류를 우선하지 않도록 별도 처리
        if ext == "dmg" || ext == "iso" || ext == "sparseimage" || ext == "sparsebundle" {
            return .disk
        }
        return extensionMap[ext] ?? .other
    }

    static func color(for node: FileNode) -> Color {
        category(for: node).color
    }
}
