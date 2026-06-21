import XCTest
@testable import WhoAteMySpace

final class TreemapLayoutTests: XCTestCase {

    /// 패딩/헤더 없는 설정으로, 평평한 트리의 depth-1 사각형이
    /// 전체 영역을 덮으며 겹치지 않고 용량에 비례하는지 검증.
    private func flatRoot(sizes: [Int64]) -> FileNode {
        let root = FileNode(url: URL(fileURLWithPath: "/root"), name: "root", isDirectory: true)
        for (i, s) in sizes.enumerated() {
            let child = FileNode(url: URL(fileURLWithPath: "/root/f\(i)"), name: "f\(i)", isDirectory: false, size: s)
            child.parent = root
            root.children.append(child)
            root.size += s
        }
        root.finalizeSorting()
        return root
    }

    private var bareConfig: TreemapLayout.Config {
        var c = TreemapLayout.Config()
        c.padding = 0
        c.headerHeight = 0
        c.minSide = 0
        return c
    }

    func testAreaSumMatchesBounds() {
        let sizes: [Int64] = [100, 50, 30, 20, 10, 5]
        let root = flatRoot(sizes: sizes)
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let rects = TreemapLayout.layout(root: root, in: bounds, config: bareConfig)

        let leaves = rects.filter { $0.depth == 1 }
        XCTAssertEqual(leaves.count, sizes.count, "모든 자식이 배치되어야 함")

        let totalArea = leaves.reduce(0.0) { $0 + Double($1.rect.width * $1.rect.height) }
        let boundsArea = Double(bounds.width * bounds.height)
        XCTAssertEqual(totalArea, boundsArea, accuracy: boundsArea * 0.01,
                       "자식 면적 합이 전체 면적과 거의 같아야 함")
    }

    func testProportionalToSize() {
        let sizes: [Int64] = [200, 100, 50]
        let root = flatRoot(sizes: sizes)
        let bounds = CGRect(x: 0, y: 0, width: 600, height: 400)
        let rects = TreemapLayout.layout(root: root, in: bounds, config: bareConfig)
            .filter { $0.depth == 1 }

        let boundsArea = Double(bounds.width * bounds.height)
        let totalSize = Double(sizes.reduce(0, +))
        for tr in rects {
            let area = Double(tr.rect.width * tr.rect.height)
            let expected = Double(tr.node.size) / totalSize * boundsArea
            XCTAssertEqual(area, expected, accuracy: expected * 0.02,
                           "면적이 용량에 비례해야 함 (\(tr.node.name))")
        }
    }

    func testNoOverlapAmongSiblings() {
        let sizes: [Int64] = [80, 60, 40, 25, 15, 10, 7, 3]
        let root = flatRoot(sizes: sizes)
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 350)
        let rects = TreemapLayout.layout(root: root, in: bounds, config: bareConfig)
            .filter { $0.depth == 1 }
            .map { $0.rect }

        for i in 0..<rects.count {
            for j in (i + 1)..<rects.count {
                let a = rects[i].insetBy(dx: 0.5, dy: 0.5) // 부동소수 경계 허용
                let b = rects[j].insetBy(dx: 0.5, dy: 0.5)
                XCTAssertFalse(a.intersects(b), "형제 사각형이 겹치면 안 됨 (\(i),\(j))")
            }
        }
    }

    func testRectsStayWithinBounds() {
        let root = flatRoot(sizes: [50, 30, 20, 10])
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        let rects = TreemapLayout.layout(root: root, in: bounds, config: bareConfig)
        for tr in rects {
            XCTAssertGreaterThanOrEqual(tr.rect.minX, bounds.minX - 0.5)
            XCTAssertGreaterThanOrEqual(tr.rect.minY, bounds.minY - 0.5)
            XCTAssertLessThanOrEqual(tr.rect.maxX, bounds.maxX + 0.5)
            XCTAssertLessThanOrEqual(tr.rect.maxY, bounds.maxY + 0.5)
        }
    }

    func testNestedLayoutProducesChildren() {
        // root > dirA(파일 2개) + fileB
        let root = FileNode(url: URL(fileURLWithPath: "/r"), name: "r", isDirectory: true)
        let dirA = FileNode(url: URL(fileURLWithPath: "/r/A"), name: "A", isDirectory: true)
        let a1 = FileNode(url: URL(fileURLWithPath: "/r/A/a1"), name: "a1", isDirectory: false, size: 60)
        let a2 = FileNode(url: URL(fileURLWithPath: "/r/A/a2"), name: "a2", isDirectory: false, size: 40)
        a1.parent = dirA; a2.parent = dirA
        dirA.children = [a1, a2]; dirA.size = 100; dirA.parent = root
        let b = FileNode(url: URL(fileURLWithPath: "/r/b"), name: "b", isDirectory: false, size: 100)
        b.parent = root
        root.children = [dirA, b]; root.size = 200
        root.finalizeSorting()

        let rects = TreemapLayout.layout(root: root, in: CGRect(x: 0, y: 0, width: 400, height: 400))
        XCTAssertTrue(rects.contains { $0.node === a1 }, "중첩된 자식 a1이 배치되어야 함")
        XCTAssertTrue(rects.contains { $0.node === a2 }, "중첩된 자식 a2가 배치되어야 함")
        XCTAssertTrue(rects.contains { $0.node === dirA && $0.depth == 1 })
    }

    func testByteFormatNonNegative() {
        XCTAssertEqual(ByteFormat.string(-10), ByteFormat.string(0))
        XCTAssertFalse(ByteFormat.string(1_500_000).isEmpty)
    }
}
