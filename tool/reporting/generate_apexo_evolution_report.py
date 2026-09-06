"""Generate the externally shareable Apexo Clinical Beta evolution report."""

from __future__ import annotations

from pathlib import Path

from reportlab.graphics.shapes import Circle, Drawing, Line, Rect, String
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    Flowable,
    Image,
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "output" / "pdf" / "Apexo_Clinical_Beta_Evolution_Report.pdf"
ICON = ROOT / "assets" / "app_icon_desktop.png"

PAGE_W, PAGE_H = A4

NAVY = colors.HexColor("#123047")
NAVY_2 = colors.HexColor("#1B425D")
BLUE = colors.HexColor("#1769E0")
CYAN = colors.HexColor("#13B8E7")
TEAL = colors.HexColor("#0D9488")
MINT = colors.HexColor("#DFF4EF")
SKY = colors.HexColor("#E8F3FF")
IVORY = colors.HexColor("#FBFAF6")
INK = colors.HexColor("#17252F")
SLATE = colors.HexColor("#53646E")
LINE_COLOR = colors.HexColor("#D7E2E6")
AMBER = colors.HexColor("#F4B740")
RED = colors.HexColor("#D95656")
WHITE = colors.white


def register_fonts() -> None:
    regular_candidates = [
        Path(r"C:\Windows\Fonts\segoeui.ttf"),
        ROOT / "assets" / "fonts" / "DejaVuSans.ttf",
        ROOT / "assets" / "fonts" / "readex.ttf",
    ]
    bold_candidates = [
        Path(r"C:\Windows\Fonts\segoeuib.ttf"),
        ROOT / "assets" / "fonts" / "readex-bold.ttf",
        ROOT / "assets" / "fonts" / "DejaVuSans.ttf",
    ]
    regular = next((path for path in regular_candidates if path.exists()), None)
    bold = next((path for path in bold_candidates if path.exists()), None)
    if regular is None or bold is None:
        raise FileNotFoundError("No suitable embedded report font was found")
    pdfmetrics.registerFont(TTFont("Apexo", regular))
    pdfmetrics.registerFont(TTFont("Apexo-Semibold", bold))
    pdfmetrics.registerFont(TTFont("Apexo-Bold", bold))
    pdfmetrics.registerFontFamily(
        "Apexo",
        normal="Apexo",
        bold="Apexo-Bold",
        italic="Apexo",
        boldItalic="Apexo-Bold",
    )


register_fonts()

styles = getSampleStyleSheet()
styles.add(
    ParagraphStyle(
        "CoverEyebrow",
        fontName="Apexo-Semibold",
        fontSize=9,
        leading=11,
        textColor=colors.HexColor("#A8E9F7"),
        spaceAfter=5 * mm,
        uppercase=True,
    )
)
styles.add(
    ParagraphStyle(
        "CoverTitle",
        fontName="Apexo-Bold",
        fontSize=28,
        leading=31,
        textColor=WHITE,
        spaceAfter=4 * mm,
    )
)
styles.add(
    ParagraphStyle(
        "CoverSub",
        fontName="Apexo",
        fontSize=12,
        leading=17,
        textColor=colors.HexColor("#D9EFF5"),
        spaceAfter=7 * mm,
    )
)
styles.add(
    ParagraphStyle(
        "H1",
        fontName="Apexo-Bold",
        fontSize=22,
        leading=26,
        textColor=NAVY,
        spaceAfter=3 * mm,
    )
)
styles.add(
    ParagraphStyle(
        "Deck",
        fontName="Apexo",
        fontSize=10.5,
        leading=15,
        textColor=SLATE,
        spaceAfter=7 * mm,
    )
)
styles.add(
    ParagraphStyle(
        "H2",
        fontName="Apexo-Bold",
        fontSize=13,
        leading=16,
        textColor=NAVY,
        spaceAfter=2 * mm,
    )
)
styles.add(
    ParagraphStyle(
        "Body",
        fontName="Apexo",
        fontSize=9,
        leading=13,
        textColor=INK,
        spaceAfter=2 * mm,
    )
)
styles.add(
    ParagraphStyle(
        "Small",
        fontName="Apexo",
        fontSize=7.6,
        leading=10.5,
        textColor=SLATE,
    )
)
styles.add(
    ParagraphStyle(
        "CardTitle",
        fontName="Apexo-Bold",
        fontSize=10.5,
        leading=13,
        textColor=NAVY,
        spaceAfter=1.5 * mm,
    )
)
styles.add(
    ParagraphStyle(
        "CardBody",
        fontName="Apexo",
        fontSize=8.2,
        leading=11.2,
        textColor=INK,
    )
)
styles.add(
    ParagraphStyle(
        "Metric",
        fontName="Apexo-Bold",
        fontSize=20,
        leading=22,
        textColor=NAVY,
        alignment=TA_CENTER,
    )
)
styles.add(
    ParagraphStyle(
        "MetricLabel",
        fontName="Apexo",
        fontSize=7.4,
        leading=10,
        textColor=SLATE,
        alignment=TA_CENTER,
    )
)
styles.add(
    ParagraphStyle(
        "Status",
        fontName="Apexo-Semibold",
        fontSize=7.4,
        leading=9,
        textColor=WHITE,
        alignment=TA_CENTER,
    )
)
styles.add(
    ParagraphStyle(
        "Quote",
        fontName="Apexo-Semibold",
        fontSize=13,
        leading=18,
        textColor=NAVY,
        alignment=TA_LEFT,
    )
)


