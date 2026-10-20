# Draws Resources/AppIcon.icns: warm tile with a cream coffee cup. Run: python3 make_icon.py
import math, os
from PIL import Image, ImageDraw, ImageFilter

S = 4  # supersample
W = 1024 * S
def p(v): return int(v * S)

# macOS tile: 824pt rounded square centred on a 1024 canvas
tile = Image.new("RGBA", (W, W), (0, 0, 0, 0))
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).rounded_rectangle([p(100), p(100), p(924), p(924)], radius=p(185), fill=255)
grad = Image.new("RGBA", (W, W))
gd = ImageDraw.Draw(grad)
top, bot = (201, 128, 74), (110, 58, 28)
for y in range(W):
    t = y / W
    gd.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
tile.paste(grad, (0, 0), mask)

shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
shadow.paste((0, 0, 0, 110), (0, p(14)), mask)
shadow = shadow.filter(ImageFilter.GaussianBlur(p(22)))
img = Image.alpha_composite(shadow, tile)

d = ImageDraw.Draw(img)
cream, coffee = (250, 245, 236, 255), (224, 166, 92, 255)

# handle (ring on the right), then body over it
# cup + handle + saucer span x 242-782, y 330-695, centred on the 512,512 tile centre
d.ellipse([p(612), p(380), p(782), p(550)], outline=cream, width=p(38))
d.rounded_rectangle([p(292), p(330), p(672), p(650)], radius=p(70), fill=cream)
d.rectangle([p(292), p(330), p(672), p(400)], fill=cream)
# coffee level inside the cup
d.rounded_rectangle([p(327), p(400), p(637), p(615)], radius=p(40), fill=coffee)
d.rectangle([p(327), p(400), p(637), p(440)], fill=coffee)
# saucer
d.rounded_rectangle([p(242), p(660), p(722), p(695)], radius=p(17), fill=cream)

img = img.resize((1024, 1024), Image.LANCZOS)
os.makedirs("Resources", exist_ok=True)
img.save("Resources/AppIcon-1024.png")
img.save("Resources/AppIcon.icns", sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)])
print("wrote Resources/AppIcon.icns")
