#!/usr/bin/env python3
"""KinetMagicDisk App Icon v2 — DaisyDisk-class
设计目标(对照 DaisyDisk 观感,原创配色):
- 全幅深空渐变圆角方形(macOS squircle 遮罩由系统做,我们画满出血)
- 主体:一颗大"行星"圆盘 —— 上方柔光、下缘反光,立体感
- 圆盘 = 太阳图:6 个大扇区(16px 仍可辨),扇区间细缝露深色
- 中心亮核(hub)带高光,像星球地核透光
- 盘外一圈细白描边(1.5% 宽)+ 微弱外发光,把圆盘从背景里托出来
- 背景:对角深蓝→近黑渐变 + 左上柔光斑
色彩:靛蓝/青/品红/琥珀 四主色,亮度错开,小尺寸不糊
输出:1024 master → appiconset 全套(显式 sRGB)
"""
import math
import os
import struct
import zlib
import numpy as np

OUT_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ASSETSET = os.path.join(OUT_ROOT, "Resources", "Assets.xcassets", "AppIcon.appiconset")
os.makedirs(ASSETSET, exist_ok=True)

SIZE = 1024  # master
SS = 2       # supersample factor per axis (anti-alias)


def build(size: int) -> np.ndarray:
    n = size * SS
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    x = (x + 0.5) / SS  # pixel centers in master coords
    y = (y + 0.5) / SS

    cx = cy = size / 2.0
    dx = x - cx
    dy = y - cy
    d = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)  # -pi..pi

    img = np.zeros((n, n, 4), dtype=np.float64)

    # ---------- 1) 背景:对角渐变 深靛 #0B0E1A → #1C2340,左上柔光 ----------
    t = (x + y) / (2 * size)  # 0 左上 → 1 右下
    bg_top = np.array([13, 17, 34], dtype=np.float64)
    bg_bot = np.array([26, 32, 58], dtype=np.float64)
    for c in range(3):
        img[..., c] = bg_top[c] + (bg_bot[c] - bg_top[c]) * t
    # 左上柔光斑
    gx, gy = size * 0.22, size * 0.18
    gd = np.hypot(x - gx, y - gy) / (size * 0.85)
    glow = np.clip(1.0 - gd, 0, 1) ** 2.2
    for c in range(3):
        img[..., c] += glow * np.array([34, 44, 80])[c]
    # 右下更深,压出体积
    vg = np.clip((d - size * 0.42) / (size * 0.3), 0, 1) ** 1.8
    for c in range(3):
        img[..., c] *= (1.0 - 0.35 * vg)

    # ---------- 2) 圆盘几何 ----------
    R = size * 0.345          # 盘半径(含描边)
    disc = d <= R

    # 6 大扇区:面积感不均(模拟真实占用),全部 >40°,16px 不糊
    # (fraction, color) —— 亮度错开
    segs = [
        (0.30, (58, 106, 245)),   # 靛蓝 30%
        (0.22, (34, 200, 196)),   # 青   22%
        (0.18, (233, 84, 134)),   # 品红 18%
        (0.14, (245, 160, 64)),   # 琥珀 14%
        (0.10, (120, 92, 240)),   # 紫罗兰 10%
        (0.06, (74, 222, 128)),   # 绿    6%
    ]
    gap = math.radians(2.2)    # 扇区缝(露背景)
    start = -math.pi / 2 + math.radians(18)

    # 每像素所属扇区索引
    a = (ang - start) % (2 * math.pi)
    bounds = []
    acc = 0.0
    for f, _ in segs:
        bounds.append((acc * 2 * math.pi, (acc + f) * 2 * math.pi))
        acc += f
    # 缝隙:边界 ± gap/2 内 → 背景色
    in_gap = np.zeros_like(disc, dtype=bool)
    seg_idx = np.full(d.shape, -1, dtype=np.int32)
    for i, (a0, a1) in enumerate(bounds):
        m = (a >= a0 + gap / 2) & (a < a1 - gap / 2) & disc
        seg_idx[m] = i
        near_edge = (np.abs(a - a0) < gap / 2) | (np.abs(a - a1) < gap / 2)
        in_gap |= near_edge & disc

    # ---------- 3) 扇区着色:径向渐变 + 顶光 + 内阴影 ----------
    rr = np.clip(d / R, 0, 1)  # 0 中心 → 1 边缘
    for i, (f, base) in enumerate(segs):
        m = seg_idx == i
        if not m.any():
            continue
        base = np.array(base, dtype=np.float64)
        # 径向:内浅外深 → 内 1.18x,外 0.72x
        shade = 1.16 - 0.46 * rr[m]
        col = base[None, :] * shade[:, None]
        # 顶光:法线朝上的区域提亮(模拟上方光源)
        ny = -dy[m] / np.maximum(d[m], 1e-6)  # -1 下 → 1 上
        top = np.clip(ny, 0, 1) ** 1.5
        col += (top * 42)[:, None] * np.array([1.0, 1.0, 1.12])[None, :]
        # 底部环境反光(微弱青)
        bot = np.clip(-ny, 0, 1) ** 2
        col += (bot * 16)[:, None] * np.array([0.4, 0.9, 1.0])[None, :]
        img[m, :3] = col

    # 中心亮核:r < 0.30R,白热光晕
    hub = disc & (d < R * 0.30)
    hub_t = np.clip(1 - d[hub] / (R * 0.30), 0, 1) ** 1.4
    core = np.array([252, 253, 255], dtype=np.float64)
    img[hub, :3] = img[hub, :3] * (1 - hub_t)[:, None] + (core[None, :] * (0.55 + 0.45 * hub_t)[:, None])

    # 高光点(左上 10 点钟方向小椭圆高光,玻璃感)
    hx, hy = cx - R * 0.38, cy - R * 0.42
    hd = np.hypot((x - hx) * 1.5, (y - hy)) / (R * 0.30)
    hm = (hd < 1) & disc
    hs = np.clip(1 - hd[hm], 0, 1) ** 2 * 0.55
    img[hm, :3] += hs[:, None] * np.array([255, 255, 255])[None, :]

    # 盘缘内侧暗环(体积感)
    rim_in = disc & (d > R * 0.88)
    rim_t = np.clip((d[rim_in] - R * 0.88) / (R * 0.12), 0, 1) ** 1.5 * 0.35
    img[rim_in, :3] *= (1 - rim_t)[:, None]

    # ---------- 4) 盘外:细白描边 + 外发光 ----------
    edge_w = size * 0.008
    edge = (d > R - edge_w) & (d <= R)
    img[edge, :3] = np.array([235, 240, 250], dtype=np.float64) * 0.92
    # 外发光
    halo = (d > R) & (d < R * 1.35)
    ht = np.clip(1 - (d[halo] - R) / (R * 0.35), 0, 1) ** 2.4 * 0.5
    img[halo, :3] += ht[:, None] * np.array([120, 150, 255])[None, :]

    # ---------- 5) alpha:画满出血(macOS 自动裁 squircle) ----------
    img[..., 3] = 255

    # ---------- supersample downsample ----------
    img = img.reshape(size, SS, size, SS, 4).mean(axis=(1, 3))
    return np.clip(img, 0, 255).astype(np.uint8)


