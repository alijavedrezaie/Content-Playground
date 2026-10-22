"""Build the hosted app, standalone HTML, and downloadable ZIP (Python 3)."""

from pathlib import Path
import shutil
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src"
DIST = ROOT / "dist"
STANDALONE = ROOT / "outputs" / "Content Playground"
RELEASES = ROOT / "outputs" / "releases"


def main():
    for directory in (DIST, STANDALONE, RELEASES):
        directory.mkdir(parents=True, exist_ok=True)

    for name in ("index.html", "style.css", "app.js"):
        shutil.copyfile(SOURCE / name, DIST / name)

    html = (SOURCE / "index.html").read_text(encoding="utf-8")
    html = html.replace(
        '<link rel="stylesheet" href="style.css">',
        "<style>" + (SOURCE / "style.css").read_text(encoding="utf-8") + "</style>",
    ).replace(
        '<script src="app.js"></script>',
        "<script>" + (SOURCE / "app.js").read_text(encoding="utf-8") + "</script>",
    )
    (STANDALONE / "Content Playground.html").write_text(html, encoding="utf-8")

    with ZipFile(RELEASES / "Content Playground.zip", "w", ZIP_DEFLATED) as archive:
        for name in ("Content Playground.html", "START HERE.txt"):
            archive.write(STANDALONE / name, arcname=name)

    print("Built dist/, standalone HTML, and release ZIP.")


if __name__ == "__main__":
    main()
