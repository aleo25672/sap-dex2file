#!/usr/bin/env python3
"""Build docs/OPEN_PERIODS_GUIDE.docx.

How finance periods, materials periods, and the asset year were opened
for company codes 1710 and 1010. Run from the repository root:

    python3 docs/samples/ic/build_period_guide_docx.py
"""

from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Inches, Pt, RGBColor
from docx.enum.table import WD_TABLE_ALIGNMENT

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parents[1] / "OPEN_PERIODS_GUIDE.docx"

NAVY = "1F4E79"
ALT = "F3F6F9"
WHITE = RGBColor(255, 255, 255)
BLACK = RGBColor(0x1A, 0x1A, 0x1A)
NAVY_RGB = RGBColor(0x1F, 0x4E, 0x79)
GRAY = RGBColor(0x55, 0x55, 0x55)


def set_run_font(run, size=11, bold=False, color=None, name="Calibri"):
    run.font.name = name
    run._element.rPr.rFonts.set(qn("w:eastAsia"), name)
    run.font.size = Pt(size)
    run.bold = bold
    if color is not None:
        run.font.color.rgb = color


def add_para(doc, text, size=11, bold=False, space_after=8):
    paragraph = doc.add_paragraph()
    paragraph.paragraph_format.space_after = Pt(space_after)
    paragraph.paragraph_format.line_spacing = 1.08
    run = paragraph.add_run(text)
    set_run_font(run, size=size, bold=bold, color=BLACK)
    return paragraph


def bullet(doc, text):
    paragraph = doc.add_paragraph(style="List Bullet")
    paragraph.paragraph_format.space_after = Pt(2)
    run = paragraph.add_run(text)
    set_run_font(run, size=11, color=BLACK)


