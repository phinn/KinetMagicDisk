#!/usr/bin/env python3
"""KinetMagicDisk App Icon Generator
DaisyDisk-style dark radial gradient disc + concentric sunburst rings + center pie.
Sizes: 1024 master -> 512/256/128/64/32/16 (with retina pairs).
Output: Resources/AppIcon.iconset/ + Assets.xcassets/AppIcon.appiconset/
"""
import math
import os
import struct
import zlib

OUT_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ICONSET = os.path.join(OUT_ROOT, "Resources", "AppIcon.iconset")
ASSETSET = os.path.join(OUT_ROOT, "Resources", "Assets.xcassets", "AppIcon.appiconset")
os.makedirs(ICONSET, exist_ok=True)
os.makedirs(ASSETSET, exist_ok=True)

SIZE = 1024


def clamp(v):
    return 0 if v < 0 else (255 if v > 255 else int(v))


def mix(c1, c2, t):
    return tuple(c1[i] + (c2[i] - c1[i]) * t for i in range(3))


def lerp(a, b, t):
    return a + (b - a) * t


def supercover_alpha(px, py, cx, cy, r_out, r_in=0.0, a0=0.0, a1=0.0):
    """Analytic coverage of pixel rect (px..px+1, py..py+1) vs annular sector.
    Fast approximation: sample 4x4 supersample grid."""
    cnt = 0
    N = 4
    for sy in range(N):
        for sx in range(N):
            x = px + (sx + 0.5) / N
            y = py + (sy + 0.5) / N
            dx = x - cx
            dy = y - cy
            d = math.hypot(dx, dy)
            if d > r_out or d < r_in:
                continue
            if a1 > a0:
                ang = math.atan2(dy, dx) % (2 * math.pi)
                if a0 <= a1:
                    if not (a0 <= ang <= a1):
                        continue
                else:  # wrap
                    if not (ang >= a0 or ang <= a1):
                        continue
            cnt += 1
    return cnt / (N * N)


def draw_squircle_mask(size):
    """macOS icon squircle: continuous-corner rounded rect ~ 824/1024 with ~185.4/1024 corner radius.
    Use a superellipse (n~4.6) fitted to Apple's curve for good approximation."""
    n = 4.6
    half = size / 2.0
    inset = size * 0.0  # full canvas; we scale content later
    m = bytearray(size * size)
    cx = half
    for y in range(size):
        fy = abs((y + 0.5) - half) / half
        for x in range(size):
            fx = abs((x + 0.5) - half) / half
            v = (fx ** n + fy ** n) ** (1.0 / n)
            m[y * size + x] = 255 if v <= 1.0 else 0
    return m


