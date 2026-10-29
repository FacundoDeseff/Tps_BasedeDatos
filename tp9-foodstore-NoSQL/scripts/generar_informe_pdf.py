"""Exporta informe_tp9.html a informe_tp9.pdf usando Chrome/Edge headless.

Uso:
    python scripts/generar_informe_pdf.py
    python scripts/generar_informe_pdf.py --html informe_tp9.html --pdf informe_tp9.pdf

No requiere dependencias externas. Si pypdf esta instalado, informa la cantidad
de paginas del PDF generado (la consigna admite hasta 5, sin contar el codigo).
Si pymupdf esta instalado, agrega el pie de pagina con la numeracion.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TITULO = "TP9 - Unidad 7 - Food Store en MongoDB"
MATERIA = "Bases de Datos II - 2026"
AUTORES = "Facundo Deseff, Santino Godoy, Facundo Ramírez y Matías Vargas"

CANDIDATES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]


def find_browser() -> str:
    env = os.environ.get("CHROME_PATH") or os.environ.get("BROWSER_PATH")
    if env and Path(env).exists():
        return env
    for candidate in CANDIDATES:
        if Path(candidate).exists():
            return candidate
    for name in ("chrome", "msedge", "google-chrome", "chromium"):
        found = shutil.which(name)
        if found:
            return found
    raise SystemExit(
        "No se encontro Chrome ni Edge. Defini CHROME_PATH con la ruta al ejecutable."
    )


def build_pdf(browser: str, html: Path, pdf: Path) -> None:
    pdf.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="tp9-pdf-") as profile:
        cmd = [
            browser,
            "--headless=new",
            "--disable-gpu",
            "--disable-extensions",
            "--no-first-run",
            "--no-default-browser-check",
            "--no-pdf-header-footer",
            "--run-all-compositor-stages-before-draw",
            "--virtual-time-budget=3000",
            f"--user-data-dir={profile}",
            f"--print-to-pdf={pdf}",
            html.resolve().as_uri(),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0 and not pdf.exists():
        sys.stderr.write(result.stdout + "\n" + result.stderr)
        raise SystemExit(f"Chrome devolvio codigo {result.returncode} y no genero el PDF")
    if not pdf.exists():
        raise SystemExit("Chrome termino sin generar el PDF")


def stamp_footer(
    pdf: Path, left: str, right: str, title: str, author: str, subject: str
) -> bool:
    """Dibuja pie de pagina, numeracion y metadatos. Requiere pymupdf."""
    try:
        import pymupdf
    except ImportError:
        return False

    doc = pymupdf.open(str(pdf))
    meta = doc.metadata
    meta.update({"title": title, "author": author, "subject": subject})
    doc.set_metadata(meta)
    total = len(doc)
    margin = 42.5  # 15 mm
    gray = (0.48, 0.53, 0.60)
    rule = (0.84, 0.87, 0.90)
    for index, page in enumerate(doc, start=1):
        width, height = page.rect.width, page.rect.height
        page.draw_line(
            (margin, height - 26), (width - margin, height - 26), color=rule, width=0.5
        )
        page.insert_text(
            (margin, height - 18), left, fontname="helv", fontsize=7.2, color=gray
        )
        label = f"{right}  ·  Página {index} de {total}"
        text_width = pymupdf.get_text_length(label, fontname="helv", fontsize=7.2)
        page.insert_text(
            (width - margin - text_width, height - 18),
            label,
            fontname="helv",
            fontsize=7.2,
            color=gray,
        )
    tmp = pdf.with_suffix(".tmp.pdf")
    doc.save(str(tmp), garbage=3, deflate=True)
    doc.close()
    tmp.replace(pdf)
    return True


def page_count(pdf: Path) -> int | None:
    try:
        from pypdf import PdfReader
    except ImportError:
        return None
    return len(PdfReader(str(pdf)).pages)


def main() -> None:
    base = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Genera el PDF del informe TP9")
    parser.add_argument("--html", default=str(base / "informe_tp9.html"))
    parser.add_argument("--pdf", default=str(base / "informe_tp9.pdf"))
    parser.add_argument(
        "--no-footer",
        action="store_true",
        help="No agrega pie de pagina ni numeracion.",
    )
    args = parser.parse_args()

    html = Path(args.html)
    pdf = Path(args.pdf)
    if not html.exists():
        raise SystemExit(f"No existe el HTML de origen: {html}")

    browser = find_browser()
    build_pdf(browser, html, pdf)
    if not args.no_footer:
        stamp_footer(pdf, TITULO, MATERIA, TITULO, AUTORES, "Bases de Datos II - Unidad 7")

    pages = page_count(pdf)
    size_kb = pdf.stat().st_size / 1024
    if pages is None:
        print(f"PDF generado: {pdf} ({size_kb:.1f} KB)")
    else:
        print(f"PDF generado: {pdf} ({pages} paginas, {size_kb:.1f} KB)")
        if pages > 5:
            print("ADVERTENCIA: la consigna admite hasta 5 paginas sin contar el codigo.")


if __name__ == "__main__":
    main()
