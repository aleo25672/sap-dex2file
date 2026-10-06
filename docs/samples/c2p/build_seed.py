#!/usr/bin/env python3
"""Build the Contract-to-Payment seed subset and correlation.json.

Reads the ZEVO extracts in ./source (semicolon-separated) and writes:

- ./seed/   rows that belong to purchase contract 4600000041 and
            release PO 4500002146 (plus the supplier and G/L accounts
            those rows reference)
- ./correlation.json   the joined chain, quantity roll-up, and gaps

CSV headers in the extracts are CDS element names in uppercase.
Re-run from this directory after replacing the source files:

    python3 build_seed.py
"""

from __future__ import annotations

import csv
import json
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source"
SEED = ROOT / "seed"

CONTRACT = "4600000041"
PO = "4500002146"
COMPANY = "1710"
SUPPLIER = "0001000559"
LEDGER = "0L"
CURRENCY = "USD"

# FI documents posted for this PO (leading ledger). Logistics numbers differ.
FI_DOCS = {
    "5000000001",  # WE for material document 5000002931
    "5000000002",  # WE for material document 5000002940
    "5000000003",  # WE for material document 5000002941
    "5100000000",  # RE for supplier invoice 5100001598
    "5100000001",  # RE for supplier invoice 5100001599
}
GL_ACCOUNTS = {"0013600000", "0021100000", "0021120000"}

# History document type on C_PurchaseOrderHistoryDEX (EKBE VGABE).
HIST_GR = "1"
HIST_IR = "2"


def source_file(entity: str) -> Path:
    matches = sorted(SOURCE.glob(f"{entity}_*.csv"))
    if len(matches) != 1:
        raise SystemExit(f"expected one source file for {entity}, found {matches}")
    return matches[0]


def read_text(path: Path) -> str:
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "cp1252"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    return raw.decode("latin-1")


def load(entity: str) -> tuple[list[str], list[dict[str, str]]]:
    text = read_text(source_file(entity))
    reader = csv.DictReader(text.splitlines(), delimiter=";")
    rows = list(reader)
    headers = list(reader.fieldnames or [])
    return headers, rows


def write_seed(entity: str, headers: list[str], rows: list[dict[str, str]]) -> None:
    SEED.mkdir(parents=True, exist_ok=True)
    path = SEED / f"{entity}.csv"
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=headers,
            delimiter=";",
            lineterminator="\n",
            extrasaction="ignore",
        )
        writer.writeheader()
        writer.writerows(rows)


def dec(value: str) -> Decimal:
    text = (value or "").strip()
    if text == "":
        return Decimal("0")
    return Decimal(text)


def money(value: Decimal) -> str:
    return f"{value.quantize(Decimal('0.01'))}"


def qty(value: Decimal) -> str:
    return f"{value.quantize(Decimal('0.001'))}"


def nonempty(row: dict[str, str], keys: list[str]) -> dict[str, str]:
    return {key: row.get(key, "") for key in keys}


