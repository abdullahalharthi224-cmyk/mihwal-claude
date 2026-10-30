import SwiftUI

struct SplitPDFView: View {
    @State private var model: SplitPDFViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: SplitPDFViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.split), files: model.files, runner: model.runner,
                   actionTitle: "Split PDF", isReady: model.isReady,
                   footnote: model.isReady ? nil : "Choose where to split to make at least two files.",
                   layout: .scroll, onRun: { model.run() }) {
            if let file = model.file {
                if model.pageCount > 1 {
                    OptionCard {
                        Picker("Split mode", selection: $model.mode) {
                            Text("Custom").tag(SplitPDFViewModel.Mode.custom)
                            Text("Every N pages").tag(SplitPDFViewModel.Mode.everyN)
                            Text("Every page").tag(SplitPDFViewModel.Mode.everyPage)
                        }
                        .pickerStyle(.segmented)

                        switch model.mode {
                        case .custom:
                            Text("Tap a page to start a new file there.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        case .everyN:
                            Stepper(value: $model.pagesPerFile, in: 1...max(1, model.pageCount - 1)) {
                                Text("\(model.pagesPerFile) pages per file")
                            }
                        case .everyPage:
                            EmptyView()
                        }

                        Label {
                            Text("\(model.groups.count) files will be created")
                                .contentTransition(.numericText())
                        } icon: {
                            Image(systemName: "doc.on.doc")
                        }
                        .font(.subheadline.weight(.semibold))
                    }

                    PageGrid(file: file, password: model.password, pageCount: model.pageCount,
                             isSelected: { model.mode == .custom && model.startsGroup($0) && $0 > 0 },
                             onTap: { model.toggleStart(at: $0) }) { page in
                        PartBadge(number: model.groupNumber(of: page), isStart: model.startsGroup(page))
                    }
                } else if model.pageCount == 1 {
                    OptionCard {
                        Text("This PDF has only one page, so it can't be split.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if file.isLocked {
                    LockedPagesView()
                }
            }
        }
        .sensoryFeedback(.selection, trigger: model.groups.count)
        .onChange(of: model.file?.id) { _, _ in model.resetForNewFile() }
    }
}

/// Small colored badge: which output file a page goes into. The first page of each
/// file shows scissors, so the cut points are easy to see.
private struct PartBadge: View {
    let number: Int
    let isStart: Bool

    private static let colors: [Color] = [.blue, .orange, .green, .purple, .pink, .teal, .indigo, .brown]

    var body: some View {
        HStack(spacing: 2) {
            if isStart {
                Image(systemName: "scissors")
            }
            Text(number, format: .number)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Self.colors[(number - 1) % Self.colors.count], in: Capsule())
        .padding(DS.Spacing.xxs)
        .accessibilityHidden(true)
    }
}
