import SwiftUI

/// Asks for a PDF password in a sheet that stays open: a wrong password, or a file that
/// also needs its owner password, is answered inside the same sheet. (An alert had to be
/// closed and reopened for that, and iOS sometimes refused to reopen it.)
struct PasswordSheet: View {
    let fileID: UUID
    let fileName: String
    let submit: (String) -> FileListModel.UnlockOutcome
    let cancel: () -> Void

    @State private var needsOwnerPassword: Bool
    @State private var password = ""
    @State private var problem: String?
    @State private var attempts = 0
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(request: PasswordRequest, submit: @escaping (String) -> FileListModel.UnlockOutcome,
         cancel: @escaping () -> Void) {
        fileID = request.fileID
        fileName = request.fileName
        self.submit = submit
        self.cancel = cancel
        _needsOwnerPassword = State(initialValue: request.needsOwnerPassword)
        _problem = State(initialValue: request.wasWrong ? String(localized: "Wrong password. Try again.") : nil)
    }

    private var message: String {
        let error: ToolError = needsOwnerPassword
            ? .ownerPasswordRequired(fileID: fileID, fileName: fileName, afterAttempt: false)
            : .passwordRequired(fileID: fileID, fileName: fileName)
        return error.message
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.l) {
                    Image(systemName: needsOwnerPassword ? "key.fill" : "lock.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.tint)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)

                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .submitLabel(.go)
                            .focused($isFocused)
                            .onSubmit(trySubmit)
                            .padding(DS.Spacing.s)
                            .background(DS.Palette.card, in: RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                                    .strokeBorder(problem == nil ? Color.clear : Color.red, lineWidth: 1.5)
                            )
                            .modifier(ShakeEffect(travel: reduceMotion ? 0 : 8, animatableData: CGFloat(attempts)))

                        if let problem {
                            Label(problem, systemImage: "exclamationmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .transition(.opacity)
                        }
                    }

                    Button(action: trySubmit) {
                        Text("Unlock")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.xxs)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(password.isEmpty)
                }
                .padding(DS.Spacing.l)
            }
            .navigationTitle(needsOwnerPassword ? Text("Owner password needed") : Text("Password needed"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.error, trigger: attempts)
        .onAppear { isFocused = true }
        .task {
            // Sheets sometimes ignore focus set while they are still sliding in.
            try? await Task.sleep(for: .milliseconds(350))
            isFocused = true
        }
    }

    private func trySubmit() {
        guard !password.isEmpty else { return }
        switch submit(password) {
        case .unlocked:
            problem = nil
        case .wrongPassword:
            fail(String(localized: "Wrong password. Try again."))
        case .needsOwnerPassword:
            if needsOwnerPassword {
                fail(ToolError.ownerPasswordRequired(fileID: fileID, fileName: fileName, afterAttempt: true).message)
            } else {
                // The file opens now; changing it needs the owner password.
                withAnimation(DS.Motion.standard) {
                    needsOwnerPassword = true
                    problem = nil
                }
                password = ""
                isFocused = true
            }
        }
    }

    private func fail(_ text: String) {
        password = ""
        withAnimation(.linear(duration: 0.35)) {
            attempts += 1
            problem = text
        }
        isFocused = true
    }
}

/// Side-to-side shake, used for a wrong password.
private struct ShakeEffect: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 4), y: 0))
    }
}
