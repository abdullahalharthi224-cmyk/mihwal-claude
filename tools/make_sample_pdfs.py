"""Builds the sample PDFs in samples/ for testing on the iPhone. Usage: python3 tools/make_sample_pdfs.py samples"""
import sys
from pypdf import PdfWriter
from pypdf.generic import (ArrayObject, DecodedStreamObject, DictionaryObject, FloatObject,
                           NameObject, NumberObject, TextStringObject)

out = sys.argv[1]

def page(writer, number, total, with_link=False):
    p = writer.add_blank_page(width=595, height=842)  # A4
    font = DictionaryObject({NameObject("/Type"): NameObject("/Font"),
                             NameObject("/Subtype"): NameObject("/Type1"),
                             NameObject("/BaseFont"): NameObject("/Helvetica")})
    p[NameObject("/Resources")] = DictionaryObject({NameObject("/Font"): DictionaryObject({NameObject("/F1"): font})})
    text = (f"BT /F1 28 Tf 72 760 Td (Mihwal sample - page {number} of {total}) Tj ET\n"
            f"BT /F1 14 Tf 72 720 Td (This text can be selected and searched.) Tj ET\n"
            f"0.2 0.5 0.9 rg 72 300 451 300 re f\n"
            f"BT /F1 60 Tf 1 1 1 rg 250 420 Td ({number}) Tj ET\n")
    stream = DecodedStreamObject()
    stream.set_data(text.encode())
    content_ref = writer._add_object(stream)
    p[NameObject("/Contents")] = content_ref
    if with_link:
        link = DictionaryObject({
            NameObject("/Type"): NameObject("/Annot"),
            NameObject("/Subtype"): NameObject("/Link"),
            NameObject("/Rect"): ArrayObject([FloatObject(72), FloatObject(680), FloatObject(300), FloatObject(700)]),
            NameObject("/Border"): ArrayObject([NumberObject(0), NumberObject(0), NumberObject(0)]),
            NameObject("/A"): DictionaryObject({NameObject("/S"): NameObject("/URI"),
                                               NameObject("/URI"): TextStringObject("https://www.apple.com")}),
        })
        p[NameObject("/Annots")] = ArrayObject([writer._add_object(link)])
        extra = DecodedStreamObject()
        extra.set_data(b"BT /F1 14 Tf 0 0 1 rg 72 685 Td (This line is a link to apple.com) Tj ET\n")
        # Streams must be referenced indirectly inside a /Contents array.
        p[NameObject("/Contents")] = ArrayObject([content_ref, writer._add_object(extra)])

def build(name, pages=3, metadata=None, link=False, user=None, owner=None, permissions=None):
    w = PdfWriter()
    for n in range(1, pages + 1):
        page(w, n, pages, with_link=link and n == 1)
    if metadata:
        w.add_metadata(metadata)
        w.xmp_metadata = None
    if user is not None or owner is not None:
        kwargs = dict(user_password=user or "", owner_password=owner, algorithm="AES-128")
        if permissions is not None:
            kwargs["permissions_flag"] = permissions
        w.encrypt(**kwargs)
    with open(f"{out}/{name}", "wb") as f:
        w.write(f)

from pypdf.constants import UserAccessPermissions as P
build("1-metadata.pdf", metadata={"/Title": "Secret plan", "/Author": "Abdullah",
                                  "/Subject": "Private notes", "/Keywords": "mihwal, test",
                                  "/Creator": "Microsoft Word", "/Producer": "Sample maker"})
build("2-password-1234.pdf", user="1234", owner="1234")
build("3-restricted-owner-5678.pdf", owner="5678",
      permissions=P.EXTRACT_TEXT_AND_GRAPHICS | P.R1 | P.R2 | P.R7 | P.R8 | P.R13 | P.R14 | P.R15 | P.R16)
build("4-both-open-1111-owner-2222.pdf", user="1111", owner="2222",
      permissions=P.R1 | P.R2 | P.R7 | P.R8 | P.R13 | P.R14 | P.R15 | P.R16)
build("5-with-link.pdf", pages=2, link=True)
build("6-ten-pages.pdf", pages=10)
