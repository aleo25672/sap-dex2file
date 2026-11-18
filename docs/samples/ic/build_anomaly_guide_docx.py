#!/usr/bin/env python3
"""Build docs/GL_ANOMALY_REPLICATION_GUIDE.docx.

Replication guide for the cases posted in the CAL system during this session.
Run from the repository root:

    python3 docs/samples/ic/build_anomaly_guide_docx.py
"""

from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Inches, Pt, RGBColor

ROOT = Path(__file__).resolve().parent
DOCS = ROOT.parents[1]
OUT = DOCS / "GL_ANOMALY_REPLICATION_GUIDE.docx"

NAVY = "1F4E79"
ALT = "F3F6F9"
WHITE = RGBColor(255, 255, 255)
BLACK = RGBColor(0x1A, 0x1A, 0x1A)
NAVY_RGB = RGBColor(0x1F, 0x4E, 0x79)
GRAY = RGBColor(0x55, 0x55, 0x55)
META = RGBColor(0x33, 0x33, 0x33)


def set_run_font(run, size=11, bold=False, color=None, name="Calibri"):
    run.font.name = name
    run._element.rPr.rFonts.set(qn("w:eastAsia"), name)
    run.font.size = Pt(size)
    run.bold = bold
    if color is not None:
        run.font.color.rgb = color


def add_para(doc, text, size=11, bold=False, space_after=8, space_before=0):
    paragraph = doc.add_paragraph()
    paragraph.paragraph_format.space_after = Pt(space_after)
    paragraph.paragraph_format.space_before = Pt(space_before)
    paragraph.paragraph_format.line_spacing = 1.08
    run = paragraph.add_run(text)
    set_run_font(run, size=size, bold=bold, color=BLACK)
    return paragraph


def shade_cell(cell, fill: str):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), fill)
    tc_pr.append(shd)


def set_cell_text(cell, text, size=8, bold=False, color=None, fill=None):
    cell.text = ""
    paragraph = cell.paragraphs[0]
    paragraph.paragraph_format.space_before = Pt(1)
    paragraph.paragraph_format.space_after = Pt(1)
    run = paragraph.add_run("" if text is None else str(text))
    set_run_font(run, size=size, bold=bold, color=color or BLACK)
    if fill:
        shade_cell(cell, fill)
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    mar = OxmlElement("w:tcMar")
    for edge in ("top", "left", "bottom", "right"):
        node = OxmlElement(f"w:{edge}")
        node.set(qn("w:w"), "60")
        node.set(qn("w:type"), "dxa")
        mar.append(node)
    tc_pr.append(mar)


def prevent_row_split(row):
    tr = row._tr
    tr_pr = tr.get_or_add_trPr()
    tr_pr.append(OxmlElement("w:cantSplit"))


def repeat_header(row):
    tr = row._tr
    tr_pr = tr.get_or_add_trPr()
    tr_pr.append(OxmlElement("w:tblHeader"))


