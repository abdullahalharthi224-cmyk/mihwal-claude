# Sample PDFs for testing

Made with `tools/make_sample_pdfs.py` (pypdf, real AES-128 encryption). Every page has
selectable text ("Mihwal sample - page N of M") and a blue box with the page number.

| File | What it tests | Passwords |
|---|---|---|
| `1-metadata.pdf` | Remove Metadata: title, author, subject, keywords, creator | none |
| `2-password-1234.pdf` | Needs a password to open; Unlock PDF; protected-output warning | open: `1234` |
| `3-restricted-owner-5678.pdf` | Opens freely, but printing and editing are blocked: every tool asks for the owner password | owner: `5678` |
| `4-both-open-1111-owner-2222.pdf` | Open password **and** restrictions: `1111` opens it, `2222` is needed to change it | open: `1111`, owner: `2222` |
| `5-with-link.pdf` | Page numbers / watermark warn that the link will be flattened | none |
| `6-ten-pages.pdf` | Page numbers, split, compress on more pages | none |
| `7-scan.pdf` | Compress PDF (strong): pages that are pictures, like a scan | none |
| `photo.jpg` | Image tools: stored sideways (EXIF orientation 6) with a GPS location and an old date, like an iPhone photo | — |
| `logo.png` | Image tools: transparent background | — |

Images and the scan are made by `tools/make_sample_images.py`. The UI tests
(`MihwalUITests`) open every tool in the app with these files and press its button.
