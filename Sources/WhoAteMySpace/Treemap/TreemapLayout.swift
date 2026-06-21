import CoreGraphics

/// Squarified treemap 레이아웃 (Bruls, Huizing, van Wijk).
/// 노드를 용량에 비례하는, 종횡비가 1에 가까운 사각형들로 중첩 배치한다.
enum TreemapLayout {

    struct Config {
        /// 폴더 내부에 자식을 그릴 때의 패딩(테두리 두께 느낌).
        var padding: CGFloat = 2
        /// 폴더 라벨을 위한 상단 헤더 높이(0이면 헤더 없음, 라벨은 오버레이로 처리).
        var headerHeight: CGFloat = 14
        /// 이보다 짧은 변을 가진 사각형은 더 이상 자식을 그리지 않는다.
        var minSide: CGFloat = 4
        /// 최대 재귀 깊이.
        var maxDepth: Int = 32
    }

    /// 루트 노드를 주어진 사각형에 배치하고, 그릴 모든 사각형을 (얕은 깊이 → 깊은 깊이 순서로) 반환한다.
    static func layout(root: FileNode, in rect: CGRect, config: Config = Config()) -> [TreemapRect] {
        var result: [TreemapRect] = []
        guard rect.width > 0, rect.height > 0 else { return result }
        layoutNode(root, rect: rect, depth: 0, config: config, into: &result)
        return result
    }

    private static func layoutNode(
        _ node: FileNode,
        rect: CGRect,
        depth: Int,
        config: Config,
        into result: inout [TreemapRect]
    ) {
        result.append(TreemapRect(node: node, rect: rect, depth: depth))

        guard node.isDirectory, !node.children.isEmpty, depth < config.maxDepth else { return }

        var inner = rect.insetBy(dx: config.padding, dy: config.padding)
        // 라벨 헤더 영역 확보 (공간이 충분할 때만).
        if config.headerHeight > 0, inner.height > config.headerHeight + config.minSide {
            inner.origin.y += config.headerHeight
            inner.size.height -= config.headerHeight
        }
        guard inner.width > config.minSide, inner.height > config.minSide else { return }

        let children = node.children.filter { $0.size > 0 }
        let totalSize = children.reduce(Int64(0)) { $0 + $1.size }
        guard !children.isEmpty, totalSize > 0 else { return }

        let totalArea = Double(inner.width) * Double(inner.height)
        let areaPerByte = totalArea / Double(totalSize)
        let items = children.map { (node: $0, area: Double($0.size) * areaPerByte) }

        let placed = squarify(items: items, in: inner)
        for (child, childRect) in placed {
            guard childRect.width >= config.minSide, childRect.height >= config.minSide else { continue }
            layoutNode(child, rect: childRect, depth: depth + 1, config: config, into: &result)
        }
    }

    // MARK: - Squarify core

    private typealias Item = (node: FileNode, area: Double)

    /// 입력 items는 용량(=area) 내림차순으로 정렬되어 있다고 가정.
    private static func squarify(items: [Item], in rect: CGRect) -> [(FileNode, CGRect)] {
        var result: [(FileNode, CGRect)] = []
        var remaining = rect
        var row: [Item] = []
        var index = 0

        func shorterSide() -> Double { Double(min(remaining.width, remaining.height)) }

        while index < items.count {
            let candidate = items[index]
            let w = shorterSide()
            if row.isEmpty || worst(row, adding: candidate.area, side: w) <= worst(row, adding: nil, side: w) {
                row.append(candidate)
                index += 1
            } else {
                placeRow(row, in: &remaining, into: &result)
                row.removeAll(keepingCapacity: true)
            }
        }
        if !row.isEmpty {
            placeRow(row, in: &remaining, into: &result)
        }
        return result
    }

    /// 행에 area를 추가했을 때의 최악(가장 큰) 종횡비.
    private static func worst(_ row: [Item], adding: Double?, side w: Double) -> Double {
        guard w > 0 else { return .infinity }
        var areas = row.map { $0.area }
        if let adding { areas.append(adding) }
        guard let maxA = areas.max(), let minA = areas.min(), minA > 0 else { return .infinity }
        let sum = areas.reduce(0, +)
        guard sum > 0 else { return .infinity }
        let w2 = w * w
        let s2 = sum * sum
        return max(w2 * maxA / s2, s2 / (w2 * minA))
    }

    /// 한 행을 remaining의 짧은 변에 수직인 스트립으로 배치하고 remaining을 줄인다.
    private static func placeRow(_ row: [Item], in remaining: inout CGRect, into result: inout [(FileNode, CGRect)]) {
        let rowArea = row.reduce(0.0) { $0 + $1.area }
        guard rowArea > 0 else { return }

        if remaining.width >= remaining.height {
            // 왼쪽에 세로 스트립. 높이를 따라 항목을 쌓는다.
            let stripWidth = min(remaining.width, CGFloat(rowArea / Double(remaining.height)))
            var y = remaining.minY
            for item in row {
                let h = CGFloat(item.area / rowArea) * remaining.height
                result.append((item.node, CGRect(x: remaining.minX, y: y, width: stripWidth, height: h)))
                y += h
            }
            remaining.origin.x += stripWidth
            remaining.size.width -= stripWidth
        } else {
            // 위쪽에 가로 스트립. 너비를 따라 항목을 늘어놓는다.
            let stripHeight = min(remaining.height, CGFloat(rowArea / Double(remaining.width)))
            var x = remaining.minX
            for item in row {
                let w = CGFloat(item.area / rowArea) * remaining.width
                result.append((item.node, CGRect(x: x, y: remaining.minY, width: w, height: stripHeight)))
                x += w
            }
            remaining.origin.y += stripHeight
            remaining.size.height -= stripHeight
        }
    }
}
