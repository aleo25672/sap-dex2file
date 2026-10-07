#!/usr/bin/env python3
"""Build the Requisition-to-Payment seed for PO 4500002148.

Requisition 0010001634 -> contract 4600000042 -> release PO 4500002148
-> goods receipt 5000002952 -> supplier invoice 5100001601.

    python3 docs/samples/rtp/build_seed.py
"""

from __future__ import annotations

import csv
import json
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source"
SEED = ROOT / "seed"

REQUISITION = "0010001634"
CONTRACT = "4600000042"
PURCHASE_ORDER = "4500002148"
COMPANY = "1710"
SUPPLIER = "0001000579"
GL_ACCOUNT = "0054400000"
COST_CENTER = "0017100100"


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
    return list(reader.fieldnames or []), list(reader)


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
    ch_h, contracts = load("C_PURCHASECONTRACTDEX")
    ci_h, contract_items = load("C_PURCHASECONTRACTITEMDEX")
    hist_h, contract_hist = load("C_PURCHASECONTRACTHISTORYDEX")
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
    seed_ch = [r for r in contracts if r["PURCHASECONTRACT"] == CONTRACT]
    seed_ci = [r for r in contract_items if r["PURCHASECONTRACT"] == CONTRACT]
    seed_hist = [r for r in contract_hist if r["PURCHASECONTRACT"] == CONTRACT and r["RELEASEORDER"] == PURCHASE_ORDER]
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

    for entity, headers, rows in [
        ("C_PURCHASEREQUISITIONITEMDEX", pr_h, seed_pr),
        ("C_PURCHASECONTRACTDEX", ch_h, seed_ch),
        ("C_PURCHASECONTRACTITEMDEX", ci_h, seed_ci),
        ("C_PURCHASECONTRACTHISTORYDEX", hist_h, seed_hist),
        ("C_PURCHASEORDERDEX", po_h, seed_po),
        ("C_PURCHASEORDERITEMDEX", poi_h, seed_poi),
        ("C_PURCHASEORDERHISTORYDEX", poh_h, seed_poh),
        ("C_PURORDACCOUNTASSIGNMENTDEX", aa_h, seed_aa),
        ("C_SUPPLIERINVOICEDEX", si_h, seed_si),
        ("C_SUPPLIERINVOICEITEMDEX", sii_h, seed_sii),
        ("I_GOODSMOVEMENTDOCUMENTDEX", gm_h, seed_gm),
        ("I_BUSINESSPARTNER", bp_h, seed_bp),
        ("I_BUSINESSPARTNERSUPPLIERDEX", sup_h, seed_sup),
        ("I_GLACCOUNT", gl_h, seed_gl),
    ]:
        write_seed(entity, headers, rows)

    supplier_name = seed_bp[0]["BUSINESSPARTNERFULLNAME"]
    contract = seed_ch[0]
    po = seed_po[0]
    gl = seed_gl[0]
    invoice_header = seed_si[0]

    requisition_items = []
    for row in sorted(seed_pr, key=lambda r: r["PURCHASEREQUISITIONITEM"]):
        requisition_items.append(
            {
                "item": row["PURCHASEREQUISITIONITEM"],
                "text": row["PURCHASEREQUISITIONITEMTEXT"],
                "quantity": row["REQUESTEDQUANTITY"],
                "unit": row["BASEUNIT"],
                "price": row["PURCHASEREQUISITIONPRICE"],
                "netAmount": row["ITEMNETAMOUNT"],
                "deliveryDate": row["DELIVERYDATE"],
                "plant": row["PLANT"],
                "supplier": row.get("SUPPLIER", ""),
                "accountAssignmentCategory": row.get("ACCOUNTASSIGNMENTCATEGORY", ""),
                "releaseStatus": row.get("PURREQNRELEASESTATUS", ""),
                "releaseDate": row.get("PURCHASEREQUISITIONRELEASEDATE", ""),
                "processingStatus": row.get("PROCESSINGSTATUS", ""),
                "purchaseContract": row.get("PURCHASECONTRACT", ""),
                "createdByUser": row.get("CREATEDBYUSER", ""),
                "creationDate": row.get("CREATIONDATE", ""),
                "requisitionType": row.get("PURCHASEREQUISITIONTYPE", ""),
                "companyCode": row.get("COMPANYCODE", ""),
                "purchasingGroup": row.get("PURCHASINGGROUP", ""),
            }
        )

    contract_item_rows = []
    for row in sorted(seed_ci, key=lambda r: r["PURCHASECONTRACTITEM"]):
        contract_item_rows.append(
            {
                "item": row["PURCHASECONTRACTITEM"],
                "text": row["PURCHASECONTRACTITEMTEXT"],
                "targetQuantity": row["TARGETQUANTITY"],
                "netPrice": row["CONTRACTNETPRICEAMOUNT"],
                "targetAmount": row["TARGETAMOUNT"],
                "unit": row["ORDERQUANTITYUNIT"],
                "plant": row["PLANT"],
                "accountAssignmentCategory": row.get("ACCOUNTASSIGNMENTCATEGORY", ""),
            }
        )

    order_items = []
    for row in sorted(seed_poi, key=lambda r: r["PURCHASEORDERITEM"]):
        order_items.append(
            {
                "item": row["PURCHASEORDERITEM"],
                "text": row["PURCHASEORDERITEMTEXT"],
                "quantity": row["ORDERQUANTITY"],
                "unit": row["PURCHASEORDERQUANTITYUNIT"],
                "netPrice": row["NETPRICEAMOUNT"],
                "netAmount": row["NETAMOUNT"],
                "purchaseContract": row["PURCHASECONTRACT"],
                "purchaseContractItem": row["PURCHASECONTRACTITEM"],
                "accountAssignmentCategory": row.get("ACCOUNTASSIGNMENTCATEGORY", ""),
                "plant": row["PLANT"],
            }
        )

    assignments = []
    for row in sorted(seed_aa, key=lambda r: r["PURCHASEORDERITEM"]):
        assignments.append(
            {
                "purchaseOrderItem": row["PURCHASEORDERITEM"],
                "accountAssignmentNumber": row["ACCOUNTASSIGNMENTNUMBER"],
                "costCenter": row.get("COSTCENTER", ""),
                "glAccount": row.get("GLACCOUNT", ""),
                "quantity": row.get("QUANTITY", ""),
                "profitCenter": row.get("PROFITCENTER", ""),
                "accountAssignmentCategory": row.get("ACCOUNTASSIGNMENTCATEGORY", ""),
            }
        )

    goods_receipts = []
    invoices_hist = []
    for row in seed_poh:
        entry = {
            "purchaseOrderItem": row["PURCHASEORDERITEM"],
            "document": row["PURCHASINGHISTORYDOCUMENT"],
            "documentItem": row["PURCHASINGHISTORYDOCUMENTITEM"],
            "quantity": row["QUANTITY"],
            "amount": row.get("PURCHASEORDERAMOUNT", ""),
            "postingDate": row["POSTINGDATE"],
            "purchaseContract": row.get("PURCHASECONTRACT", ""),
            "purchaseContractItem": row.get("PURCHASECONTRACTITEM", ""),
            "goodsMovementType": row.get("GOODSMOVEMENTTYPE", ""),
        }
        if row["PURCHASINGHISTORYDOCUMENTTYPE"] == "1":
            goods_receipts.append(entry)
        elif row["PURCHASINGHISTORYDOCUMENTTYPE"] == "2":
            invoices_hist.append(entry)

    material_docs = []
    for row in sorted(seed_gm, key=lambda r: r["MATERIALDOCUMENTITEM"]):
        material_docs.append(
            {
                "materialDocument": row["MATERIALDOCUMENT"],
                "year": row["MATERIALDOCUMENTYEAR"],
                "item": row["MATERIALDOCUMENTITEM"],
                "purchaseOrderItem": row["PURCHASEORDERITEM"],
                "goodsMovementType": row["GOODSMOVEMENTTYPE"],
                "quantity": row["QUANTITYINENTRYUNIT"],
                "postingDate": row["POSTINGDATE"],
            }
        )

    invoice = {
        "supplierInvoice": invoice_header["SUPPLIERINVOICE"],
        "fiscalYear": invoice_header["FISCALYEAR"],
        "postingDate": invoice_header["POSTINGDATE"],
        "reference": invoice_header["SUPPLIERINVOICEIDBYINVCGPARTY"],
        "invoicingParty": invoice_header["INVOICINGPARTY"],
        "grossAmount": invoice_header["INVOICEGROSSAMOUNT"],
        "currency": invoice_header["DOCUMENTCURRENCY"],
        "status": invoice_header["SUPPLIERINVOICESTATUS"],
        "items": [
            {
                "item": row["SUPPLIERINVOICEITEM"],
                "purchaseOrderItem": row["PURCHASEORDERITEM"],
                "quantity": row["QUANTITYINPURCHASEORDERUNIT"],
                "amount": row["SUPPLIERINVOICEITEMAMOUNT"],
            }
            for row in sorted(seed_sii, key=lambda r: r["SUPPLIERINVOICEITEM"])
        ],
    }

    rollup = []
    for req in requisition_items:
        contract_item = next(row for row in contract_item_rows if row["text"] == req["text"])
        order_item = next(row for row in order_items if row["text"] == req["text"])
        received = sum(
            (dec(row["quantity"]) for row in goods_receipts if row["purchaseOrderItem"] == order_item["item"]),
            Decimal("0"),
        )
        invoiced = sum(
            (dec(row["quantity"]) for row in invoices_hist if row["purchaseOrderItem"] == order_item["item"]),
            Decimal("0"),
        )
        invoiced_amt = sum(
            (dec(row["amount"]) for row in invoices_hist if row["purchaseOrderItem"] == order_item["item"]),
            Decimal("0"),
        )
        target = dec(contract_item["targetQuantity"])
        released = dec(order_item["quantity"])
        rollup.append(
            {
                "text": req["text"],
                "requisitionItem": req["item"],
                "contractItem": contract_item["item"],
                "purchaseOrderItem": order_item["item"],
                "requisitionQuantity": qty(dec(req["quantity"])),
                "requisitionPrice": req["price"],
                "contractTargetQuantity": qty(target),
                "contractPrice": contract_item["netPrice"],
                "contractTargetAmount": contract_item["targetAmount"],
                "releasedQuantity": qty(released),
                "releasedAmount": order_item["netAmount"],
                "receivedQuantity": qty(received),
                "invoicedQuantity": qty(invoiced),
                "invoicedAmount": money(invoiced_amt),
                "unreleasedQuantity": qty(target - released),
            }
        )

    correlation = {
        "extractRun": "20261007_142521",
        "seed": {
            "purchaseRequisition": REQUISITION,
            "purchaseContract": CONTRACT,
            "purchaseOrder": PURCHASE_ORDER,
            "companyCode": COMPANY,
            "supplier": SUPPLIER,
            "supplierName": supplier_name,
            "currency": "USD",
        },
        "requisitionItems": requisition_items,
        "contract": {
            "purchaseContract": contract["PURCHASECONTRACT"],
            "purchaseContractType": contract["PURCHASECONTRACTTYPE"],
            "supplier": contract["SUPPLIER"],
            "companyCode": contract["COMPANYCODE"],
            "purchasingOrganization": contract["PURCHASINGORGANIZATION"],
            "purchasingGroup": contract["PURCHASINGGROUP"],
            "validityStartDate": contract["VALIDITYSTARTDATE"],
            "validityEndDate": contract["VALIDITYENDDATE"],
            "documentCurrency": contract["DOCUMENTCURRENCY"],
            "paymentTerms": contract["PAYMENTTERMS"],
            "createdByUser": contract["CREATEDBYUSER"],
            "creationDate": contract["CREATIONDATE"],
            "items": contract_item_rows,
        },
        "purchaseOrder": {
            "purchaseOrder": po["PURCHASEORDER"],
            "purchaseOrderType": po["PURCHASEORDERTYPE"],
            "supplier": po["SUPPLIER"],
            "companyCode": po["COMPANYCODE"],
            "purchaseOrderDate": po["PURCHASEORDERDATE"],
            "documentCurrency": po["DOCUMENTCURRENCY"],
            "paymentTerms": po["PAYMENTTERMS"],
            "totalAmount": po["PURGRELEASETIMETOTALAMOUNT"],
            "createdByUser": po["CREATEDBYUSER"],
            "purchasingProcessingStatus": po["PURCHASINGPROCESSINGSTATUS"],
            "items": order_items,
        },
        "accountAssignments": assignments,
        "glAccount": {
            "glAccount": gl["GLACCOUNT"],
            "external": gl["GLACCOUNTEXTERNAL"],
            "group": gl["GLACCOUNTGROUP"],
            "isProfitLossAccount": gl["ISPROFITLOSSACCOUNT"],
            "costCenter": COST_CENTER,
        },
        "goodsReceipts": goods_receipts,
        "materialDocuments": material_docs,
        "invoiceHistory": invoices_hist,
        "supplierInvoice": invoice,
        "quantityReconciliation": rollup,
        "joinKeys": [
            {
                "from": "C_PurchaseRequisitionItemDEX",
                "to": "C_PurchaseContractItemDEX",
                "keys": ["Same item text, supplier, plant, account assignment category, and target quantity"],
                "note": "Processing status K means the requisition item was converted to a contract. PurchaseContract on the requisition item is blank in this extract. The contract price is lower than the requisition price.",
            },
            {
                "from": "C_PurchaseContractDEX",
                "to": "C_PurchaseContractItemDEX",
                "keys": ["PurchaseContract"],
            },
            {
                "from": "C_PurchaseContractItemDEX",
                "to": "C_PurchaseContractHistoryDEX",
                "keys": ["PurchaseContract", "PurchaseContractItem"],
                "note": "ReleaseOrder / ReleaseOrderItem is purchase order 4500002148.",
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
                "to": "C_PurOrdAccountAssignmentDEX",
                "keys": ["PurchaseOrder", "PurchaseOrderItem"],
                "note": "Account assignment category K. Cost center 0017100100. G/L 0054400000.",
            },
            {
                "from": "C_PurchaseOrderHistoryDEX type 1",
                "to": "I_GoodsMovementDocumentDEX",
                "keys": ["PurchasingHistoryDocument = MaterialDocument", "PurchaseOrder", "PurchaseOrderItem"],
            },
            {
                "from": "C_PurchaseOrderHistoryDEX type 2",
                "to": "C_SupplierInvoiceDEX",
                "keys": ["PurchasingHistoryDocument = SupplierInvoice"],
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
    }

    (ROOT / "correlation.json").write_text(json.dumps(correlation, indent=2) + "\n", encoding="utf-8")

    assert len(seed_pr) == 2 and len(seed_ch) == 1 and len(seed_ci) == 2
    assert len(seed_po) == 1 and len(seed_poi) == 2 and len(seed_hist) == 2
    assert len(seed_gm) == 2 and invoice["supplierInvoice"] == "5100001601"
    assert invoice["grossAmount"] == "221.00"
    assert money(sum((dec(i["amount"]) for i in invoice["items"]), Decimal("0"))) == "219.00"
    assert supplier_name == "Office equipment supplier domestic 1"
    assert all(row["processingStatus"] == "K" for row in requisition_items)
    assert all(not row["purchaseContract"] for row in requisition_items)
    by_text = {row["text"]: row for row in rollup}
    assert by_text["Printer A4 paper"]["releasedQuantity"] == "20.000"
    assert by_text["Printer A4 paper"]["receivedQuantity"] == "20.000"
    assert by_text["Printer A4 paper"]["unreleasedQuantity"] == "980.000"
    assert by_text["Printer Toner"]["releasedQuantity"] == "5.000"
    assert by_text["Printer Toner"]["invoicedAmount"] == "121.00"
    assert by_text["Printer Toner"]["unreleasedQuantity"] == "95.000"
    assert assignments[0]["costCenter"] == COST_CENTER
    print(f"PR {REQUISITION} -> contract {CONTRACT} -> PO {PURCHASE_ORDER} invoice {invoice['grossAmount']}")


if __name__ == "__main__":
    main()
