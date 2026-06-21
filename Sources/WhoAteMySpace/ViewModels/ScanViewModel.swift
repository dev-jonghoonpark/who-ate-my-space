import SwiftUI
import AppKit

@MainActor
final class ScanViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case scanning
        case loaded
    }

    @Published var state: State = .idle

    /// 스캔의 최상위 노드.
    @Published private(set) var scanRoot: FileNode?
    /// 현재 트리맵에 보여주는(줌된) 루트.
    @Published var currentRoot: FileNode?
    /// 트리 변경(삭제 등) 시 증가 → 트리맵 레이아웃 강제 재계산용.
    @Published private(set) var layoutVersion: Int = 0

    @Published var progressFiles: Int = 0
    @Published var progressBytes: Int64 = 0
    @Published var errorMessage: String?

    @Published var volumeFreeBytes: Int64?
    @Published var volumeTotalBytes: Int64?

    private var scanTask: Task<Void, Never>?

    var canZoomOut: Bool {
        guard let current = currentRoot, let root = scanRoot else { return false }
        return current !== root
    }

    // MARK: - Scanning

    func chooseFolderAndScan() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Scan")
        panel.message = String(localized: "Choose a folder or volume to analyze.")
        if panel.runModal() == .OK, let url = panel.url {
            scan(url: url)
        }
    }

    func scan(url: URL) {
        scanTask?.cancel()
        state = .scanning
        progressFiles = 0
        progressBytes = 0
        errorMessage = nil
        scanRoot = nil
        currentRoot = nil
        loadVolumeInfo(for: url)

        let scanner = DiskScanner()
        scanTask = Task { [weak self] in
            guard let self else { return }
            let root = await scanner.scan(rootURL: url) { files, bytes in
                Task { @MainActor in
                    self.progressFiles = files
                    self.progressBytes = bytes
                }
            }
            guard !Task.isCancelled else {
                self.state = .idle
                return
            }
            self.scanRoot = root
            self.currentRoot = root
            self.state = .loaded
        }
    }

    func rescan() {
        guard let url = scanRoot?.url else { return }
        scan(url: url)
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        state = .idle
    }

    // MARK: - Navigation

    func zoom(into node: FileNode) {
        guard node.isDirectory, !node.children.isEmpty else { return }
        currentRoot = node
    }

    func navigate(to node: FileNode) {
        currentRoot = node
    }

    func zoomOut() {
        if let parent = currentRoot?.parent {
            currentRoot = parent
        }
    }

    // MARK: - File operations

    func trash(_ node: FileNode) {
        guard node !== scanRoot else {
            errorMessage = String(localized: "The scan root cannot be deleted.")
            return
        }
        guard FileActions.confirmTrash(node) else { return }
        do {
            try FileActions.moveToTrash(node.url)
            let parent = node.parent
            parent?.removeChild(node)
            parent?.propagateSizeDelta(node.size)
            if currentRoot === node {
                currentRoot = parent ?? scanRoot
            }
            layoutVersion &+= 1
        } catch {
            errorMessage = String(localized: "Couldn't move to Trash: \(error.localizedDescription)")
        }
    }

    // MARK: - Volume info

    private func loadVolumeInfo(for url: URL) {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let rv = try? url.resourceValues(forKeys: keys) else {
            volumeTotalBytes = nil
            volumeFreeBytes = nil
            return
        }
        volumeTotalBytes = rv.volumeTotalCapacity.map(Int64.init)
        if let important = rv.volumeAvailableCapacityForImportantUsage {
            volumeFreeBytes = important
        } else if let avail = rv.volumeAvailableCapacity {
            volumeFreeBytes = Int64(avail)
        } else {
            volumeFreeBytes = nil
        }
    }
}
