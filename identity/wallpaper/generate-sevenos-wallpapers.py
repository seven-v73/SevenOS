#!/usr/bin/env python3
"""Generate the built-in SevenOS dynamic wallpaper collection."""

from __future__ import annotations

import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "identity/wallpaper/dynamic"
MANIFEST = OUT / "manifest.json"

FAMILIES = [
    {
        "key": "prism",
        "title": "Prism",
        "style": "liquid glass prism",
        "accent": "#6EA8FF",
        "secondary": "#8B7CFF",
        "shape": "prism",
    },
    {
        "key": "aurora",
        "title": "Aurora",
        "style": "soft spectral sky",
        "accent": "#33D6A6",
        "secondary": "#6EA8FF",
        "shape": "aurora",
    },
    {
        "key": "kente",
        "title": "Kente",
        "style": "woven geometric glow",
        "accent": "#FBBF24",
        "secondary": "#FB7185",
        "shape": "woven",
    },
    {
        "key": "orbit",
        "title": "Orbit",
        "style": "calm celestial depth",
        "accent": "#A78BFA",
        "secondary": "#38BDF8",
        "shape": "orbit",
    },
    {
        "key": "terra",
        "title": "Terra",
        "style": "mineral landscape",
        "accent": "#D8793C",
        "secondary": "#33D6A6",
        "shape": "landscape",
    },
]

MOMENTS = [
    ("dawn", "Dawn", "light", "#EAF3FF", "#BFD7F5", "#F4C7A1", "#6B83B7"),
    ("morning", "Morning", "light", "#F4F8FF", "#C8E8FF", "#A6D8C9", "#6384B7"),
    ("noon", "Noon", "light", "#F7FBFF", "#DDEBFA", "#8FC9FF", "#617EA8"),
    ("afternoon", "Afternoon", "balanced", "#DDE8F6", "#9FBEE4", "#DCA76E", "#38527A"),
    ("golden", "Golden", "balanced", "#F2D8A8", "#DA8F5A", "#6EA8FF", "#33283E"),
    ("dusk", "Dusk", "balanced", "#465076", "#2D355A", "#F472B6", "#10152A"),
    ("night", "Night", "dark", "#11111B", "#1B1F30", "#6EA8FF", "#050713"),
    ("midnight", "Midnight", "dark", "#060A17", "#10182B", "#8B7CFF", "#02040B"),
    ("mist", "Mist", "balanced", "#C8D6EA", "#7D91B6", "#94E2D5", "#273245"),
]

PROFILE_FAMILIES = [
    {
        "key": "equinox",
        "title": "Equinox",
        "role": "host, settings and balanced daily work",
        "accent": "#6EA8FF",
        "secondary": "#8B7CFF",
        "signal": "#94E2D5",
        "shape": "prism-hub",
    },
    {
        "key": "baobab",
        "title": "Baobab",
        "role": "African culture, memory and transmission",
        "accent": "#D6A13D",
        "secondary": "#2E8B6D",
        "signal": "#C94563",
        "shape": "roots",
    },
    {
        "key": "forge",
        "title": "Forge",
        "role": "development, services and deployment",
        "accent": "#7C7CFF",
        "secondary": "#4DA3FF",
        "signal": "#00D4FF",
        "shape": "circuit",
    },
    {
        "key": "shield",
        "title": "Shield",
        "role": "security, audit and forensics",
        "accent": "#2DD4BF",
        "secondary": "#38BDF8",
        "signal": "#A7F3D0",
        "shape": "shield",
    },
    {
        "key": "studio",
        "title": "Studio",
        "role": "creation, media and visual design",
        "accent": "#F472B6",
        "secondary": "#A78BFA",
        "signal": "#FBCFE8",
        "shape": "ribbons",
    },
    {
        "key": "atlas",
        "title": "Atlas",
        "role": "documents, maps, research and archives",
        "accent": "#38BDF8",
        "secondary": "#D6A13D",
        "signal": "#A7F3D0",
        "shape": "map",
    },
    {
        "key": "pulse",
        "title": "Pulse",
        "role": "gaming, performance and Linux play",
        "accent": "#F97316",
        "secondary": "#8B5CF6",
        "signal": "#22C55E",
        "shape": "wave",
    },
]