class AccentRule(Flowable):
    def __init__(self, width: float, color: colors.Color = CYAN):
        super().__init__()
        self.width = width
        self.height = 3
        self.color = color

    def draw(self) -> None:
        self.canv.setStrokeColor(self.color)
        self.canv.setLineWidth(2)
        self.canv.line(0, 1, self.width, 1)


def p(text: str, style: str = "Body") -> Paragraph:
    return Paragraph(text, styles[style])


def bullets(items: list[str], style: str = "CardBody") -> list[Paragraph]:
    return [
        Paragraph(f"<bullet>&#8226;</bullet>{item}", styles[style]) for item in items
    ]


def stat_card(value: str, label: str, tint: colors.Color = SKY) -> Table:
    table = Table(
        [[p(value, "Metric")], [p(label, "MetricLabel")]],
        colWidths=[42 * mm],
        rowHeights=[13 * mm, 11 * mm],
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), tint),
                ("BOX", (0, 0), (-1, -1), 0.6, LINE_COLOR),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4 * mm),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4 * mm),
                ("TOPPADDING", (0, 0), (-1, -1), 1 * mm),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 1 * mm),
            ]
        )
    )
    return table


def card(title: str, body: str, tint: colors.Color = WHITE, accent: colors.Color = CYAN) -> Table:
    content = [p(title, "CardTitle"), p(body, "CardBody")]
    table = Table([[content]], colWidths=[82 * mm])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), tint),
                ("BOX", (0, 0), (-1, -1), 0.6, LINE_COLOR),
                ("LINEBEFORE", (0, 0), (0, -1), 3, accent),
                ("LEFTPADDING", (0, 0), (-1, -1), 4 * mm),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4 * mm),
                ("TOPPADDING", (0, 0), (-1, -1), 4 * mm),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4 * mm),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]
        )
    )
    return table


def status_pill(label: str, color: colors.Color, width: float = 22 * mm) -> Table:
    table = Table([[p(label.upper(), "Status")]], colWidths=[width], rowHeights=[7 * mm])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), color),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 2 * mm),
                ("RIGHTPADDING", (0, 0), (-1, -1), 2 * mm),
                ("TOPPADDING", (0, 0), (-1, -1), 0),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
            ]
        )
    )
    return table


def section_title(number: str, title: str, deck: str) -> list:
    return [
        p(f"{number} / {title}", "H1"),
        AccentRule(26 * mm),
        Spacer(1, 3 * mm),
        p(deck, "Deck"),
    ]


