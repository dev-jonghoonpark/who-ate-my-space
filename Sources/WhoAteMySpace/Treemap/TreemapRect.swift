import CoreGraphics

/// 트리맵 레이아웃 결과의 한 항목. 화면에 그릴 사각형 + 대응 노드 + 깊이.
struct TreemapRect: Identifiable {
    let node: FileNode
    let rect: CGRect
    let depth: Int

    var id: FileNode.ID { node.id }
}
