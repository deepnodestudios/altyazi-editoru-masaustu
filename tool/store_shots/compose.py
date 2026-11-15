"""Masaüstü ekran görüntülerinden mobil tarzı tanıtım kartları üretir.

Kullanım:
  python tool/store_shots/compose.py <çıktı_klasörü> [Dil ...]

Girdi: build/store_shots/{TR,EN}/*.png (store_shots_test.dart üretir)
Çıktı: <çıktı_klasörü>/<Dil>/store-N.webp (1920x1080)
"""
import html
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / "build" / "store_shots"
COPY = json.loads((Path(__file__).parent / "copy.json").read_text(encoding="utf-8"))
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

SCENES = [
    "01_main", "02_language", "03_history", "04_preview",
    "05_compare", "06_settings", "07_features", "08_editor",
]
# Büyütülecek bölge (2560x1600 ekran görüntüsü koordinatları)
CALLOUTS = {
    "01_main": (185, 175, 1352, 282),
    "02_language": (120, 360, 1290, 700),
    "03_history": (1100, 225, 2550, 540),
    "04_preview": (430, 430, 2130, 880),
    "05_compare": (430, 400, 2130, 760),
    "06_settings": (1820, 600, 2420, 820),
    "07_features": (1320, 200, 2525, 560),
    "08_editor": (190, 100, 1112, 300),
}
RTL = {"Arapça", "İbranice"}
SRC_W, SRC_H = 2560, 1600

TEMPLATE = """<!doctype html><html><head><meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;700;800&family=Noto+Sans:wght@500;700;800&family=Noto+Sans+JP:wght@500;700;800&family=Noto+Sans+KR:wght@500;700;800&family=Noto+Sans+SC:wght@500;700;800&family=Noto+Sans+Thai:wght@500;700;800&family=Noto+Sans+Arabic:wght@500;700;800&family=Noto+Sans+Hebrew:wght@500;700;800&display=block" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:1920px;height:1080px;overflow:hidden;background:#0c0a16}
body{font-family:'Plus Jakarta Sans','Noto Sans','Noto Sans JP','Noto Sans KR','Noto Sans SC','Noto Sans Thai','Noto Sans Arabic','Noto Sans Hebrew',sans-serif;color:#fff;position:relative}
.bg{position:absolute;inset:0;
 background:
  radial-gradient(900px 700px at 22% 105%, rgba(124,58,237,.42), transparent 70%),
  radial-gradient(700px 520px at 92% 8%, rgba(219,39,119,.16), transparent 70%),
  radial-gradient(1200px 900px at 70% 70%, rgba(76,29,149,.30), transparent 72%),
  linear-gradient(160deg,#120f22 0%,#0c0a16 55%,#0e0a1c 100%)}
.rings{position:absolute;inset:0}
.text{position:absolute;top:96px;left:96px;width:640px}
.rtl .text{left:auto;right:96px;direction:rtl;text-align:right}
.pill{display:inline-flex;align-items:center;gap:12px;padding:10px 22px;border-radius:999px;
 background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.06);
 font-weight:700;font-size:24px;letter-spacing:.02em;color:#d8c8ff}
.pill i{width:10px;height:10px;border-radius:50%;background:#f472b6;box-shadow:0 0 12px #f472b6}
.count{position:absolute;top:108px;right:96px;font-size:26px;font-weight:500;color:rgba(255,255,255,.55)}
.rtl .count{right:auto;left:96px}
h1{margin-top:40px;font-weight:800;font-size:{FS}px;line-height:1.06;letter-spacing:-.02em}
h1 span{display:inline-block;white-space:nowrap}
h1 em{font-style:normal;background:linear-gradient(90deg,#c4b0ff 0%,#e9a8ee 55%,#f6a4cf 100%);
 -webkit-background-clip:text;background-clip:text;color:transparent}
p{margin-top:28px;font-size:30px;line-height:1.38;color:rgba(235,230,255,.72);font-weight:500;max-width:580px}
.win{position:absolute;top:150px;left:{WINX}px;width:{WINW}px;border-radius:14px;overflow:hidden;
 box-shadow:0 40px 90px rgba(0,0,0,.6),0 0 0 1px rgba(255,255,255,.10),0 0 120px rgba(124,58,237,.25)}
.bar{height:38px;background:#1b1a22;display:flex;align-items:center;padding:0 16px;gap:10px;
 font-family:'Segoe UI','Noto Sans',sans-serif;font-size:14px;color:rgba(255,255,255,.82)}
.bar .dot{width:16px;height:16px;border-radius:4px;background:linear-gradient(135deg,#3b82f6,#a855f7,#f43f5e)}
.bar .t{flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.bar .ctl{display:flex;gap:34px;font-size:15px;color:rgba(255,255,255,.75);padding-right:6px}
.win img{display:block;width:100%}
.call{position:absolute;bottom:{CALLB}px;left:{CALLX}px;padding:3px;border-radius:22px;
 background:linear-gradient(135deg,rgba(196,176,255,.95),rgba(244,114,182,.85));
 transform:rotate({ROT}deg);box-shadow:0 30px 70px rgba(0,0,0,.65),0 0 60px rgba(168,85,247,.35)}
.call .in{border-radius:19px;overflow:hidden;position:relative;width:{CW}px;height:{CH}px;background:#000}
.call img{position:absolute;left:{CIX}px;top:{CIY}px;width:{CIW}px}
</style></head>
<body class="{DIR}"><div class="bg"></div>
<svg class="rings" width="1920" height="1080"><g fill="none" stroke="rgba(255,255,255,.045)" stroke-width="2">
<circle cx="{RCX}" cy="1180" r="420"/><circle cx="{RCX}" cy="1180" r="640"/><circle cx="{RCX}" cy="1180" r="880"/><circle cx="{RCX}" cy="1180" r="1140"/></g></svg>
<div class="text"><div class="pill"><i></i>{TAG}</div>
<h1><span>{H1}</span><br><span>{H2}</span></h1><p>{SUB}</p></div>
<div class="count">{N} / 08</div>
<div class="win"><div class="bar"><div class="dot"></div><div class="t">{TITLE}</div><div class="ctl"><span>&#8212;</span><span>&#9744;</span><span>&#10005;</span></div></div>
<img src="{SHOT}"></div>
<div class="call"><div class="in"><img src="{SHOT}"></div></div>
<script>
function fit(){const h=document.querySelector('h1');let f=96;h.style.fontSize=f+'px';
const max=590;while(f>40&&[...h.children].some(s=>s.getBoundingClientRect().width>max)){f-=2;h.style.fontSize=f+'px';}}
fit();window.addEventListener('load',fit);document.fonts.ready.then(fit);
let n=0;const t=setInterval(()=>{fit();if(++n>20)clearInterval(t);},150);
</script>
</body></html>"""


