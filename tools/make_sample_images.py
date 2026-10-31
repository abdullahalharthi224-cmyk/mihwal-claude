"""Builds image samples in samples/: a camera-like JPEG (stored sideways with EXIF
orientation 6 and a GPS location), a transparent PNG, and a scanned-looking PDF.
Usage: python3 tools/make_sample_images.py samples"""
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
random.seed(7)

# 1) photo.jpg — stored 1200×800 (landscape) but EXIF says "rotate 90° clockwise to view",
#    like an iPhone portrait photo. Viewed upright it is 800×1200 with the red band on top.
photo = Image.new("RGB", (1200, 800))
draw = ImageDraw.Draw(photo)
for x in range(1200):
    draw.line([(x, 0), (x, 800)], fill=(40 + x * 150 // 1200, 120, 200 - x * 120 // 1200))
draw.rectangle([0, 0, 160, 800], fill=(220, 40, 40))            # left = top when upright
draw.ellipse([500, 250, 800, 550], fill=(255, 210, 60))
exif = Image.Exif()
exif[0x0112] = 6                                                   # Orientation
exif[0x9003] = "2015:01:01 10:00:00"                               # DateTimeOriginal (old)
gps = {1: "N", 2: (24.0, 42.0, 49.0), 3: "E", 4: (46.0, 40.0, 31.0)}
exif[0x8825] = gps                                                 # GPSInfo
photo.save(f"{out}/photo.jpg", "JPEG", quality=95, exif=exif.tobytes())

# 2) logo.png — transparent background
logo = Image.new("RGBA", (400, 400), (0, 0, 0, 0))
d = ImageDraw.Draw(logo)
d.rounded_rectangle([40, 40, 360, 360], radius=60, fill=(0, 150, 140, 255))
d.polygon([(130, 200), (230, 130), (230, 270)], fill=(255, 255, 255, 255))
logo.save(f"{out}/logo.png", "PNG")

# 3) 7-scan.pdf — two A4 pages that are detailed pictures (like a scan at 150 dpi).
pages = []
for n in range(2):
    page = Image.new("RGB", (1240, 1754), (250, 248, 240))
    pd = ImageDraw.Draw(page)
    for _ in range(9000):
        x, y = random.randint(0, 1239), random.randint(0, 1753)
        shade = random.randint(30, 200)
        pd.rectangle([x, y, x + random.randint(2, 18), y + random.randint(2, 6)], fill=(shade, shade, shade))
    page = page.filter(ImageFilter.GaussianBlur(0.6))
    pages.append(page)
pages[0].save(f"{out}/7-scan.pdf", "PDF", resolution=150, save_all=True, append_images=pages[1:], quality=92)
