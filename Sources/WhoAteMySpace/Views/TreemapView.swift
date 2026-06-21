import SwiftUI

/// 트리맵을 SwiftUI Canvas로 렌더링하고 hover/click/우클릭 인터랙션을 처리한다.
struct TreemapView: View {
    @ObservedObject var viewModel: ScanViewModel
    @Binding var hoveredNode: FileNode?

    @State private var rects: [TreemapRect] = []
    @State private var lastSize: CGSize = .zero

    private let config = TreemapLayout.Config()

    var body: some View {
        GeometryReader { geo in
            Canvas(rendersAsynchronously: true) { context, _ in
                draw(context: context)
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hoveredNode = node(at: point)
                case .ended:
                    hoveredNode = nil
                }
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in handleTap(at: value.location) }
            )
            .contextMenu { contextMenuItems() }
            .background(Color(white: 0.11))
            .onChange(of: geo.size) { newValue in
                recompute(size: newValue)
            }
            .onChange(of: viewModel.currentRoot?.id) { _ in
                recompute(size: geo.size)
            }
            .onChange(of: viewModel.layoutVersion) { _ in
                recompute(size: geo.size)
            }
            .onAppear { recompute(size: geo.size) }
        }
    }

    // MARK: - Layout

    private func recompute(size: CGSize) {
        lastSize = size
        guard let root = viewModel.currentRoot, size.width > 1, size.height > 1 else {
            rects = []
            return
        }
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
        rects = TreemapLayout.layout(root: root, in: rect, config: config)
    }

    /// 포인트 아래에서 가장 깊은(=가장 구체적인) 노드를 찾는다.
    private func node(at point: CGPoint) -> FileNode? {
        for tr in rects.reversed() where tr.rect.contains(point) {
            return tr.node
        }
        return nil
    }

    // MARK: - Interaction

    private func handleTap(at point: CGPoint) {
        guard let node = node(at: point) else { return }
        if node.isDirectory, !node.children.isEmpty {
            viewModel.zoom(into: node)
        }
    }

    @ViewBuilder
    private func contextMenuItems() -> some View {
        if let node = hoveredNode {
            Text(verbatim: node.name)
            Divider()
            Button("Reveal in Finder") { FileActions.revealInFinder(node.url) }
            Button("Open") { FileActions.open(node.url) }
            if node.isDirectory, !node.children.isEmpty {
                Button("Zoom in here") { viewModel.zoom(into: node) }
            }
            Button("Copy path") { FileActions.copyPath(node.url) }
            Divider()
            Button("Move to Trash…", role: .destructive) { viewModel.trash(node) }
        } else {
            Text("Right-click an item.")
        }
    }

    // MARK: - Drawing

    private func draw(context: GraphicsContext) {
        for tr in rects {
            let path = Path(tr.rect)
            let category = FileCategory.category(for: tr.node)
            let baseColor = category.color

            if tr.node.isDirectory {
                // 폴더: 옅게 채워 자식이 위에 비치게 함 + 헤더 띠
                context.fill(path, with: .color(baseColor.opacity(0.18)))
                drawFolderHeader(context: context, tr: tr, color: baseColor)
            } else {
                context.fill(path, with: .color(baseColor.opacity(0.92)))
                drawLeafLabel(context: context, tr: tr)
            }
            context.stroke(path, with: .color(.black.opacity(0.4)), lineWidth: 0.5)
        }

        // hover 하이라이트
        if let node = hoveredNode, let tr = rects.last(where: { $0.node === node }) {
            context.stroke(Path(tr.rect.insetBy(dx: 0.5, dy: 0.5)),
                           with: .color(.white), lineWidth: 1.5)
        }
    }

    private func drawFolderHeader(context: GraphicsContext, tr: TreemapRect, color: Color) {
        let rect = tr.rect
        guard rect.width > 28, rect.height > config.headerHeight else { return }
        let headerRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: config.headerHeight)
        context.fill(Path(headerRect), with: .color(color.opacity(0.55)))

        var clip = context
        clip.clip(to: Path(headerRect.insetBy(dx: 3, dy: 0)))
        let label = Text(verbatim: "\(tr.node.name)  ·  \(ByteFormat.string(tr.node.size))")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white)
        clip.draw(label, at: CGPoint(x: rect.minX + 4, y: rect.minY + config.headerHeight / 2), anchor: .leading)
    }

    private func drawLeafLabel(context: GraphicsContext, tr: TreemapRect) {
        let rect = tr.rect
        guard rect.width > 46, rect.height > 24 else { return }
        var clip = context
        clip.clip(to: Path(rect.insetBy(dx: 3, dy: 2)))
        let name = Text(verbatim: tr.node.name)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white)
        let size = Text(verbatim: ByteFormat.string(tr.node.size))
            .font(.system(size: 8))
            .foregroundColor(.white.opacity(0.85))
        clip.draw(name, at: CGPoint(x: rect.midX, y: rect.midY - 5), anchor: .center)
        clip.draw(size, at: CGPoint(x: rect.midX, y: rect.midY + 6), anchor: .center)
    }
}
