import Foundation
import PDFKit

/// Every PDF writer (PDFKit included) adds its own document information while saving:
/// "Producer: iOS … Quartz PDFContext" and fresh dates. To leave no metadata at all, the
/// strings of the information dictionary are blanked in place after saving. Each byte is
/// replaced by a space, so nothing moves and the file's offset table stays valid.
enum PDFInfoScrubber {
    /// Returns true when the dictionary was found and blanked. If the result wouldn't
    /// open exactly like before, the original bytes are put back.
    @discardableResult
    static func scrub(_ url: URL) throws -> Bool {
        let original = try Data(contentsOf: url)
        var bytes = [UInt8](original)
        guard let reference = infoReference(in: bytes),
              let range = objectRange(number: reference.0, generation: reference.1, in: bytes) else {
            return false
        }
        blankStrings(in: &bytes, range: range)
        let scrubbed = Data(bytes)
        guard scrubbed != original else { return false }

        let pageCountBefore = PDFDocument(data: original)?.pageCount
        guard let check = PDFDocument(data: scrubbed), check.pageCount == pageCountBefore else {
            return false
        }
        try scrubbed.write(to: url, options: .atomic)
        return true
    }

    // MARK: Finding the dictionary

    /// "/Info 12 0 R" in the last trailer (or cross-reference stream dictionary).
    static func infoReference(in bytes: [UInt8]) -> (Int, Int)? {
        guard let start = lastIndex(of: Array("/Info".utf8), in: bytes) else { return nil }
        var index = start + 5
        guard let number = readInteger(bytes, &index), let generation = readInteger(bytes, &index) else { return nil }
        skipSpaces(bytes, &index)
        guard index < bytes.count, bytes[index] == UInt8(ascii: "R") else { return nil }
        return (number, generation)
    }

    /// The bytes between "12 0 obj" and "endobj" (the last definition wins, as in PDF updates).
    static func objectRange(number: Int, generation: Int, in bytes: [UInt8]) -> Range<Int>? {
        let header = Array("\(number) \(generation) obj".utf8)
        var searchEnd = bytes.count
        while let found = lastIndex(of: header, in: bytes, before: searchEnd) {
            let isStartOfToken = found == 0 || isWhitespace(bytes[found - 1])
            if isStartOfToken {
                let bodyStart = found + header.count
                guard let end = firstIndex(of: Array("endobj".utf8), in: bytes, from: bodyStart) else { return nil }
                return bodyStart..<end
            }
            searchEnd = found
        }
        return nil
    }

    // MARK: Blanking

    /// Replaces the content of every (literal) and <hex> string with spaces.
    static func blankStrings(in bytes: inout [UInt8], range: Range<Int>) {
        let space = UInt8(ascii: " ")
        var index = range.lowerBound
        while index < range.upperBound {
            let byte = bytes[index]
            if byte == UInt8(ascii: "(") {
                var depth = 1
                var cursor = index + 1
                while cursor < range.upperBound, depth > 0 {
                    let current = bytes[cursor]
                    if current == UInt8(ascii: "\\") {
                        bytes[cursor] = space
                        if cursor + 1 < range.upperBound { bytes[cursor + 1] = space }
                        cursor += 2
                        continue
                    }
                    if current == UInt8(ascii: "(") { depth += 1 }
                    if current == UInt8(ascii: ")") { depth -= 1 }
                    if depth > 0 { bytes[cursor] = space }
                    cursor += 1
                }
                index = cursor
            } else if byte == UInt8(ascii: "<"), index + 1 < range.upperBound, bytes[index + 1] != UInt8(ascii: "<") {
                // Hex string: every pair of digits becomes "20" (a space).
                var cursor = index + 1
                var isHigh = true
                while cursor < range.upperBound, bytes[cursor] != UInt8(ascii: ">") {
                    if isHexDigit(bytes[cursor]) {
                        bytes[cursor] = isHigh ? UInt8(ascii: "2") : UInt8(ascii: "0")
                        isHigh.toggle()
                    }
                    cursor += 1
                }
                index = cursor + 1
            } else if byte == UInt8(ascii: "<") {
                index += 2
            } else {
                index += 1
            }
        }
    }

    // MARK: Byte helpers

    private static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 || byte == 0x0C || byte == 0x00
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        (0x30...0x39).contains(byte) || (0x41...0x46).contains(byte) || (0x61...0x66).contains(byte)
    }

    private static func skipSpaces(_ bytes: [UInt8], _ index: inout Int) {
        while index < bytes.count, isWhitespace(bytes[index]) { index += 1 }
    }

    private static func readInteger(_ bytes: [UInt8], _ index: inout Int) -> Int? {
        skipSpaces(bytes, &index)
        var value = 0
        var digits = 0
        while index < bytes.count, (0x30...0x39).contains(bytes[index]), digits < 10 {
            value = value * 10 + Int(bytes[index] - 0x30)
            index += 1
            digits += 1
        }
        return digits > 0 ? value : nil
    }

    private static func lastIndex(of pattern: [UInt8], in bytes: [UInt8], before end: Int? = nil) -> Int? {
        let limit = min(end ?? bytes.count, bytes.count) - pattern.count
        guard limit >= 0 else { return nil }
        var index = limit
        while index >= 0 {
            if bytes[index] == pattern[0], Array(bytes[index..<(index + pattern.count)]) == pattern {
                return index
            }
            index -= 1
        }
        return nil
    }

    private static func firstIndex(of pattern: [UInt8], in bytes: [UInt8], from start: Int) -> Int? {
        guard bytes.count >= pattern.count, start <= bytes.count - pattern.count else { return nil }
        for index in start...(bytes.count - pattern.count)
        where bytes[index] == pattern[0] && Array(bytes[index..<(index + pattern.count)]) == pattern {
            return index
        }
        return nil
    }
}
