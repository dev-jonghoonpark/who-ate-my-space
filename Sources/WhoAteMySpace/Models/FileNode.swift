import Foundation

/// 파일/폴더 트리의 한 노드. 트리 구조 + 부모 역참조가 필요하므로 참조 타입(class).
/// 백그라운드 스레드에서 구축한 뒤 메인에서 읽기만 한다.
final class FileNode: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool

    /// 디스크에 실제로 할당된 용량(byte). SpaceSniffer의 "size on disk"와 동일.
    /// 디렉토리는 모든 자식의 합.
    var size: Int64

    /// 디렉토리의 직속 자식. 파일은 빈 배열. 용량 내림차순으로 정렬해 둔다.
    var children: [FileNode]

    /// 스캔 중 접근 거부/오류로 일부 항목을 건너뛴 디렉토리 표시.
    var hadAccessError: Bool = false

    weak var parent: FileNode?

    init(url: URL, name: String, isDirectory: Bool, size: Int64 = 0, children: [FileNode] = []) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.children = children
    }

    /// 스캔 루트부터 이 노드까지의 경로(브레드크럼용). 루트가 [0].
    var ancestry: [FileNode] {
        var chain: [FileNode] = []
        var node: FileNode? = self
        while let n = node {
            chain.append(n)
            node = n.parent
        }
        return chain.reversed()
    }

    /// 자식을 용량 내림차순으로 정렬하고 size(부모 합)를 확정한다. 트리 구축 후 1회 호출.
    func finalizeSorting() {
        children.sort { $0.size > $1.size }
        for child in children where child.isDirectory {
            child.finalizeSorting()
        }
    }

    /// 이 노드와 모든 조상의 size에서 delta를 뺀다(삭제 후 갱신용).
    func propagateSizeDelta(_ delta: Int64) {
        var node: FileNode? = self
        while let n = node {
            n.size = max(0, n.size - delta)
            node = n.parent
        }
    }

    /// 자식에서 특정 노드를 제거(휴지통 이동 후).
    func removeChild(_ child: FileNode) {
        children.removeAll { $0 === child }
    }
}
