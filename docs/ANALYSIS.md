# Mihwal / مِحوَل — Phase 0 Analysis

Status: **draft, waiting for owner approval**. No app code exists yet.

This document covers every one of the 21 tools: what it does, which Apple framework does
the work, the edge cases, and an honest difficulty rating. It ends with the architecture,
the UX ideas, the risks, and the open questions.

Difficulty scale: **1** = a few lines of PDFKit · **2** = straightforward but needs care ·
**3** = real engineering, edge cases · **4** = no native API, custom approach · **5** = not
possible natively without a dependency.

---

## 0. Ground rules that apply to every tool

| Rule | How |
|---|---|
| Never block the UI | Engines run in a detached `Task` (not on `MainActor`). Progress is reported page by page or image by image. |
| Cancel | `try Task.checkCancellation()` between pages/images. Partial output files are deleted. |
| Memory | Each page/image is processed inside `autoreleasepool { }`. Big images are decoded already downsampled with `CGImageSourceCreateThumbnailAtIndex`. Nothing holds every page bitmap at once. |
| PDFKit and threads | `PDFDocument` is not thread-safe. Each engine opens **its own** `PDFDocument` from the URL. The UI's thumbnail loader uses a separate instance. |
| Storage | Before writing, check `volumeAvailableCapacityForImportantUsage` against an estimate (input size × factor). We also catch `NSFileWriteOutOfSpaceError` → "Not enough storage". |
| Encrypted input | Any PDF tool that gets a locked PDF first asks for the password (`PDFDocument.unlock(withPassword:)`). A wrong password gives a clear error that can be retried. |
| Corrupted input | `PDFDocument(url:)` returns `nil` → "This file is damaged or is not a PDF". Images: `CGImageSourceCreateWithURL` / `CGImageSourceGetStatus` → "Unsupported or damaged image". |
| Output | Written to `tmp/Outputs/<UUID>/`, then shown with Quick Look / ShareLink / fileExporter / Save to Photos. The temp folder is cleaned on launch and after export. |
| Multiple output files | Shared directly as several files (ShareLink supports many). For "Save to Files" as one file we use our own small ZIP writer (see §4). |
| File names | Output keeps the original name plus a suffix, e.g. `report (merged).pdf`, `photo (compressed).jpg`. |

---

## 1. Organize PDF (11 tools)