def workflow_drawing() -> Drawing:
    d = Drawing(500, 82)
    x_positions = [48, 180, 312, 444]
    labels = ["Select patient", "Chart or plan", "Record outcome", "Review history"]
    sublabels = ["Searchable record", "Catalogue-driven", "One-click status", "Tooth-specific"]
    fills = [SKY, MINT, colors.HexColor("#FFF1D3"), colors.HexColor("#EDE9FE")]
    for index, x in enumerate(x_positions):
        if index < len(x_positions) - 1:
            d.add(Line(x + 32, 39, x_positions[index + 1] - 32, 39, strokeColor=LINE_COLOR, strokeWidth=2))
        d.add(Circle(x, 39, 25, fillColor=fills[index], strokeColor=WHITE, strokeWidth=3))
        d.add(Circle(x, 39, 25, fillColor=None, strokeColor=CYAN if index < 2 else TEAL, strokeWidth=1.2))
        d.add(String(x, 37, str(index + 1), fontName="Apexo-Bold", fontSize=13, fillColor=NAVY, textAnchor="middle"))
        d.add(String(x, 5, labels[index], fontName="Apexo-Semibold", fontSize=8.2, fillColor=INK, textAnchor="middle"))
        d.add(String(x, -7, sublabels[index], fontName="Apexo", fontSize=6.8, fillColor=SLATE, textAnchor="middle"))
    return d


def draw_first_page(canvas, doc) -> None:
    canvas.saveState()
    canvas.setFillColor(IVORY)
    canvas.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    canvas.setFillColor(NAVY)
    canvas.rect(0, PAGE_H - 103 * mm, PAGE_W, 103 * mm, fill=1, stroke=0)
    canvas.setFillColor(NAVY_2)
    canvas.circle(PAGE_W - 14 * mm, PAGE_H - 3 * mm, 63 * mm, fill=1, stroke=0)
    canvas.setFillColor(colors.HexColor("#0D5F82"))
    canvas.circle(PAGE_W - 4 * mm, PAGE_H - 7 * mm, 35 * mm, fill=1, stroke=0)
    canvas.setFillColor(CYAN)
    canvas.rect(0, PAGE_H - 105 * mm, PAGE_W, 2 * mm, fill=1, stroke=0)
    canvas.setFillColor(SLATE)
    canvas.setFont("Apexo", 7.5)
    canvas.drawString(17 * mm, 11 * mm, "Prepared for clinical feedback and migration planning")
    canvas.drawRightString(PAGE_W - 17 * mm, 11 * mm, "7 September 2026")
    canvas.restoreState()


def draw_later_page(canvas, doc) -> None:
    canvas.saveState()
    canvas.setFillColor(IVORY)
    canvas.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    canvas.setFillColor(NAVY)
    canvas.rect(0, PAGE_H - 15 * mm, PAGE_W, 15 * mm, fill=1, stroke=0)
    canvas.setFillColor(CYAN)
    canvas.rect(0, PAGE_H - 16 * mm, PAGE_W, 1 * mm, fill=1, stroke=0)
    if ICON.exists():
        canvas.drawImage(str(ICON), 15 * mm, PAGE_H - 12.2 * mm, 8 * mm, 8 * mm, mask="auto")
    canvas.setFillColor(WHITE)
    canvas.setFont("Apexo-Semibold", 8.5)
    canvas.drawString(26 * mm, PAGE_H - 9.3 * mm, "APEXO CLINICAL BETA")
    canvas.setFillColor(SLATE)
    canvas.setStrokeColor(LINE_COLOR)
    canvas.setLineWidth(0.5)
    canvas.line(15 * mm, 14 * mm, PAGE_W - 15 * mm, 14 * mm)
    canvas.setFont("Apexo", 7)
    canvas.drawString(15 * mm, 9 * mm, "Evolution from original Apexo 0.14.1")
    canvas.drawRightString(PAGE_W - 15 * mm, 9 * mm, f"{doc.page} / 5")
    if doc.page == 5:
        canvas.setFont("Apexo", 6.4)
        canvas.drawString(
            15 * mm,
            20 * mm,
            "This report covers the local clinical beta through 7 September 2026. It is a product and testing overview,",
        )
        canvas.drawString(
            15 * mm,
            16.8 * mm,
            "not a regulatory or production-readiness claim. Built on the original open-source Apexo 0.14.1 foundation.",
        )
    canvas.restoreState()


