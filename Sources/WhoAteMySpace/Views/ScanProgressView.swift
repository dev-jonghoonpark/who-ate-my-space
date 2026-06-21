import SwiftUI

/// 스캔 진행 화면 (진행률 + 취소).
struct ScanProgressView: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Scanning…")
                .font(.headline)
            Text("\(viewModel.progressFiles) files · \(ByteFormat.string(viewModel.progressBytes))")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Button("Cancel") {
                viewModel.cancelScan()
            }
            .keyboardShortcut(.cancelAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
