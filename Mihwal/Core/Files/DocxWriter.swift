import Foundation

/// Writes a real Word document (.docx): a ZIP of a few XML files (Office Open XML).
/// Text only: one Word paragraph per paragraph of text, a page break between PDF pages.
/// Arabic paragraphs are marked right-to-left (<w:bidi/>) and Arabic runs as complex
/// script (<w:rtl/>), so Word and Pages show and shape them correctly.
enum DocxWriter {
    static let wordNamespace = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

    static func write(pages: [[String]], to url: URL) throws {
        let entries = [
            ZipWriter.Entry(path: "[Content_Types].xml", data: Data(contentTypes.utf8)),
            ZipWriter.Entry(path: "_rels/.rels", data: Data(packageRelationships.utf8)),
            ZipWriter.Entry(path: "word/_rels/document.xml.rels", data: Data(documentRelationships.utf8)),
            ZipWriter.Entry(path: "word/styles.xml", data: Data(styles.utf8)),
            ZipWriter.Entry(path: "word/document.xml", data: Data(documentXML(pages: pages).utf8)),
        ]
        try ZipWriter.write(entries: entries, to: url)
    }

    // MARK: Paragraphs from PDF text

    /// PDF text has a line break at the end of every printed line. Lines that wrap (long,
    /// not ending a sentence) are joined back into one paragraph; short lines (titles) and
    /// lines ending with . ! ? ؟ : end a paragraph; empty lines always do.
    static func paragraphs(from pageText: String) -> [String] {
        let lines = pageText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        let longest = lines.map(\.count).max() ?? 0
        var result: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty { result.append(current) }
            current = ""
        }
        for line in lines {
            guard !line.isEmpty else {
                flush()
                continue
            }
            if startsListItem(line) {
                flush()
            }
            current = current.isEmpty ? line : current + " " + line
            let wraps = Double(line.count) >= Double(longest) * 0.6 && !endsSentence(line)
            if !wraps {
                flush()
            }
        }
        flush()
        return result
    }

    static func endsSentence(_ line: String) -> Bool {
        guard let last = line.last else { return true }
        return ".!?؟:;…".contains(last)
    }

    static func startsListItem(_ line: String) -> Bool {
        if let first = line.first, "•-–*●▪".contains(first) { return true }
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 3 else { return false }
        let after = line.dropFirst(digits.count).first
        return after == "." || after == ")" || after == "-"
    }

    // MARK: Direction

    static func isStrongRTL(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0590...0x05FF, 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF,
             0xFB1D...0xFDFF, 0xFE70...0xFEFF:
            return scalar.properties.isAlphabetic
        default:
            return false
        }
    }

    static func isStrongLTR(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isAlphabetic && !isStrongRTL(scalar)
    }

    /// A paragraph is right-to-left when its first letter is Arabic (or Hebrew).
    static func isRightToLeft(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if isStrongRTL(scalar) { return true }
            if isStrongLTR(scalar) { return false }
        }
        return false
    }

    /// Splits text into runs of one direction. Spaces, digits and punctuation stay with the
    /// run they are in, so "مرحبا 2026" is one Arabic run.
    static func runs(_ text: String) -> [(text: String, rtl: Bool)] {
        var runs: [(text: String, rtl: Bool)] = []
        var current = ""
        var currentRTL = isRightToLeft(text)
        for character in text {
            let scalars = character.unicodeScalars
            let rtl = scalars.contains(where: isStrongRTL)
            let ltr = !rtl && scalars.contains(where: isStrongLTR)
            if (rtl && !currentRTL) || (ltr && currentRTL) {
                if !current.isEmpty { runs.append((current, currentRTL)) }
                current = ""
                currentRTL = rtl
            }
            current.append(character)
        }
        if !current.isEmpty { runs.append((current, currentRTL)) }
        return runs
    }

    // MARK: XML

    /// Escapes XML and drops characters XML can't hold (control codes), which some PDFs contain.
    static func escape(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            default:
                let value = scalar.value
                let allowed = value == 0x9 || value == 0xA || value == 0xD
                    || (0x20...0xD7FF).contains(value) || (0xE000...0xFFFD).contains(value) || value >= 0x10000
                if allowed { result.unicodeScalars.append(scalar) }
            }
        }
        return result
    }

    static func paragraphXML(_ paragraph: String) -> String {
        var xml = "<w:p>"
        if isRightToLeft(paragraph) {
            xml += "<w:pPr><w:bidi/></w:pPr>"
        }
        for run in runs(paragraph) {
            xml += "<w:r>"
            if run.rtl {
                xml += "<w:rPr><w:rtl/></w:rPr>"
            }
            xml += "<w:t xml:space=\"preserve\">\(escape(run.text))</w:t></w:r>"
        }
        return xml + "</w:p>"
    }

    static func documentXML(pages: [[String]]) -> String {
        var body = ""
        for (index, paragraphs) in pages.enumerated() {
            if index > 0 {
                body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
            }
            body += paragraphs.map(paragraphXML).joined()
        }
        if body.isEmpty {
            body = "<w:p/>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="\(wordNamespace)"><w:body>\(body)<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>\
        <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>\
        </w:sectPr></w:body></w:document>
        """
    }

    static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
    <Default Extension="xml" ContentType="application/xml"/>\
    <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>\
    <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>\
    </Types>
    """

    static let packageRelationships = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>\
    </Relationships>
    """

    static let documentRelationships = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\
    </Relationships>
    """

    /// Default fonts: Calibri for Latin, Arial for Arabic (complex script), 12 pt.
    static let styles = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults>\
    <w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Arial"/>\
    <w:sz w:val="24"/><w:szCs w:val="24"/><w:lang w:val="en-US" w:bidi="ar-SA"/></w:rPr></w:rPrDefault>\
    <w:pPrDefault><w:pPr><w:spacing w:after="160" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault>\
    </w:docDefaults></w:styles>
    """
}
