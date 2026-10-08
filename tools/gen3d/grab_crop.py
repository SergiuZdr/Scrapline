"""051: turns a browser capture of one generated image (chatgpt_show.js) into a concept PNG:
drops the window's dark bands at the edges, crops to the drawing (non-white pixels), and pads it
onto a white square. Usage: python3 tools/gen3d/grab_crop.py <capture.jpg> <out.png>"""
import sys
from PIL import Image, ImageChops

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
w, h = im.size
px = im.load()

def dark_row(y):
    return sum(1 for x in range(0, w, 7) if sum(px[x, y]) < 120) > 0.9 * (w / 7)

bottom = h
while bottom > 0 and dark_row(bottom - 1):
    bottom -= 1
top = 0
while top < bottom and dark_row(top):
    top += 1
im = im.crop((0, top, w, bottom))
# The drawing: anything clearly off white.
diff = ImageChops.difference(im, Image.new("RGB", im.size, (255, 255, 255))).convert("L").point(lambda v: 255 if v > 24 else 0)
box = diff.getbbox()
art = im.crop(box)
side = int(max(art.size) * 1.12)
sheet = Image.new("RGB", (side, side), (255, 255, 255))
sheet.paste(art, ((side - art.size[0]) // 2, (side - art.size[1]) // 2))
sheet.save(out)
print("%s: %dx%d drawing -> %dx%d" % (out, art.size[0], art.size[1], side, side))