def hl(s: str) -> str:
    s = html.escape(s)
    return re.sub(r"\{(.+?)\}", r"<em>\1</em>", s)


def build_html(lang: str, idx: int) -> str:
    tag, h1, h2, sub = COPY[lang][idx]
    scene = SCENES[idx]
    ui = "TR" if lang == "Türkçe" else "EN"
    shot = (SHOTS / ui / f"{scene}.png").as_uri()
    rtl = lang in RTL

    win_w = 1160
    win_x = 1920 - 96 - win_w + 40 if not rtl else 56
    x1, y1, x2, y2 = CALLOUTS[scene]
    cw = min(820, int((x2 - x1) * 0.62))
    c = cw / (x2 - x1)
    ch = int((y2 - y1) * c)
    if ch > 300:
        c = 300 / (y2 - y1)
        ch = 300
        cw = int((x2 - x1) * c)
    call_x = 70 if not rtl else 1920 - 70 - cw - 6
    longest = max(len(h1), len(re.sub(r"[{}]", "", h2)))
    fs = 92 if longest <= 13 else 80 if longest <= 17 else 68 if longest <= 22 else 58
    title = ("Starlight Cartographers.srt — "
             + ("AI Altyazı Çeviri & Editör" if ui == "TR" else "AI Subtitle Translator & Editor"))
    rep = {
        "{FS}": str(fs), "{WINX}": str(win_x), "{WINW}": str(win_w),
        "{CALLB}": "70", "{CALLX}": str(call_x), "{ROT}": "-1.2" if not rtl else "1.2",
        "{CW}": str(cw), "{CH}": str(ch),
        "{CIX}": str(-int(x1 * c)), "{CIY}": str(-int(y1 * c)), "{CIW}": str(int(SRC_W * c)),
        "{DIR}": "rtl" if rtl else "", "{RCX}": "380" if not rtl else "1540",
        "{TAG}": html.escape(tag), "{H1}": hl(h1), "{H2}": hl(h2), "{SUB}": hl(sub),
        "{N}": f"{idx + 1:02d}", "{TITLE}": html.escape(title), "{SHOT}": shot,
    }
    out = TEMPLATE
    for k, v in rep.items():
        out = out.replace(k, v)
    return out


def render(lang: str, idx: int, out_dir: Path, tmp: Path) -> Path:
    page = tmp / f"card_{idx}.html"
    page.write_text(build_html(lang, idx), encoding="utf-8")
    png = tmp / f"card_{idx}.png"
    subprocess.run([
        CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
        "--allow-file-access-from-files", "--force-device-scale-factor=1",
        "--window-size=1920,1080", "--virtual-time-budget=6000",
        f"--screenshot={png}", page.as_uri(),
    ], check=True, capture_output=True, timeout=120)
    dest = out_dir / lang / f"store-{idx + 1}.webp"
    dest.parent.mkdir(parents=True, exist_ok=True)
    Image.open(png).convert("RGB").save(dest, "WEBP", quality=86, method=6)
    return dest


def main():
    out_dir = Path(sys.argv[1])
    langs = sys.argv[2:] or [k for k in COPY if not k.startswith("_")]
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        for lang in langs:
            for i in range(8):
                d = render(lang, i, out_dir, tmp)
            print("ok", lang, flush=True)


if __name__ == "__main__":
    main()
