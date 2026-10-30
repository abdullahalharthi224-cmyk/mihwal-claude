import Foundation

enum StorageGuard {
    /// Extra room kept free so iOS itself never runs out of space.
    static let safetyMargin: Int64 = 50 * 1024 * 1024

    /// Throws `.notEnoughStorage` when the device can't fit `bytes` more.
    static func ensureSpace(for bytes: Int64) throws {
        let values = try? FileManager.default.temporaryDirectory
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let available = values?.volumeAvailableCapacityForImportantUsage else { return }
        if available < bytes + safetyMargin {
            throw ToolError.notEnoughStorage
        }
    }
}