PROFILE_VARIANTS = [
    ("light", "Light", "light", "#F8FBFF", "#DCEBFA", "#8FB4E8", "#52657D"),
    ("soft", "Soft", "light", "#F3F7FC", "#D8E0EC", "#B8C7D9", "#4A596D"),
    ("neutral", "Neutral", "balanced", "#C9D3E2", "#7E91AA", "#8AA0BD", "#2D3748"),
    ("glass", "Glass", "balanced", "#B9C8DA", "#566982", "#91A7C2", "#1B2432"),
    ("dusk", "Dusk", "balanced", "#505A78", "#252E45", "#D58FB4", "#101726"),
    ("dark", "Dark", "dark", "#121826", "#0A101B", "#6EA8FF", "#030611"),
    ("deep", "Deep", "dark", "#070B14", "#111727", "#A78BFA", "#01030A"),
]


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    raw = value.lstrip("#")
    return int(raw[0:2], 16), int(raw[2:4], 16), int(raw[4:6], 16)


def mix(a: str, b: str, amount: float) -> str:
    ar, ag, ab = hex_to_rgb(a)
    br, bg, bb = hex_to_rgb(b)
    return "#%02X%02X%02X" % (
        round(ar + (br - ar) * amount),
        round(ag + (bg - ag) * amount),
        round(ab + (bb - ab) * amount),
    )


def wave_path(seed: int, y: int, height: int, amplitude: int) -> str:
    points = []
    for index in range(9):
        x = -80 + index * 270
        dy = math.sin(index * 1.23 + seed) * amplitude
        points.append((x, y + dy))
    path = f"M {points[0][0]} {points[0][1]:.1f}"
    for index in range(1, len(points), 2):
        p1 = points[index]
        p2 = points[min(index + 1, len(points) - 1)]
        path += f" C {p1[0]} {p1[1]:.1f}, {p1[0] + 110} {p1[1] - 40:.1f}, {p2[0]} {p2[1]:.1f}"
    path += f" L 2020 {height} L -80 {height} Z"
    return path


def seven_prism(cx: int, cy: int, r: int, accent: str, secondary: str, opacity: float = 0.55) -> str:
    points = []
    for index in range(6):
        angle = -math.pi / 2 + index * math.pi / 3
        points.append((cx + math.cos(angle) * r, cy + math.sin(angle) * r))
    polygon = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    spokes = "\n".join(
        f'<line x1="{cx}" y1="{cy}" x2="{x:.1f}" y2="{y:.1f}" stroke="{secondary}" stroke-opacity="{opacity * 0.38:.3f}" stroke-width="2"/>'
        for x, y in points
    )
    return f"""
    <g opacity="{opacity:.3f}">
      <polygon points="{polygon}" fill="#FFFFFF" fill-opacity="0.030" stroke="{accent}" stroke-opacity="0.45" stroke-width="2.4"/>
      {spokes}
      <circle cx="{cx}" cy="{cy}" r="{max(5, r // 13)}" fill="#FFFFFF" fill-opacity="0.55"/>
    </g>
    """


