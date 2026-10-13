"""069: a numbered sheet of candidate concepts for the user to approve.
Usage: python3 tools/gen3d/concept_sheet.py <out.png> <dir> <id> [<id> ...]  (reads <dir>/<id>.png)"""
import sys
from PIL import Image, ImageDraw, ImageFont

out, src, ids = sys.argv[1], sys.argv[2], sys.argv[3:]
S, cols, cap = 520, 4, 56
rows = (len(ids) + cols - 1) // cols
sheet = Image.new("RGB", (S * cols, (S + cap) * rows), "white")
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("art/fonts/BarlowSemiCondensed-Medium.ttf", 34)
except OSError:
    font = ImageFont.load_default()
for i, pid in enumerate(ids):
    im = Image.open("%s/%s.png" % (src, pid)).convert("RGB")
    im.thumbnail((S - 20, S - 20))
    x, y = (i % cols) * S, (i // cols) * (S + cap)
    sheet.paste(im, (x + (S - im.width) // 2, y + (S - im.height) // 2))
    draw.text((x + 14, y + S + 6), "%d  %s" % (i + 1, pid), fill="black", font=font)
    draw.rectangle((x, y, x + S - 1, y + S + cap - 1), outline=(200, 200, 200))
sheet.save(out)
print(out, sheet.size)