### 1.1 Merge — difficulty 2
- **Input:** 2+ PDFs (images allowed too: they are converted to pages first, an extra the website doesn't have).
- **Options:** order (thumbnail grid with drag-to-reorder of *files*); an optional per-file page range from the visual picker.
- **Output:** one PDF.
- **Framework:** PDFKit: create a new `PDFDocument`, then `insert(page.copy(), at:)` for each page, then `write(to:)`.
- **Edge cases:** files with different page sizes (kept as they are, not stretched); an encrypted source (password asked per file); hundreds of pages (pages are copied one at a time, with progress per page); a source that has form fields (they are kept, but two files with the same field names can clash, a documented limitation).
- **Note:** we copy `PDFPage` objects instead of re-drawing them, so text stays selectable and links/annotations survive.

### 1.2 Split — difficulty 2
- **Options:** (a) every page on its own, (b) every N pages, (c) custom groups picked visually (tap pages, "new group" divider).
- **Output:** several PDFs, shared as many files or saved as one `.zip`.
- **Framework:** PDFKit, the same page copying as merge.
- **Edge cases:** a 1-page PDF (the button is disabled with an explanation); 500 pages "each page alone" means 500 files, so we warn and offer the ZIP.

### 1.3 Compress — difficulty **4** ⚠️ (no clean native API)
iOS has no "Reduce File Size" Quartz filter (that exists on macOS only). The realistic plan has two levels:

| Level | How | Keeps text selectable? | Typical result |
|---|---|---|---|
| **Balanced** | `PDFDocument.write(to:withOptions:)` with `.saveImagesAsJPEGOption` and `.optimizeImagesForScreenOption` (public, iOS 16+). PDFKit re-encodes the embedded images. | ✅ Yes | Good for scanned/photo-heavy PDFs, little effect on text-only PDFs. |
| **Strong** | Render every page to a bitmap at a chosen DPI (100/150) → JPEG (quality 0.5–0.7) → new PDF with `UIGraphicsPDFRenderer`. | ❌ No (it becomes an image). We tell the user clearly. | Big savings for scans. Can be *bigger* for text-only PDFs. |

- **Output rule:** if the result is not smaller than the original, we say "This file is already optimized" and do **not** offer a bigger file. Before/after size is always shown.
- **Honest risk:** the effect of the Balanced options depends on how the PDF stores its images, and Apple documents them very briefly. Unit tests will measure them on a generated image-heavy PDF. If they turn out to do nothing on iOS, Balanced falls back to "Strong at 200 DPI".

### 1.4 Rotate — difficulty 1
- **Options:** rotate selected pages (or all) by 90° / 180° / 270°, chosen visually: tapping a thumbnail rotates it with an animation.
- **Framework:** `PDFPage.rotation` (a multiple of 90; we normalize it to 0..<360).
- **Edge case:** pages that already have a rotation (we add to it, we never replace it).

### 1.5 Delete pages — difficulty 1
- Multi-select thumbnails → `removePage(at:)` from the highest index to the lowest.
- **Edge case:** deleting every page is blocked ("A PDF needs at least one page").

### 1.6 Extract pages — difficulty 1
- Multi-select → a new PDF with copies of those pages, in reading order (or in tap order, as an option).

### 1.7 Reverse order — difficulty 1
- A new document with the pages inserted in reverse. One tap, no options.

### 1.8 Page numbers — difficulty 3
- **Options:** position (6 positions: top/bottom × start/center/end), format (`1`, `1 / 10`, `Page 1 of 10`, `صفحة ١ من ١٠`), Arabic-Indic or Western digits, start number, skip the first page, font size, a live preview on the first page.
- **Framework:** re-draw each page into `UIGraphicsPDFRenderer` (`PDFPage.draw(with: .mediaBox, to:)`, which keeps text as vectors), then draw the number with `NSAttributedString.draw(at:)`. That uses Core Text, so Arabic shapes correctly.
- **Trade-off (honest):** re-drawing loses **links, form fields, bookmarks/outline** (they become flat). The alternative, a `PDFAnnotation` of type `.freeText`, keeps everything but the stamp can be edited or removed and looks different across viewers. **Recommendation:** re-draw (it looks the same everywhere), and the success screen shows "Links and forms were flattened" only when the source had any.
- **Edge cases:** rotated pages (the stamp must be placed in the *visual* orientation: we apply the page's rotation transform), and mixed page sizes.

### 1.9 Text watermark — difficulty 3
- **Options:** text (Arabic/English), font size, color, opacity, angle (0/45/custom), position (center / tiled), which pages, a live preview.
- **Framework:** the same re-draw pipeline as page numbers, plus a rotated `CGContext` for the angle. Same trade-off about flattened links.
- **Note:** this is a visual watermark, not a security feature. Anyone with a PDF editor can remove it. We say so in the help text.

### 1.10 Strip metadata — difficulty 2
- **What it removes:** the Info dictionary (Title, Author, Subject, Keywords, Creator, Producer, dates) **and** the XMP metadata stream.
- **Framework:** PDFKit `documentAttributes = [:]` is not enough (the XMP stream can survive). The engine builds a *fresh* `PDFDocument`, copies the pages in, and writes it. A unit test then opens the output with `CGPDFDocument` and checks that the catalog has no `/Metadata` key and that the Info dictionary is empty. If PDFKit still copies XMP, we fall back to the re-draw pipeline.
- **Shows:** a "before" list of the metadata found, so the user sees what was removed (better than the website).

### 1.11 Remove restrictions (password required) — difficulty 3
- **Rule:** we only remove protection **when the user knows the password.** No cracking, no bypassing.
- **Two kinds of protection:**
  - *Open password* (user password): `unlock(withPassword:)` must succeed.
  - *Permissions password* (owner password; the file opens but printing/copying is blocked): `unlock(withPassword:)` must give `permissionsStatus == .owner`. If the user only has the open password, we explain that the owner password is needed.
- **Output:** written with **no** `ownerPasswordOption` / `userPasswordOption`, which produces an unencrypted file. The test checks `isEncrypted == false` on the output.
- **Honest risk:** I am fairly but not fully sure PDFKit drops encryption when you write an unlocked document without options. The unit test will prove it. If it fails, the fallback is to copy the pages into a fresh `PDFDocument` (which has no encryption dictionary).
- **Edge cases:** AES-256 PDFs (PDFKit supports them), a wrong password (retry with a shake animation + haptic), a file that isn't protected at all ("This PDF has no restrictions").

---

## 2. Convert (5 tools)

### 2.1 PDF → Word (.docx) — difficulty **4** ⚠️ (no native API)
- iOS cannot write `.doc`/`.docx`: `NSAttributedString.DocumentType.officeOpenXML` is **macOS only**.
- **Realistic approach:** a `.docx` is a ZIP of a few XML files. We generate them ourselves:
  `[Content_Types].xml`, `_rels/.rels`, `word/document.xml` (+ `word/_rels`, `word/media/*` for images).
- **Content:** text per page from the PDF text layer (OCR fallback, as in 2.2), split into paragraphs, with a page break between PDF pages. Each paragraph gets `<w:bidi/>` + `<w:rtl/>` when it is Arabic, so Word shows it right-to-left. An option "Include page images" embeds each page as a picture (the fallback for complex layouts).
- **Honest limitation (shown in the UI):** this is a **text conversion, not a layout copy.** Columns, tables, and fonts are not reproduced. Only commercial SDKs (e.g. Adobe, PSPDFKit) do that, and they need a licence and most of them a server. For a free on-device app this is the best realistic result.
- **Needs:** the ZIP writer from §4 (stored entries, CRC-32; no compression needed, Word accepts stored entries).

### 2.2 PDF → Text — difficulty 3
- **Step 1:** `PDFPage.string` per page.
- **Step 2:** if a page has no text (scans) → render it at about 2× (capped near 2500 px on the long side) → `VNRecognizeTextRequest` (`.accurate`, `recognitionLanguages = ["ar-SA", "en-US"]`, `usesLanguageCorrection = true`).
- **Arabic clean-up:** some PDFs store Arabic as *presentation forms* (U+FB50–U+FEFF). We normalize them with `precomposedStringWithCompatibilityMapping`, so the text becomes normal, searchable Arabic.
- **Options:** force OCR on all pages; page separators on/off.
- **Output:** `.txt` (UTF-8), plus "Copy all" to the clipboard.
- **Honest risks:**
  - Arabic in Vision OCR is supported on recent iOS versions only. We check `supportedRecognitionLanguages()` at runtime; if Arabic is missing, we show "Arabic OCR needs a newer iOS" and still recognize English.
  - Some badly made PDFs store Arabic in *visual* order (reversed). We cannot always detect this reliably; we document it.

### 2.3 Text → PDF (Arabic) — difficulty 3
- **Input:** typed/pasted text in an editor, or a `.txt` file.
- **Options:** page size (A4 / Letter), margins, font size, font (System / Naskh-style system fonts available on iOS such as "Geeza Pro"), alignment (automatic by language / right / left / center), line spacing.
- **Framework:** `NSAttributedString` + `NSParagraphStyle` (`baseWritingDirection` per paragraph, `.natural` alignment) → `CTFramesetter` paginates (`CTFramesetterCreateFrame` page by page until all text is used) → drawn into `UIGraphicsPDFRenderer`. Core Text does the shaping, so letters connect and mixed Arabic/English/numbers follow the Unicode bidi algorithm. No manual glyph drawing.
- **Edge cases:** an empty text (button disabled); very long text (paginated with progress); emoji (supported by Core Text); the y-axis flip between UIKit and Core Text (handled once, in a helper with a test).
- **Bonus:** the text stays selectable and searchable in the output PDF.

### 2.4 Images → PDF — difficulty 2
- **Input:** many images from Photos/Files (HEIC, JPEG, PNG, WebP, …), reorderable thumbnail grid.
- **Options:** page size (fit to image / A4 / Letter), orientation (auto / portrait / landscape), margin (none/small/large), quality (keeps the size reasonable).
- **Framework:** ImageIO downsampling → JPEG data → `CGImage(jpegDataProviderSource:…)` → drawn into `UIGraphicsPDFRenderer`. An image built from JPEG data is embedded as JPEG (passthrough) instead of a huge uncompressed bitmap. A test checks the output size stays near the sum of the JPEG sizes.
- **Edge cases:** EXIF orientation (we apply it, so photos are not sideways); a 48 MP image (downsampled to the page's needs, never decoded at full size); PNGs with transparency (drawn on white).

### 2.5 PDF → Images — difficulty 2
- **Options:** pages (visual picker, default all), format (JPEG/PNG/HEIC), resolution (72 / 150 / 300 DPI), JPEG quality.
- **Framework:** for each page a `CGContext` bitmap with white fill → `PDFPage.draw(with:to:)` → `CGImageDestination`. Size is capped (e.g. 8000 px long side) to avoid memory spikes.
- **Output:** Save all to Photos (one tap), share, or a ZIP to Files.

---

## 3. Images (5 tools)

All image tools work in **batch** (many images at once) and **strip location (GPS) by default** for privacy, with a switch to keep metadata.

### 3.1 Convert format — difficulty 2, WebP **output** is 5 ⚠️
- **Input:** HEIC, HEIF, JPEG, PNG, WebP, GIF (first frame), TIFF, BMP. ImageIO decodes them all natively.
- **Output:** JPEG, PNG, HEIC (native encode via `CGImageDestination`).
- **WebP output:** ImageIO on iOS can **read** WebP but **cannot write** it. We will confirm with `CGImageDestinationCopyTypeIdentifiers()` in a test, but every source I know says it is not there. Choices:
  1. **Recommended:** WebP is an input format only; output is JPEG/PNG/HEIC. Zero dependencies.
  2. Add Google's `libwebp` via Swift Package Manager (open source, BSD licence, about 1 MB). It works offline and fits the rules, but it is a third-party dependency and a C library in CI (more build risk).
  → **Owner decides** (question 1 below).
- **Edge cases:** the HEIC encoder may be missing on old devices/simulators (we hide HEIC when `CGImageDestinationCopyTypeIdentifiers` doesn't list it); PNG → JPEG with transparency (flattened on white, with a color option).

### 3.2 Compress — difficulty 2
- **Options:** a quality slider with 3 presets (High / Balanced / Small), output format (keep / JPEG / HEIC: HEIC is about 40% smaller at the same quality), an optional max size (e.g. 2048 px long side).
- **Framework:** ImageIO: `kCGImageDestinationLossyCompressionQuality`, downsampling via `CGImageSourceCreateThumbnailAtIndex`.
- **UI:** before/after size per image and in total ("Saved 14.2 MB, 63%"), plus a before/after comparison slider on one image.
- **Edge case:** PNG input with "keep format" (PNG is lossless, so quality does nothing; we suggest a resize or a conversion).

### 3.3 Resize — difficulty 1
- **Options:** by percent, by max width/height (aspect locked), or presets (Instagram 1080, HD 1920, 4K…). No upscaling unless the user asks.
- **Framework:** `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize` (fast, memory-safe, high quality, and applies the EXIF orientation).

### 3.4 Rotate / Flip — difficulty 1
- **Options:** 90° left/right, 180°, flip horizontal/vertical, live preview with animation.
- **Framework:** a `CGContext` with an affine transform, re-encoded in the same format. JPEG quality is kept high (0.95), because rotating JPEGs without any loss is not possible natively; we document this.

### 3.5 Text watermark — difficulty 2
- Same options as the PDF watermark (text, size, color, opacity, angle, position/tiled) with a live preview.
- **Framework:** a `CGContext` bitmap + `NSAttributedString` drawing (Core Text, so Arabic is correct). Font size is relative to the image width, so it looks the same on every image in a batch.

---

## 4. Shared pieces that are not in the tool list

| Piece | Why |
|---|---|
| `ZipWriter` (about 150 lines, our own code) | Needed for `.docx` and for "save many files as one". STORE method (no compression) + CRC-32. Unit tests check the headers, the central directory and the CRC values against known vectors. No dependency. (iOS has no public ZIP *writer*; the `NSFileCoordinator .forUploading` trick puts an extra top-level folder in the archive, which breaks `.docx`.) |
| `ThumbnailProvider` (actor) | Lazy page/image thumbnails with an `NSCache` limited by cost (pixels). Requests are cancelled when cells scroll away. |
| `PDFRedrawPipeline` | Shared by page numbers + watermark (+ the Strong compress level): re-draws pages with a "decorate page" closure. |
| `TextLayout` (Core Text helper) | Shared by text→PDF, page numbers, and both watermarks: Arabic shaping + flipped coordinates in one tested place. |
| `ToolError` | One enum → a localized title + message + suggested action (e.g. "Try again", "Enter password"). |
| `StorageGuard` | Checks free space before heavy writes. |

---

## 5. Summary table

| # | Tool | Framework | Difficulty | Native? |
|---|---|---|---|---|
| 1 | Merge | PDFKit | 2 | ✅ |
| 2 | Split | PDFKit + ZipWriter | 2 | ✅ |
| 3 | Compress PDF | PDFKit write options / rasterize | **4** | ⚠️ partial |
| 4 | Rotate | PDFKit | 1 | ✅ |
| 5 | Delete pages | PDFKit | 1 | ✅ |
| 6 | Extract pages | PDFKit | 1 | ✅ |
| 7 | Reverse order | PDFKit | 1 | ✅ |
| 8 | Page numbers | PDFKit + UIGraphicsPDFRenderer + Core Text | 3 | ✅ (flattens links) |
| 9 | PDF watermark | same | 3 | ✅ (flattens links) |
| 10 | Strip metadata | PDFKit + CGPDFDocument check | 2 | ✅ (verify XMP) |
| 11 | Remove restrictions | PDFKit (password required) | 3 | ✅ (verify) |
| 12 | PDF → Word | own DOCX writer + ZipWriter | **4** | ⚠️ text only |
| 13 | PDF → Text | PDFKit + Vision OCR | 3 | ✅ |
| 14 | Text → PDF | Core Text + UIGraphicsPDFRenderer | 3 | ✅ |
| 15 | Images → PDF | ImageIO + UIGraphicsPDFRenderer | 2 | ✅ |
| 16 | PDF → Images | PDFKit + Core Graphics + ImageIO | 2 | ✅ |
| 17 | Image convert | ImageIO | 2 (WebP out = 5) | ⚠️ no WebP out |
| 18 | Image compress | ImageIO | 2 | ✅ |
| 19 | Resize | ImageIO | 1 | ✅ |
| 20 | Rotate / flip | Core Graphics | 1 | ✅ |
| 21 | Image watermark | Core Graphics + Core Text | 2 | ✅ |

---

## 6. Architecture

```
App/                 MihwalApp, RootView, AppState (recents, favorites), deep links / "Open in"
DesignSystem/        DS.swift (colors, spacing, radii, typography, haptics), shared components
Core/
  Files/             import (fileImporter, PhotosPicker, Open-in inbox), export, temp cleanup, ZipWriter
  PDF/               PDFLoader (password flow), PDFRedrawPipeline, PageSelection
  Images/            ImageLoader (downsampling), ImageEncoder
  Thumbnails/        ThumbnailProvider (actor + NSCache)
  Progress/          ToolProgress, ToolRunner (Task + cancel + state machine)
  Errors/            ToolError
  Text/              TextLayout (Core Text helpers)
Tools/<ToolName>/    <Tool>Engine.swift (no SwiftUI) · <Tool>ViewModel.swift · <Tool>View.swift
Resources/           Localizable.xcstrings, Assets.xcassets, Info.plist additions
Tests/               one XCTest file per engine, sample files generated in code
```

### The tool protocol
Options are different for each tool, so a single non-generic `run(options:)` would need `Any`.
Instead there are two layers:

```swift
// What the home grid / registry knows about (non-generic, so it fits in an array)
struct ToolDescriptor: Identifiable {
    let id: ToolID                 // enum, stable for favorites/recents
    let title: LocalizedStringResource
    let symbol: String             // SF Symbol
    let category: ToolCategory     // .organize / .convert / .images
    let accepts: [UTType]          // used by "Open in" to suggest tools
    let makeView: @MainActor () -> AnyView
}

// What each engine implements (generic, pure logic, unit-testable, no SwiftUI)
protocol FileTool: Sendable {
    associatedtype Options: Sendable
    func run(input: ToolInput, options: Options,
             progress: @Sendable (Double) -> Void) async throws -> ToolOutput
}
```

Adding a tool = a new folder + one line in `ToolRegistry`. No other tool is touched.

`ToolRunner` (shared, `@MainActor @Observable`) runs any `FileTool`, owns the `Task`, and exposes a
state machine `idle → processing(progress) → success(output) / failure(ToolError)` that every
tool screen uses, so empty/processing/success/error look identical everywhere.

### Dependencies
**None planned.** Only Apple frameworks: SwiftUI, PDFKit, ImageIO, CoreGraphics, CoreText,
Vision, UniformTypeIdentifiers, PhotosUI, QuickLook, UIKit (renderers only).
The only candidate is `libwebp` (question 1).

### Network
No networking code at all. There is also no `NSAppTransportSecurity` exception, no analytics
SDK, and a CI step that fails the build if `URLSession` appears in the source.

---

## 7. UX ideas that make the app better than the website

1. **"Open in Mihwal" from anywhere.** Share a PDF from Mail/WhatsApp/Files → the app opens with a sheet *"What do you want to do with this file?"* showing only the tools that accept that type.
2. **Tool chaining.** On the success screen: *"Continue with…"* → e.g. merge → compress → add page numbers, without saving and re-importing in between.
3. **Visual everything.** Page thumbnails with multi-select (drag across to select a range, like Photos), tap to rotate, drag to reorder, a long-press peek at a page in full size.
4. **Live previews** for watermark and page numbers: you see the result before processing.
5. **Before/after** size with a percentage, and a comparison slider for images.
6. **Batch image processing** with per-image results.
7. **Privacy you can see.** An "Offline · On-device" badge; image tools remove GPS by default; temp files are wiped automatically.
8. **Home Screen quick actions** (long-press the app icon) for the 3 favorite tools.
9. **Drag & drop** files into the app (useful in Split View on iPhone with Files, and later on iPad).
10. **Haptics** on success/error, reorder pick-up and drop, and page selection.
11. **Arabic first.** Arabic-Indic digits option for page numbers, correct RTL layout, Arabic OCR.
12. **Bonus tool, optional:** *Scan document → PDF* with VisionKit's `VNDocumentCameraViewController` (native, offline). Not in the 21 tools; question 3.

---

## 8. Risks I see now (honest)

| Risk | Impact | Mitigation |
|---|---|---|
| No local Mac: every compile error costs one CI run | Slow iterations | Small phases; I keep to APIs I am sure about; a CI test job runs before the IPA job. |
| PDF compression results vary by file | User disappointment | Two levels, a clear before/after, never return a bigger file. |
| PDF → Word loses layout | User disappointment | Named "PDF → Word (text)" with a one-line explanation in the tool. |
| WebP output not native | Missing feature | Question 1. |
| Arabic OCR depends on the iOS version | Missing on older iOS | Runtime check + clear message. |
| Write-option behaviour (encryption, XMP) | Silent failure | Unit tests assert the output, with fallbacks ready. |
| Large PDFs (1000+ pages) | Memory | Per-page autoreleasepool, lazy thumbnails, NSCache cost limits. |
| Sideloaded app + "Open in" | Document types work with any signing, but a re-signing service can change the bundle id | Nothing depends on the bundle id. |

---

## 9. Questions for the owner (please answer before Phase 1)

1. **WebP output:** (a) input only, zero dependencies (recommended), or (b) add `libwebp`?
2. **Bundle id:** is `com.personal.mihwal` OK? (Your signing store may change it anyway.)
3. **Bonus "Scan → PDF"** tool with the camera: yes / later / no?
4. **Branch:** you asked me to push each phase to `main`. My session is set up to work on the
   branch `claude/trusting-ptolemy-8fwckb`. I will push there **and** update `main` unless you prefer only one.
5. **Page numbers/watermark:** OK to flatten links/forms (looks identical everywhere), as recommended?
