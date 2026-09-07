#!/usr/bin/env python
"""Build app.html from app.template.html, stamping in the version from version.txt.
    python build.py
Then upload app.html + version.txt to GitHub (madisonhypes/etc-schedule-maker).
"""
import pathlib, sys
ROOT = pathlib.Path(__file__).parent

def main():
    version = (ROOT / "version.txt").read_text(encoding="utf-8").strip() or "0.0.0"
    html = (ROOT / "app.template.html").read_text(encoding="utf-8").replace("__VERSION__", version)
    out = ROOT / "app.html"
    out.write_text(html, encoding="utf-8")
    size = out.stat().st_size
    print(f"Built app.html  v{version}  {size:,} bytes")
    if size < 40_000:
        print("WARNING: app.html is under 40 KB; the launcher rejects downloads that small (MIN_SIZE).", file=sys.stderr)

if __name__ == "__main__":
    main()
