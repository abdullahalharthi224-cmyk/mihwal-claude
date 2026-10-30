import Foundation

/// A small ZIP writer (STORE method: files are packed, not compressed).
/// iOS has no public API to create ZIP files. We need one for "save many files as one"
/// and later for .docx (which is a ZIP of XML files). No ZIP64: each file and the
/// whole archive must stay under 4 GB.
enum ZipWriter {
    struct Entry {
        let path: String
        let data: Data
    }

    enum ZipError: Error {
        case tooLarge
    }

    /// Packs files by their names. Duplicate names get " 2", " 3"… so nothing is overwritten.
    static func write(files: [URL], to destination: URL) throws {
        var usedNames = Set<String>()
        let entries = try files.map { url -> Entry in
            let name = uniqueName(for: url, used: &usedNames)
            return Entry(path: name, data: try Data(contentsOf: url, options: .mappedIfSafe))
        }
        try write(entries: entries, to: destination)
    }

    static func write(entries: [Entry], to destination: URL) throws {
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw ToolError.writeFailed
        }
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }

        let stamp = dosDateTime(Date())
        var centralDirectory = Data()
        var offset: UInt64 = 0

        for entry in entries {
            try Task.checkCancellation()
            let name = Data(entry.path.utf8)
            guard entry.data.count < Int(UInt32.max), offset < UInt64(UInt32.max) else {
                throw ZipError.tooLarge
            }
            let crc = CRC32.checksum(entry.data)
            let size = UInt32(entry.data.count)

            var local = Data()
            local.appendLE(UInt32(0x0403_4B50)) // local file header signature
            local.appendLE(UInt16(20))          // version needed to extract
            local.appendLE(UInt16(0x0800))      // flags: names are UTF-8
            local.appendLE(UInt16(0))           // method: store
            local.appendLE(stamp.time)
            local.appendLE(stamp.date)
            local.appendLE(crc)
            local.appendLE(size)                // compressed size
            local.appendLE(size)                // uncompressed size
            local.appendLE(UInt16(name.count))
            local.appendLE(UInt16(0))           // extra field length
            local.append(name)
            try handle.write(contentsOf: local)
            try handle.write(contentsOf: entry.data)

            centralDirectory.appendLE(UInt32(0x0201_4B50)) // central directory signature
            centralDirectory.appendLE(UInt16(20))          // version made by
            centralDirectory.appendLE(UInt16(20))          // version needed
            centralDirectory.appendLE(UInt16(0x0800))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(stamp.time)
            centralDirectory.appendLE(stamp.date)
            centralDirectory.appendLE(crc)
            centralDirectory.appendLE(size)
            centralDirectory.appendLE(size)
            centralDirectory.appendLE(UInt16(name.count))
            centralDirectory.appendLE(UInt16(0))           // extra field length
            centralDirectory.appendLE(UInt16(0))           // comment length
            centralDirectory.appendLE(UInt16(0))           // disk number
            centralDirectory.appendLE(UInt16(0))           // internal attributes
            centralDirectory.appendLE(UInt32(0))           // external attributes
            centralDirectory.appendLE(UInt32(offset))      // where the local header starts
            centralDirectory.append(name)

            offset += UInt64(local.count) + UInt64(entry.data.count)
        }

        guard offset + UInt64(centralDirectory.count) < UInt64(UInt32.max), entries.count < Int(UInt16.max) else {
            throw ZipError.tooLarge
        }
        var end = Data()
        end.appendLE(UInt32(0x0605_4B50)) // end of central directory signature
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(entries.count))
        end.appendLE(UInt16(entries.count))
        end.appendLE(UInt32(centralDirectory.count))
        end.appendLE(UInt32(offset))
        end.appendLE(UInt16(0))           // comment length
        try handle.write(contentsOf: centralDirectory)
        try handle.write(contentsOf: end)
    }

    static func dosDateTime(_ date: Date) -> (time: UInt16, date: UInt16) {
        let parts = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        let year = max(1980, parts.year ?? 1980)
        let time = (parts.hour ?? 0) << 11 | (parts.minute ?? 0) << 5 | (parts.second ?? 0) / 2
        let day = (year - 1980) << 9 | (parts.month ?? 1) << 5 | (parts.day ?? 1)
        return (UInt16(truncatingIfNeeded: time), UInt16(truncatingIfNeeded: day))
    }

    private static func uniqueName(for url: URL, used: inout Set<String>) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var name = url.lastPathComponent
        var counter = 2
        while used.contains(name) {
            name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            counter += 1
        }
        used.insert(name)
        return name
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) != 0 ? (0xEDB8_8320 ^ (value >> 1)) : (value >> 1)
        }
        return value
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            for byte in buffer {
                crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