def chunk(typ, data):
    c = struct.pack(">I", len(data)) + typ + data
    return c + struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)


def write_png_srgb(path, size, flat):
    """flat: h*w*4 uint8 RGB — 显式写 sRGB chunk + gAMA,防色彩被 ASC 判 P3"""
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)  # color type 2 RGB
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"sRGB", b"\x00")            # perceptual
    png += chunk(b"gAMA", struct.pack(">I", 45455))
    raw = b"".join(b"\x00" + flat[y * size * 3:(y + 1) * size * 3].tobytes() for y in range(size))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


print("rendering 1024 master ...")
master = build(1024)
# 转 RGB flat
rgb = master[..., :3]

jobs = [
    (1024, "icon_512x512@2x.png"),
    (512, ["icon_512x512.png", "icon_256x256@2x.png"]),
    (256, ["icon_256x256.png", "icon_128x128@2x.png"]),
    (128, "icon_128x128.png"),
    (64, "icon_32x32@2x.png"),
    (32, "icon_32x32.png"),
    (16, "icon_16x16.png"),
]
for size, names in jobs:
    if isinstance(names, str):
        names = [names]
    # box downsample from master
    k = 1024 // size
    small = rgb.reshape(size, k, size, k, 3).mean(axis=(1, 3)).astype(np.uint8)
    flat = small.reshape(-1)
    for nm in names:
        write_png_srgb(os.path.join(ASSETSET, nm), size, flat)
        print(f"  -> {nm} ({size}px)")

# Contents.json 不变(文件名一致)
print("done:", ASSETSET)