def shade_cell(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
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
    run = paragraph.add_run(str(text))
    set_run_font(run, size=size, bold=bold, color=color or BLACK)
    if fill:
        shade_cell(cell, fill)


def add_table(doc, headers, rows, font=8):
    table = doc.add_table(rows=1 + len(rows), cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    for index, header in enumerate(headers):
        set_cell_text(table.rows[0].cells[index], header, size=font, bold=True, color=WHITE, fill=NAVY)
        tr_pr = table.rows[0]._tr.get_or_add_trPr()
        tr_pr.append(OxmlElement("w:tblHeader"))
    for r_index, row in enumerate(rows):
        fill = ALT if r_index % 2 else "FFFFFF"
        for c_index, value in enumerate(row):
            set_cell_text(table.rows[r_index + 1].cells[c_index], value, size=font, fill=fill)
    doc.add_paragraph().paragraph_format.space_after = Pt(6)
    return table


def add_footer(section):
    footer = section.footer
    footer.is_linked_to_previous = False
    paragraph = footer.paragraphs[0]
    paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    run = paragraph.add_run("Open periods  ·  company codes 1710 and 1010  ·  ")
    set_run_font(run, size=8, color=GRAY)
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = " PAGE "
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    page_run = paragraph.add_run()
    set_run_font(page_run, size=8, color=GRAY)
    page_run._r.append(begin)
    page_run._r.append(instr)
    page_run._r.append(end)


def main() -> None:
    doc = Document()
    section = doc.sections[0]
    section.top_margin = Cm(1.6)
    section.bottom_margin = Cm(1.6)
    section.left_margin = Cm(1.6)
    section.right_margin = Cm(1.6)
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    add_footer(section)

    normal = doc.styles["Normal"]
    normal.font.name = "Calibri"
    normal.font.size = Pt(11)
    normal.font.color.rgb = BLACK
    for name, size in (("Heading 1", 16), ("Heading 2", 13)):
        style = doc.styles[name]
        style.font.name = "Calibri"
        style.font.color.rgb = NAVY_RGB
        style.font.size = Pt(size)
        style.font.bold = True

    core = doc.core_properties
    core.title = "Open finance periods, materials periods, and the asset year"
    core.subject = "Company codes 1710 and 1010"
    core.category = "Period opening"

    title = doc.add_paragraph()
    title.paragraph_format.space_after = Pt(2)
    run = title.add_run("Open finance, materials, and asset periods")
    set_run_font(run, size=22, bold=True, color=NAVY_RGB)
    sub = doc.add_paragraph()
    sub.paragraph_format.space_after = Pt(10)
    run = sub.add_run("Company codes 1710 (United States) and 1010 (Germany)")
    set_run_font(run, size=14, color=NAVY_RGB)

    doc.add_heading("1. Three calendars", level=1)
    add_para(
        doc,
        "A posting date in October 2026 needs three calendars open in the company "
        "code that posts. They are independent. Finance can be open through 2030 "
        "while materials management is still in 2025 and Asset Accounting is still in 2019.",
    )
    add_table(
        doc,
        ["Calendar", "What it blocks", "Where you open it"],
        [
            ["Finance", "FI postings, including vendor invoices and payments", "OB52"],
            ["Materials", "Goods receipts and goods issues", "MMRV to read, MMPV to roll forward"],
            ["Asset", "Invoice value posted to a fixed asset", "OAAQ, AFAB, RAJABS00, FAGLGVTR"],
        ],
    )
    add_para(
        doc,
        "The asset invoice in company 1710 was blocked by the asset year, not by OB52. "
        "The message was: You cannot post to asset in company code 1710 fiscal year 2026. "
        "A goods receipt of an asset can succeed before the asset year is open. The value "
        "hits the asset at invoice verification.",
    )
    add_para(doc, "These transactions and programs are not in this system:", bold=True, space_after=4)
    bullet(doc, "AJRW")
    bullet(doc, "FAA_FISCAL_YEAR_CHANGE")
    bullet(doc, "RAJAWE00")
    add_para(
        doc,
        "Year-end closing is RAJABS00. It does not raise Highest F.Year. "
        "The step that raises Highest F.Year is FAGLGVTR.",
    )

    doc.add_heading("2. Finance posting periods — OB52", level=1)
    bullet(doc, "In SE16, table T001, read OPVAR for the company code. That is its posting period variant.")
    bullet(doc, "Run OB52 and find that variant.")
    bullet(doc, "For account types +, A, D, K, M, S, and V, the first interval must include the posting period. For a calendar year that is period 1 through 12 of the fiscal year. The second interval is special periods 13 through 16.")
    add_para(
        doc,
        "Company code 1010 uses variant 1010. Every account type was already open from "
        "period 1 / 2000 through period 12 / 2030, and special periods 13 / 2000 through "
        "16 / 2030. 2026 is inside that range, so OB52 was left unchanged.",
    )
    add_para(
        doc,
        "Check company code 1710 the same way before relying on it. The asset invoice "
        "in 1710 was not an OB52 problem.",
    )

    doc.add_heading("3. Materials period — MMRV, then MMPV", level=1)
    bullet(doc, "Run MMRV for the company code. Current period is the open materials period. Previous period is also open when Allow posting to previous per. is selected.")
    bullet(doc, "A goods movement whose posting date is outside those two periods is rejected.")
    bullet(doc, "In MMPV, enter the company code in From and To. Enter the period after the one MMRV shows as current, and its fiscal year. That entry becomes the new current period. Leave Date empty. Select Close period. Execute.")
    bullet(doc, "Example: MMRV shows 04 / 2025. The first MMPV entry is period 05, fiscal year 2025. Run MMRV again. It should show 05 / 2025. Then MMPV is 06 / 2025, and so on.")
    bullet(doc, "MMPV moves one month at a time. Repeat until MMRV shows the month you need.")
    bullet(doc, "The message The specified year is not the current calendar year is a warning. Execute anyway when you are rolling an old period forward.")
    add_para(
        doc,
        "The period you type in MMPV is the period that becomes current. It is not the "
        "period you are leaving. To post a goods movement in October 2026, the last MMPV "
        "entry is period 10, fiscal year 2026. Period 9 / 2026 only opens September.",
    )
    add_para(doc, "Company code 1010, as first read in MMRV:", bold=True, space_after=4)
    add_table(
        doc,
        ["Field", "Value"],
        [
            ["Current period", "11 / 2025"],
            ["Previous period", "10 / 2025"],
            ["Last period of the previous year", "12 / 2024"],
            ["Posting to the previous period", "Allowed"],
        ],
    )
    add_para(
        doc,
        "Sequence to reach October 2026: 12 / 2025, then 01 / 2026 through 10 / 2026. "
        "Company code 1710 later returned Incorrect period in control rec. of CoCd 1710; "
        "no conversion. The control record was 04 / 2025, so that run did not move the "
        "period. The first MMPV entry for 1710 is 05 / 2025, then one month at a time "
        "until MMRV shows the period you need.",
    )

    doc.add_heading("4. Asset year — one year at a time", level=1)
    add_para(
        doc,
        "Do one fiscal year completely, then start the next. Do not press Close in "
        "OAAQ while RAJABS00 says depreciation is not posted.",
    )
    add_para(doc, "Step A. Read the year to close.", bold=True, space_after=4)
    bullet(doc, "Run OAAQ. Company code, ledger 0L.")
    bullet(doc, "The year to close is the year after Cl.FY on area 01. Example: Cl.FY 2023 means the year to close is 2024.")
    bullet(doc, "Highest F.Year is a different number. It is raised later, by FAGLGVTR, and only by one year each time.")
    add_para(doc, "Step B. Post depreciation for that year.", bold=True, space_after=4)
    bullet(doc, "Run AFAB. Company code, fiscal year = the year from Step A, posting period 12.")
    bullet(doc, "Select Test Run. Execute online. Read the log.")
    bullet(doc, "Clear Test Run. Choose Program → Execute in Background. Online update stops with: This processing can only be carried out as background processing.")
    bullet(doc, "Run SM37. Wait until the job status is Finished.")
    add_para(doc, "Step C. Test the close.", bold=True, space_after=4)
    bullet(doc, "Run RAJABS00. Same company code and same fiscal year. Select Test Run. Execute.")
    bullet(doc, "Contains assets with depreciation not posted completely means go back to Step B. Leave Test Run selected.")
    bullet(doc, "Other error = No and an empty detail list means the test is clean. Close carried out stays No. That is expected on a test.")
    add_para(doc, "Step D. Close the year.", bold=True, space_after=4)
    bullet(doc, "Run RAJABS00 again for the same year. Clear Test Run. Execute.")
    bullet(doc, "Refresh OAAQ. Cl.FY on area 01 should now be the year you just closed.")
    bullet(doc, "If one area is still on the older year, tick Select on that row and choose Close. The button is above the table, next to Reopen.")
    add_para(doc, "Step E. Raise Highest F.Year by one.", bold=True, space_after=4)
    bullet(doc, "Run FAGLGVTR. Company code. Carry the balances of the year you just closed into the next year.")
    bullet(doc, "Refresh OAAQ. Highest F.Year should be one higher than before this step.")
    add_para(
        doc,
        "Then go back to Step A for the next year. For a posting in 2026, the last "
        "close is 2025 and the last FAGLGVTR is into 2026. Repeat the same steps for "
        "ledger 2L when a posting uses that ledger.",
    )
    add_para(
        doc,
        "Company 1710, ledger 0L, as read on the current OAAQ screen: Highest F.Year "
        "2024, and areas 01, 90, 91, 92, and 93 closed through 2023. The year to close "
        "now is 2024. RAJABS00 already returned: Contains assets with depreciation not "
        "posted completely, and Closing of fiscal year 2024 failed for depreciation "
        "area 01. Start at Step B for 2024. Do not press Close.",
    )
    add_para(doc, "Warnings on FAGLGVTR that did not block company 1710:", bold=True, space_after=4)
    bullet(doc, "Predictive ledgers 0C and 0E are skipped.")
    bullet(doc, "Postings during the run may lead to incorrect results.")
    bullet(doc, "ACDOCA-GLACCOUNT_TYPE differs from G/L master data.")

    doc.add_heading("5. Company code 1710", level=1)
    add_para(
        doc,
        "The asset invoice was blocked because ledger 0L had Highest F.Year 2024. "
        "Book depreciation area 01 was closed only through 2022. Areas 90 to 93 were "
        "closed through 2024.",
    )
    add_table(
        doc,
        ["Step", "What was done"],
        [
            ["AFAB", "Test run for the open year: 40 assets, no errors. Update run in background, then SM37."],
            ["RAJABS00", "First test: depreciation not posted completely. After AFAB, Other error = No and the detail list was empty. Then run without Test Run. Area 01 showed closed fiscal year 2023."],
            ["OAAQ Close", "Select row 1 Book Depreciation and choose Close. Area 01 then closed through 2024."],
            ["FAGLGVTR", "Carryforward raised Highest F.Year from 2024 to 2025. The log had no errors."],
            ["Still to confirm", "Carry forward once more, into 2026. In OAAQ, Highest F.Year must be 2026 on ledger 0L and ledger 2L before an asset invoice dated in 2026."],
        ],
    )
    add_para(
        doc,
        "The supplier invoice was posted after this year-opening work, so the asset "
        "year was far enough open for that posting. Confirm both ledgers at 2026 "
        "before the next asset invoice.",
    )

    doc.add_heading("6. Company code 1010", level=1)
    add_table(
        doc,
        ["Calendar", "Starting point", "What to do"],
        [
            ["Finance, variant 1010", "OB52 already open 1/2000–12/2030, and special periods 13–16, for account types +, A, D, K, M, S, and V.", "Leave it unchanged. 2026 is covered."],
            ["Materials", "MMRV current period 11/2025, previous 10/2025, last period of the previous year 12/2024. Posting to the previous period is allowed.", "MMPV one month at a time. Last entry for an October 2026 goods movement is period 10 / 2026."],
            ["Asset ledger 0L", "Highest F.Year 2019. Areas 01 Book Depreciation and 15 Local Tax closed through 12/31/2017. Fiscal year variant K4. Country DE.", "The 2018 close test was clean, with no depreciation error. Close each year with RAJABS00, then FAGLGVTR into the next year."],
            ["Asset ledger 0L, finished", "Highest F.Year 2026. Areas 01 and 15 closed through 12/31/2025.", "This is the state after the year roll."],
            ["Asset ledger 2L", "Present in the OAAQ tree. Not confirmed at Highest F.Year 2026.", "Open it in OAAQ and carry it forward if a posting updates that ledger."],
        ],
    )
    add_para(
        doc,
        "Do not close a year that OAAQ already shows as closed. RAJABS00 on an "
        "already closed year is the wrong program for the next step. Read Cl.FY "
        "and close only the next open year.",
    )

    doc.add_heading("7. Order of work for a new posting date", level=1)
    bullet(doc, "OB52 for the posting period variant of that company code. Confirm the period and the special periods.")
    bullet(doc, "MMRV. If the posting date is outside the current and previous materials periods, roll MMPV one month at a time until the period of the posting date is current.")
    bullet(doc, "OAAQ for ledger 0L and ledger 2L. If the posting hits an asset and Highest F.Year is below the fiscal year, run AFAB, RAJABS00, and FAGLGVTR one year at a time until Highest F.Year is that year.")
    add_para(
        doc,
        "python3 docs/samples/ic/build_period_guide_docx.py writes docs/OPEN_PERIODS_GUIDE.docx.",
    )
    doc.save(OUT)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
