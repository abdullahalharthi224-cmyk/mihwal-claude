import OSLog

/// Logs every step of importing so a failure can never be silent.
/// Visible in Console.app (filter: subsystem com.abdullah.mihwal) and in Xcode test logs.
enum Log {
    static let importing = Logger(subsystem: "com.abdullah.mihwal", category: "import")
    static let tools = Logger(subsystem: "com.abdullah.mihwal", category: "tools")
}
