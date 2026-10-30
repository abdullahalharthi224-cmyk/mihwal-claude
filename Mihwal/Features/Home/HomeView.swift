import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var query = ""

    var body: some View {
        @Bindable var appState = appState

        NavigationStack(path: $appState.path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.l) {
                    if query.isEmpty {
                        browseContent
                    } else {
                        searchContent
                    }
                }
                .padding(.horizontal, DS.Spacing.m)
                .padding(.bottom, DS.Spacing.l)
                .animation(DS.Motion.standard, value: appState.favorites)
            }
            .contentMargins(.bottom, DS.Size.floatingBarClearance, for: .scrollContent)
            .background(DS.Palette.background)
            .navigationTitle("Mihwal")
            .searchable(text: $query, prompt: Text("Search tools"))
            .navigationDestination(for: ToolRoute.self) { route in
                ToolDestinationView(route: route)
            }
        }
        .sensoryFeedback(.selection, trigger: appState.favorites)
        .sheet(item: $appState.incoming) { incoming in
            IncomingFilesSheet(incoming: incoming) { toolID in
                appState.open(toolID, with: incoming.files)
            }
        }
        .alert(Text("Can't open this file"), isPresented: incomingErrorBinding, presenting: appState.incomingError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
    }

    private var incomingErrorBinding: Binding<Bool> {
        Binding(
            get: { appState.incomingError != nil },
            set: { if !$0 { appState.incomingError = nil } }
        )
    }

    // MARK: Sections

    @ViewBuilder
    private var browseContent: some View {
        OfflineBadge()

        if !favoriteTools.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                SectionHeader("Favorites", symbol: "star")
                grid(favoriteTools)
            }
        }

        if !recentTools.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                SectionHeader("Recent", symbol: "clock") {
                    Button("Clear") {
                        withAnimation(DS.Motion.standard) { appState.clearRecents() }
                    }
                    .font(.subheadline)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(recentTools) { tool in
                            NavigationLink(value: ToolRoute(tool: tool.id)) {
                                RecentChip(tool: tool)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }

        ForEach(ToolCategory.allCases) { category in
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                SectionHeader(category.title, symbol: category.symbol)
                grid(ToolRegistry.tools(in: category))
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        let results = ToolRegistry.search(query)
        if results.isEmpty {
            ContentUnavailableView.search(text: query)
                .padding(.top, DS.Spacing.xl)
        } else {
            grid(results)
        }
    }

    private func grid(_ tools: [ToolDescriptor]) -> some View {
        LazyVGrid(columns: columns, spacing: DS.Spacing.s) {
            ForEach(tools) { tool in
                NavigationLink(value: ToolRoute(tool: tool.id)) {
                    ToolCard(tool: tool, isFavorite: appState.isFavorite(tool.id), isCompact: !isSingleColumn)
                }
                .buttonStyle(PressableStyle())
                .contextMenu { favoriteButton(for: tool.id) }
                .accessibilityAction(named: appState.isFavorite(tool.id)
                                     ? Text("Remove from Favorites")
                                     : Text("Add to Favorites")) {
                    appState.toggleFavorite(tool.id)
                }
            }
        }
    }

    @ViewBuilder
    private func favoriteButton(for id: ToolID) -> some View {
        Button {
            withAnimation(DS.Motion.standard) { appState.toggleFavorite(id) }
        } label: {
            if appState.isFavorite(id) {
                Label("Remove from Favorites", systemImage: "star.slash")
            } else {
                Label("Add to Favorites", systemImage: "star")
            }
        }
    }

    // MARK: Data

    /// The "Larger Accessibility Sizes" text sizes get one column so nothing is cut off.
    private var isSingleColumn: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    /// Always exactly two columns otherwise, on every iPhone width.
    private var columns: [GridItem] {
        let column = GridItem(.flexible(), spacing: DS.Spacing.s, alignment: .top)
        return isSingleColumn ? [column] : [column, column]
    }

    private var favoriteTools: [ToolDescriptor] {
        appState.favorites.compactMap(ToolRegistry.descriptor(for:))
    }

    private var recentTools: [ToolDescriptor] {
        appState.recents.compactMap(ToolRegistry.descriptor(for:))
    }
}
