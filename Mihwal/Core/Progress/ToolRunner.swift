import Foundation
import Observation

/// Runs any FileTool off the main thread and exposes one state machine that every
/// tool screen shares: idle → processing → success / failure.
@MainActor
@Observable
final class ToolRunner {
    enum Phase {
        case idle
        case processing
        case success(ToolOutput)
        case failure(ToolError)
    }

    private(set) var phase: Phase = .idle
    private(set) var progress: Double = 0
    /// Counters that change on every result, used as haptic triggers.
    private(set) var successCount = 0
    private(set) var failureCount = 0

    private var workTask: Task<ToolOutput, Error>?
    private var currentRun: UUID?

    var isProcessing: Bool {
        if case .processing = phase { return true }
        return false
    }

    var output: ToolOutput? {
        if case .success(let output) = phase { return output }
        return nil
    }

    var error: ToolError? {
        if case .failure(let error) = phase { return error }
        return nil
    }

    /// `requiresFiles: false` is for tools whose input is in the options (Text to PDF).
    func run<Tool: FileTool>(_ tool: Tool, input: ToolInput, options: Tool.Options, requiresFiles: Bool = true) {
        cancel()
        reset()
        guard !input.files.isEmpty || !requiresFiles else {
            fail(.noInput)
            return
        }
        let runID = UUID()
        currentRun = runID
        phase = .processing
        let inputWasProtected = input.files.contains { $0.isEncrypted }

        let reporter: @Sendable (Double) -> Void = { [weak self] value in
            Task { @MainActor in
                self?.report(value, for: runID)
            }
        }
        let work = Task.detached(priority: .userInitiated) {
            try await tool.run(input: input, options: options, progress: reporter)
        }
        workTask = work

        Task { [weak self] in
            do {
                var output = try await work.value
                output.removedProtection = output.removedProtection || inputWasProtected
                self?.finish(output, for: runID)
            } catch is CancellationError {
                // The user cancelled; cancel() already returned to idle.
            } catch {
                self?.fail(ToolError(error), for: runID)
            }
        }
    }

    func cancel() {
        workTask?.cancel()
        workTask = nil
        currentRun = nil
        if isProcessing {
            phase = .idle
            progress = 0
        }
    }

    /// Back to idle. Deletes the previous result's files (they were already shared or saved).
    func reset() {
        if let output {
            FileStore.remove(output.directory)
        }
        phase = .idle
        progress = 0
    }

    private func report(_ value: Double, for runID: UUID) {
        guard runID == currentRun else { return }
        // Updates can arrive out of order; progress only moves forward.
        progress = max(progress, min(1, max(0, value)))
    }

    private func finish(_ output: ToolOutput, for runID: UUID) {
        guard runID == currentRun else {
            // A result that arrived after Cancel: throw it away.
            FileStore.remove(output.directory)
            return
        }
        workTask = nil
        progress = 1
        phase = .success(output)
        successCount += 1
    }

    private func fail(_ error: ToolError, for runID: UUID? = nil) {
        if let runID, runID != currentRun { return }
        workTask = nil
        phase = .failure(error)
        failureCount += 1
    }
}
