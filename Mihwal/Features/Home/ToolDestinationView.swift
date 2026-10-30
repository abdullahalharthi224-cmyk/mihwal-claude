import SwiftUI

/// Shows a tool's own screen, or "Coming soon" for tools not built yet.
struct ToolDestinationView: View {
    let id: ToolID
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let tool = ToolRegistry.descriptor(for: id) {
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
                    withAnimation(DS.Motion.standard) { appState.toggleFavorite(id) }
                } label: {
                    Image(systemName: appState.isFavorite(id) ? "star.fill" : "star")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(appState.isFavorite(id)
                                    ? Text("Remove from Favorites")
                                    : Text("Add to Favorites"))
            }
        }
        .onAppear { appState.recordUse(id) }
    }

    @ViewBuilder
    private func content(for tool: ToolDescriptor) -> some View {
        if let makeView = tool.makeView {
            makeView()
        } else {
            ContentUnavailableView {
                Label {
                    Text(tool.title)
                } icon: {
                    ToolIcon(symbol: tool.symbol, tint: tool.category.tint, baseSize: 64)
                }
            } description: {
                Text("Coming soon")
                    .font(.headline)
                Text("This tool arrives in a coming update.")
            }
            .background(DS.Palette.background)
        }
    }
}
