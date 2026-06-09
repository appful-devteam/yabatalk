#!/usr/bin/env python3
"""rembg 背景除去ユーティリティ。

Codex image_gen は透過を出せず緑/単色背景を焼き込むため、生成後にこれで
背景を除去して透過 PNG にする。フワフワ毛のソフトエッジ保持のため
alpha-matting を使う。

usage: python3 cutout.py <in.png> <out.png>
       python3 cutout.py --batch <dir>   # dir 内の *.png を *_cut.png に
"""
import sys
from pathlib import Path
from rembg import remove, new_session
from PIL import Image

_SESSION = None


def session():
    global _SESSION
    if _SESSION is None:
        _SESSION = new_session("u2net")
    return _SESSION


def cutout(inp: str, out: str) -> tuple:
    im = Image.open(inp).convert("RGBA")
    try:
        res = remove(
            im,
            session=session(),
            alpha_matting=True,
            alpha_matting_foreground_threshold=240,
            alpha_matting_background_threshold=10,
            alpha_matting_erode_size=10,
        )
    except Exception as e:  # noqa: BLE001
        print(f"  alpha-matting failed ({e}); plain remove", file=sys.stderr)
        res = remove(im, session=session())
    res.save(out)
    return res.size, res.getchannel("A").getextrema(), res.getbbox()


def main():
    args = sys.argv[1:]
    if args and args[0] == "--batch":
        d = Path(args[1])
        for p in sorted(d.glob("*.png")):
            if p.stem.endswith("_cut"):
                continue
            o = p.with_name(p.stem + "_cut.png")
            size, ext, bbox = cutout(str(p), str(o))
            print(f"{p.name} -> {o.name}  size={size} alpha={ext} bbox={bbox}")
    else:
        inp, out = args[0], args[1]
        size, ext, bbox = cutout(inp, out)
        print(f"{inp} -> {out}  size={size} alpha={ext} bbox={bbox}")


if __name__ == "__main__":
    main()
