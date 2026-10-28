#!/usr/bin/env python3
"""Genera informe_u6.pdf a partir de informe_u6.md (subconjunto de Markdown).

Soporta: '# ', '## ', listas '- ', negrita **texto** y codigo `texto`.
Uso: python scripts/generar_informe_pdf.py
"""
import re
from pathlib import Path

from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "informe_u6.md"
TARGET = ROOT / "informe_u6.pdf"


def escape(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def inline(text: str) -> str:
    text = escape(text)
    text = re.sub(r"`([^`]+)`", r'<font face="Courier" size="8">\1</font>', text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    return text


def build() -> None:
    title = ParagraphStyle(
        "title", fontName="Helvetica-Bold", fontSize=15, leading=17,
        alignment=TA_LEFT, spaceAfter=1,
    )
    subtitle = ParagraphStyle(
        "subtitle", fontName="Helvetica", fontSize=10, leading=12,
        textColor="#444444", spaceAfter=8,
    )
    body = ParagraphStyle(
        "body", fontName="Helvetica", fontSize=8.7, leading=10.6,
        spaceAfter=4,
    )
    bullet = ParagraphStyle(
        "bullet", parent=body, leftIndent=11, bulletIndent=2, spaceAfter=2,
    )

    story = []
    for raw in SOURCE.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if not line.strip():
            story.append(Spacer(1, 3))
        elif line.startswith("## "):
            story.append(Paragraph(inline(line[3:]), subtitle))
        elif line.startswith("# "):
            story.append(Paragraph(inline(line[2:]), title))
        elif line.startswith("- "):
            story.append(Paragraph(inline(line[2:]), bullet, bulletText="•"))
        else:
            story.append(Paragraph(inline(line), body))

    def footer(canvas, doc):
        canvas.saveState()
        canvas.setFont("Helvetica", 7)
        canvas.setFillColor("#777777")
        canvas.drawString(1.6 * cm, 1.1 * cm, "TP Unidad 6 · Food Store · borrador de referencia (2026-10-28)")
        canvas.drawRightString(A4[0] - 1.6 * cm, 1.1 * cm, f"Pagina {doc.page}")
        canvas.restoreState()

    doc = SimpleDocTemplate(
        str(TARGET), pagesize=A4,
        leftMargin=1.6 * cm, rightMargin=1.6 * cm,
        topMargin=1.4 * cm, bottomMargin=1.5 * cm,
        title="Informe TP Unidad 6 - Food Store",
        author="Equipo Food Store",
    )
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(f"OK -> {TARGET}")


if __name__ == "__main__":
    build()