def cover_story() -> list:
    stats = Table(
        [[
            stat_card("0.14.1", "Original upstream baseline", colors.HexColor("#EEF3F5")),
            stat_card("0.15.0", "Clinical beta series", SKY),
            stat_card("279", "Treatments in Demo catalogue", MINT),
            stat_card("32", "Permanent teeth charted", colors.HexColor("#FFF1D3")),
        ]],
        colWidths=[43.5 * mm] * 4,
        hAlign="LEFT",
    )
    stats.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 2 * mm)]))

    summary = Table(
        [[
            [p("What this milestone is", "CardTitle"), p(
                "A focused clinical expansion of Apexo for a Greek dental practice: deeper chairside charting, more structured treatment planning, practical Google Calendar workflows and safer preparation for legacy DentalWin data.",
                "CardBody",
            )],
            [p("What it is not", "CardTitle"), p(
                "It is still a feedback beta. Full-clinic migration, the staff Android companion and multi-device treatment-plan synchronization remain deliberately outside the current release.",
                "CardBody",
            )],
        ]],
        colWidths=[87 * mm, 87 * mm],
    )
    summary.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, 0), SKY),
                ("BACKGROUND", (1, 0), (1, 0), colors.HexColor("#FFF3E3")),
                ("BOX", (0, 0), (-1, -1), 0.6, LINE_COLOR),
                ("INNERGRID", (0, 0), (-1, -1), 0.6, LINE_COLOR),
                ("LEFTPADDING", (0, 0), (-1, -1), 5 * mm),
                ("RIGHTPADDING", (0, 0), (-1, -1), 5 * mm),
                ("TOPPADDING", (0, 0), (-1, -1), 5 * mm),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5 * mm),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]
        )
    )

    return [
        Spacer(1, 2 * mm),
        Table(
            [[Image(str(ICON), 17 * mm, 17 * mm), p("APEXO / CLINICAL BETA", "CoverEyebrow")]],
            colWidths=[22 * mm, 145 * mm],
            style=TableStyle([("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 0)]),
        ),
        Spacer(1, 5 * mm),
        p("From practice management<br/>to a clinical workspace", "CoverTitle"),
        p(
            "A concise, externally shareable account of the capabilities added to the original open-source dental practice software - and the safeguards around what comes next.",
            "CoverSub",
        ),
        Spacer(1, 9 * mm),
        stats,
        Spacer(1, 9 * mm),
        summary,
        Spacer(1, 8 * mm),
        p(
            "The direction is intentionally practical: fewer clicks at the chair, richer clinical context, and migration that can be rehearsed before any real practice data is touched.",
            "Quote",
        ),
        Spacer(1, 4 * mm),
        AccentRule(42 * mm, TEAL),
    ]


def page_two() -> list:
    domains = [
        ("01", "Clinical odontogram", "Permanent dentition in three anatomical views, editable surfaces, layered treatment overlays, tooth-specific history and fast status buttons."),
        ("02", "Treatment planning", "Multiple alternatives, item and plan discounts, lab selection and cost snapshot, consent workflow, signed attachments and branded A4 patient PDFs."),
        ("03", "Periodontal chart", "Six sites per tooth, rapid auto-advance entry, PD/GM/CAL and clinical markers, lightweight graphs, plus completed and blank A4 charts."),
        ("04", "Appointments", "Work-week calendar, patient-aware entry, unassigned clinic appointments, 24-hour time and privacy-controlled Google Calendar synchronization."),
        ("05", "Practice operations", "Searchable therapy and expense catalogues, lab partners and procedure eligibility, plus a configurable shopping list with variants and urgency."),
        ("06", "Safer transition", "Disposable Demo workflows, portable USB Web pilot, read-only DentalWin analysis, deterministic staging and tightly capped rehearsal imports."),
    ]
    rows = []
    for i in range(0, len(domains), 2):
        row = []
        for number, title, body in domains[i : i + 2]:
            badge = Table([[p(number, "Status")]], colWidths=[10 * mm], rowHeights=[10 * mm])
            badge.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), BLUE), ("VALIGN", (0, 0), (-1, -1), "MIDDLE")]))
            inner = Table([[badge, [p(title, "CardTitle"), p(body, "CardBody")]]], colWidths=[13 * mm, 69 * mm])
            inner.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 2 * mm)]))
            row.append(inner)
        rows.append(row)
    table = Table(rows, colWidths=[88 * mm, 88 * mm], rowHeights=[45 * mm] * 3)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), WHITE),
                ("BOX", (0, 0), (-1, -1), 0.6, LINE_COLOR),
                ("INNERGRID", (0, 0), (-1, -1), 0.6, LINE_COLOR),
                ("LEFTPADDING", (0, 0), (-1, -1), 4 * mm),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4 * mm),
                ("TOPPADDING", (0, 0), (-1, -1), 5 * mm),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4 * mm),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]
        )
    )
    return [
        *section_title(
            "01",
            "What changed at a glance",
            "The fork keeps Apexo's original practice-management foundation, then adds a coherent clinical layer around the patient record.",
        ),
        table,
        Spacer(1, 7 * mm),
        Table(
            [[p("Design principle", "CardTitle"), p("Structured enough to support clinical history and migration, but fast enough for everyday chairside use.", "CardBody")]],
            colWidths=[38 * mm, 138 * mm],
            style=TableStyle([
                ("BACKGROUND", (0, 0), (-1, -1), MINT),
                ("BOX", (0, 0), (-1, -1), 0.6, colors.HexColor("#A8D8CF")),
                ("LEFTPADDING", (0, 0), (-1, -1), 4 * mm),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4 * mm),
                ("TOPPADDING", (0, 0), (-1, -1), 4 * mm),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4 * mm),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ]),
        ),
    ]


