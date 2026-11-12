from PIL import Image, ImageEnhance, ImageDraw, ImageFilter
import math, os

src = "assets/vip_animated_combined10/set1_vip01.png"
out = "assets/vip_animated_combined10/set1_vip01.gif"

im = Image.open(src).convert("RGBA")
w, h = im.size
frames = []

# Blue-highlight mask: existing cyan/blue pixels only
pixels = im.load()
mask = Image.new("L", (w, h), 0)
mp = mask.load()

for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        if a > 0 and b > 100 and b > r * 1.18 and g > r * 1.12:
            mp[x, y] = min(255, int(a * 0.8))

mask = mask.filter(ImageFilter.GaussianBlur(max(2, w // 180)))

for i in range(16):
    phase = i / 16 * 2 * math.pi
    glow = 0.12 + 0.20 * (0.5 + 0.5 * math.sin(phase))
    frame = im.copy()

    # Gentle blue glow over existing blue details
    blue = Image.new("RGBA", (w, h), (35, 190, 255, 0))
    blue.putalpha(mask.point(lambda p: int(p * glow)))
    frame = Image.alpha_composite(frame, blue)

    # Very subtle overall light pulse; alpha remains unchanged
    rgb = ImageEnhance.Brightness(frame.convert("RGB")).enhance(
        1.0 + 0.025 * math.sin(phase)
    )
    rgb.putalpha(im.getchannel("A"))
    frames.append(rgb)

frames[0].save(
    out, save_all=True, append_images=frames[1:],
    duration=90, loop=0, disposal=2, optimize=True
)

print("Animation created:", out)
print("Size:", os.path.getsize(out), "bytes")
print("Frames:", len(frames), "| Dimensions:", w, "x", h)
