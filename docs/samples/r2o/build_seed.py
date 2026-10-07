#!/usr/bin/env python3
"""Build the Requisition-to-Order seed subset and correlation.json.

Reads the ZEVO extracts in ./source and writes ./seed plus ./correlation.json
for purchase requisition 0010001624 and purchase order 4500002147.

    python3 docs/samples/r2o/build_seed.py
"""

from __future__ import annotations

import csv
import json
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source"
SEED = ROOT / "seed"

REQUISITION = "0010001624"
PURCHASE_ORDER = "4500002147"
COMPANY = "1710"
SUPPLIER = "0001000579"
ASSET = "000000600004"
GL_ACCOUNT = "0016014000"


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
    return list(reader.fieldnames or []), rows


def write_seed(entity: str, headers: list[str], rows: list[dict[str, str]]) -> None:
    SEED.mkdir(parents=True, exist_ok=True)
    with (SEED / f"{entity}.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=headers, delimiter=";", lineterminator="\n", extrasaction="ignore"
        )
        writer.writeheader()
        writer.writerows(rows)


def dec(value: str) -> Decimal:
    text = (value or "").strip()
    return Decimal(text) if text else Decimal("0")


def money(value: Decimal) -> str:
    return f"{value.quantize(Decimal('0.01'))}"


def qty(value: Decimal) -> str:
    return f"{value.quantize(Decimal('0.001'))}"