def render(size):
    """Render the icon at given pixel size. Returns RGBA bytes + mask."""
    S = size
    img = [None] * (S * S)  # (r,g,b,a) premul-less straight alpha

    # --- geometry (relative coords, icon drawn in 824x824 box centered) ---
    box = S * 824.0 / 1024.0
    ox = (S - box) / 2.0
    oy = (S - box) / 2.0
    n_curv = 4.6
    half_b = box / 2.0
    bcx = ox + half_b
    bcy = oy + half_b

    # palette
    bg_dark = (24, 26, 34)  # deep navy charcoal
    bg_mid = (34, 38, 52)
    ring_glow = (64, 74, 108)

    # sunburst segment colors (vivid, DaisyDisk-like but original)
    seg_colors = [
        (231, 76, 60),    # red
        (230, 126, 34),   # orange
        (241, 196, 15),   # yellow
        (46, 204, 113),   # green
        (26, 188, 156),   # teal
        (52, 152, 219),   # blue
        (155, 89, 182),   # purple
        (223, 96, 129),   # pink
    ]

    # disc layout radii (relative to box)
    r_disc = box * 0.5
    r_rim_in = box * 0.44       # outer ring inner edge (the "data" ring zone)
    r_ring_out = r_disc * 0.985
    r_ring_in = r_rim_in
    r_pie = r_rim_in * 0.86     # inner pie
    r_hub = box * 0.045

    # segments for outer ring: 12 segments, sizes uneven (like real disk usage)
    seg_fracs = [0.16, 0.07, 0.11, 0.05, 0.14, 0.09, 0.06, 0.12, 0.04, 0.07, 0.05, 0.04]
    ring_start = -math.pi / 2 + 0.28  # start angle offset so it looks natural
    ring_segs = []
    acc = ring_start
    for i, f in enumerate(seg_fracs):
        a0 = acc
        a1 = acc + f * 2 * math.pi
        ring_segs.append((a0, a1, seg_colors[i % len(seg_colors)]))
        acc = a1
        # gap between segments
        acc += 0.012

    # inner pie: 3 slices
    pie_fracs = [(0.0, 0.42, seg_colors[5]), (0.42, 0.78, seg_colors[4]), (0.78, 1.0, seg_colors[1])]
    pie_start = -math.pi / 2 + 0.9

    # precompute per-pixel: inside squircle?
    def inside_squircle(px, py):
        fx = abs((px + 0.5) - bcx) / half_b
        fy = abs((py + 0.5) - bcy) / half_b
        if fx > 1.0 or fy > 1.0:
            return 0.0
        v = (fx ** n_curv + fy ** n_curv) ** (1.0 / n_curv)
        if v <= 0.94:
            return 1.0
        # smooth edge
        return max(0.0, min(1.0, (1.0 - v) / 0.06))

    # pixel loop
    inv = 1.0 / S
    for y in range(S):
        fy = (y + 0.5) * inv  # 0..1
        row = y * S
        for x in range(S):
            fx = (x + 0.5) * inv
            # map to box-local coords
            lx = (x + 0.5) - bcx
            ly = (y + 0.5) - bcy
            d = math.hypot(lx, ly)
            ang = math.atan2(ly, lx)

            mask = inside_squircle(x, y)
            if mask <= 0.0:
                img[row + x] = (0, 0, 0, 0)
                continue

            # default: radial gradient background (top-left light -> bottom-right dark)
            t = ((lx + ly) / box + 1.0) / 2.0
            r_, g_, b_ = mix(bg_mid, bg_dark, t)

            # subtle vertical sheen
            r_ += (1 - fy) * 6
            g_ += (1 - fy) * 6
            b_ += (1 - fy) * 8

            in_disc = d <= r_disc

            if in_disc:
                # --- disc face ---
                if d > r_ring_in:
                    # outer data ring zone
                    # find segment
                    a = (ang - ring_start) % (2 * math.pi)
                    f = a / (2 * math.pi)
                    sidx = -1
                    run = 0.0
                    for i, frac in enumerate(seg_fracs):
                        if f < run + frac + 0.006:
                            sidx = i
                            break
                        run += frac + 0.012
                    if sidx >= 0:
                        base = ring_segs[sidx][2]
                        # radial shading within ring
                        rr = (d - r_ring_in) / (r_ring_out - r_ring_in)
                        shade = 0.82 + 0.18 * rr
                        r_ = base[0] * shade
                        g_ = base[1] * shade
                        b_ = base[2] * shade
                        # top-light bevel
                        lt = max(0.0, (1.0 - fy) - 0.35) / 0.65
                        r_ += 26 * lt
                        g_ += 26 * lt
                        b_ += 26 * lt
                    # rim highlight at very outer edge
                    if d > r_ring_out - box * 0.012:
                        r_ = min(255, r_ + 38)
                        g_ = min(255, g_ + 38)
                        b_ = min(255, b_ + 42)
                else:
                    # inner zone: dark well + pie
                    well = mix((16, 18, 26), (28, 32, 46), d / r_ring_in)
                    r_, g_, b_ = well

                    if d <= r_pie:
                        a = (ang - pie_start) % (2 * math.pi)
                        f = a / (2 * math.pi)
                        for (f0, f1, col) in pie_fracs:
                            if f0 <= f < f1:
                                # gradient within slice
                                tt = (f - f0) / (f1 - f0)
                                base = mix(col, tuple(min(255, c + 34) for c in col), tt)
                                # radial shading
                                rr = d / r_pie
                                shade = 1.02 - 0.22 * rr
                                r_ = base[0] * shade
                                g_ = base[1] * shade
                                b_ = base[2] * shade
                                break

                    # hub
                    if d <= r_hub:
                        r_, g_, b_ = (245, 247, 252)
                    elif d <= r_hub * 1.6:
                        tt = (d - r_hub) / (r_hub * 0.6)
                        r_ = lerp(245, well[0], tt)
                        g_ = lerp(247, well[1], tt)
                        b_ = lerp(252, well[2], tt)

                    # inner ring separators (thin spokes) for tech feel
                    if r_hub * 2.0 < d < r_pie:
                        spoke = abs((ang * 6 / math.pi) % 2.0 - 1.0)
                        if spoke > 0.988:
                            r_ = min(255, r_ + 30)
                            g_ = min(255, g_ + 30)
                            b_ = min(255, b_ + 34)

                # disc edge darkening
                if d > r_disc * 0.93:
                    ed = (d - r_disc * 0.93) / (r_disc * 0.07)
                    r_ *= (1 - 0.35 * ed)
                    g_ *= (1 - 0.35 * ed)
                    b_ *= (1 - 0.38 * ed)

            # glass highlight sweep (top arc)
            hl_dy = ly + r_disc * 0.55
            hl = 0.0
            if abs(lx) < r_disc and abs(hl_dy) < r_disc * 0.5:
                # ellipse-ish highlight
                nx = lx / (r_disc * 0.86)
                ny = hl_dy / (r_disc * 0.30)
                e = nx * nx + ny * ny
                if e < 1.0 and ly < 0:
                    hl = (1.0 - e) ** 2 * 0.5
            r_ = min(255, r_ + 255 * hl * 0.10)
            g_ = min(255, g_ + 255 * hl * 0.10)
            b_ = min(255, b_ + 255 * hl * 0.13)

            img[row + x] = (clamp(r_), clamp(g_), clamp(b_), int(mask * 255))

    return img, S