def add_table(doc, headers, rows, font=8):
    table = doc.add_table(rows=1 + len(rows), cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = True
    for index, header in enumerate(headers):
        set_cell_text(table.rows[0].cells[index], header, size=font, bold=True, color=WHITE, fill=NAVY)
    repeat_header(table.rows[0])
    prevent_row_split(table.rows[0])
    for r_index, row in enumerate(rows):
        fill = ALT if r_index % 2 else "FFFFFF"
        for c_index, value in enumerate(row):
            set_cell_text(table.rows[r_index + 1].cells[c_index], value, size=font, fill=fill)
        prevent_row_split(table.rows[r_index + 1])
    doc.add_paragraph().paragraph_format.space_after = Pt(6)
    return table


def add_footer(section):
    footer = section.footer
    footer.is_linked_to_previous = False
    paragraph = footer.paragraphs[0]
    paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    run = paragraph.add_run("GL anomaly replication  ·  company 1710  ·  ")
    set_run_font(run, size=8, color=GRAY)
    fld_begin = OxmlElement("w:fldChar")
    fld_begin.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = " PAGE "
    fld_end = OxmlElement("w:fldChar")
    fld_end.set(qn("w:fldCharType"), "end")
    page_run = paragraph.add_run()
    set_run_font(page_run, size=8, color=GRAY)
    page_run._r.append(fld_begin)
    page_run._r.append(instr)
    page_run._r.append(fld_end)


def bullet(doc, text):
    paragraph = doc.add_paragraph(style="List Bullet")
    paragraph.paragraph_format.space_after = Pt(2)
    run = paragraph.add_run(text)
    set_run_font(run, size=11, color=BLACK)


def numbered(doc, steps):
    for index, step in enumerate(steps, start=1):
        paragraph = doc.add_paragraph()
        paragraph.paragraph_format.space_after = Pt(2)
        paragraph.paragraph_format.left_indent = Cm(0.75)
        run = paragraph.add_run(f"{index}. {step}")
        set_run_font(run, size=11, color=BLACK)


def case(doc, code, title, txn, posted, fields, steps, level=2):
    doc.add_heading(f"{code} — {title}", level=level)
    add_para(doc, f"Transaction: {txn}. {posted}")
    add_para(doc, "Data to enter", bold=True, space_after=4)
    add_table(doc, ["Field", "Value"], fields, font=9)
    add_para(doc, "Steps", bold=True, space_after=4)
    numbered(doc, steps)


def main() -> None:
    doc = Document()
    section = doc.sections[0]
    section.top_margin = Cm(1.6)
    section.bottom_margin = Cm(1.6)
    section.left_margin = Cm(1.5)
    section.right_margin = Cm(1.5)
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.orientation = 0
    add_footer(section)

    normal = doc.styles["Normal"]
    normal.font.name = "Calibri"
    normal.font.size = Pt(11)
    normal.font.color.rgb = BLACK
    for style_name, size in (("Heading 1", 16), ("Heading 2", 13), ("Heading 3", 12)):
        style = doc.styles[style_name]
        style.font.name = "Calibri"
        style.font.color.rgb = NAVY_RGB
        style.font.size = Pt(size)
        style.font.bold = True

    core = doc.core_properties
    core.title = "GL anomaly replication guide"
    core.subject = "Cases posted in company code 1710"
    core.category = "GL anomaly"

    title = doc.add_paragraph()
    title.paragraph_format.space_after = Pt(2)
    run = title.add_run("GL anomaly replication guide")
    set_run_font(run, size=22, bold=True, color=NAVY_RGB)

    subtitle = doc.add_paragraph()
    subtitle.paragraph_format.space_after = Pt(2)
    run = subtitle.add_run("Cases posted in the CAL system")
    set_run_font(run, size=14, color=NAVY_RGB)

    meta = doc.add_paragraph()
    meta.paragraph_format.space_after = Pt(12)
    run = meta.add_run(
        "Company code 1710 · chart of accounts YCOA · fiscal year 2026\n"
        "Manual journals are document type SA unless noted\n"
        "Document numbers are the numbers returned by the system"
    )
    set_run_font(run, size=10, color=META)

    doc.add_heading("1. Purpose", level=1)
    add_para(
        doc,
        "This is the step-by-step recipe for the cases posted in the CAL system. "
        "Each case names the SAP transaction, the fields and values to enter, the "
        "order of the steps, and the document number the system returned. The test "
        "script IDs (E01, D08, and the others) are the names used while the documents "
        "were created.",
    )
    add_para(
        doc,
        "The two intercompany resales of TG11, from company 1710 to company 1010, "
        "are already described in INTERCOMPANY_RESALE.docx. Section 8 below is only "
        "the replication outline and the document numbers.",
    )

    doc.add_heading("2. Accounts and fields used on every journal", level=1)
    add_table(
        doc,
        ["Item", "Value"],
        [
            ["Company code", "1710"],
            ["Currency", "USD"],
            ["Expense, tax-relevant", "52060000. Tax code I0. Cost center 17101101"],
            ["Expense, also tax-relevant", "54400000. Tax code I0. Cost center 17101101"],
            ["Other cost center, used on the purchase order", "17100100"],
            ["Revenue", "41000000. Tax code O0 (letter O, then zero). Profitability segment, profit center YB600"],
            ["Bank", "11002000. No tax code and no cost center"],
            ["US tax jurisdiction, when required", "CA00000000"],
            ["Tax procedure", "TAXUSJ. The code 00 (two zeros) does not exist"],
            ["Discount income, used on one payment", "70040000"],
            ["Vendor", "1000559, EVOLVER DOMESTIC SUPPLIER 1"],
            ["Posting keys, when the screen asks", "40 debit G/L, 50 credit G/L, 31 vendor credit, 25 vendor debit"],
        ],
    )
    add_para(
        doc,
        "FS219 on 52060000 is a check. Press Enter. FS214 on 54400000 requires tax code I0. "
        "KI235 means the line needs cost center 17101101. KI248 on revenue means the cost center "
        "is only statistical: open Prof. segment and enter profit center YB600. A parked FB50 "
        "document is completed with FBV0, or changed with FBV2 and then posted.",
    )

    doc.add_heading("3. How to recognize a manual journal", level=1)
    add_para(
        doc,
        "The extract I_GLAccountLineItemRawData has no single manual flag. Read the origin fields together.",
    )
    add_table(
        doc,
        ["Field", "Manual journal", "Sub-ledger or system posting"],
        [
            ["ReferenceDocumentType", "BKPF or BKPFF", "RMRP invoice, MKPF goods movement, VBRK billing"],
            ["AccountingDocumentType", "SA for these journals", "RE, WE, WA, DR, KZ, and similar"],
            ["AccountingDocCreatedByUser", "A person, in this session ARIA", "A batch, interface, or service user"],
            ["Transaction shown on the document", "FB50, FBS1, F-02, FB08, F.81", "MIRO, MIGO, VF01, F-53"],
        ],
    )
    add_para(
        doc,
        "SA alone is not proof. Confirm the rule on document 100000001 and on one invoice-driven "
        "journal before the test uses it. A manual posting can also be made inside a sub-ledger transaction.",
    )

    doc.add_heading("4. Catalog of posted journals", level=1)
    add_table(
        doc,
        ["Document", "Case", "What it shows", "Amount"],
        [
            ["100000001", "E01, D08", "Round 1,000.00 moved between two P&L accounts", "1,000.00"],
            ["100000002", "E09", "Patterned amount 111111", "111,111.00"],
            ["100000003", "F05", "Header text “plug to hit target”", "87.65"],
            ["100000004", "F04, F06", "No reference and no header text", "53.17"],
            ["100000005", "D07", "Revenue posted from a journal", "480.00"],
            ["100000006", "D03", "Cash posted from a journal", "320.47"],
            ["100000007", "D02", "Revenue debited", "275.40"],
            ["100000008", "B04, B05", "Document date 15.09.2026, posted 20.10.2026", "64.80"],
            ["100000009", "B01", "Posted on Saturday 17.10.2026", "41.20"],
            ["100000010", "B03", "Posted 30.10.2026, end of the period", "28.90"],
            ["100000011", "B09", "Posting date 15.11.2026", "19.40"],
            ["100000012 / 100000013", "F02", "31.10.2026 journal reversed on 02.11.2026", "73.15"],
            ["100000014 / 100000015", "F03", "Accrual reversed on 02.11.2026, no supplier invoice", "88.20"],
            ["100000016 / 100000017", "F07", "56.40 out on 21.10.2026 and back on 05.11.2026, not a reversal", "56.40"],
            ["100000018 / 019 / 020", "E06", "Same 62.37 on 21.10, 23.10, and 27.10.2026", "62.37"],
            ["100000021", "B07", "Special period 13", "33.25"],
            ["100000022", "D01", "Cash against revenue", "91.15"],
        ],
    )
    add_para(
        doc,
        "Every journal in this catalog is document type SA and has no approver. That is also case C02.",
    )

    doc.add_heading("5. How to post each journal", level=1)
    add_para(
        doc,
        "Each case below is one posting. The transaction is the SAP code to open. "
        "The table is the data to type. The numbered steps are the order. "
        "Unless the case says otherwise, the journal is FB50, company 1710, document type SA, "
        "currency USD, debit 52060000 and credit 54400000, tax code I0 and cost center 17101101 "
        "on both lines. Post only when the balance is 0.00.",
    )

    case(
        doc,
        "E01 and D08",
        "Round amount, and a P&L reclassification",
        "FB50",
        "Posted document 100000001. Both effects are in this one journal.",
        [
            ["Company code", "1710"],
            ["Document type", "SA"],
            ["Document date", "20.10.2026"],
            ["Posting date", "20.10.2026"],
            ["Currency", "USD"],
            ["Reference", "E01"],
            ["Line 1", "Debit 52060000, 1000.00, tax code I0, cost center 17101101"],
            ["Line 2", "Credit 54400000, 1000.00, tax code I0, cost center 17101101"],
        ],
        [
            "Open FB50 and enter the header fields.",
            "Enter the debit line, then the credit line. One of the two lines must be a debit.",
            "Post when the balance is 0.00.",
        ],
    )
    case(
        doc,
        "E09",
        "Patterned amount",
        "FB50",
        "Posted document 100000002.",
        [
            ["Company code / type / currency", "1710 / SA / USD"],
            ["Document date and posting date", "20.10.2026"],
            ["Reference", "E09"],
            ["Line 1", "Debit 52060000, 111111.00, tax code I0, cost center 17101101"],
            ["Line 2", "Credit 54400000, 111111.00, tax code I0, cost center 17101101"],
        ],
        ["Enter the header, then the two lines.", "Post when the balance is 0.00."],
    )
    case(
        doc,
        "F05",
        "Narrative that describes the entry",
        "FB50",
        "Posted document 100000003.",
        [
            ["Company code / type / currency", "1710 / SA / USD"],
            ["Document date and posting date", "20.10.2026"],
            ["Reference", "F05"],
            ["Header text", "plug to hit target"],
            ["Line 1", "Debit 52060000, 87.65, tax code I0, cost center 17101101"],
            ["Line 2", "Credit 54400000, 87.65, tax code I0, cost center 17101101"],
        ],
        ["Enter the header text exactly as shown.", "Post when the balance is 0.00."],
    )
    case(
        doc,
        "F04 and F06",
        "No reference and no description",
        "FB50",
        "Posted document 100000004.",
        [
            ["Company code / type / currency", "1710 / SA / USD"],
            ["Document date and posting date", "20.10.2026"],
            ["Reference", "Leave empty"],
            ["Header text", "Leave empty"],
            ["Line 1", "Debit 52060000, 53.17, tax code I0, cost center 17101101"],
            ["Line 2", "Credit 54400000, 53.17, tax code I0, cost center 17101101"],
        ],
        ["Do not type a reference or a header text.", "Post when the balance is 0.00."],
    )
    case(
        doc,
        "D07",
        "Revenue from a journal",
        "FB50",
        "Posted document 100000005.",
        [
            ["Company code / type / currency", "1710 / SA / USD"],
            ["Document date and posting date", "20.10.2026"],
            ["Reference", "D07"],
            ["Line 1", "Debit 54400000, 480.00, tax code I0, cost center 17101101"],
            ["Line 2", "Credit 41000000, 480.00, tax code O0 (letter O, then zero)"],
            ["Revenue assignment", "Prof. segment, profit center YB600. A cost center alone returns KI248"],
        ],
        [
            "Enter the debit line.",
            "On the revenue line, choose the button beside Prof. segment and enter YB600.",
            "Post when the balance is 0.00.",
        ],
    )
    case(
        doc,
        "D03",
        "Cash from a journal",
        "FB50",
        "Posted document 100000006.",
        [
            ["Company code / type / currency", "1710 / SA / USD"],
            ["Document date and posting date", "20.10.2026"],
            ["Reference", "D03"],
            ["Line 1", "Debit 11002000, 320.47. No tax code. No cost center. Value date 20.10.2026 if required"],
            ["Line 2", "Credit 54400000, 320.47, tax code I0, cost center 17101101"],
        ],
        ["Enter the bank line first.", "Enter the expense line.", "Post when the balance is 0.00."],
    )
    case(
        doc,
        "D02",
        "Posting against the normal balance",
        "FB50",
        "Posted document 100000007. Revenue is normally a credit. This journal debits it.",
        [
            ["Company code / type / currency", "1710 / SA / USD"],
            ["Document date and posting date", "20.10.2026"],
            ["Reference", "D02"],
            ["Line 1", "Debit 41000000, 275.40, tax code O0, profit center YB600 on the profitability segment"],
            ["Line 2", "Credit 54400000, 275.40, tax code I0, cost center 17101101"],
        ],
        ["Enter the revenue line as a debit.", "Enter the expense line as a credit.", "Post when the balance is 0.00."],
    )
    case(
        doc,
        "B04 and B05",
        "Backdated document",
        "FB50",
        "Posted document 100000008. The period stays 10 because the posting date is in October.",
        [
            ["Company code / type / currency", "1710 / SA / USD"],
            ["Document date", "15.09.2026"],
            ["Posting date", "20.10.2026"],
            ["Reference", "B05"],
            ["Lines", "Debit 52060000 and credit 54400000, 64.80, tax code I0, cost center 17101101"],
        ],
        ["Enter the document date and the posting date as two different dates.", "Post when the balance is 0.00."],
    )
    case(
        doc,
        "B01",
        "Weekend posting date",
        "FB50",
        "Posted document 100000009.",
        [
            ["Company code / type / currency", "1710 / SA / USD"],
            ["Document date and posting date", "17.10.2026, a Saturday"],
            ["Reference", "B01"],
            ["Lines", "Debit 52060000 and credit 54400000, 41.20, tax code I0, cost center 17101101"],
        ],
        ["Use the Saturday as both dates.", "Post when the balance is 0.00."],
    )
    case(
        doc,
        "B03",
        "Period-end posting",
        "FB50",
        "Posted document 100000010.",
        [
            ["Company code / type / currency", "1710 / SA / USD"],
            ["Document date and posting date", "30.10.2026"],
            ["Reference", "B03"],
            ["Lines", "Debit 52060000 and credit 54400000, 28.90, tax code I0, cost center 17101101"],
        ],
        ["Use the last Friday of October as both dates.", "Post when the balance is 0.00."],
    )
    case(
        doc,
        "B09",
        "Future posting date",
        "FB50",
        "Posted document 100000011. Period 11.",
        [
            ["Company code / type / currency", "1710 / SA / USD"],
            ["Document date and posting date", "15.11.2026"],
            ["Reference", "B09"],
            ["Lines", "Debit 52060000 and credit 54400000, 19.40, tax code I0, cost center 17101101"],
        ],
        ["Use the November date as both dates.", "Post when the balance is 0.00. If the period is not open, stop."],
    )
    case(
        doc,
        "F02",
        "Reversed in the next period",
        "FB50, then FB08",
        "Original document 100000012. Reversal document 100000013.",
        [
            ["FB50 company / type / currency", "1710 / SA / USD"],
            ["FB50 document date and posting date", "31.10.2026"],
            ["FB50 reference", "F02"],
            ["FB50 lines", "Debit 52060000 and credit 54400000, 73.15, tax code I0, cost center 17101101"],
            ["FB08 document", "100000012"],
            ["FB08 company code and fiscal year", "1710 / 2026"],
            ["FB08 reversal reason", "02"],
            ["FB08 posting date", "02.11.2026"],
        ],
        [
            "Post the journal in FB50 and note the document number.",
            "Open FB08 and enter that document, company 1710, and year 2026.",
            "Use reversal reason 02 and posting date 02.11.2026, then post.",
        ],
    )
    case(
        doc,
        "F03",
        "Accrual released with no invoice",
        "FBS1, then F.81",
        "Accrual document 100000014. Reversal document 100000015. Do not post a supplier invoice for 88.20.",
        [
            ["FBS1 company / type / currency", "1710 / SA / USD"],
            ["FBS1 document date and posting date", "31.10.2026"],
            ["FBS1 reference", "F03"],
            ["FBS1 header text", "Accrual released w/o rep"],
            ["FBS1 reversal reason", "02"],
            ["FBS1 reversal date", "02.11.2026"],
            ["FBS1 line 1", "Posting key 40, G/L 54400000, 88.20, tax code I0, cost center 17101101"],
            ["FBS1 line 2", "Posting key 50, G/L 52060000, 88.20, tax code I0, cost center 17101101"],
            ["F.81 company code", "1710"],
            ["F.81 document and fiscal year", "100000014 / 2026"],
            ["F.81 test run", "Off"],
        ],
        [
            "Open FBS1. FB50 does not store a reversal date.",
            "Enter the header, the reversal reason, the reversal date, and the two lines. Post.",
            "The reversal date on the header does not post the reversal. Open F.81, enter the document, and run it with the test run off.",
        ],
    )
    case(
        doc,
        "F07",
        "Round trip that is not a reversal",
        "FB50, twice",
        "October document 100000016. November document 100000017. Do not use FB08.",
        [
            ["Both journals, company / type / currency", "1710 / SA / USD"],
            ["First journal dates", "21.10.2026"],
            ["First journal reference", "F07A"],
            ["First journal lines", "Debit 52060000 and credit 54400000, 56.40, tax code I0, cost center 17101101"],
            ["Second journal dates", "05.11.2026"],
            ["Second journal reference", "F07B"],
            ["Second journal lines", "Debit 54400000 and credit 52060000, 56.40, tax code I0, cost center 17101101"],
        ],
        [
            "Post the October journal.",
            "Post a second journal in November with the debit and the credit swapped.",
            "Leave both documents unreversed.",
        ],
    )
    case(
        doc,
        "E06",
        "Same non-round amount on three dates",
        "FB50, three times",
        "Documents 100000018, 100000019, and 100000020.",
        [
            ["Each journal, company / type / currency", "1710 / SA / USD"],
            ["Reference on each journal", "E06"],
            ["Lines on each journal", "Debit 52060000 and credit 54400000, 62.37, tax code I0, cost center 17101101"],
            ["First dates", "21.10.2026"],
            ["Second dates", "23.10.2026"],
            ["Third dates", "27.10.2026"],
        ],
        [
            "Post the same two lines three times.",
            "On each journal, set the document date equal to the posting date.",
            "Keep the dates a few days apart. A gap of one month with the same text looks like a recurring entry.",
        ],
    )
    case(
        doc,
        "B07",
        "Special period",
        "F-02",
        "Posted document 100000021. FB50 derives the period from the posting date and will not offer period 13.",
        [
            ["Document date and posting date", "31.12.2026"],
            ["Posting period", "13"],
            ["Company code and fiscal year", "1710 / 2026"],
            ["Currency and document type", "USD / SA"],
            ["Reference", "B07"],
            ["First line", "Posting key 40, G/L 52060000, 33.25, tax code I0, cost center 17101101"],
            ["Second line", "Posting key 50, G/L 54400000, 33.25, tax code I0, cost center 17101101"],
        ],
        [
            "Open F-02 and enter the header, including period 13.",
            "Enter posting key 40 and account 52060000, then the amount and the assignments.",
            "Enter posting key 50 and account 54400000, then the amount and the assignments.",
            "Post when the balance is 0.00. If the system says period 13 is not open, stop.",
        ],
    )
    case(
        doc,
        "D01",
        "Cash against revenue",
        "FB50",
        "Posted document 100000022.",
        [
            ["Company code / type / currency", "1710 / SA / USD"],
            ["Document date and posting date", "21.10.2026"],
            ["Reference", "D01"],
            ["Line 1", "Debit 11002000, 91.15. No tax code. No cost center. Value date 21.10.2026 if required"],
            ["Line 2", "Credit 41000000, 91.15, tax code O0 (letter O, then zero), jurisdiction CA00000000"],
            ["Revenue assignment", "Prof. segment, profit center YB600"],
        ],
        [
            "Enter the bank debit.",
            "On the revenue line, use tax code O0. The code 00 is rejected: TAXUSJ 00 does not exist.",
            "Open Prof. segment and enter profit center YB600.",
            "Post when the balance is 0.00.",
        ],
    )

    doc.add_heading("6. Purchase-to-pay cases", level=1)
    add_para(
        doc,
        "These cases start from a purchase order. Post them in this order: the order, "
        "the goods receipt, then the invoice. The document numbers below are the ones "
        "returned in this session.",
    )

    doc.add_heading("Trading good posted to an asset", level=2)
    add_para(
        doc,
        "Posted purchase order 4500002196, goods receipt 5000003090 on 23.10.2026, "
        "and supplier invoice 5100001633 on 26.10.2026. The material is trading good TG11, "
        "which would otherwise be stock. Account assignment A puts the invoice value on the asset.",
    )
    case(
        doc,
        "Order",
        "ME21N",
        "ME21N",
        "Purchase order 4500002196.",
        [
            ["Vendor", "1000559"],
            ["Purchasing organization / group / company", "1710 / 001 / 1710"],
            ["Account assignment category", "A"],
            ["Material", "TG11"],
            ["Quantity and unit", "10 PC"],
            ["Net price", "13.50 USD"],
            ["Plant", "1710"],
            ["Asset", "600004"],
        ],
        [
            "Open ME21N and enter the header.",
            "Enter one item with account assignment A, material TG11, and asset 600004.",
            "Save. The order in this session was 10 PC, so the later invoice of 135.00 is 10 times 13.50.",
        ],
        level=3,
    )
    case(
        doc,
        "Receipt",
        "MIGO",
        "MIGO",
        "Material document 5000003090. Quantity 10 PC. Value 0.00.",
        [
            ["Transaction", "Goods receipt for purchase order"],
            ["Movement type", "101"],
            ["Purchase order", "4500002196"],
            ["Posting date", "23.10.2026"],
        ],
        [
            "Open MIGO, select goods receipt for the purchase order, movement 101.",
            "Enter the purchase order and check the quantity.",
            "Post. The receipt carries quantity and no value because the item is assigned to an asset.",
        ],
        level=3,
    )
    case(
        doc,
        "Invoice",
        "MIRO",
        "MIRO",
        "Invoice 5100001633. Header amount 135.00 USD. Tax 0.00.",
        [
            ["Company code", "1710"],
            ["Invoice date", "26.10.2026"],
            ["Reference", "INV.TG11.001"],
            ["Amount", "135.00"],
            ["Purchase order", "4500002196"],
            ["Tax code on the line", "I1"],
            ["Tax amount", "0.00"],
        ],
        [
            "Open MIRO in company 1710.",
            "Enter the header amount 135.00 and the purchase order.",
            "Keep the tax at 0.00 and post. The value is on asset 600004, not on stock.",
        ],
        level=3,
    )

    doc.add_heading("Cost center on the invoice differs from the purchase order", level=2)
    add_para(
        doc,
        "A valuated goods receipt posts the cost to the purchase-order cost center. "
        "MIRO then only clears the receipt, so a cost center typed on the invoice is ignored. "
        "That happened on purchase order 4500002197: goods receipt 5000003091 posted 40.00 USD.",
    )
    add_para(
        doc,
        "To keep the invoice cost center, the goods receipt must be non-valuated. "
        "Purchase order 4500002198 was created for this, cost center 17100100, amount 55.00 USD, "
        "GR non-valuated selected. Goods receipt 5000003092 was posted with no value. "
        "A later invoice, reference INV.OFF.SUPP.002, amount 250.00 USD, G/L 54400000, "
        "showed cost center 17101101 while the purchase order still showed 17100100. "
        "The purchase-order number and the posted invoice number for that 250.00 document "
        "were not recorded. Confirm those two numbers in ME23N and MIR4 before citing them. "
        "The steps below recreate the non-valuated pattern.",
    )
    case(
        doc,
        "Order",
        "ME21N",
        "ME21N",
        "Purchase order 4500002198. Cost center 17100100.",
        [
            ["Vendor", "1000559"],
            ["Purchasing organization / group / company", "1710 / 001 / 1710"],
            ["Account assignment category", "K"],
            ["Short text", "Office supplies"],
            ["Amount", "55.00 USD"],
            ["Plant", "1710"],
            ["G/L account", "54400000"],
            ["Cost center", "17100100"],
            ["Item Delivery tab", "GR non-valuated selected"],
        ],
        [
            "Open ME21N and enter a cost-center item.",
            "On the item Delivery tab, select GR non-valuated before you save.",
            "Save. Do not change the cost center later in ME22N.",
        ],
        level=3,
    )
    case(
        doc,
        "Receipt",
        "MIGO",
        "MIGO",
        "Material document 5000003092. Amount 0.00.",
        [
            ["Transaction", "Goods receipt for purchase order"],
            ["Movement type", "101"],
            ["Purchase order", "4500002198"],
        ],
        [
            "Post the goods receipt.",
            "Confirm the receipt amount is 0.00.",
            "Do not change the account assignment on the receipt.",
        ],
        level=3,
    )
    case(
        doc,
        "Invoice",
        "MIRO",
        "MIRO",
        "Reference INV.OFF.SUPP.002. Amount 250.00 USD. Cost center on the invoice 17101101.",
        [
            ["Company code", "1710"],
            ["Reference", "INV.OFF.SUPP.002"],
            ["Amount", "250.00"],
            ["Account assignment", "K"],
            ["G/L account", "54400000"],
            ["Cost center proposed from the order", "17100100"],
            ["Cost center to type on the invoice", "17101101"],
            ["Layout", "All information"],
        ],
        [
            "Open MIRO for the purchase order.",
            "Set the layout to All information. Scroll to Cost Center, or open the account-assignment icon.",
            "Replace 17100100 with 17101101. Leave the purchase order unchanged.",
            "Post, then display the invoice. The posted cost center must still be 17101101.",
        ],
        level=3,
    )

    doc.add_heading("Invoices reversed, then paid", level=2)
    add_para(
        doc,
        "Purchase order 4500002197, goods receipt 5000003091, value 40.00 USD. "
        "Two invoices were reversed in logistics and the financial items stayed open. "
        "Those open invoices were then paid. Stop after the first payment to leave the "
        "reversal items open. Continue through the clearing to reproduce the ledger as it ended.",
    )
    add_para(doc, "Documents returned in this session", bold=True, space_after=4)
    add_table(
        doc,
        ["Document", "Date", "What it did"],
        [
            ["4500002197", "—", "Purchase order. Valuated receipt of 40.00"],
            ["5000003091", "—", "Goods receipt, value 40.00"],
            ["5100001634 / 5100000009", "22.10.2026", "First invoice, reference INV.OFF.SUPP.001, vendor credit 40.00"],
            ["5100001635 / 5100000010", "22.10.2026", "Reversal. Vendor line posting key 21, net 38.80 in the clearing screen"],
            ["5100001636 / 5100000011", "23.10.2026", "Second invoice, same reference, vendor credit 40.00"],
            ["5100001637 / 5100000012", "23.10.2026", "Reversal. Vendor line posting key 21, net 38.80"],
            ["1500000005", "26.10.2026", "Payment of both invoices: vendor 80.00, bank 11002000 credit 77.60, discount 70040000 credit 2.40"],
            ["5100001638 / 5100000013", "28.10.2026", "Third invoice, 40.00, same reference"],
            ["1500000006", "—", "Payment of the third invoice. The bank split was not recorded"],
            ["100000024", "30.10.2026", "Journal: bank debit 80.00, vendor credit 80.00. No cash was received"],
            ["100000025", "30.10.2026", "Clearing of the refund against the reversal items. Discount 2.40 and 2.40- cancel"],
        ],
    )
    case(
        doc,
        "Order and receipt",
        "ME21N, then MIGO",
        "ME21N, then MIGO",
        "Purchase order 4500002197. Material document 5000003091, value 40.00.",
        [
            ["Vendor", "1000559"],
            ["Company code", "1710"],
            ["Purchasing organization / group", "1710 / 001"],
            ["Account assignment category", "K"],
            ["Cost center", "17100100"],
            ["Amount", "40.00 USD"],
            ["Goods receipt", "Valuated. Leave GR non-valuated blank"],
            ["MIGO movement", "101"],
        ],
        [
            "Create the purchase order in ME21N and save.",
            "Post the goods receipt in MIGO. The receipt value must be 40.00.",
        ],
        level=3,
    )
    case(
        doc,
        "First invoice and reversal",
        "MIRO, then MR8M",
        "MIRO, then MR8M",
        "Invoice 5100001634, financial document 5100000009. Reversal 5100001635, financial document 5100000010.",
        [
            ["MIRO company code", "1710"],
            ["Invoice date", "22.10.2026"],
            ["Reference", "INV.OFF.SUPP.001"],
            ["Amount", "40.00"],
            ["Purchase order", "4500002197"],
            ["MR8M document", "5100001634"],
            ["MR8M reversal date", "22.10.2026"],
        ],
        [
            "Post the invoice in MIRO.",
            "Reverse it in MR8M on the same day.",
            "The message “Please manually clear FI documents” means the logistics reversal exists and the vendor items are still open. Do not clear them.",
        ],
        level=3,
    )
    case(
        doc,
        "Second invoice and reversal",
        "MIRO, then MR8M",
        "MIRO, then MR8M",
        "Invoice 5100001636, financial document 5100000011. Reversal 5100001637, financial document 5100000012.",
        [
            ["MIRO company code", "1710"],
            ["Invoice date", "23.10.2026"],
            ["Reference", "INV.OFF.SUPP.001"],
            ["Amount", "40.00"],
            ["Purchase order", "4500002197"],
            ["MR8M document", "5100001636"],
            ["MR8M reversal date", "23.10.2026"],
        ],
        [
            "Post a second invoice for the same purchase order and the same reference.",
            "Reverse it in MR8M.",
            "Leave both financial reversals open.",
        ],
        level=3,
    )
    case(
        doc,
        "Pay the reversed invoices",
        "F-53",
        "F-53",
        "Payment 1500000005. Stop here to leave the reversal items open.",
        [
            ["Company code", "1710"],
            ["Vendor", "1000559"],
            ["Posting date", "26.10.2026"],
            ["Bank account", "11002000"],
            ["Items to select", "The two invoice credits, posting key 31, documents 5100000009 and 5100000011, 40.00 each"],
            ["Items to leave open", "The two reversals, posting key 21, documents 5100000010 and 5100000012"],
            ["Posted split", "Vendor 80.00, bank credit 77.60, discount account 70040000 credit 2.40"],
        ],
        [
            "Open F-53 for vendor 1000559.",
            "Select only the original invoice items. SAP still allows that payment after MR8M.",
            "Post. Documents 5100000010 and 5100000012 stay open. That is the unpaid-reversal fault.",
        ],
        level=3,
    )
    case(
        doc,
        "Third invoice and payment",
        "MIRO, then F-53",
        "MIRO, then F-53",
        "Invoice 5100001638, financial document 5100000013. Payment 1500000006. The bank split on this payment was not recorded.",
        [
            ["MIRO date", "28.10.2026"],
            ["Reference", "INV.OFF.SUPP.001"],
            ["Amount", "40.00"],
            ["Purchase order", "4500002197"],
            ["F-53 vendor and company", "1000559 / 1710"],
            ["F-53 item", "5100000013"],
        ],
        [
            "Post a third invoice in MIRO for the same purchase order.",
            "Pay that invoice in F-53.",
        ],
        level=3,
    )
    case(
        doc,
        "Journal that looks like a refund",
        "F-02",
        "F-02",
        "Document 100000024. No cash was received. Only payments 1500000005 and 1500000006 moved money.",
        [
            ["Document date and posting date", "30.10.2026"],
            ["Company code / type / currency", "1710 / SA / USD"],
            ["Line 1", "Posting key 40, G/L 11002000, 80.00. No tax code"],
            ["Line 2", "Posting key 31, vendor 1000559, 80.00"],
        ],
        [
            "Post the journal. The bank debit makes the account look reimbursed.",
            "The vendor line is a credit of 80.00. It is not a receipt from the vendor.",
        ],
        level=3,
    )
    case(
        doc,
        "Clear the reversals",
        "F-44",
        "F-44",
        "Clearing document 100000025. The two discount lines cancel, so no further discount remains.",
        [
            ["Vendor", "1000559"],
            ["Company code", "1710"],
            ["Amount on the selection screen", "Leave empty"],
            ["Select", "5100000010 and 5100000012, posting key 21, net 38.80 each, and the 80.00 vendor credit on 100000024"],
            ["Leave unselected", "Every other open item, including a 130.95 item that appeared in the list"],
            ["Difference", "2.40. That is the discount taken on payment 1500000005"],
            ["Difference line", "Posting key 50, account 70040000, 2.40"],
        ],
        [
            "Open F-44. Do not enter an amount.",
            "Select only the two reversal items and the 80.00 credit. The two reversals have the same sign, so they cannot clear each other.",
            "The difference is 2.40. Posting key 40 on that difference adds another 2.40 and turns it into 4.80. Use posting key 50 to 70040000.",
            "Post the clearing.",
        ],
        level=3,
    )

    doc.add_heading("7. Cases the ledger will not store", level=1)
    add_para(
        doc,
        "Do not try to post these. A normal document cannot produce them, or the system rejects them before saving.",
    )
    add_table(
        doc,
        ["Test", "Why it is not posted"],
        [
            ["A01, A02, A12, D12", "A journal must balance. One line cannot carry both a debit and a credit."],
            ["A03, A04, A05", "The document key and the account must exist before SAP saves."],
            ["B06", "SAP does not post a date in a closed period."],
            ["D11", "This system has no consolidation ledger with topside entries."],
            ["C04, C06, C09, C10, G05", "These need an authority matrix, an HR list, or an external target."],
            ["Account type forbidden by the document type", "SAP rejects the line. The conflict never reaches the journal."],
            ["Locked cost center", "SAP rejects the posting. A later lock does not rewrite the document."],
            ["Bank account on account assignment K", "A cost-center item accepts an expense account, not 11002000."],
        ],
    )
    add_para(
        doc,
        "D10, intercompany amounts that do not eliminate, is already in the resale documents. "
        "Do not post it again. Case 1 bills 203.76 EUR in company 1710 against a 270.00 USD "
        "purchase plus tax in company 1010. Case 2 matches the goods at 125.00 EUR and then "
        "differs by 23.75 EUR of tax on vendor invoice 5100001610.",
    )

    doc.add_heading("8. Intercompany resales, outline only", level=1)
    add_para(
        doc,
        "The full narrative, partners, and correlation are in INTERCOMPANY_RESALE.docx. "
        "The numbers to recreate are these.",
    )
    add_table(
        doc,
        ["Case", "Chain"],
        [
            ["Case 1, differences kept", "PO 4500002162, 10 PC at 27.00 USD, company 1010. Receipt 5000002991, 286.56 EUR. Billing 90005786, payer 10401010, 203.76 EUR, tax 0. Vendor invoice 5100001607, vendor 0017401710, 321.30 USD. The outgoing payment number was not recorded."],
            ["Case 2, same goods price", "PO 4500002164 from contract 4600000041 item 30, vendor 1000559, 5 PC at 13.50 USD. Receipt 5000003010. Invoice 5100001609, FI 5100000005, 67.50. Payment 1500000004. Sales order 6323, customer 10401010, 5 times 25.00 EUR. PO 4500002165, company 1010, vendor BP1710, 125.00 EUR. The sales order stores the purchase-order number. The purchase order does not store the sales-order number. Delivery 80006442, goods issue 4900008971. Receipt 5000003011. Billing 90005787, 125.00 EUR. Vendor invoice 5100001610, 148.75 EUR including 23.75 tax. Payment 1500000001. Receipt 1400000002."],
        ],
    )
    add_para(
        doc,
        "BP1710 is the vendor for plant 1710 because the supplier Plant field is 1710. "
        "0017401710 is the vendor for company 1710. Customer 10401010 is company 1010. "
        "Customer 10411010 is plant 1010. The generic map of those fields is the Business "
        "partner mapping section of the session readme.",
    )

    doc.add_heading("9. Rebuild", level=1)
    add_para(
        doc,
        "python3 docs/samples/ic/build_anomaly_guide_docx.py writes docs/GL_ANOMALY_REPLICATION_GUIDE.docx.",
    )

    doc.save(OUT)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