def page_three() -> list:
    clinical_left = [
        p("Odontogram", "H2"),
        *bullets([
            "All 32 permanent FDI teeth with facial, occlusal and oral anatomy.",
            "DentalWin-style surface square: select and later edit exact M/D/F/L/O surfaces.",
            "Procedure workflows for surfaces, whole tooth, bridge, removable and patient-level work.",
            "Selected-tooth history rail removes the need to scan the full event list.",
            "Planned and completed visual overlays for fillings, crowns, endodontics, extraction and implants.",
        ]),
    ]
    clinical_right = [
        p("Treatment planning", "H2"),
        *bullets([
            "Alternative plans can be compared without overwriting one another.",
            "Quantity, unit price, item discount and whole-plan discount are visible and auditable.",
            "Greek, English and German patient views with branded A4 PDF output.",
            "Lab partner and lab-cost snapshots stay attached to the planned procedure.",
            "Completion writes an immutable clinical event; it does not silently create a payment.",
        ]),
    ]
    two_col = Table([[clinical_left, clinical_right]], colWidths=[87 * mm, 87 * mm])
    two_col.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, 0), SKY),
        ("BACKGROUND", (1, 0), (1, 0), MINT),
        ("BOX", (0, 0), (-1, -1), 0.6, LINE_COLOR),
        ("INNERGRID", (0, 0), (-1, -1), 0.6, LINE_COLOR),
        ("LEFTPADDING", (0, 0), (-1, -1), 5 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 5 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5 * mm),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))

    perio = Table(
        [[
            [p("Periodontal chart", "H2"), p("Six measurements per tooth with rapid numeric entry and automatic advance. Records PD, GM and calculated CAL alongside bleeding, plaque, suppuration, mobility, furcation, missing teeth and implants.", "CardBody")],
            [p("Fast visual review", "H2"), p("Lightweight upper and lower pocket-depth graphs avoid a heavy charting dependency. A4 output supports both completed clinical records and a clean blank form for handwriting.", "CardBody")],
        ]],
        colWidths=[87 * mm, 87 * mm],
    )
    perio.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), WHITE),
        ("BOX", (0, 0), (-1, -1), 0.6, LINE_COLOR),
        ("INNERGRID", (0, 0), (-1, -1), 0.6, LINE_COLOR),
        ("LINEBEFORE", (0, 0), (0, 0), 3, TEAL),
        ("LINEBEFORE", (1, 0), (1, 0), 3, AMBER),
        ("LEFTPADDING", (0, 0), (-1, -1), 5 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 5 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5 * mm),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))

    return [
        *section_title(
            "02",
            "Chairside clinical workflow",
            "The most visible change is a connected path from tooth selection to treatment history, without forcing the clinician through separate lists.",
        ),
        workflow_drawing(),
        Spacer(1, 7 * mm),
        two_col,
        Spacer(1, 7 * mm),
        perio,
        Spacer(1, 5 * mm),
        p("Reserved, not shipped: the periodontal data model has a voice-token parsing seam, but microphone-driven pocket entry is intentionally not enabled in this beta.", "Small"),
    ]


