import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScanViewModel()
    @State private var hoveredNode: FileNode?

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                idleView
            case .scanning:
                ScanProgressView(viewModel: viewModel)
            case .loaded:
                loadedView
            }
        }
        .frame(minWidth: 820, minHeight: 580)
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 18) {
            Image(systemName: "internaldrive")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Who Ate My Space")
                .font(.largeTitle.bold())
            Text("Select a folder or volume to see its disk usage as a treemap.")
                .foregroundStyle(.secondary)

            Button {
                viewModel.chooseFolderAndScan()
            } label: {
                Label("Choose a folder to scan", systemImage: "folder")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .controlSize(.large)
            .keyboardShortcut("o")

            HStack(spacing: 10) {
                quickScanButton("Home", url: FileManager.default.homeDirectoryForCurrentUser)
                quickScanButton("Macintosh HD", url: URL(fileURLWithPath: "/"))
            }
            .padding(.top, 4)

            Button {
                FileActions.openStorageSettings()
            } label: {
                Label("Open System Settings → Storage", systemImage: "gearshape")
            }
            .buttonStyle(.link)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func quickScanButton(_ title: LocalizedStringKey, url: URL) -> some View {
        Button(title) { viewModel.scan(url: url) }
            .buttonStyle(.bordered)
    }

    // MARK: - Loaded

    private var loadedView: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            BreadcrumbView(viewModel: viewModel)
            Divider()
            TreemapView(viewModel: viewModel, hoveredNode: $hoveredNode)
            Divider()
            LegendView()
            Divider()
            statusBar
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.chooseFolderAndScan()
            } label: {
                Label("Choose folder", systemImage: "folder")
            }
            Button {
                viewModel.rescan()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            Button {
                viewModel.zoomOut()
            } label: {
                Label("Up one level", systemImage: "arrow.up.left")
            }
            .disabled(!viewModel.canZoomOut)

            Spacer()

            if let root = viewModel.scanRoot {
                Text("Total \(ByteFormat.string(root.size))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if let node = hoveredNode {
                Image(systemName: node.isDirectory ? "folder" : "doc")
                    .foregroundStyle(.secondary)
                Text(verbatim: node.url.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 12)
                Text(verbatim: ByteFormat.string(node.size))
                    .monospacedDigit()
                    .bold()
            } else {
                Text(volumeSummary)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private var volumeSummary: LocalizedStringKey {
        if let free = viewModel.volumeFreeBytes, let total = viewModel.volumeTotalBytes {
            return "Free \(ByteFormat.string(free)) · Capacity \(ByteFormat.string(total))"
        }
        if let free = viewModel.volumeFreeBytes {
            return "Free \(ByteFormat.string(free))"
        }
        if let total = viewModel.volumeTotalBytes {
            return "Capacity \(ByteFormat.string(total))"
        }
        return "Hover over an item to see details."
    }
}
