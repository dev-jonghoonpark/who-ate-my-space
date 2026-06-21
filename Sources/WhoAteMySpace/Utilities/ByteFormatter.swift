import Foundation

/// 용량(byte) → 사람이 읽는 문자열. `ByteCountFormatter`를 감싼다.
enum ByteFormat {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file        // 1 KB = 1000 byte (Finder와 동일)
        f.allowsNonnumericFormatting = false
        return f
    }()

    static func string(_ bytes: Int64) -> String {
        formatter.string(fromByteCount: max(0, bytes))
    }
}
