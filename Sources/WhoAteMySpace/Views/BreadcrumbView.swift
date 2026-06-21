import SwiftUI

/// 스캔 루트 → 현재 줌 위치까지의 경로. 세그먼트 클릭으로 해당 레벨로 이동.
struct BreadcrumbView: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        if let current = viewModel.currentRoot {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(current.ancestry.enumerated()), id: \.element.id) { index, node in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            viewModel.navigate(to: node)
                        } label: {
                            Text(node.name)
                                .font(.callout)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(node === current ? Color.primary : Color.accentColor)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
        }
    }
}