def page_four() -> list:
    cards = [
        card("Appointments and Google Calendar", "Patient search and contact preview during entry; work-week view; unassigned clinic appointments; 24-hour time; manual and low-traffic automatic sync. Google titles and contact notes are explicitly configurable for privacy.", SKY, BLUE),
        card("Patient record and intake", "Responsive demographics, normalized contact search, unknown/import-review states and immutable medical-history revisions. A separate protected intake flow captures multilingual forms, signature and signed PDF without overwriting filled fields.", MINT, TEAL),
        card("Therapies and laboratories", "Editable groups and procedures, search, ordering, colours, durations and treatment-target rules. A lab-required flag keeps fillings and endodontics out of Labworks; eligible procedures can snapshot a chosen partner and cost.", colors.HexColor("#FFF4E0"), AMBER),
        card("Shopping and expenses", "A fully editable shopping list seeded from the supplied workbook supports categories, variants, quantity, notes and urgency. Red items surface in a separate urgent rail; medium priority is yellow. Expense orders can reuse a searchable item catalogue.", colors.HexColor("#F6EEFF"), colors.HexColor("#8B5CF6")),
    ]
    grid = Table([[cards[0], cards[1]], [cards[2], cards[3]]], colWidths=[88 * mm, 88 * mm], rowHeights=[57 * mm, 57 * mm])
    grid.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 2 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3 * mm),
    ]))

    theme_table = Table(
        [[
            p("Visual themes", "CardTitle"),
            p("Classic preserves the familiar look; Aegean, Sage and Warm Sand add coordinated light and dark surfaces. Clinical status colours remain stable, without a complex palette editor.", "CardBody"),
            status_pill("New", TEAL, 18 * mm),
        ]],
        colWidths=[33 * mm, 113 * mm, 28 * mm],
    )
    theme_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), WHITE),
        ("BOX", (0, 0), (-1, -1), 0.6, LINE_COLOR),
        ("LEFTPADDING", (0, 0), (-1, -1), 4 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 4 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4 * mm),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))

    return [
        *section_title(
            "03",
            "Everyday practice, connected",
            "The surrounding workflows were reshaped so clinical context, scheduling, laboratories and purchasing are easier to reach without turning Apexo into a heavyweight system.",
        ),
        grid,
        Spacer(1, 4 * mm),
        theme_table,
        Spacer(1, 7 * mm),
        p("Google Calendar scope", "H2"),
        p("Current two-way handling is intentionally limited to Apexo-managed events. Ordinary events created directly in Google Calendar still need the planned review-and-link workflow before they can safely become patient appointments.", "Body"),
    ]


def readiness_row(status: str, area: str, statement: str, color: colors.Color) -> list:
    return [status_pill(status, color), p(area, "CardTitle"), p(statement, "CardBody")]


