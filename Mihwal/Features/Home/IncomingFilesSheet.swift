import SwiftUI

/// Shown when a file is shared into Mihwal: "What do you want to do with it?"
/// Only tools that accept the file's type are listed.
struct IncomingFilesSheet: View {
    let incoming: IncomingFiles
    let onPick: (ToolID) -> Void

    @Environment(\.dismiss) private var dismiss

    private var tools: [ToolDescriptor] {
        guard let first = incoming.files.first else { return [] }
        return ToolRegistry.tools(accepting: first.contentType)
    }

    var body: some View {
        NavigationStack {
            Group {
                if tools.isEmpty {
                    ContentUnavailableView {
                        Label("Unsupported file", systemImage: "doc.questionmark")
                    } description: {
                        Text("Mihwal works with PDFs, images and text files.")
                    }
                } else {
                    List {
                        Section {
                            ForEach(incoming.files) { file in
                                FileRow(file: file, password: nil, onUnlock: {})
                            }
                        }
                        Section {
                            ForEach(tools) { tool in
                                Button {
                                    onPick(tool.id)
                                } label: {
                                    HStack(spacing: DS.Spacing.s) {
                                        ToolIcon(symbol: tool.symbol, tint: tool.category.tint, baseSize: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tool.title)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(.primary)
                                            Text(tool.subtitle)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text("Choose a tool")
                        }
                    }
                }
            }
            .navigationTitle(Text("Open in Mihwal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