def write_png(path, size, img):
    def chunk(typ, data):
        c = struct.pack(">I", len(data)) + typ + data
        c += struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)
        return c

    raw = bytearray()
    stride = size * 4
    for y in range(size):
        raw.append(0)  # filter none
        row = y * size
        for x in range(size):
            r, g, b, a = img[row + x]
            raw += bytes((r, g, b, a))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


print("rendering 1024 master ...")
img1024, S = render(1024)
write_png(os.path.join(ICONSET, "icon_512x512@2x.png"), 1024, img1024)

for size, name in [(512, "icon_512x512.png"), (256, "icon_256x256.png"),
                   (128, "icon_128x128.png"), (64, "icon_256x256@2x.png"),
                   (32, "icon_32x32.png"), (16, "icon_16x16.png")]:
    print(f"rendering {name} ...")
    # downscale from master by box-averaging
    k = 1024 // size
    out = [None] * (size * size)
    for y in range(size):
        for x in range(size):
            r = g = b = a = 0
            for sy in range(k):
                row = (y * k + sy) * 1024
                for sx in range(k):
                    pr, pg, pb, pa = img1024[row + x * k + sx]
                    r += pr; g += pg; b += pb; a += pa
            n = k * k
            out[y * size + x] = (r // n, g // n, b // n, a // n)
    write_png(os.path.join(ICONSET, name), size, out)
    print(f"  -> {name}")

# export sizes needed by asset catalog: 16,32,64,128,256,512,1024
needed = {
    16: "icon_16x16.png", 32: "icon_32x32.png", 64: "icon_32x32@2x.png",
    128: "icon_128x128.png", 256: "icon_128x128@2x.png",
    256: "icon_256x256.png", 512: "icon_256x256@2x.png",
    512: "icon_512x512.png", 1024: "icon_512x512@2x.png",
}
print("done:", ICONSET)