def style_layer(shape: str, accent: str, secondary: str, dark: str, seed: int) -> str:
    if shape == "aurora":
        return "\n".join(
            f'<path d="{wave_path(seed + i, 210 + i * 82, 1080, 60 + i * 8)}" fill="none" stroke="{mix(accent, secondary, i / 5)}" stroke-opacity="{0.18 - i * 0.018:.3f}" stroke-width="{42 - i * 3}" filter="url(#soft)"/>'
            for i in range(5)
        )
    if shape == "woven":
        lines = []
        for i in range(0, 1920, 120):
            color = accent if (i // 120) % 2 == 0 else secondary
            lines.append(f'<rect x="{i}" y="0" width="28" height="1080" fill="{color}" opacity="0.050"/>')
        for j in range(80, 1080, 150):
            lines.append(f'<path d="M0 {j} L1920 {j - 120}" stroke="{secondary}" stroke-opacity="0.075" stroke-width="18"/>')
        return "\n".join(lines)
    if shape == "orbit":
        return "\n".join(
            f'<ellipse cx="{980 + i * 32}" cy="{520 - i * 24}" rx="{440 + i * 86}" ry="{130 + i * 24}" fill="none" stroke="{mix(accent, secondary, i / 4)}" stroke-opacity="{0.18 - i * 0.028:.3f}" stroke-width="2.2" transform="rotate({-18 + i * 8} 960 540)"/>'
            for i in range(5)
        )
    if shape == "landscape":
        return "\n".join(
            f'<path d="{wave_path(seed + i, 600 + i * 78, 1080, 64 - i * 6)}" fill="{mix(dark, accent, 0.10 + i * 0.08)}" opacity="{0.80 - i * 0.10:.3f}"/>'
            for i in range(4)
        )
    return seven_prism(960, 498, 245, accent, secondary, 0.52) + seven_prism(1540, 245, 112, secondary, accent, 0.24)


def profile_layer(shape: str, accent: str, secondary: str, signal: str, deep: str, seed: int) -> str:
    if shape == "roots":
        roots = []
        for index in range(9):
            x = 300 + index * 165
            bend = math.sin(seed + index * 0.75) * 62
            roots.append(
                f'<path d="M{x} 210 C{x + bend} 410,{x - bend * 0.7} 650,{x + 36} 980" '
                f'fill="none" stroke="{mix(accent, secondary, index / 10)}" stroke-opacity="{0.15 + index * 0.007:.3f}" stroke-width="{8 + index % 3}" stroke-linecap="round"/>'
            )
        canopy = "\n".join(
            f'<ellipse cx="{380 + i * 190}" cy="{260 + math.sin(seed + i) * 34:.1f}" rx="{160 + (i % 3) * 28}" ry="{72 + (i % 2) * 18}" fill="{mix(secondary, signal, i / 8)}" opacity="0.11" filter="url(#soft)"/>'
            for i in range(7)
        )
        return canopy + "\n" + "\n".join(roots)
    if shape == "circuit":
        paths = []
        for index in range(8):
            y = 170 + index * 104
            x1 = 180 + (index % 3) * 55
            x2 = 1650 - (index % 4) * 44
            paths.append(
                f'<path d="M{x1} {y} H{x2} Q{x2 + 70} {y} {x2 + 70} {y + 70}" fill="none" '
                f'stroke="{mix(accent, signal, index / 8)}" stroke-opacity="0.15" stroke-width="2.4"/>'
            )
            paths.append(f'<circle cx="{x1}" cy="{y}" r="5" fill="{signal}" opacity="0.38"/>')
        return "\n".join(paths) + seven_prism(1510, 760, 88, accent, secondary, 0.22)
    if shape == "shield":
        return f"""
        <path d="M960 170 C1135 230 1268 242 1388 260 C1360 585 1236 794 960 930 C684 794 560 585 532 260 C652 242 785 230 960 170Z"
              fill="{deep}" fill-opacity="0.18" stroke="{accent}" stroke-opacity="0.34" stroke-width="3"/>
        <path d="M960 244 L1210 326 C1182 580 1086 724 960 806 C834 724 738 580 710 326Z"
              fill="none" stroke="{signal}" stroke-opacity="0.18" stroke-width="2"/>
        {seven_prism(960, 520, 178, accent, secondary, 0.20)}
        """
    if shape == "ribbons":
        return "\n".join(
            f'<path d="M{-120 + i * 30} {210 + i * 88} C420 {60 + i * 78},850 {420 + math.sin(seed + i) * 120:.1f},2040 {170 + i * 68}" '
            f'fill="none" stroke="{mix(accent, secondary, i / 7)}" stroke-opacity="{0.22 - i * 0.018:.3f}" stroke-width="{34 - i * 2}" filter="url(#soft)"/>'
            for i in range(7)
        )
    if shape == "map":
        grid = []
        for x in range(120, 1840, 170):
            grid.append(f'<path d="M{x} 90 C{x - 60} 320,{x + 80} 650,{x - 30} 1010" stroke="{secondary}" stroke-opacity="0.070" stroke-width="1.8" fill="none"/>')
        for y in range(150, 1010, 130):
            grid.append(f'<path d="M90 {y} C440 {y - 80},980 {y + 90},1830 {y - 20}" stroke="{accent}" stroke-opacity="0.075" stroke-width="1.8" fill="none"/>')
        grid.append(seven_prism(1330, 415, 96, signal, accent, 0.24))
        return "\n".join(grid)
    if shape == "wave":
        waves = []
        for index in range(8):
            y = 240 + index * 84
            waves.append(
                f'<path d="M80 {y} C310 {y - 90},440 {y + 100},660 {y} S1010 {y - 90},1230 {y} S1580 {y + 100},1840 {y}" '
                f'fill="none" stroke="{mix(accent, signal, index / 8)}" stroke-opacity="{0.20 - index * 0.015:.3f}" stroke-width="{4 + index % 4}"/>'
            )
        return "\n".join(waves) + seven_prism(1680, 780, 76, secondary, signal, 0.20)
    return (
        seven_prism(960, 470, 250, accent, secondary, 0.36)
        + seven_prism(960, 470, 118, signal, accent, 0.25)
        + seven_prism(1540, 265, 88, secondary, signal, 0.18)
    )


def svg_for(family: dict, moment: tuple[str, str, str, str, str, str, str], index: int) -> str:
    moment_key, moment_title, tone, bg_a, bg_b, moment_accent, dark = moment
    accent = mix(family["accent"], moment_accent, 0.28)
    secondary = mix(family["secondary"], moment_accent, 0.18)
    deep = mix(dark, "#02040A", 0.45 if tone == "dark" else 0.16)
    surface = mix(bg_b, dark, 0.38 if tone == "light" else 0.62)
    seed = (index + 3) * 7
    layer = style_layer(family["shape"], accent, secondary, deep, seed)
    prism_opacity = 0.22 if family["shape"] == "prism" else 0.16
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="{bg_a}"/>
      <stop offset="46%" stop-color="{surface}"/>
      <stop offset="100%" stop-color="{deep}"/>
    </linearGradient>
    <radialGradient id="glowA" cx="18%" cy="12%" r="76%">
      <stop offset="0%" stop-color="{accent}" stop-opacity="0.44"/>
      <stop offset="55%" stop-color="{secondary}" stop-opacity="0.12"/>
      <stop offset="100%" stop-color="{deep}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowB" cx="86%" cy="18%" r="60%">
      <stop offset="0%" stop-color="{secondary}" stop-opacity="0.38"/>
      <stop offset="100%" stop-color="{deep}" stop-opacity="0"/>
    </radialGradient>
    <filter id="soft"><feGaussianBlur stdDeviation="34"/></filter>
    <filter id="grain" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.74" numOctaves="2" seed="{seed}"/>
      <feColorMatrix type="saturate" values="0"/>
      <feComponentTransfer><feFuncA type="table" tableValues="0 0.050"/></feComponentTransfer>
    </filter>
  </defs>
  <rect width="1920" height="1080" fill="url(#sky)"/>
  <rect width="1920" height="1080" fill="url(#glowA)"/>
  <rect width="1920" height="1080" fill="url(#glowB)"/>
  <circle cx="{1460 + (seed % 210)}" cy="{150 + (seed % 90)}" r="{95 + (seed % 40)}" fill="{moment_accent}" opacity="{0.20 if tone != 'dark' else 0.12}" filter="url(#soft)"/>
  {layer}
  <path d="{wave_path(seed, 810, 1080, 42)}" fill="{deep}" opacity="{0.32 if tone == 'light' else 0.56}"/>
  <path d="M100 880 C420 828,680 905,980 840 C1260 780,1510 850,1840 790" fill="none" stroke="{accent}" stroke-opacity="0.16" stroke-width="3"/>
  {seven_prism(1720, 820, 78, accent, secondary, prism_opacity)}
  <rect width="1920" height="1080" filter="url(#grain)" opacity="0.65"/>
</svg>
"""


def profile_svg_for(profile: dict, variant: tuple[str, str, str, str, str, str, str], index: int) -> str:
    variant_key, variant_title, tone, bg_a, bg_b, variant_accent, dark = variant
    accent = mix(profile["accent"], variant_accent, 0.20)
    secondary = mix(profile["secondary"], variant_accent, 0.16)
    signal = profile["signal"]
    deep = mix(dark, "#02040A", 0.50 if tone == "dark" else 0.20)
    surface = mix(bg_b, dark, 0.36 if tone == "light" else 0.60)
    seed = 401 + index * 13
    layer = profile_layer(profile["shape"], accent, secondary, signal, deep, seed)
    horizon_opacity = 0.30 if tone == "light" else 0.52
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="{bg_a}"/>
      <stop offset="48%" stop-color="{surface}"/>
      <stop offset="100%" stop-color="{deep}"/>
    </linearGradient>
    <radialGradient id="profileGlow" cx="22%" cy="12%" r="76%">
      <stop offset="0%" stop-color="{accent}" stop-opacity="0.40"/>
      <stop offset="55%" stop-color="{secondary}" stop-opacity="0.11"/>
      <stop offset="100%" stop-color="{deep}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="signalGlow" cx="84%" cy="18%" r="58%">
      <stop offset="0%" stop-color="{signal}" stop-opacity="0.26"/>
      <stop offset="100%" stop-color="{deep}" stop-opacity="0"/>
    </radialGradient>
    <filter id="soft"><feGaussianBlur stdDeviation="32"/></filter>
    <filter id="grain" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.68" numOctaves="2" seed="{seed}"/>
      <feColorMatrix type="saturate" values="0"/>
      <feComponentTransfer><feFuncA type="table" tableValues="0 0.042"/></feComponentTransfer>
    </filter>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <rect width="1920" height="1080" fill="url(#profileGlow)"/>
  <rect width="1920" height="1080" fill="url(#signalGlow)"/>
  <circle cx="{1460 + (seed % 180)}" cy="{150 + (seed % 120)}" r="{105 + seed % 70}" fill="{signal}" opacity="{0.14 if tone != 'dark' else 0.09}" filter="url(#soft)"/>
  {layer}
  <path d="{wave_path(seed, 785, 1080, 54)}" fill="{deep}" opacity="{horizon_opacity}"/>
  <path d="M115 890 C480 820,760 910,1050 825 C1325 750,1540 842,1835 760" fill="none" stroke="{accent}" stroke-opacity="0.16" stroke-width="3"/>
  <g opacity="{0.70 if tone == 'dark' else 0.52}">
    <line x1="960" y1="165" x2="960" y2="925" stroke="{signal}" stroke-opacity="0.055" stroke-width="1.4"/>
    <line x1="180" y1="540" x2="1740" y2="540" stroke="{accent}" stroke-opacity="0.055" stroke-width="1.4"/>
  </g>
  <rect width="1920" height="1080" filter="url(#grain)" opacity="0.62"/>
</svg>
"""


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    items = []
    counter = 0
    for family in FAMILIES:
        for moment in MOMENTS:
            counter += 1
            moment_key, moment_title, tone, *_rest = moment
            slug = f"{family['key']}-{moment_key}"
            title = f"{family['title']} {moment_title}"
            filename = f"{slug}.svg"
            (OUT / filename).write_text(svg_for(family, moment, counter), encoding="utf-8")
            items.append({
                "slug": slug,
                "title": title,
                "family": family["key"],
                "style": family["style"],
                "moment": moment_key,
                "tone": tone,
                "accent": family["accent"],
                "secondary": family["secondary"],
                "svg": filename,
            })
    for profile in PROFILE_FAMILIES:
        for variant in PROFILE_VARIANTS:
            counter += 1
            variant_key, variant_title, tone, *_rest = variant
            slug = f"{profile['key']}-{variant_key}"
            title = f"{profile['title']} {variant_title}"
            filename = f"{slug}.svg"
            (OUT / filename).write_text(profile_svg_for(profile, variant, counter), encoding="utf-8")
            items.append({
                "slug": slug,
                "title": title,
                "family": "mini-os",
                "profile": profile["key"],
                "role": profile["role"],
                "style": f"{profile['title']} identity wallpaper",
                "moment": variant_key,
                "tone": tone,
                "accent": profile["accent"],
                "secondary": profile["secondary"],
                "svg": filename,
            })
    MANIFEST.write_text(json.dumps({
        "schema": "sevenos.wallpaper.collection.v1",
        "title": "SevenOS Dynamic Wallpapers",
        "count": len(items),
        "base_count": len(FAMILIES) * len(MOMENTS),
        "mini_os_count": len(PROFILE_FAMILIES) * len(PROFILE_VARIANTS),
        "items": items,
    }, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(items)} wallpapers in {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
