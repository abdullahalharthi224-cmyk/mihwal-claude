"""Draws the placeholder app icon (1024x1024, no alpha). Replaced by the real icon in Phase 7.

Usage: python3 tools/make_placeholder_icon.py <output.png>
"""
import sys
from PIL import Image, ImageDraw

SIZE = 1024
top, bottom = (0, 150, 140), (0, 92, 110)

img = Image.new("RGB", (SIZE, SIZE))
draw = ImageDraw.Draw(img)
for y in range(SIZE):  # vertical gradient
    t = y / (SIZE - 1)
    draw.line([(0, y), (SIZE, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))

white = (255, 255, 255)
# A document sheet with a folded corner
x0, y0, x1, y1, fold = 300, 210, 724, 814, 120
draw.polygon([(x0, y0), (x1 - fold, y0), (x1, y0 + fold), (x1, y1), (x0, y1)], fill=white)
draw.polygon([(x1 - fold, y0), (x1 - fold, y0 + fold), (x1, y0 + fold)], fill=(200, 230, 228))
# Two opposite arrows = "convert"
c = (0, 120, 122)
draw.rounded_rectangle([380, 430, 600, 470], radius=20, fill=c)
draw.polygon([(600, 400), (660, 450), (600, 500)], fill=c)
draw.rounded_rectangle([424, 574, 644, 614], radius=20, fill=c)
draw.polygon([(424, 544), (364, 594), (424, 644)], fill=c)

img.save(sys.argv[1], "PNG")