def main() -> None:
    pr_h, prs = load("C_PURCHASEREQUISITIONITEMDEX")
    po_h, pos = load("C_PURCHASEORDERDEX")
    poi_h, po_items = load("C_PURCHASEORDERITEMDEX")
    poh_h, po_hist = load("C_PURCHASEORDERHISTORYDEX")
    aa_h, assignments = load("C_PURORDACCOUNTASSIGNMENTDEX")
    si_h, invoices = load("C_SUPPLIERINVOICEDEX")
    sii_h, invoice_items = load("C_SUPPLIERINVOICEITEMDEX")
    gm_h, movements = load("I_GOODSMOVEMENTDOCUMENTDEX")
    bp_h, partners = load("I_BUSINESSPARTNER")
    sup_h, suppliers = load("I_BUSINESSPARTNERSUPPLIERDEX")
    gl_h, gl_accounts = load("I_GLACCOUNT")

    seed_pr = [r for r in prs if r["PURCHASEREQUISITION"] == REQUISITION]
    seed_po = [r for r in pos if r["PURCHASEORDER"] == PURCHASE_ORDER]
    seed_poi = [r for r in po_items if r["PURCHASEORDER"] == PURCHASE_ORDER]
    seed_poh = [r for r in po_hist if r["PURCHASEORDER"] == PURCHASE_ORDER]
    seed_aa = [r for r in assignments if r["PURCHASEORDER"] == PURCHASE_ORDER]
    seed_sii = [r for r in invoice_items if r["PURCHASEORDER"] == PURCHASE_ORDER]
    invoice_ids = {r["SUPPLIERINVOICE"] for r in seed_sii}
    seed_si = [r for r in invoices if r["SUPPLIERINVOICE"] in invoice_ids]
    seed_gm = [r for r in movements if r.get("PURCHASEORDER") == PURCHASE_ORDER]
    seed_bp = [r for r in partners if r.get("BUSINESSPARTNER") == SUPPLIER]
    seed_sup = [r for r in suppliers if r.get("SUPPLIER") == SUPPLIER]
    seed_gl = [r for r in gl_accounts if r["COMPANYCODE"] == COMPANY and r["GLACCOUNT"] == GL_ACCOUNT]

    write_seed("C_PURCHASEREQUISITIONITEMDEX", pr_h, seed_pr)
    write_seed("C_PURCHASEORDERDEX", po_h, seed_po)
    write_seed("C_PURCHASEORDERITEMDEX", poi_h, seed_poi)
    write_seed("C_PURCHASEORDERHISTORYDEX", poh_h, seed_poh)
    write_seed("C_PURORDACCOUNTASSIGNMENTDEX", aa_h, seed_aa)
    write_seed("C_SUPPLIERINVOICEDEX", si_h, seed_si)
    write_seed("C_SUPPLIERINVOICEITEMDEX", sii_h, seed_sii)
    write_seed("I_GOODSMOVEMENTDOCUMENTDEX", gm_h, seed_gm)
    write_seed("I_BUSINESSPARTNER", bp_h, seed_bp)
    write_seed("I_BUSINESSPARTNERSUPPLIERDEX", sup_h, seed_sup)
    write_seed("I_GLACCOUNT", gl_h, seed_gl)

    header = seed_po[0]
    supplier_name = seed_bp[0].get("BUSINESSPARTNERFULLNAME", "")
    gl = seed_gl[0]

    requisition_items = []
    for row in sorted(seed_pr, key=lambda r: r["PURCHASEREQUISITIONITEM"]):
        requisition_items.append(
            {
                "purchaseRequisitionItem": row["PURCHASEREQUISITIONITEM"],
                "text": row["PURCHASEREQUISITIONITEMTEXT"],
                "material": row.get("MATERIAL", ""),
                "requestedQuantity": row["REQUESTEDQUANTITY"],
                "unit": row["BASEUNIT"],
                "price": row["PURCHASEREQUISITIONPRICE"],
                "netAmount": row["ITEMNETAMOUNT"],
                "deliveryDate": row["DELIVERYDATE"],
                "plant": row["PLANT"],
                "purchasingGroup": row["PURCHASINGGROUP"],
                "supplier": row.get("SUPPLIER", ""),
                "accountAssignmentCategory": row.get("ACCOUNTASSIGNMENTCATEGORY", ""),
                "releaseStatus": row.get("PURREQNRELEASESTATUS", ""),
                "releaseDate": row.get("PURCHASEREQUISITIONRELEASEDATE", ""),
                "processingStatus": row.get("PROCESSINGSTATUS", ""),
                "createdByUser": row.get("CREATEDBYUSER", ""),
                "creationDate": row.get("CREATIONDATE", ""),
                "requisitionType": row.get("PURCHASEREQUISITIONTYPE", ""),
                "companyCode": row.get("COMPANYCODE", ""),
            }
        )

    order_items = []
    for row in sorted(seed_poi, key=lambda r: r["PURCHASEORDERITEM"]):
        order_items.append(
            {
                "purchaseOrderItem": row["PURCHASEORDERITEM"],
                "purchaseRequisition": row["PURCHASEREQUISITION"],
                "purchaseRequisitionItem": row["PURCHASEREQUISITIONITEM"],
                "text": row["PURCHASEORDERITEMTEXT"],
                "material": row.get("MATERIAL", ""),
                "orderQuantity": row["ORDERQUANTITY"],
                "unit": row["PURCHASEORDERQUANTITYUNIT"],
                "netPrice": row["NETPRICEAMOUNT"],
                "netAmount": row["NETAMOUNT"],
                "accountAssignmentCategory": row.get("ACCOUNTASSIGNMENTCATEGORY", ""),
                "plant": row["PLANT"],
                "goodsReceiptIsExpected": row.get("GOODSRECEIPTISEXPECTED", ""),
                "invoiceIsExpected": row.get("INVOICEISEXPECTED", ""),
            }
        )

    account_assignments = []
    for row in sorted(seed_aa, key=lambda r: r["PURCHASEORDERITEM"]):
        account_assignments.append(
            {
                "purchaseOrderItem": row["PURCHASEORDERITEM"],
                "accountAssignmentNumber": row["ACCOUNTASSIGNMENTNUMBER"],
                "masterFixedAsset": row.get("MASTERFIXEDASSET", ""),
                "fixedAsset": row.get("FIXEDASSET", ""),
                "glAccount": row.get("GLACCOUNT", ""),
                "quantity": row.get("QUANTITY", ""),
                "profitCenter": row.get("PROFITCENTER", ""),
                "accountAssignmentCategory": row.get("ACCOUNTASSIGNMENTCATEGORY", ""),
            }
        )

    history = []
    for row in seed_poh:
        history.append(
            {
                "purchaseOrderItem": row["PURCHASEORDERITEM"],
                "documentType": row["PURCHASINGHISTORYDOCUMENTTYPE"],
                "category": row["PURCHASINGHISTORYCATEGORY"],
                "document": row["PURCHASINGHISTORYDOCUMENT"],
                "documentItem": row["PURCHASINGHISTORYDOCUMENTITEM"],
                "goodsMovementType": row.get("GOODSMOVEMENTTYPE", ""),
                "quantity": row["QUANTITY"],
                "amount": row.get("PURCHASEORDERAMOUNT", ""),
                "postingDate": row["POSTINGDATE"],
                "accountAssignmentNumber": row.get("ACCOUNTASSIGNMENTNUMBER", ""),
            }
        )

    goods_receipts = []
    for row in sorted(seed_gm, key=lambda r: r["MATERIALDOCUMENT"]):
        goods_receipts.append(
            {
                "materialDocument": row["MATERIALDOCUMENT"],
                "materialDocumentYear": row["MATERIALDOCUMENTYEAR"],
                "materialDocumentItem": row["MATERIALDOCUMENTITEM"],
                "purchaseOrderItem": row["PURCHASEORDERITEM"],
                "goodsMovementType": row["GOODSMOVEMENTTYPE"],
                "quantity": row["QUANTITYINENTRYUNIT"],
                "postingDate": row["POSTINGDATE"],
                "companyCode": row["COMPANYCODE"],
            }
        )

    invoice = None
    if seed_si:
        header_iv = seed_si[0]
        invoice = {
            "supplierInvoice": header_iv["SUPPLIERINVOICE"],
            "fiscalYear": header_iv["FISCALYEAR"],
            "companyCode": header_iv["COMPANYCODE"],
            "postingDate": header_iv["POSTINGDATE"],
            "invoicingParty": header_iv["INVOICINGPARTY"],
            "reference": header_iv["SUPPLIERINVOICEIDBYINVCGPARTY"],
            "grossAmount": header_iv["INVOICEGROSSAMOUNT"],
            "currency": header_iv["DOCUMENTCURRENCY"],
            "status": header_iv["SUPPLIERINVOICESTATUS"],
            "items": [
                {
                    "supplierInvoiceItem": item["SUPPLIERINVOICEITEM"],
                    "purchaseOrderItem": item["PURCHASEORDERITEM"],
                    "quantity": item["QUANTITYINPURCHASEORDERUNIT"],
                    "amount": item["SUPPLIERINVOICEITEMAMOUNT"],
                }
                for item in sorted(seed_sii, key=lambda r: r["SUPPLIERINVOICEITEM"])
            ],
        }

    rollup = []
    for item in order_items:
        received = sum(
            (
                dec(row["quantity"])
                for row in history
                if row["purchaseOrderItem"] == item["purchaseOrderItem"] and row["documentType"] == "1"
            ),
            Decimal("0"),
        )
        invoiced_qty = sum(
            (
                dec(row["quantity"])
                for row in history
                if row["purchaseOrderItem"] == item["purchaseOrderItem"] and row["documentType"] == "2"
            ),
            Decimal("0"),
        )
        invoiced_amt = sum(
            (
                dec(row["amount"])
                for row in history
                if row["purchaseOrderItem"] == item["purchaseOrderItem"] and row["documentType"] == "2"
            ),
            Decimal("0"),
        )
        ordered = dec(item["orderQuantity"])
        rollup.append(
            {
                "purchaseRequisitionItem": item["purchaseRequisitionItem"],
                "purchaseOrderItem": item["purchaseOrderItem"],
                "text": item["text"],
                "orderedQuantity": qty(ordered),
                "orderedAmount": money(dec(item["netAmount"])),
                "receivedQuantity": qty(received),
                "invoicedQuantity": qty(invoiced_qty),
                "invoicedAmount": money(invoiced_amt),
                "openQuantity": qty(ordered - received),
                "openAmount": money(dec(item["netAmount"]) - invoiced_amt),
            }
        )

    other_requisitions = sorted({r["PURCHASEREQUISITION"] for r in prs if r["PURCHASEREQUISITION"] != REQUISITION})

    correlation = {
        "extractRun": "20261007_121746",
        "delimiter": ";",
        "seed": {
            "purchaseRequisition": REQUISITION,
            "purchaseOrder": PURCHASE_ORDER,
            "companyCode": COMPANY,
            "supplier": SUPPLIER,
            "supplierName": supplier_name,
            "currency": "USD",
        },
        "supplier": {
            "supplier": SUPPLIER,
            "name": supplier_name,
        },
        "purchaseOrder": {
            "purchaseOrder": header["PURCHASEORDER"],
            "purchaseOrderType": header["PURCHASEORDERTYPE"],
            "supplier": header["SUPPLIER"],
            "invoicingParty": header["INVOICINGPARTY"],
            "companyCode": header["COMPANYCODE"],
            "purchasingOrganization": header["PURCHASINGORGANIZATION"],
            "purchasingGroup": header["PURCHASINGGROUP"],
            "purchaseOrderDate": header["PURCHASEORDERDATE"],
            "documentCurrency": header["DOCUMENTCURRENCY"],
            "paymentTerms": header["PAYMENTTERMS"],
            "purchasingProcessingStatus": header["PURCHASINGPROCESSINGSTATUS"],
            "totalAmount": header["PURGRELEASETIMETOTALAMOUNT"],
            "createdByUser": header["CREATEDBYUSER"],
            "items": order_items,
        },
        "requisitionItems": requisition_items,
        "accountAssignments": account_assignments,
        "glAccount": {
            "glAccount": gl["GLACCOUNT"],
            "external": gl["GLACCOUNTEXTERNAL"],
            "group": gl["GLACCOUNTGROUP"],
            "reconciliationAccountType": gl["RECONCILIATIONACCOUNTTYPE"],
            "isBalanceSheetAccount": gl["ISBALANCESHEETACCOUNT"],
        },
        "asset": ASSET,
        "history": history,
        "goodsReceipts": goods_receipts,
        "supplierInvoice": invoice,
        "quantityReconciliation": rollup,
        "joinKeys": [
            {
                "from": "C_PurchaseRequisitionItemDEX",
                "to": "C_PurchaseOrderItemDEX",
                "keys": ["PurchaseRequisition", "PurchaseRequisitionItem"],
                "note": "The purchase order number is not stored on the requisition item in this extract. The PO item points back to the requisition.",
            },
            {
                "from": "C_PurchaseOrderDEX",
                "to": "C_PurchaseOrderItemDEX",
                "keys": ["PurchaseOrder"],
            },
            {
                "from": "C_PurchaseOrderItemDEX",
                "to": "C_PurOrdAccountAssignmentDEX",
                "keys": ["PurchaseOrder", "PurchaseOrderItem"],
                "note": "Account assignment category A. MasterFixedAsset is the asset. GLAccount 0016014000 is the asset reconciliation account.",
            },
            {
                "from": "C_PurchaseOrderDEX",
                "to": "I_BusinessPartner",
                "keys": ["Supplier = BusinessPartner"],
            },
            {
                "from": "C_PurOrdAccountAssignmentDEX",
                "to": "I_GLAccount",
                "keys": ["GLAccount", "CompanyCode"],
            },
        ],
        "sourceCounts": {
            "C_PURCHASEREQUISITIONITEMDEX": len(prs),
            "C_PURCHASEORDERDEX": len(pos),
            "C_PURCHASEORDERITEMDEX": len(po_items),
            "C_PURCHASEORDERHISTORYDEX": len(po_hist),
            "C_PURORDACCOUNTASSIGNMENTDEX": len(assignments),
            "C_SUPPLIERINVOICEDEX": len(invoices),
            "C_SUPPLIERINVOICEITEMDEX": len(invoice_items),
            "I_GOODSMOVEMENTDOCUMENTDEX": len(movements),
            "I_BUSINESSPARTNER": len(partners),
            "I_BUSINESSPARTNERSUPPLIERDEX": len(suppliers),
            "I_GLACCOUNT": len(gl_accounts),
        },
        "otherRequisitions": other_requisitions,
        "gaps": [
            {
                "id": "requisition-has-no-po-number",
                "detail": (
                    "C_PurchaseRequisitionItemDEX in this extract does not carry PurchaseOrder. "
                    "Follow PurchaseRequisition and PurchaseRequisitionItem on the PO item."
                ),
            },
            {
                "id": "partial-follow-on",
                "detail": (
                    "Each PO item is ordered for 20. Goods receipt and invoice so far cover 10. "
                    "10 remain open on each item."
                ),
            },
            {
                "id": "no-contract",
                "detail": "The bounded contract header and item extracts in this run contain no rows.",
            },
            {
                "id": "other-requisition",
                "detail": (
                    "Requisition 0010001573 item 00010 (RM2_DS, 150 at 5.25) is in the same "
                    "extract with processing status N and has no purchase order here."
                ),
            },
            {
                "id": "no-journal",
                "detail": "This extract set has no universal-journal file, so the invoice payment is not in the sample.",
            },
        ],
    }

    out = ROOT / "correlation.json"
    out.write_text(json.dumps(correlation, indent=2) + "\n", encoding="utf-8")

    assert len(seed_pr) == 2
    assert len(seed_po) == 1
    assert len(seed_poi) == 2
    assert {r["purchaseRequisition"] for r in order_items} == {REQUISITION}
    assert len(seed_aa) == 2
    assert {r["masterFixedAsset"] for r in account_assignments} == {ASSET}
    assert len(seed_gm) == 2
    assert invoice is not None and invoice["grossAmount"] == "21500.00"
    assert supplier_name == "Office equipment supplier domestic 1"
    by_item = {r["purchaseOrderItem"]: r for r in rollup}
    assert by_item["00010"]["orderedQuantity"] == "20.000"
    assert by_item["00010"]["receivedQuantity"] == "10.000"
    assert by_item["00010"]["invoicedAmount"] == "20000.00"
    assert by_item["00020"]["invoicedAmount"] == "1500.00"
    assert by_item["00020"]["openQuantity"] == "10.000"
    assert gl["RECONCILIATIONACCOUNTTYPE"] == "A"
    print(f"wrote {out}")
    print(f"PR {REQUISITION} -> PO {PURCHASE_ORDER} {header['PURGRELEASETIMETOTALAMOUNT']} USD; invoiced {invoice['grossAmount']}")


if __name__ == "__main__":
    main()