def page_five() -> list:
    readiness = [
        readiness_row("Ready", "Clinical beta", "Odontogram, treatment planning, periodontal chart, catalogues, shopping and appointment refinements are available for focused feedback.", TEAL),
        readiness_row("Ready", "Portable rehearsal", "A clean USB Web template bundles local PocketBase, a dedicated browser profile, checksums and backup scripts. No patient data or credentials are distributed.", TEAL),
        readiness_row("Pilot", "DentalWin migration", "Read-only extraction, deterministic staging and capped loopback imports have been rehearsed. The writer remains limited to 5 patients and 2 appointments per patient.", AMBER),
        readiness_row("Planned", "Staff Android companion", "Agenda, patient lookup, tap-to-call, copy/paste and calendar review are designed but not implemented. The periodontal chart is intentionally excluded.", BLUE),
        readiness_row("Deferred", "Full production move", "Ambiguous appointments, primary teeth, files/images, financial history and medical activation require explicit reconciliation before any clinic-wide import.", RED),
    ]
    table = Table(
        readiness,
        colWidths=[31 * mm, 40 * mm, 105 * mm],
        rowHeights=[24 * mm] * len(readiness),
        repeatRows=0,
    )
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), WHITE),
        ("ROWBACKGROUNDS", (0, 0), (-1, -1), [WHITE, colors.HexColor("#F7FAFB")]),
        ("BOX", (0, 0), (-1, -1), 0.6, LINE_COLOR),
        ("INNERGRID", (0, 0), (-1, -1), 0.4, LINE_COLOR),
        ("LEFTPADDING", (0, 0), (-1, -1), 4 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 4 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4 * mm),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))

    numbers = Table(
        [[
            stat_card("5 / 10", "Phase 4 patients / appointments", SKY),
            stat_card("121", "Phase 5 historic treatment rows", MINT),
            stat_card("19", "Mapping v2 surface projections", colors.HexColor("#FFF1D3")),
            stat_card("2,452", "Calendar links requiring review", colors.HexColor("#FDE9E9")),
        ]],
        colWidths=[43.5 * mm] * 4,
    )
    numbers.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 2 * mm)]))

    close = Table(
        [[
            [p("Recommended next use", "CardTitle"), p("Run the portable beta with synthetic or backed-up test data, gather chairside feedback, then complete a formal migration rehearsal before authorizing any production write.", "CardBody")],
            [p("Safety position", "CardTitle"), p("The original DentalWin source stays read-only. Clinical surfaces are never guessed. Every staged record keeps provenance and deterministic identity for repeatable rollback and review.", "CardBody")],
        ]],
        colWidths=[87 * mm, 87 * mm],
    )
    close.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, 0), MINT),
        ("BACKGROUND", (1, 0), (1, 0), SKY),
        ("BOX", (0, 0), (-1, -1), 0.6, LINE_COLOR),
        ("INNERGRID", (0, 0), (-1, -1), 0.6, LINE_COLOR),
        ("LEFTPADDING", (0, 0), (-1, -1), 5 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5 * mm),
        ("TOPPADDING", (0, 0), (-1, -1), 5 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5 * mm),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))

    return [
        *section_title(
            "04",
            "Beta readiness and the safe path forward",
            "The project deliberately distinguishes what is usable today from what is only prepared, piloted or planned.",
        ),
        table,
        Spacer(1, 7 * mm),
        p("Migration rehearsal evidence", "H2"),
        numbers,
        Spacer(1, 7 * mm),
        close,
    ]


def build() -> Path:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        leftMargin=17 * mm,
        rightMargin=17 * mm,
        topMargin=24 * mm,
        bottomMargin=19 * mm,
        title="Apexo Clinical Beta - Evolution Report",
        author="Apexo Clinical Beta project",
        subject="Changes from original Apexo 0.14.1 through clinical beta 0.15.0",
        creator="Apexo report generator",
    )
    story = []
    story.extend(cover_story())
    story.append(PageBreak())
    story.extend(page_two())
    story.append(PageBreak())
    story.extend(page_three())
    story.append(PageBreak())
    story.extend(page_four())
    story.append(PageBreak())
    story.extend(page_five())
    doc.build(story, onFirstPage=draw_first_page, onLaterPages=draw_later_page)
    return OUTPUT


if __name__ == "__main__":
    print(build())