def main() -> None:
    contract_h, contracts = load("C_PURCHASECONTRACTDEX")
    item_h, items = load("C_PURCHASECONTRACTITEMDEX")
    chist_h, chist = load("C_PURCHASECONTRACTHISTORYDEX")
    po_h, pos = load("C_PURCHASEORDERDEX")
    poitem_h, poitems = load("C_PURCHASEORDERITEMDEX")
    pohist_h, pohist = load("C_PURCHASEORDERHISTORYDEX")
    aa_h, aa_rows = load("C_PURORDACCOUNTASSIGNMENTDEX")
    si_h, invoices = load("C_SUPPLIERINVOICEDEX")
    sii_h, invoice_items = load("C_SUPPLIERINVOICEITEMDEX")
    gm_h, movements = load("I_GOODSMOVEMENTDOCUMENTDEX")
    gl_h, gl_accounts = load("I_GLACCOUNT")
    je_h, journal = load("I_GLACCOUNTLINEITEMRAWDATA")
    bp_h, partners = load("I_BUSINESSPARTNER")
    sup_h, suppliers = load("I_BUSINESSPARTNERSUPPLIERDEX")
    ref_h, ref_types = load("I_GOODSMOVEMENTREFDOCTYPE")
    reft_h, ref_texts = load("I_GOODSMOVEMENTREFDOCTYPETEXT")

    seed_contracts = [r for r in contracts if r["PURCHASECONTRACT"] == CONTRACT]
    seed_items = [r for r in items if r["PURCHASECONTRACT"] == CONTRACT]
    seed_chist = [r for r in chist if r["PURCHASECONTRACT"] == CONTRACT]
    seed_pos = [r for r in pos if r["PURCHASEORDER"] == PO]
    seed_poitems = [r for r in poitems if r["PURCHASEORDER"] == PO]
    seed_pohist = [r for r in pohist if r["PURCHASEORDER"] == PO]
    seed_aa = [
        r
        for r in aa_rows
        if r.get("PURCHASEORDER") == PO
    ]
    seed_invoice_items = [r for r in invoice_items if r["PURCHASEORDER"] == PO]
    invoice_ids = {r["SUPPLIERINVOICE"] for r in seed_invoice_items}
    seed_invoices = [
        r
        for r in invoices
        if r["SUPPLIERINVOICE"] in invoice_ids and r["COMPANYCODE"] == COMPANY
    ]
    seed_gm = [r for r in movements if r.get("PURCHASEORDER") == PO]
    mat_docs = {r["MATERIALDOCUMENT"] for r in seed_gm}
    seed_je = [
        r
        for r in journal
        if r["COMPANYCODE"] == COMPANY
        and r["SOURCELEDGER"] == LEDGER
        and r["ACCOUNTINGDOCUMENT"] in FI_DOCS
    ]
    seed_gl = [
        r
        for r in gl_accounts
        if r["COMPANYCODE"] == COMPANY and r["GLACCOUNT"] in GL_ACCOUNTS
    ]
    seed_bp = [r for r in partners if r.get("BUSINESSPARTNER") == SUPPLIER]
    seed_sup = [r for r in suppliers if r.get("SUPPLIER") == SUPPLIER]
    ref_codes = {r.get("GOODSMOVEMENTREFDOCTYPE", "") for r in seed_gm}
    seed_ref = [r for r in ref_types if r.get("GOODSMOVEMENTREFDOCTYPE", "") in ref_codes]
    seed_reft = [
        r
        for r in ref_texts
        if r.get("LANGUAGE") == "E" and r.get("GOODSMOVEMENTREFDOCTYPE", "") in ref_codes
    ]

    write_seed("C_PURCHASECONTRACTDEX", contract_h, seed_contracts)
    write_seed("C_PURCHASECONTRACTITEMDEX", item_h, seed_items)
    write_seed("C_PURCHASECONTRACTHISTORYDEX", chist_h, seed_chist)
    write_seed("C_PURCHASEORDERDEX", po_h, seed_pos)
    write_seed("C_PURCHASEORDERITEMDEX", poitem_h, seed_poitems)
    write_seed("C_PURCHASEORDERHISTORYDEX", pohist_h, seed_pohist)
    write_seed("C_PURORDACCOUNTASSIGNMENTDEX", aa_h, seed_aa)
    write_seed("C_SUPPLIERINVOICEDEX", si_h, seed_invoices)
    write_seed("C_SUPPLIERINVOICEITEMDEX", sii_h, seed_invoice_items)
    write_seed("I_GOODSMOVEMENTDOCUMENTDEX", gm_h, seed_gm)
    write_seed("I_GLACCOUNTLINEITEMRAWDATA", je_h, seed_je)
    write_seed("I_GLACCOUNT", gl_h, seed_gl)
    write_seed("I_BUSINESSPARTNER", bp_h, seed_bp)
    write_seed("I_BUSINESSPARTNERSUPPLIERDEX", sup_h, seed_sup)
    write_seed("I_GOODSMOVEMENTREFDOCTYPE", ref_h, seed_ref)
    write_seed("I_GOODSMOVEMENTREFDOCTYPETEXT", reft_h, seed_reft)

    header = seed_contracts[0]
    po_header = seed_pos[0]
    supplier_name = seed_bp[0].get("BUSINESSPARTNERFULLNAME", "")

    contract_items = []
    for row in sorted(seed_items, key=lambda r: r["PURCHASECONTRACTITEM"]):
        contract_items.append(
            {
                "purchaseContractItem": row["PURCHASECONTRACTITEM"],
                "material": row["MATERIAL"],
                "text": row["PURCHASECONTRACTITEMTEXT"],
                "targetQuantity": row["TARGETQUANTITY"],
                "netPrice": row["CONTRACTNETPRICEAMOUNT"],
                "targetAmount": row["TARGETAMOUNT"],
                "unit": row["ORDERQUANTITYUNIT"],
                "plant": row["PLANT"],
                "goodsReceiptIsExpected": row["GOODSRECEIPTISEXPECTED"],
                "invoiceIsExpected": row["INVOICEISEXPECTED"],
                "invoiceIsGoodsReceiptBased": row["INVOICEISGOODSRECEIPTBASED"],
            }
        )

    po_item_rows = []
    for row in sorted(seed_poitems, key=lambda r: r["PURCHASEORDERITEM"]):
        po_item_rows.append(
            {
                "purchaseOrderItem": row["PURCHASEORDERITEM"],
                "material": row["MATERIAL"],
                "text": row["PURCHASEORDERITEMTEXT"],
                "orderQuantity": row["ORDERQUANTITY"],
                "netPrice": row["NETPRICEAMOUNT"],
                "netAmount": row["NETAMOUNT"],
                "unit": row["PURCHASEORDERQUANTITYUNIT"],
                "plant": row["PLANT"],
                "storageLocation": row["STORAGELOCATION"],
                "purchaseContract": row["PURCHASECONTRACT"],
                "purchaseContractItem": row["PURCHASECONTRACTITEM"],
                "goodsReceiptIsExpected": row["GOODSRECEIPTISEXPECTED"],
                "invoiceIsExpected": row["INVOICEISEXPECTED"],
                "invoiceIsGoodsReceiptBased": row["INVOICEISGOODSRECEIPTBASED"],
                "accountAssignmentCategory": row.get("ACCOUNTASSIGNMENTCATEGORY", ""),
            }
        )

    history = []
    for row in seed_pohist:
        history.append(
            {
                "purchaseOrderItem": row["PURCHASEORDERITEM"],
                "purchasingHistoryDocumentType": row["PURCHASINGHISTORYDOCUMENTTYPE"],
                "purchasingHistoryCategory": row["PURCHASINGHISTORYCATEGORY"],
                "purchasingHistoryDocument": row["PURCHASINGHISTORYDOCUMENT"],
                "purchasingHistoryDocumentItem": row["PURCHASINGHISTORYDOCUMENTITEM"],
                "goodsMovementType": row.get("GOODSMOVEMENTTYPE", ""),
                "postingDate": row["POSTINGDATE"],
                "material": row["MATERIAL"],
                "quantity": row["QUANTITY"],
                "amount": row["PURCHASEORDERAMOUNT"],
                "purchaseContract": row["PURCHASECONTRACT"],
                "purchaseContractItem": row["PURCHASECONTRACTITEM"],
                "referenceDocument": row.get("REFERENCEDOCUMENT", ""),
                "debitCreditCode": row.get("DEBITCREDITCODE", ""),
            }
        )

    goods_receipts = []
    for row in sorted(seed_gm, key=lambda r: r["MATERIALDOCUMENT"]):
        goods_receipts.append(
            {
                "materialDocument": row["MATERIALDOCUMENT"],
                "materialDocumentYear": row["MATERIALDOCUMENTYEAR"],
                "materialDocumentItem": row["MATERIALDOCUMENTITEM"],
                "goodsMovementType": row["GOODSMOVEMENTTYPE"],
                "inventoryTransactionType": row["INVENTORYTRANSACTIONTYPE"],
                "goodsMovementRefDocType": row.get("GOODSMOVEMENTREFDOCTYPE", ""),
                "purchaseOrder": row["PURCHASEORDER"],
                "purchaseOrderItem": row["PURCHASEORDERITEM"],
                "material": row["MATERIAL"],
                "quantity": row["QUANTITYINENTRYUNIT"],
                "unit": row["ENTRYUNIT"],
                "postingDate": row["POSTINGDATE"],
                "plant": row["PLANT"],
                "storageLocation": row["STORAGELOCATION"],
                "companyCode": row["COMPANYCODE"],
            }
        )

    invoice_docs = []
    for row in sorted(seed_invoices, key=lambda r: r["SUPPLIERINVOICE"]):
        lines = [
            item
            for item in seed_invoice_items
            if item["SUPPLIERINVOICE"] == row["SUPPLIERINVOICE"]
        ]
        invoice_docs.append(
            {
                "supplierInvoice": row["SUPPLIERINVOICE"],
                "fiscalYear": row["FISCALYEAR"],
                "companyCode": row["COMPANYCODE"],
                "postingDate": row["POSTINGDATE"],
                "invoicingParty": row["INVOICINGPARTY"],
                "supplierInvoiceIdByInvcgParty": row["SUPPLIERINVOICEIDBYINVCGPARTY"],
                "grossAmount": row["INVOICEGROSSAMOUNT"],
                "currency": row["DOCUMENTCURRENCY"],
                "supplierInvoiceStatus": row["SUPPLIERINVOICESTATUS"],
                "isInvoice": row["ISINVOICE"],
                "items": [
                    {
                        "supplierInvoiceItem": item["SUPPLIERINVOICEITEM"],
                        "purchaseOrder": item["PURCHASEORDER"],
                        "purchaseOrderItem": item["PURCHASEORDERITEM"],
                        "material": item["PURCHASEORDERITEMMATERIAL"],
                        "quantity": item["QUANTITYINPURCHASEORDERUNIT"],
                        "amount": item["SUPPLIERINVOICEITEMAMOUNT"],
                        "referenceMaterialDocument": item.get("PRMTHBREFERENCEDOCUMENT", ""),
                        "referenceMaterialDocumentYear": item.get(
                            "PRMTHBREFERENCEDOCUMENTFSCLYR", ""
                        ),
                        "referenceMaterialDocumentItem": item.get(
                            "PRMTHBREFERENCEDOCUMENTITEM", ""
                        ),
                    }
                    for item in sorted(lines, key=lambda r: r["SUPPLIERINVOICEITEM"])
                ],
            }
        )

    journal_lines = []
    for row in sorted(
        seed_je,
        key=lambda r: (r["ACCOUNTINGDOCUMENT"], r["LEDGERGLLINEITEM"]),
    ):
        journal_lines.append(
            {
                "sourceLedger": row["SOURCELEDGER"],
                "companyCode": row["COMPANYCODE"],
                "fiscalYear": row["FISCALYEAR"],
                "accountingDocument": row["ACCOUNTINGDOCUMENT"],
                "ledgerGLLineItem": row["LEDGERGLLINEITEM"],
                "accountingDocumentType": row["ACCOUNTINGDOCUMENTTYPE"],
                "postingDate": row["POSTINGDATE"],
                "glAccount": row["GLACCOUNT"],
                "financialAccountType": row["FINANCIALACCOUNTTYPE"],
                "debitCreditCode": row["DEBITCREDITCODE"],
                "amountInCompanyCodeCurrency": row["AMOUNTINCOMPANYCODECURRENCY"],
                "companyCodeCurrency": row["COMPANYCODECURRENCY"],
                "supplier": row.get("SUPPLIER", ""),
                "purchasingDocument": row.get("PURCHASINGDOCUMENT", ""),
                "purchasingDocumentItem": row.get("PURCHASINGDOCUMENTITEM", ""),
                "referenceDocumentType": row.get("REFERENCEDOCUMENTTYPE", ""),
                "referenceDocument": row.get("REFERENCEDOCUMENT", ""),
                "referenceDocumentItem": row.get("REFERENCEDOCUMENTITEM", ""),
                "assignmentReference": row.get("ASSIGNMENTREFERENCE", ""),
                "documentItemText": row.get("DOCUMENTITEMTEXT", ""),
                "clearingDate": row.get("CLEARINGDATE", ""),
                "clearingAccountingDocument": row.get("CLEARINGACCOUNTINGDOCUMENT", ""),
                "offsettingAccount": row.get("OFFSETTINGACCOUNT", ""),
            }
        )

    gl_out = []
    for row in sorted(seed_gl, key=lambda r: r["GLACCOUNT"]):
        gl_out.append(
            {
                "glAccount": row["GLACCOUNT"],
                "companyCode": row["COMPANYCODE"],
                "chartOfAccounts": row["CHARTOFACCOUNTS"],
                "glAccountType": row["GLACCOUNTTYPE"],
                "reconciliationAccountType": row["RECONCILIATIONACCOUNTTYPE"],
                "isOpenItemManaged": row["ISOPENITEMMANAGED"],
                "glAccountExternal": row["GLACCOUNTEXTERNAL"],
                "companyCodeName": row["COMPANYCODENAME"],
            }
        )

    def hist_sum(po_item: str, doc_type: str) -> tuple[Decimal, Decimal]:
        quantity = Decimal("0")
        amount = Decimal("0")
        for row in seed_pohist:
            if (
                row["PURCHASEORDERITEM"] == po_item
                and row["PURCHASINGHISTORYDOCUMENTTYPE"] == doc_type
            ):
                quantity += dec(row["QUANTITY"])
                amount += dec(row["PURCHASEORDERAMOUNT"])
        return quantity, amount

    rollup = []
    for item in po_item_rows:
        received_qty, received_amt = hist_sum(item["purchaseOrderItem"], HIST_GR)
        invoiced_qty, invoiced_amt = hist_sum(item["purchaseOrderItem"], HIST_IR)
        ordered_qty = dec(item["orderQuantity"])
        ordered_amt = dec(item["netAmount"])
        contract_item = next(
            row
            for row in contract_items
            if row["purchaseContractItem"] == item["purchaseContractItem"]
        )
        target_qty = dec(contract_item["targetQuantity"])
        released_qty = sum(
            (
                dec(row["RELEASEORDERITEMORDERQUANTITY"])
                for row in seed_chist
                if row["PURCHASECONTRACTITEM"] == item["purchaseContractItem"]
                and row.get("RELEASEORDERITEMISDELETED", "") == ""
            ),
            Decimal("0"),
        )
        rollup.append(
            {
                "purchaseContractItem": item["purchaseContractItem"],
                "purchaseOrderItem": item["purchaseOrderItem"],
                "material": item["material"],
                "contractTargetQuantity": qty(target_qty),
                "releasedQuantity": qty(released_qty),
                "orderQuantity": qty(ordered_qty),
                "orderAmount": money(ordered_amt),
                "receivedQuantity": qty(received_qty),
                "receivedAmount": money(received_amt),
                "invoicedQuantity": qty(invoiced_qty),
                "invoicedAmount": money(invoiced_amt),
                "openReceiptQuantity": qty(ordered_qty - received_qty),
                "openReceiptAmount": money(ordered_amt - received_amt),
                "unreleasedQuantity": qty(target_qty - released_qty),
            }
        )

    # Contract item with no release in this extract.
    released_items = {row["purchaseContractItem"] for row in po_item_rows}
    for contract_item in contract_items:
        if contract_item["purchaseContractItem"] in released_items:
            continue
        rollup.append(
            {
                "purchaseContractItem": contract_item["purchaseContractItem"],
                "purchaseOrderItem": "",
                "material": contract_item["material"],
                "contractTargetQuantity": contract_item["targetQuantity"],
                "releasedQuantity": "0.000",
                "orderQuantity": "0.000",
                "orderAmount": "0.00",
                "receivedQuantity": "0.000",
                "receivedAmount": "0.00",
                "invoicedQuantity": "0.000",
                "invoicedAmount": "0.00",
                "openReceiptQuantity": "0.000",
                "openReceiptAmount": "0.00",
                "unreleasedQuantity": contract_item["targetQuantity"],
            }
        )

    ap_lines = [
        line
        for line in journal_lines
        if line["financialAccountType"] == "K" and line["glAccount"] == "0021100000"
    ]
    open_ap = sum((dec(line["amountInCompanyCodeCurrency"]) for line in ap_lines), Decimal("0"))
    # Vendor credit is stored as a negative amount. Open payable is the absolute value.
    open_ap_amount = money(abs(open_ap))

    grir_net = sum(
        (
            dec(line["amountInCompanyCodeCurrency"])
            for line in journal_lines
            if line["glAccount"] == "0021120000"
        ),
        Decimal("0"),
    )

    other_release_pos = sorted(
        {
            row["RELEASEORDER"]
            for row in chist
            if row["RELEASEORDER"] in {r["PURCHASEORDER"] for r in pos}
            and row["PURCHASECONTRACT"] != CONTRACT
        }
    )
    contracts_without_release = sorted(
        {
            row["PURCHASECONTRACT"]
            for row in contracts
            if row["PURCHASECONTRACT"]
            not in {h["PURCHASECONTRACT"] for h in chist}
        }
    )

    correlation = {
        "extractRun": "20261006_094549",
        "delimiter": ";",
        "seed": {
            "purchaseContract": CONTRACT,
            "purchaseOrder": PO,
            "companyCode": COMPANY,
            "supplier": SUPPLIER,
            "supplierName": supplier_name,
            "currency": CURRENCY,
            "ledger": LEDGER,
        },
        "whyThisSeed": (
            "4600000041 is the only purchase contract that is present in the "
            "bounded contract header and item extracts and that also has a "
            "release order in the purchase-order extract. PO 4500002146 is "
            "that release, and it continues through goods receipt, supplier "
            "invoice, and the universal journal."
        ),
        "contract": {
            "purchaseContract": header["PURCHASECONTRACT"],
            "purchaseContractType": header["PURCHASECONTRACTTYPE"],
            "purchasingDocumentCategory": header["PURCHASINGDOCUMENTCATEGORY"],
            "supplier": header["SUPPLIER"],
            "companyCode": header["COMPANYCODE"],
            "purchasingOrganization": header["PURCHASINGORGANIZATION"],
            "purchasingGroup": header["PURCHASINGGROUP"],
            "validityStartDate": header["VALIDITYSTARTDATE"],
            "validityEndDate": header["VALIDITYENDDATE"],
            "documentCurrency": header["DOCUMENTCURRENCY"],
            "paymentTerms": header["PAYMENTTERMS"],
            "createdByUser": header["CREATEDBYUSER"],
            "creationDate": header["CREATIONDATE"],
            "items": contract_items,
        },
        "purchaseOrder": {
            "purchaseOrder": po_header["PURCHASEORDER"],
            "purchaseOrderType": po_header["PURCHASEORDERTYPE"],
            "supplier": po_header["SUPPLIER"],
            "invoicingParty": po_header["INVOICINGPARTY"],
            "companyCode": po_header["COMPANYCODE"],
            "purchasingOrganization": po_header["PURCHASINGORGANIZATION"],
            "purchasingGroup": po_header["PURCHASINGGROUP"],
            "purchaseOrderDate": po_header["PURCHASEORDERDATE"],
            "documentCurrency": po_header["DOCUMENTCURRENCY"],
            "paymentTerms": po_header["PAYMENTTERMS"],
            "purchasingProcessingStatus": po_header["PURCHASINGPROCESSINGSTATUS"],
            "totalAmount": po_header["PURGRELEASETIMETOTALAMOUNT"],
            "createdByUser": po_header["CREATEDBYUSER"],
            "items": po_item_rows,
        },
        "purchaseOrderHistory": history,
        "goodsReceipts": goods_receipts,
        "supplierInvoices": invoice_docs,
        "journalLines": journal_lines,
        "glAccounts": gl_out,
        "quantityReconciliation": rollup,
        "payment": {
            "status": "open",
            "openAmount": open_ap_amount,
            "currency": CURRENCY,
            "glAccount": "0021100000",
            "clearingDate": "",
            "clearingAccountingDocument": "",
            "grirNetAmount": money(grir_net),
            "note": (
                "No payment or clearing document is in this extract. "
                "ClearingDate and ClearingAccountingDocument are blank on "
                "every journal line of the seed. The vendor items on "
                "21100000 remain open."
            ),
        },
        "joinKeys": [
            {
                "from": "C_PurchaseContractDEX",
                "to": "C_PurchaseContractItemDEX",
                "keys": ["PurchaseContract"],
            },
            {
                "from": "C_PurchaseContractItemDEX",
                "to": "C_PurchaseContractHistoryDEX",
                "keys": ["PurchaseContract", "PurchaseContractItem"],
                "note": "ReleaseOrder / ReleaseOrderItem is the purchase order.",
            },
            {
                "from": "C_PurchaseContractItemDEX",
                "to": "C_PurchaseOrderItemDEX",
                "keys": ["PurchaseContract", "PurchaseContractItem"],
            },
            {
                "from": "C_PurchaseOrderDEX",
                "to": "C_PurchaseOrderItemDEX",
                "keys": ["PurchaseOrder"],
            },
            {
                "from": "C_PurchaseOrderItemDEX",
                "to": "C_PurchaseOrderHistoryDEX",
                "keys": ["PurchaseOrder", "PurchaseOrderItem"],
                "note": "PurchasingHistoryDocumentType 1 = goods receipt, 2 = invoice receipt.",
            },
            {
                "from": "C_PurchaseOrderHistoryDEX",
                "to": "I_GoodsMovementDocumentDEX",
                "keys": ["PurchasingHistoryDocument = MaterialDocument", "PurchaseOrder", "PurchaseOrderItem"],
                "note": "Only history type 1. GoodsMovementType 101.",
            },
            {
                "from": "C_PurchaseOrderHistoryDEX",
                "to": "C_SupplierInvoiceDEX",
                "keys": ["PurchasingHistoryDocument = SupplierInvoice"],
                "note": "Only history type 2. CompanyCode + FiscalYear also match.",
            },
            {
                "from": "C_SupplierInvoiceItemDEX",
                "to": "I_GoodsMovementDocumentDEX",
                "keys": ["PrmthbReferenceDocument = MaterialDocument"],
                "note": "Filled when the PO item is goods-receipt-based invoice verification.",
            },
            {
                "from": "I_GoodsMovementDocumentDEX",
                "to": "I_GLAccountLineItemRawData",
                "keys": ["MaterialDocument = ReferenceDocument", "ReferenceDocumentType = MKPF"],
                "note": "AccountingDocument is a different number from MaterialDocument.",
            },
            {
                "from": "C_SupplierInvoiceDEX",
                "to": "I_GLAccountLineItemRawData",
                "keys": ["SupplierInvoice = ReferenceDocument", "ReferenceDocumentType = RMRP"],
                "note": "AccountingDocument is a different number from SupplierInvoice.",
            },
            {
                "from": "I_GLAccountLineItemRawData GR/IR line",
                "to": "C_PurchaseOrderItemDEX",
                "keys": ["PurchasingDocument", "PurchasingDocumentItem"],
                "note": "AssignmentReference repeats PurchaseOrder + PurchaseOrderItem with no separator.",
            },
            {
                "from": "I_GLAccountLineItemRawData vendor line",
                "to": "supplier invoice and PO",
                "keys": ["AccountingDocument of the same RE document", "Supplier", "ReferenceDocument"],
                "note": "The vendor line (21100000) has no PurchasingDocument. Use the GR/IR lines on the same accounting document.",
            },
            {
                "from": "C_PurchaseOrderDEX",
                "to": "I_BusinessPartner / I_BusinessPartnerSupplierDEX",
                "keys": ["Supplier = BusinessPartner"],
            },
            {
                "from": "I_GLAccountLineItemRawData",
                "to": "I_GLAccount",
                "keys": ["GLAccount", "CompanyCode"],
            },
        ],
        "sourceCounts": {
            "C_PURCHASECONTRACTDEX": len(contracts),
            "C_PURCHASECONTRACTITEMDEX": len(items),
            "C_PURCHASECONTRACTHISTORYDEX": len(chist),
            "C_PURCHASEORDERDEX": len(pos),
            "C_PURCHASEORDERITEMDEX": len(poitems),
            "C_PURCHASEORDERHISTORYDEX": len(pohist),
            "C_PURORDACCOUNTASSIGNMENTDEX": len(aa_rows),
            "C_SUPPLIERINVOICEDEX": len(invoices),
            "C_SUPPLIERINVOICEITEMDEX": len(invoice_items),
            "I_GOODSMOVEMENTDOCUMENTDEX": len(movements),
            "I_GLACCOUNTLINEITEMRAWDATA": len(journal),
            "I_GLACCOUNT": len(gl_accounts),
            "I_BUSINESSPARTNER": len(partners),
            "I_BUSINESSPARTNERSUPPLIERDEX": len(suppliers),
        },
        "gaps": [
            {
                "id": "no-payment",
                "detail": (
                    "ClearingDate is 00000000 and ClearingAccountingDocument is "
                    "blank. Document types in company 1710 are RE, RV, WA, WE, WL. "
                    "There is no payment document."
                ),
            },
            {
                "id": "partial-receipt",
                "detail": (
                    "PO 4500002146 item 00020 ordered 15 and received 10. "
                    "Item 00010 ordered 10 and received 3. Invoiced quantity "
                    "equals received quantity on both items."
                ),
            },
            {
                "id": "contract-item-not-released",
                "detail": (
                    "Contract item 00010 material TG10 target quantity 100 has "
                    "no release order in the full contract-history extract."
                ),
            },
            {
                "id": "no-account-assignment",
                "detail": (
                    "C_PurOrdAccountAssignmentDEX has a header and zero rows. "
                    "Both PO items have a blank account-assignment category "
                    "(stock procurement)."
                ),
            },
            {
                "id": "no-inbound-delivery",
                "detail": "Purchase-order history DeliveryDocumentItem is 000000 on every seed row.",
            },
            {
                "id": "fi-number-is-not-the-logistics-number",
                "detail": (
                    "Material document 5000002931 posts to accounting document "
                    "5000000001. Supplier invoice 5100001598 posts to accounting "
                    "document 5100000000. Join on ReferenceDocument, not on "
                    "AccountingDocument."
                ),
            },
            {
                "id": "parallel-ledger",
                "detail": (
                    "The same FI documents also exist on ledger 2L. The seed "
                    "keeps leading ledger 0L only."
                ),
            },
            {
                "id": "other-pos-missing-contract-header",
                "detail": (
                    "Purchase orders "
                    + ", ".join(other_release_pos)
                    + " are in the PO extract as releases of contract 4600000038, "
                    "which is not in the bounded contract header or item files. "
                    "Only 4500002143 has a goods receipt (material document "
                    "5000002930, accounting document 5000000000). None of them "
                    "has a supplier invoice in this extract."
                ),
            },
            {
                "id": "contracts-without-release",
                "detail": (
                    "Contracts "
                    + ", ".join(contracts_without_release)
                    + " are in the bounded header and item extracts and have "
                    "no rows in the full contract-history extract."
                ),
            },
            {
                "id": "no-gl-account-name",
                "detail": "I_GLAccount in this extract has no account-name column.",
            },
        ],
    }

    out = ROOT / "correlation.json"
    out.write_text(json.dumps(correlation, indent=2) + "\n", encoding="utf-8")

    assert len(seed_contracts) == 1, len(seed_contracts)
    assert len(seed_items) == 3, len(seed_items)
    assert len(seed_chist) == 2, len(seed_chist)
    assert len(seed_pos) == 1, len(seed_pos)
    assert len(seed_poitems) == 2, len(seed_poitems)
    assert len(seed_pohist) == 6, len(seed_pohist)
    assert len(seed_gm) == 3, len(seed_gm)
    assert len(seed_invoices) == 2, len(seed_invoices)
    assert len(seed_invoice_items) == 3, len(seed_invoice_items)
    assert len(seed_je) == 11, len(seed_je)
    assert len(seed_gl) == 3, len(seed_gl)
    assert len(seed_bp) == 1 and len(seed_sup) == 1
    assert supplier_name == "EVOLVER DOMESTIC SUPPLIER 1"
    assert open_ap_amount == "160.50", open_ap_amount
    assert money(grir_net) == "0.00", money(grir_net)
    assert mat_docs == {"5000002931", "5000002940", "5000002941"}
    assert invoice_ids == {"5100001598", "5100001599"}
    assert all(
        (line["clearingDate"] in ("", "00000000"))
        and line["clearingAccountingDocument"] == ""
        for line in journal_lines
    )
    by_item = {row["purchaseOrderItem"]: row for row in rollup if row["purchaseOrderItem"]}
    assert by_item["00020"]["receivedQuantity"] == "10.000"
    assert by_item["00020"]["invoicedQuantity"] == "10.000"
    assert by_item["00020"]["openReceiptQuantity"] == "5.000"
    assert by_item["00010"]["receivedQuantity"] == "3.000"
    assert by_item["00010"]["invoicedAmount"] == "40.50"
    assert by_item["00010"]["openReceiptQuantity"] == "7.000"
    unreleased = next(row for row in rollup if row["purchaseContractItem"] == "00010")
    assert unreleased["releasedQuantity"] == "0.000"

    print(f"wrote {out}")
    print(f"seed files: {len(list(SEED.glob('*.csv')))}")
    print(f"open AP {open_ap_amount} {CURRENCY}; GR/IR net {money(grir_net)}")


if __name__ == "__main__":
    main()
