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


def case(doc, code, title, posted, steps):
    doc.add_heading(f"{code} — {title}", level=2)
    add_para(doc, posted)
    for step in steps:
        bullet(doc, step)


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
    for style_name, size in (("Heading 1", 16), ("Heading 2", 13)):
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
        "This guide is the recipe for the cases posted in the CAL system so that a "
        "general-ledger anomaly test can find them. Each case is a normal SAP posting. "
        "The test script IDs (E01, D08, and the others) are the names used while the "
        "documents were created.",
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
        "Unless a step says otherwise, run FB50 in company 1710, document type SA, currency USD. "
        "Debit 52060000 and credit 54400000. Tax code I0 and cost center 17101101 on both lines. "
        "Post only when the balance is 0.00.",
    )

    case(
        doc,
        "E01 and D08",
        "Round amount, and a P&L reclassification",
        "Posted document 100000001. Both effects are in this one journal.",
        [
            "Dates 20.10.2026. Reference E01.",
            "Debit 52060000 and credit 54400000, amount 1000.00.",
            "One line must be a debit and the other a credit. Two credits do not balance.",
        ],
    )
    case(
        doc,
        "E09",
        "Patterned amount",
        "Posted document 100000002.",
        ["Dates 20.10.2026. Reference E09. Amount 111111.00 on both lines."],
    )
    case(
        doc,
        "F05",
        "Narrative that describes the entry",
        "Posted document 100000003.",
        ["Dates 20.10.2026. Reference F05. Header text: plug to hit target. Amount 87.65."],
    )
    case(
        doc,
        "F04 and F06",
        "No reference and no description",
        "Posted document 100000004.",
        ["Dates 20.10.2026. Leave the reference and the header text empty. Amount 53.17."],
    )
    case(
        doc,
        "D07",
        "Revenue from a journal",
        "Posted document 100000005.",
        [
            "Dates 20.10.2026. Reference D07. Amount 480.00.",
            "Debit 54400000 with tax code I0 and cost center 17101101.",
            "Credit 41000000 with tax code O0. Open Prof. segment and enter profit center YB600.",
            "Do not rely on a cost center alone for the revenue line. KI248 means the assignment is only statistical.",
        ],
    )
    case(
        doc,
        "D03",
        "Cash from a journal",
        "Posted document 100000006.",
        [
            "Dates 20.10.2026. Reference D03. Amount 320.47.",
            "Debit 11002000. Leave tax code and cost center empty. Value date 20.10.2026 if required.",
            "Credit 54400000 with tax code I0 and cost center 17101101.",
        ],
    )
    case(
        doc,
        "D02",
        "Posting against the normal balance",
        "Posted document 100000007. Revenue is normally a credit. This journal debits it.",
        [
            "Dates 20.10.2026. Reference D02. Amount 275.40.",
            "Debit 41000000, tax code O0, profitability segment profit center YB600.",
            "Credit 54400000, tax code I0, cost center 17101101.",
        ],
    )
    case(
        doc,
        "B04 and B05",
        "Backdated document",
        "Posted document 100000008.",
        [
            "Reference B05. Document date 15.09.2026. Posting date 20.10.2026. Amount 64.80.",
            "The posting period stays 10 because the posting date is in October.",
        ],
    )
    case(
        doc,
        "B01",
        "Weekend posting date",
        "Posted document 100000009.",
        ["Reference B01. Document date and posting date 17.10.2026, a Saturday. Amount 41.20."],
    )
    case(
        doc,
        "B03",
        "Period-end posting",
        "Posted document 100000010.",
        ["Reference B03. Document date and posting date 30.10.2026. Amount 28.90."],
    )
    case(
        doc,
        "B09",
        "Future posting date",
        "Posted document 100000011.",
        ["Reference B09. Document date and posting date 15.11.2026, period 11. Amount 19.40."],
    )
    case(
        doc,
        "F02",
        "Reversed in the next period",
        "Original document 100000012. Reversal document 100000013.",
        [
            "FB50. Reference F02. Document date and posting date 31.10.2026. Amount 73.15.",
            "Then FB08. Document 100000012, company 1710, fiscal year 2026.",
            "Reversal reason 02. Posting date 02.11.2026.",
        ],
    )
    case(
        doc,
        "F03",
        "Accrual released with no invoice",
        "Accrual document 100000014. Reversal document 100000015. Header text on the accrual: Accrual released w/o rep. Reference F03.",
        [
            "FBS1, not FB50. Document type SA. Document date and posting date 31.10.2026.",
            "Reversal reason 02 was stored on the posted document. Reversal date 02.11.2026. Amount 88.20.",
            "Posting key 40 on 54400000. Posting key 50 on 52060000. Tax code I0 and cost center 17101101.",
            "Do not post a supplier invoice for 88.20.",
            "The header stores the reversal date. It does not post the reversal by itself. Run F.81 for company 1710, document 100000014, fiscal year 2026, without the test run. The reversal posted was 100000015.",
        ],
    )
    case(
        doc,
        "F07",
        "Round trip that is not a reversal",
        "October document 100000016, reference F07A. November document 100000017, reference F07B. Do not use FB08.",
        [
            "First journal: dates 21.10.2026. Debit 52060000, credit 54400000, amount 56.40.",
            "Second journal: dates 05.11.2026. Debit 54400000, credit 52060000, amount 56.40.",
        ],
    )
    case(
        doc,
        "E06",
        "Same non-round amount on three dates",
        "Documents 100000018, 100000019, and 100000020. Reference E06. Amount 62.37.",
        [
            "Post the same two lines three times.",
            "Dates 21.10.2026, 23.10.2026, and 27.10.2026. Document date equals posting date on each journal.",
            "Keep the dates a few days apart. A gap of one month with the same text looks like a recurring entry and is excluded by that test.",
        ],
    )
    case(
        doc,
        "B07",
        "Special period",
        "Posted document 100000021.",
        [
            "Use F-02. FB50 derives the period from the posting date and will not offer period 13.",
            "Document date and posting date 31.12.2026. Period 13. Fiscal year 2026. Reference B07. Amount 33.25.",
            "Posting key 40 on 52060000. Posting key 50 on 54400000.",
            "If the system says period 13 is not open, stop. Do not change OB52 unless that is the intended setup.",
        ],
    )
    case(
        doc,
        "D01",
        "Cash against revenue",
        "Posted document 100000022.",
        [
            "Dates 21.10.2026. Reference D01. Amount 91.15.",
            "Debit 11002000. No tax code and no cost center. Value date 21.10.2026 if required.",
            "Credit 41000000. Tax code O0, the letter O then zero. Jurisdiction CA00000000.",
            "Open Prof. segment and enter profit center YB600.",
            "The code 00, two zeros, is rejected: TAXUSJ 00 does not exist in T007A.",
        ],
    )

    doc.add_heading("6. Purchase-to-pay cases", level=1)

    doc.add_heading("Trading good posted to an asset", level=2)
    add_para(
        doc,
        "Posted purchase order 4500002196, goods receipt 5000003090 on 23.10.2026, "
        "and supplier invoice 5100001633 on 26.10.2026. The receipt quantity is 10 PC "
        "and its value is 0.00. The invoice is 135.00 USD. Account assignment is A, so "
        "the value is on the asset. The material is trading good TG11, which would "
        "otherwise be stock. Vendor 1000559. Reference on the invoice screen was INV.TG11.001. "
        "Tax code on the invoice line was I1 and the tax amount was 0.00.",
    )
    bullet(doc, "ME21N. Vendor 1000559. Purchasing organization 1710, group 001, company 1710. Account assignment A. Material TG11. Plant 1710. Asset 600004.")
    bullet(doc, "The posted order was 10 PC, not 1 PC. The invoice amount 135.00 is 10 times 13.50.")
    bullet(doc, "MIGO, movement 101. The receipt carries quantity and no value.")
    bullet(doc, "MIRO in company 1710 for the purchase order. Header amount 135.00 when tax stays 0.00.")

    doc.add_heading("Cost center on the invoice differs from the purchase order", level=2)
    add_para(
        doc,
        "A valuated goods receipt posts the cost to the purchase-order cost center. "
        "MIRO then only clears the receipt, so a cost center typed on the invoice is ignored. "
        "That happened on purchase order 4500002197: goods receipt 5000003091 posted 40.00 USD, "
        "and invoice changes did not move the cost.",
    )
    add_para(
        doc,
        "Use a non-valuated goods receipt so the invoice posts the cost. Purchase order "
        "4500002198 was created for this, with cost center 17100100, amount 55.00 USD, and "
        "GR non-valuated selected. Goods receipt 5000003092 was posted with no value.",
    )
    add_para(
        doc,
        "A later invoice screen, reference INV.OFF.SUPP.002, amount 250.00 USD, account "
        "assignment K, G/L 54400000, showed cost center 17101101 while the purchase order "
        "still showed 17100100. The purchase-order number and the posted invoice number for "
        "that 250.00 document were not recorded. Confirm those two numbers in ME23N and MIR4 "
        "before citing them.",
    )
    bullet(doc, "ME21N. Account assignment K. Short text. Plant 1710. G/L 54400000. Cost center 17100100. On the item Delivery tab, select GR non-valuated.")
    bullet(doc, "MIGO, movement 101. The amount on the receipt must be 0.00. Do not change the account assignment.")
    bullet(doc, "MIRO. Layout All information. Scroll to Cost Center, or use the account-assignment icon. Replace 17100100 with 17101101. Do not change the purchase order in ME22N.")
    bullet(doc, "After posting, display the invoice. The cost center on the posted item must be 17101101. If it has returned to 17100100, the system did not keep the change.")

    doc.add_heading("Invoices reversed, then paid", level=2)
    add_para(
        doc,
        "Purchase order 4500002197, one goods receipt of 40.00 USD, material document "
        "5000003091. The logistics invoice history is two invoices and two reversals. "
        "The financial documents of the invoices stayed open and were paid.",
    )
    add_table(
        doc,
        ["Document", "Date", "What it did"],
        [
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
    add_para(
        doc,
        "MR8M reversal message “Please manually clear FI documents” means the logistics "
        "reversal exists and the vendor items are still open. SAP still allows F-53 to pay "
        "the original invoice, posting key 31. Do not select the reversal lines, posting key 21.",
    )
    add_para(
        doc,
        "Document 100000024 makes the bank look reimbursed. It is not a receipt from the "
        "vendor. In reality only 1500000005 and 1500000006 moved money. The two reversal "
        "items of 38.80 cannot clear each other because they have the same sign. They were "
        "cleared against the 80.00 vendor credit on 100000024. The 2.40 gap is the discount "
        "on the payment. Posting key 40 on that difference adds another 2.40 and turns it "
        "into 4.80. Posting key 50 to 70040000 offsets it. On 100000025 the two discount "
        "lines cancel, so no further discount remains.",
    )
    bullet(doc, "To reproduce the unpaid-reversal fault, stop after 1500000005. Leave 5100000010 and 5100000012 open.")
    bullet(doc, "To reproduce the ledger as it ended, also post the third invoice, pay it, post the 80.00 journal to the bank and the vendor, and clear with F-44.")
    bullet(doc, "F-44, vendor 1000559, company 1710. Do not enter an amount. Select only the two reversal items and the 80.00 credit. Do not select other invoices, including a 130.95 item that appeared in the open-item list.")

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
