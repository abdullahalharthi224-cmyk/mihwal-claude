import SwiftUI

/// Shows a tool's own screen, or the generic screen for tools that aren't built yet.
struct ToolDestinationView: View {
    let route: ToolRoute
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let tool = ToolRegistry.descriptor(for: route.tool) {
                content(for: tool)
                    .navigationTitle(Text(tool.title))
            } else {
                ContentUnavailableView("Coming soon", systemImage: "hammer")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(DS.Motion.standard) { appState.toggleFavorite(route.tool) }
                } label: {
                    Image(systemName: appState.isFavorite(route.tool) ? "star.fill" : "star")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(appState.isFavorite(route.tool)
                                    ? Text("Remove from Favorites")
                                    : Text("Add to Favorites"))
            }
        }
        .onAppear { appState.recordUse(route.tool) }
    }

    @ViewBuilder
    private func content(for tool: ToolDescriptor) -> some View {
        if let makeView = tool.makeView {
            makeView(route.files)
        } else {
            GenericToolView(tool: tool, initialFiles: route.files)
        }
    }
}

/// Until a tool is built, its screen already imports files (so Files, Photos and
/// "Open in" can be tested); only the action button is disabled.
private struct GenericToolView: View {
    let tool: ToolDescriptor
    @State private var files: FileListModel
    @State private var runner = ToolRunner()

    init(tool: ToolDescriptor, initialFiles: [ImportedFile]) {
        self.tool = tool
        _files = State(initialValue: FileListModel(accepts: tool.accepts,
                                                   allowsMultiple: tool.allowsMultipleFiles,
                                                   initial: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: tool, files: files, runner: runner,
                   actionTitle: "Coming soon", isReady: false,
                   footnote: "This tool arrives in a coming update.",
                   onRun: {}) {
            EmptyView()
        }
    }
}
