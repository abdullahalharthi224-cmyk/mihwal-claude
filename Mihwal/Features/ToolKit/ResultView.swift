import QuickLook
import SwiftUI

/// Success screen: what was made, before/after size, and every way to get the result out:
/// Quick Look, Share, Save to Files, Save to Photos (images), Save as ZIP (many files).
struct ResultView: View {
    let output: ToolOutput
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var previewURL: URL?
    @State private var exporter = FileExportCoordinator()
    @State private var savedToFiles = false
    @State private var isSavingPhotos = false
    @State private var savedToPhotos = false
    @State private var saveError: ToolError?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: DS.Spacing.s) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                            .symbolEffect(.bounce, value: output.id)
                            .accessibilityHidden(true)
                        Text("Done!")
                            .font(.title2.weight(.bold))
                        Text("Your files stayed on this iPhone.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.s)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("result.success")
                }

                if output.removedProtection {
                    Section {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("This copy is not protected")
                                    .font(.headline)
                                Text("The original PDF had a password or restrictions. Anyone who gets this file can open, copy and change it.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundStyle(.orange)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                if let inputBytes = output.inputBytes {
                    Section {
                        SizeComparisonView(before: inputBytes, after: output.outputBytes)
                    }
                }

                Section {
                    ForEach(output.files, id: \.self) { url in
                        Button {
                            previewURL = url
                        } label: {
                            OutputFileRow(url: url)
                        }
                        .accessibilityHint(Text("Shows a preview"))
                    }
                } header: {
                    Text(output.files.count > 1 ? LocalizedStringKey("Files") : LocalizedStringKey("File"))
                }

                if !output.notes.isEmpty {
                    Section {
                        ForEach(output.notes, id: \.self) { note in
                            Label(note, systemImage: "info.circle")
                                .font(.footnote)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actions
            }
            .navigationTitle(Text("Result"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { close() }
                }
            }
            .quickLookPreview($previewURL, in: output.files)
            .alert(Text(saveError?.title ?? ""), isPresented: saveErrorBinding, presenting: saveError) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
            .sensoryFeedback(.success, trigger: savedToPhotos)
            .sensoryFeedback(.success, trigger: savedToFiles)
        }
    }

    private var actions: some View {
        VStack(spacing: DS.Spacing.s) {
            ShareLink(items: output.files) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xxs)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: DS.Spacing.s) {
                Button {
                    export(output.files)
                } label: {
                    Label(savedToFiles ? LocalizedStringKey("Saved") : LocalizedStringKey("Save to Files"),
                          systemImage: savedToFiles ? "checkmark" : "folder")
                        .frame(maxWidth: .infinity)
                }

                if output.isAllImages {
                    Button {
                        saveToPhotos()
                    } label: {
                        Label(savedToPhotos ? LocalizedStringKey("Saved") : LocalizedStringKey("Save to Photos"),
                              systemImage: savedToPhotos ? "checkmark" : "photo.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isSavingPhotos || savedToPhotos)
                } else if output.files.count > 1 {
                    Button {
                        exportAsZip()
                    } label: {
                        Label("Save as ZIP", systemImage: "doc.zipper")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .background(.bar)
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    private func close() {
        onDone()
        dismiss()
    }

    private func export(_ urls: [URL]) {
        exporter.export(urls) { outcome in
            switch outcome {
            case .saved:
                savedToFiles = true
            case .cancelled:
                break
            case .failed(let error):
                saveError = error
            }
        }
    }

    private func exportAsZip() {
        let files = output.files
        let zipURL = FileStore.outputURL(in: output.directory, baseName: String(localized: "Mihwal files"),
                                         suffix: nil, pathExtension: "zip")
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try ZipWriter.write(files: files, to: zipURL)
                }.value
                export([zipURL])
            } catch {
                saveError = ToolError(error)
            }
        }
    }

    private func saveToPhotos() {
        isSavingPhotos = true
        Task {
            do {
                try await PhotoSaver.save(output.files)
                savedToPhotos = true
            } catch {
                saveError = ToolError(error)
            }
            isSavingPhotos = false
        }
    }
}

private struct OutputFileRow: View {
    let url: URL

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            let isPDF = FileStore.contentType(of: url).conforms(to: .pdf)
            ThumbnailView(source: isPDF ? .pdfPage(url, index: 0) : .image(url), maxPixelSize: 160)
                .frame(width: DS.Size.rowThumbnail, height: DS.Size.rowThumbnail * 1.3)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: DS.Spacing.xxs) {
                    Text(FileStore.byteCount(of: url).formatted(.byteCount(style: .file)))
                    if !isPDF, let size = ImageReader.pixelSize(at: url) {
                        Text(verbatim: "·")
                        Text(verbatim: "\(size.width) × \(size.height)")
                            .monospacedDigit()
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "eye")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
    }
}

/// "12.4 MB → 3.1 MB  −75%"
struct SizeComparisonView: View {
    let before: Int64
    let after: Int64

    private var change: Double {
        guard before > 0 else { return 0 }
        return Double(after - before) / Double(before)
    }

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            sizeColumn(title: "Before", bytes: before)
            Image(systemName: "arrow.forward")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            sizeColumn(title: "After", bytes: after)
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Text(verbatim: change < 0 ? "−" : "+")
                Text(abs(change), format: .percent.precision(.fractionLength(0)))
            }
            .font(.title3.weight(.bold).monospacedDigit())
            .foregroundStyle(change < 0 ? Color.green : Color.orange)
        }
        .accessibilityElement(children: .combine)
    }

    private func sizeColumn(title: LocalizedStringResource, bytes: Int64) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(bytes.formatted(.byteCount(style: .file)))
                .font(.headline.monospacedDigit())
        }
    }
}
