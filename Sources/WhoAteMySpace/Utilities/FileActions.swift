import AppKit

/// 파일에 대한 시스템 작업 모음 (Finder 보기, 휴지통, Quick Look, 경로 복사).
enum FileActions {

    /// Finder에서 해당 항목을 선택해 보여준다.
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// 기본 앱으로 연다.
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// 휴지통으로 이동. 성공 시 true. 실패 시 throw.
    @discardableResult
    static func moveToTrash(_ url: URL) throws -> URL? {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return resultingURL as URL?
    }

    /// 경로 문자열을 클립보드에 복사.
    static func copyPath(_ url: URL) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.path, forType: .string)
    }

    /// 휴지통 이동 전 사용자 확인 알림. 사용자가 "휴지통으로 이동"을 누르면 true.
    static func confirmTrash(_ node: FileNode) -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Move “\(node.name)” to the Trash?")
        alert.informativeText = String(localized: "Size: \(ByteFormat.string(node.size))\nPath: \(node.url.path)")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Move to Trash"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// 시스템 설정의 "저장 공간" 패널을 연다. (macOS 13+ System Settings → General → Storage)
    static func openStorageSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.Storage",
            "x-apple.systempreferences:com.apple.SettingsStorage",
            "x-apple.systempreferences:com.apple.preference.general",
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
