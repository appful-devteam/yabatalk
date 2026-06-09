#!/usr/bin/env python3
"""透過済み cutout PNG を imageset へ配置（リサイズ + 最適化）。

各 imageset は単一 PNG (<name>.png) を参照しているので上書きするだけ。
バンドル肥大を避けるため最長辺を MAXPX に縮小し、コンテンツの透明余白は
左右上下対称になるよう軽くトリム + 正方パディングして元の中央寄せを維持。

usage:
  python3 place.py <cutout.png> <name>          # 単体
  python3 place.py --batch <cutout_dir>         # dir 内 *_cut.png / *.png を name 推定で一括
"""
import sys
from pathlib import Path
from PIL import Image

ASSETS = Path("/Users/chisato/Desktop/apps/yabatalk/lovetalk/Assets.xcassets")
MAXPX = 640


def install(cut_path: str, name: str):
    im = Image.open(cut_path).convert("RGBA")
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    # 正方キャンバスに中央配置（10% 余白）
    side = int(max(im.size) * 1.12)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    if side > MAXPX:
        canvas = canvas.resize((MAXPX, MAXPX), Image.LANCZOS)
    target_dir = ASSETS / f"{name}.imageset"
    if not target_dir.is_dir():
        print(f"  !! imageset not found: {target_dir}", file=sys.stderr)
        return False
    out = target_dir / f"{name}.png"
    canvas.save(out, optimize=True)
    kb = out.stat().st_size // 1024
    print(f"  placed {name}  ({canvas.size[0]}px, {kb}KB)")
    return True


def derive_name(p: Path) -> str:
    stem = p.stem
    for suf in ("_cut", "_chroma"):
        if stem.endswith(suf):
            stem = stem[: -len(suf)]
    return stem


def main():
    args = sys.argv[1:]
    if args and args[0] == "--batch":
        d = Path(args[1])
        # 優先: *_cut.png。無ければ素の *.png
        cuts = sorted(d.glob("*_cut.png"))
        seen = {derive_name(c) for c in cuts}
        plain = [p for p in sorted(d.glob("*.png"))
                 if not p.stem.endswith(("_cut", "_chroma"))
                 and not p.stem.startswith("_")
                 and derive_name(p) not in seen]
        ok = 0
        for p in cuts + plain:
            if install(str(p), derive_name(p)):
                ok += 1
        print(f"placed {ok} assets")
    else:
        install(args[0], args[1])


if __name__ == "__main__":
    main()
