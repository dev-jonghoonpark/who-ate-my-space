import Foundation

/// 디렉토리 트리를 병렬로 재귀 스캔해 `FileNode` 트리를 만든다.
///
/// - 최상위 하위 디렉토리들을 `TaskGroup`으로 분산 스캔(병렬), 각 서브트리는 동기 재귀로 처리.
/// - 용량은 "디스크 할당 용량"(allocated size on disk)을 사용해 `du`와 유사하게 집계.
/// - 심볼릭 링크는 따라가지 않는다(루프/중복 집계 방지).
/// - 취소는 호출한 `Task`의 취소 상태(`Task.isCancelled`)를 따른다.
struct DiskScanner {

    /// 진행률 집계용 스레드 안전 카운터.
    final class Stats: @unchecked Sendable {
        private let lock = NSLock()
        private var files = 0
        private var bytes: Int64 = 0

        func add(files f: Int, bytes b: Int64) {
            lock.lock()
            files += f
            bytes += b
            lock.unlock()
        }

        var snapshot: (files: Int, bytes: Int64) {
            lock.lock(); defer { lock.unlock() }
            return (files, bytes)
        }
    }

    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
        .nameKey,
    ]

    /// 루트 URL을 스캔한다. `onProgress`는 약 0.1초마다 백그라운드에서 호출되므로
    /// 호출 측에서 메인 스레드로 전환해야 한다. 취소되면 부분 트리를 반환한다.
    func scan(
        rootURL: URL,
        onProgress: @escaping @Sendable (_ files: Int, _ bytes: Int64) -> Void
    ) async -> FileNode {
        let stats = Stats()

        // 주기적 진행률 보고 루프.
        let progressTask = Task {
            while !Task.isCancelled {
                let s = stats.snapshot
                onProgress(s.files, s.bytes)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        defer {
            progressTask.cancel()
            let s = stats.snapshot
            onProgress(s.files, s.bytes) // 최종값 1회 보고
        }

        let rv = try? rootURL.resourceValues(forKeys: Self.resourceKeys)
        let isDir = (rv?.isDirectory ?? true) && !(rv?.isSymbolicLink ?? false)
        let root = FileNode(
            url: rootURL,
            name: rootURL.lastPathComponent.isEmpty ? rootURL.path : rootURL.lastPathComponent,
            isDirectory: isDir
        )

        guard isDir else {
            let size = Self.allocatedSize(rv)
            root.size = size
            stats.add(files: 1, bytes: size)
            return root
        }

        root.size = Self.allocatedSize(rv) // 디렉토리 자체 블록

        let entries = (try? FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: Array(Self.resourceKeys),
            options: []
        )) ?? []
        if entries.isEmpty, (try? FileManager.default.contentsOfDirectory(atPath: rootURL.path)) == nil {
            root.hadAccessError = true
        }

        // 최상위 항목: 디렉토리는 병렬, 파일은 인라인 처리.
        await withTaskGroup(of: FileNode?.self) { group in
            for entry in entries {
                let erv = try? entry.resourceValues(forKeys: Self.resourceKeys)
                let entryIsLink = erv?.isSymbolicLink ?? false
                let entryIsDir = (erv?.isDirectory ?? false) && !entryIsLink

                if entryIsDir {
                    let ownSize = Self.allocatedSize(erv)
                    group.addTask { Self.walk(entry, ownSize: ownSize, stats: stats) }
                } else {
                    let size = Self.allocatedSize(erv)
                    stats.add(files: 1, bytes: size)
                    let child = FileNode(url: entry, name: entry.lastPathComponent, isDirectory: false, size: size)
                    child.parent = root
                    root.children.append(child)
                    root.size += size
                }
            }
            for await child in group {
                guard let child else { continue }
                child.parent = root
                root.children.append(child)
                root.size += child.size
            }
        }

        root.finalizeSorting()
        return root
    }

    /// 디렉토리 한 그루를 동기 재귀로 스캔. 호출 측 Task의 취소를 존중한다.
    private static func walk(_ url: URL, ownSize: Int64, stats: Stats) -> FileNode {
        let node = FileNode(url: url, name: url.lastPathComponent, isDirectory: true)
        node.size = ownSize

        if Task.isCancelled { return node }

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: []
        ) else {
            node.hadAccessError = true
            return node
        }

        for entry in entries {
            if Task.isCancelled { break }
            let erv = try? entry.resourceValues(forKeys: resourceKeys)
            let isLink = erv?.isSymbolicLink ?? false
            let isDir = (erv?.isDirectory ?? false) && !isLink

            let child: FileNode
            if isDir {
                child = walk(entry, ownSize: allocatedSize(erv), stats: stats)
            } else {
                let size = allocatedSize(erv)
                stats.add(files: 1, bytes: size)
                child = FileNode(url: entry, name: entry.lastPathComponent, isDirectory: false, size: size)
            }
            child.parent = node
            node.children.append(child)
            node.size += child.size
        }
        return node
    }

    private static func allocatedSize(_ rv: URLResourceValues?) -> Int64 {
        guard let rv else { return 0 }
        if let total = rv.totalFileAllocatedSize { return Int64(total) }
        if let file = rv.fileAllocatedSize { return Int64(file) }
        return 0
    }
}
