#!/usr/bin/env python3
"""Build the Order-to-Cash seed subset and correlation.json.

Reads the ZEVO extracts in ./source (semicolon-separated) and writes:

- ./seed/   rows that belong to sales order 6321 (customer 0001000569),
            its deliveries, goods issue, billing document, journal, and
            incoming payment, plus the customer and G/L accounts used
- ./correlation.json   the joined chain, quantity roll-up, and gaps

I_GLAccount is read from ../c2p/source (full extract, same system).
Re-run from the repository root after replacing the source files:

    python3 docs/samples/o2c/build_seed.py
"""

from __future__ import annotations

import csv
import json
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source"
SEED = ROOT / "seed"
GL_SOURCE = ROOT.parent / "c2p" / "source"

SALES_ORDER = "0000006321"
SALES_ORDER_SHORT = "6321"
COMPANY = "1710"
CUSTOMER = "0001000569"
LEDGER = "0L"
CURRENCY = "USD"

# FI documents on leading ledger 0L for this sales order.
FI_DOCS = {
    "4900000004",  # WL goods issue for material document 4900008955
    "9400000001",  # RV billing document 0090005785
    "1400000000",  # DZ incoming payment clearing the receivable
}
GL_ACCOUNTS = {"0011002000", "0012120000", "0013600000", "0041000000", "0054083000"}


def source_file(folder: Path, entity: str) -> Path:
    matches = sorted(folder.glob(f"{entity}_*.csv"))
    if len(matches) != 1:
        raise SystemExit(f"expected one source file for {entity} in {folder}, found {matches}")
    return matches[0]


def read_text(path: Path) -> str:
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "cp1252"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    return raw.decode("latin-1")


def load(entity: str, folder: Path = SOURCE) -> tuple[list[str], list[dict[str, str]]]:
    text = read_text(source_file(folder, entity))
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
    so_h, orders = load("I_SALESORDER")
    soi_h, order_items = load("I_SALESORDERITEM")
    dl_h, deliveries = load("I_DELIVERYDOCUMENT")
    dli_h, delivery_items = load("I_DELIVERYDOCUMENTITEM")
    bd_h, billings = load("I_BILLINGDOCUMENT")
    bdi_h, billing_items = load("I_BILLINGDOCUMENTITEM")
    gm_h, movements = load("I_GOODSMOVEMENTDOCUMENTDEX")
    je_h, journal = load("I_GLACCOUNTLINEITEMRAWDATA")
    cu_h, customers = load("I_CUSTOMER")
    gl_h, gl_accounts = load("I_GLACCOUNT", GL_SOURCE)

    seed_orders = [r for r in orders if r["SALESORDER"] == SALES_ORDER]
    seed_order_items = [r for r in order_items if r["SALESORDER"] == SALES_ORDER]
    seed_delivery_items = [r for r in delivery_items if r["REFERENCESDDOCUMENT"] == SALES_ORDER]
    delivery_ids = sorted({r["DELIVERYDOCUMENT"] for r in seed_delivery_items})
    seed_deliveries = [r for r in deliveries if r["DELIVERYDOCUMENT"] in delivery_ids]
    seed_billing_items = [r for r in billing_items if r["SALESDOCUMENT"] == SALES_ORDER]
    billing_ids = sorted({r["BILLINGDOCUMENT"] for r in seed_billing_items})
    seed_billings = [r for r in billings if r["BILLINGDOCUMENT"] in billing_ids]
    seed_gm = [r for r in movements if r.get("DELIVERYDOCUMENT") in delivery_ids]
    seed_je = [
        r
        for r in journal
        if r["COMPANYCODE"] == COMPANY
        and r["SOURCELEDGER"] == LEDGER
        and r["ACCOUNTINGDOCUMENT"] in FI_DOCS
    ]
    seed_gl = [r for r in gl_accounts if r["COMPANYCODE"] == COMPANY and r["GLACCOUNT"] in GL_ACCOUNTS]
    seed_customers = [r for r in customers if r["CUSTOMER"] == CUSTOMER]

    write_seed("I_SALESORDER", so_h, seed_orders)
    write_seed("I_SALESORDERITEM", soi_h, seed_order_items)
    write_seed("I_DELIVERYDOCUMENT", dl_h, seed_deliveries)
    write_seed("I_DELIVERYDOCUMENTITEM", dli_h, seed_delivery_items)
    write_seed("I_BILLINGDOCUMENT", bd_h, seed_billings)
    write_seed("I_BILLINGDOCUMENTITEM", bdi_h, seed_billing_items)
    write_seed("I_GOODSMOVEMENTDOCUMENTDEX", gm_h, seed_gm)
    write_seed("I_GLACCOUNTLINEITEMRAWDATA", je_h, seed_je)
    write_seed("I_GLACCOUNT", gl_h, seed_gl)
    write_seed("I_CUSTOMER", cu_h, seed_customers)

    header = seed_orders[0]
    customer = seed_customers[0]

    order_item_rows = []
    for row in sorted(seed_order_items, key=lambda r: r["SALESORDERITEM"]):
        order_item_rows.append(
            {
                "salesOrderItem": row["SALESORDERITEM"],
                "itemCategory": row["SALESORDERITEMCATEGORY"],
                "material": row["MATERIAL"],
                "text": row["SALESORDERITEMTEXT"],
                "plant": row["PLANT"],
                "storageLocation": row["STORAGELOCATION"],
                "orderQuantity": row["ORDERQUANTITY"],
                "unit": row["ORDERQUANTITYUNIT"],
                "confirmedQuantity": row["CONFDDELIVQTYINORDERQTYUNIT"],
                "netPrice": row["NETPRICEAMOUNT"],
                "netAmount": row["NETAMOUNT"],
                "currency": row["TRANSACTIONCURRENCY"],
                "profitCenter": row["PROFITCENTER"],
                "shipToParty": row["SHIPTOPARTY"],
                "requestedDeliveryDate": row["REQUESTEDDELIVERYDATE"],
                "deliveryStatus": row["DELIVERYSTATUS"],
                "processStatus": row["SDPROCESSSTATUS"],
            }
        )

    delivery_docs = []
    for dl in sorted(seed_deliveries, key=lambda r: r["DELIVERYDOCUMENT"]):
        items = [
            {
                "deliveryDocumentItem": it["DELIVERYDOCUMENTITEM"],
                "referenceSDDocument": it["REFERENCESDDOCUMENT"],
                "referenceSDDocumentItem": it["REFERENCESDDOCUMENTITEM"],
                "material": it["MATERIAL"],
                "plant": it["PLANT"],
                "storageLocation": it["STORAGELOCATION"],
                "actualDeliveryQuantity": it["ACTUALDELIVERYQUANTITY"],
                "unit": it["DELIVERYQUANTITYUNIT"],
                "goodsMovementType": it["GOODSMOVEMENTTYPE"],
                "pickingStatus": it["PICKINGSTATUS"],
                "goodsMovementStatus": it["GOODSMOVEMENTSTATUS"],
                "deliveryRelatedBillingStatus": it["DELIVERYRELATEDBILLINGSTATUS"],
            }
            for it in sorted(seed_delivery_items, key=lambda r: r["DELIVERYDOCUMENTITEM"])
            if it["DELIVERYDOCUMENT"] == dl["DELIVERYDOCUMENT"]
        ]
        delivery_docs.append(
            {
                "deliveryDocument": dl["DELIVERYDOCUMENT"],
                "deliveryDocumentType": dl["DELIVERYDOCUMENTTYPE"],
                "sdDocumentCategory": dl["SDDOCUMENTCATEGORY"],
                "createdByUser": dl["CREATEDBYUSER"],
                "creationDate": dl["CREATIONDATE"],
                "shippingPoint": dl["SHIPPINGPOINT"],
                "shipToParty": dl["SHIPTOPARTY"],
                "soldToParty": dl["SOLDTOPARTY"],
                "pickingDate": dl["PICKINGDATE"],
                "plannedGoodsIssueDate": dl["PLANNEDGOODSISSUEDATE"],
                "actualGoodsMovementDate": dl["ACTUALGOODSMOVEMENTDATE"],
                "deliveryDate": dl["DELIVERYDATE"],
                "overallGoodsMovementStatus": dl["OVERALLGOODSMOVEMENTSTATUS"],
                "overallPickingStatus": dl["OVERALLPICKINGSTATUS"],
                "overallBillingStatus": dl["OVERALLDELIVRELTDBILLGSTATUS"],
                "overallProcessStatus": dl["OVERALLSDPROCESSSTATUS"],
                "items": items,
            }
        )

    goods_issues = []
    for row in sorted(seed_gm, key=lambda r: (r["MATERIALDOCUMENT"], r["MATERIALDOCUMENTITEM"])):
        goods_issues.append(
            {
                "materialDocument": row["MATERIALDOCUMENT"],
                "materialDocumentYear": row["MATERIALDOCUMENTYEAR"],
                "materialDocumentItem": row["MATERIALDOCUMENTITEM"],
                "deliveryDocument": row["DELIVERYDOCUMENT"],
                "deliveryDocumentItem": row["DELIVERYDOCUMENTITEM"],
                "material": row["MATERIAL"],
                "plant": row["PLANT"],
                "storageLocation": row["STORAGELOCATION"],
                "goodsMovementType": row["GOODSMOVEMENTTYPE"],
                "inventoryTransactionType": row["INVENTORYTRANSACTIONTYPE"],
                "goodsMovementRefDocType": row["GOODSMOVEMENTREFDOCTYPE"],
                "quantity": row["QUANTITYINENTRYUNIT"],
                "unit": row["ENTRYUNIT"],
                "debitCreditCode": row["DEBITCREDITCODE"],
                "postingDate": row["POSTINGDATE"],
                "customer": row["CUSTOMER"],
                "companyCode": row["COMPANYCODE"],
                "fiscalYear": row["FISCALYEAR"],
            }
        )

    billing_docs = []
    for bd in sorted(seed_billings, key=lambda r: r["BILLINGDOCUMENT"]):
        items = [
            {
                "billingDocumentItem": it["BILLINGDOCUMENTITEM"],
                "referenceSDDocument": it["REFERENCESDDOCUMENT"],
                "referenceSDDocumentItem": it["REFERENCESDDOCUMENTITEM"],
                "referenceSDDocumentCategory": it["REFERENCESDDOCUMENTCATEGORY"],
                "salesDocument": it["SALESDOCUMENT"],
                "salesDocumentItem": it["SALESDOCUMENTITEM"],
                "material": it["MATERIAL"],
                "text": it["BILLINGDOCUMENTITEMTEXT"],
                "billingQuantity": it["BILLINGQUANTITY"],
                "unit": it["BILLINGQUANTITYUNIT"],
                "netAmount": it["NETAMOUNT"],
                "costAmount": it["COSTAMOUNT"],
                "profitCenter": it["PROFITCENTER"],
                "servicesRenderedDate": it["SERVICESRENDEREDDATE"],
            }
            for it in sorted(seed_billing_items, key=lambda r: r["BILLINGDOCUMENTITEM"])
            if it["BILLINGDOCUMENT"] == bd["BILLINGDOCUMENT"]
        ]
        billing_docs.append(
            {
                "billingDocument": bd["BILLINGDOCUMENT"],
                "billingDocumentType": bd["BILLINGDOCUMENTTYPE"],
                "billingDocumentCategory": bd["BILLINGDOCUMENTCATEGORY"],
                "billingDocumentDate": bd["BILLINGDOCUMENTDATE"],
                "createdByUser": bd["CREATEDBYUSER"],
                "soldToParty": bd["SOLDTOPARTY"],
                "payerParty": bd["PAYERPARTY"],
                "customerPaymentTerms": bd["CUSTOMERPAYMENTTERMS"],
                "totalNetAmount": bd["TOTALNETAMOUNT"],
                "totalTaxAmount": bd["TOTALTAXAMOUNT"],
                "currency": bd["TRANSACTIONCURRENCY"],
                "companyCode": bd["COMPANYCODE"],
                "fiscalYear": bd["FISCALYEAR"],
                "accountingDocument": bd["ACCOUNTINGDOCUMENT"],
                "accountingPostingStatus": bd["ACCOUNTINGPOSTINGSTATUS"],
                "accountingTransferStatus": bd["ACCOUNTINGTRANSFERSTATUS"],
                "isCancelled": bd["BILLINGDOCUMENTISCANCELLED"],
                "items": items,
            }
        )

    journal_lines = []
    for row in sorted(seed_je, key=lambda r: (r["ACCOUNTINGDOCUMENT"], r["LEDGERGLLINEITEM"])):
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
                "postingKey": row["POSTINGKEY"],
                "amountInCompanyCodeCurrency": row["AMOUNTINCOMPANYCODECURRENCY"],
                "companyCodeCurrency": row["COMPANYCODECURRENCY"],
                "quantity": row.get("QUANTITY", ""),
                "customer": row.get("CUSTOMER", ""),
                "salesDocument": row.get("SALESDOCUMENT", ""),
                "salesDocumentItem": row.get("SALESDOCUMENTITEM", ""),
                "soldProduct": row.get("SOLDPRODUCT", ""),
                "profitCenter": row.get("PROFITCENTER", ""),
                "referenceDocumentType": row.get("REFERENCEDOCUMENTTYPE", ""),
                "referenceDocument": row.get("REFERENCEDOCUMENT", ""),
                "referenceDocumentItem": row.get("REFERENCEDOCUMENTITEM", ""),
                "assignmentReference": row.get("ASSIGNMENTREFERENCE", ""),
                "clearingDate": row.get("CLEARINGDATE", ""),
                "clearingAccountingDocument": row.get("CLEARINGACCOUNTINGDOCUMENT", ""),
                "offsettingAccount": row.get("OFFSETTINGACCOUNT", ""),
                "offsettingAccountType": row.get("OFFSETTINGACCOUNTTYPE", ""),
            }
        )

    gl_out = [
        {
            "glAccount": row["GLACCOUNT"],
            "companyCode": row["COMPANYCODE"],
            "chartOfAccounts": row["CHARTOFACCOUNTS"],
            "glAccountGroup": row["GLACCOUNTGROUP"],
            "reconciliationAccountType": row["RECONCILIATIONACCOUNTTYPE"],
            "isProfitLossAccount": row["ISPROFITLOSSACCOUNT"],
            "isBalanceSheetAccount": row["ISBALANCESHEETACCOUNT"],
            "glAccountExternal": row["GLACCOUNTEXTERNAL"],
        }
        for row in sorted(seed_gl, key=lambda r: r["GLACCOUNT"])
    ]

    # Quantity roll-up per sales order item.
    rollup = []
    for item in order_item_rows:
        so_item = item["salesOrderItem"]
        delivered_posted = Decimal("0")
        delivered_open = Decimal("0")
        for dl in delivery_docs:
            for it in dl["items"]:
                if it["referenceSDDocumentItem"] != so_item:
                    continue
                if it["goodsMovementStatus"] == "C":
                    delivered_posted += dec(it["actualDeliveryQuantity"])
                else:
                    delivered_open += dec(it["actualDeliveryQuantity"])
        billed_qty = Decimal("0")
        billed_amt = Decimal("0")
        for bd in billing_docs:
            for it in bd["items"]:
                if it["salesDocumentItem"] == so_item:
                    billed_qty += dec(it["billingQuantity"])
                    billed_amt += dec(it["netAmount"])
        ordered = dec(item["orderQuantity"])
        rollup.append(
            {
                "salesOrderItem": so_item,
                "material": item["material"],
                "orderQuantity": qty(ordered),
                "orderNetAmount": money(dec(item["netAmount"])),
                "goodsIssuedQuantity": qty(delivered_posted),
                "inOpenDeliveryQuantity": qty(delivered_open),
                "billedQuantity": qty(billed_qty),
                "billedNetAmount": money(billed_amt),
                "notYetBilledQuantity": qty(ordered - billed_qty),
                "notYetBilledNetAmount": money(dec(item["netAmount"]) - billed_amt),
            }
        )

    ar_lines = [l for l in journal_lines if l["glAccount"] == "0012120000"]
    ar_balance = sum((dec(l["amountInCompanyCodeCurrency"]) for l in ar_lines), Decimal("0"))
    receipt_lines = [l for l in journal_lines if l["accountingDocumentType"] == "DZ"]
    receipt_docs = sorted({l["accountingDocument"] for l in receipt_lines})
    receipt_doc = receipt_docs[0] if len(receipt_docs) == 1 else ""
    received = sum(
        (dec(l["amountInCompanyCodeCurrency"]) for l in receipt_lines if l["glAccount"] == "0011002000"),
        Decimal("0"),
    )
    revenue = sum(
        (dec(l["amountInCompanyCodeCurrency"]) for l in journal_lines if l["glAccount"] == "0041000000"),
        Decimal("0"),
    )
    cogs = sum(
        (dec(l["amountInCompanyCodeCurrency"]) for l in journal_lines if l["glAccount"] == "0054083000"),
        Decimal("0"),
    )
    cleared_receivables = [
        {
            "accountingDocument": l["accountingDocument"],
            "billingDocument": l["referenceDocument"],
            "amount": l["amountInCompanyCodeCurrency"],
            "clearingDate": l["clearingDate"],
            "clearingAccountingDocument": l["clearingAccountingDocument"],
        }
        for l in journal_lines
        if l["accountingDocumentType"] == "RV" and l["glAccount"] == "0012120000"
    ]
    receipt_customer_line = next(
        (l for l in receipt_lines if l["glAccount"] == "0012120000"), None
    )

    other_orders = sorted(
        {
            (r["SALESORDER"], r["SALESORDERTYPE"], r["SOLDTOPARTY"], r["TOTALNETAMOUNT"])
            for r in orders
            if r["SALESORDER"] != SALES_ORDER
        }
    )

    correlation = {
        "extractRun": "20261006_154927",
        "delimiter": ";",
        "seed": {
            "salesOrder": SALES_ORDER,
            "salesOrderShort": SALES_ORDER_SHORT,
            "companyCode": COMPANY,
            "salesOrganization": header["SALESORGANIZATION"],
            "customer": CUSTOMER,
            "customerName": customer["BPCUSTOMERFULLNAME"],
            "currency": CURRENCY,
            "ledger": LEDGER,
        },
        "customer": {
            "customer": customer["CUSTOMER"],
            "name": customer["CUSTOMERNAME"],
            "fullName": customer["CUSTOMERFULLNAME"],
            "bpFullName": customer["BPCUSTOMERFULLNAME"],
            "accountGroup": customer["CUSTOMERACCOUNTGROUP"],
            "country": customer["COUNTRY"],
            "postalCode": customer["POSTALCODE"],
            "street": customer["STREETNAME"],
            "region": customer["REGION"],
            "language": customer["LANGUAGE"],
            "createdByUser": customer["CREATEDBYUSER"],
            "creationDate": customer["CREATIONDATE"],
        },
        "salesOrder": {
            "salesOrder": header["SALESORDER"],
            "salesOrderType": header["SALESORDERTYPE"],
            "createdByUser": header["CREATEDBYUSER"],
            "creationDate": header["CREATIONDATE"],
            "salesOrderDate": header["SALESORDERDATE"],
            "salesOrganization": header["SALESORGANIZATION"],
            "distributionChannel": header["DISTRIBUTIONCHANNEL"],
            "division": header["ORGANIZATIONDIVISION"],
            "soldToParty": header["SOLDTOPARTY"],
            "purchaseOrderByCustomer": header["PURCHASEORDERBYCUSTOMER"],
            "customerPurchaseOrderDate": header["CUSTOMERPURCHASEORDERDATE"],
            "requestedDeliveryDate": header["REQUESTEDDELIVERYDATE"],
            "totalNetAmount": header["TOTALNETAMOUNT"],
            "currency": header["TRANSACTIONCURRENCY"],
            "customerPaymentTerms": header["CUSTOMERPAYMENTTERMS"],
            "incoterms": header["INCOTERMSCLASSIFICATION"],
            "incotermsLocation": header["INCOTERMSLOCATION1"],
            "billingCompanyCode": header["BILLINGCOMPANYCODE"],
            "creditControlArea": header["CREDITCONTROLAREA"],
            "overallDeliveryStatus": header["OVERALLDELIVERYSTATUS"],
            "overallProcessStatus": header["OVERALLSDPROCESSSTATUS"],
            "items": order_item_rows,
        },
        "deliveries": delivery_docs,
        "goodsIssues": goods_issues,
        "billingDocuments": billing_docs,
        "journalLines": journal_lines,
        "glAccounts": gl_out,
        "quantityReconciliation": rollup,
        "profit": {
            "revenue": money(abs(revenue)),
            "costOfGoodsSold": money(cogs),
            "grossMargin": money(abs(revenue) - cogs),
            "currency": CURRENCY,
        },
        "cash": {
            "status": "cleared" if receipt_doc and ar_balance == 0 else "open",
            "receivedAmount": money(received),
            "receivableBalance": money(ar_balance),
            "currency": CURRENCY,
            "receivableGlAccount": "0012120000",
            "bankGlAccount": "0011002000",
            "accountingDocument": receipt_doc,
            "accountingDocumentType": "DZ",
            "postingDate": receipt_customer_line["postingDate"] if receipt_customer_line else "",
            "clearingDate": receipt_customer_line["clearingDate"] if receipt_customer_line else "",
            "customer": CUSTOMER,
            "clearedReceivables": cleared_receivables,
            "lines": [
                {
                    "ledgerGLLineItem": l["ledgerGLLineItem"],
                    "glAccount": l["glAccount"],
                    "financialAccountType": l["financialAccountType"],
                    "debitCreditCode": l["debitCreditCode"],
                    "postingKey": l["postingKey"],
                    "amountInCompanyCodeCurrency": l["amountInCompanyCodeCurrency"],
                    "customer": l["customer"],
                    "offsettingAccount": l["offsettingAccount"],
                    "assignmentReference": l["assignmentReference"],
                    "clearingDate": l["clearingDate"],
                    "clearingAccountingDocument": l["clearingAccountingDocument"],
                }
                for l in receipt_lines
            ],
        },
        "joinKeys": [
            {"from": "I_SalesOrder", "to": "I_SalesOrderItem", "keys": ["SalesOrder"]},
            {
                "from": "I_SalesOrderItem",
                "to": "I_DeliveryDocumentItem",
                "keys": ["SalesOrder = ReferenceSDDocument", "SalesOrderItem = ReferenceSDDocumentItem"],
                "note": "ReferenceSDDocumentCategory C = sales order.",
            },
            {"from": "I_DeliveryDocument", "to": "I_DeliveryDocumentItem", "keys": ["DeliveryDocument"]},
            {
                "from": "I_DeliveryDocumentItem",
                "to": "I_GoodsMovementDocumentDEX",
                "keys": ["DeliveryDocument", "DeliveryDocumentItem"],
                "note": "GoodsMovementType 601, GoodsMovementRefDocType L. ReferenceDocument is also the delivery.",
            },
            {
                "from": "I_DeliveryDocumentItem",
                "to": "I_BillingDocumentItem",
                "keys": ["DeliveryDocument = ReferenceSDDocument", "DeliveryDocumentItem = ReferenceSDDocumentItem"],
                "note": "ReferenceSDDocumentCategory J = delivery. SalesDocument / SalesDocumentItem point back to the order.",
            },
            {"from": "I_BillingDocument", "to": "I_BillingDocumentItem", "keys": ["BillingDocument"]},
            {
                "from": "I_BillingDocument",
                "to": "I_GLAccountLineItemRawData",
                "keys": ["AccountingDocument + CompanyCode + FiscalYear", "or ReferenceDocumentType VBRK and ReferenceDocument = BillingDocument"],
                "note": "I_BillingDocument carries AccountingDocument directly.",
            },
            {
                "from": "I_GoodsMovementDocumentDEX",
                "to": "I_GLAccountLineItemRawData",
                "keys": ["ReferenceDocumentType MKPF", "ReferenceDocument = MaterialDocument"],
                "note": "COGS lines carry SalesDocument and SalesDocumentItem.",
            },
            {
                "from": "I_GLAccountLineItemRawData receivable line",
                "to": "Incoming payment type DZ",
                "keys": ["ClearingAccountingDocument", "ClearingDate", "Customer"],
            },
            {"from": "I_SalesOrder", "to": "I_Customer", "keys": ["SoldToParty = Customer"]},
            {"from": "I_GLAccountLineItemRawData", "to": "I_GLAccount", "keys": ["GLAccount", "CompanyCode"]},
        ],
        "sourceCounts": {
            "I_SALESORDER": len(orders),
            "I_SALESORDERITEM": len(order_items),
            "I_DELIVERYDOCUMENT": len(deliveries),
            "I_DELIVERYDOCUMENTITEM": len(delivery_items),
            "I_BILLINGDOCUMENT": len(billings),
            "I_BILLINGDOCUMENTITEM": len(billing_items),
            "I_GOODSMOVEMENTDOCUMENTDEX": len(movements),
            "I_GLACCOUNTLINEITEMRAWDATA": len(journal),
            "I_CUSTOMER": len(customers),
            "I_GLACCOUNT": len(gl_accounts),
        },
        "otherSalesOrders": [
            {"salesOrder": so, "type": typ, "soldToParty": party, "totalNetAmount": amt}
            for so, typ, party, amt in other_orders
        ],
        "gaps": [
            {
                "id": "second-delivery-open",
                "detail": (
                    "Delivery 0080006426 (61 of MZ-TG-Y240 and 15 of MZ-TG-Y200) was created "
                    "by SAP_SYSTEM on 20261006. Picking, goods movement, and billing status are A. "
                    "It has no material document, no billing item, and no journal line."
                ),
            },
            {
                "id": "partial-billing",
                "detail": (
                    "Order net value 14800.00. Billed 3240.00 on 0090005785 for delivery "
                    "0080006423. 11560.00 is not yet billed."
                ),
            },
            {
                "id": "no-tax",
                "detail": "TotalTaxAmount is 0.00 on the billing document and no tax line is in the journal.",
            },
            {
                "id": "sd-number-vs-fi-number",
                "detail": (
                    "Billing document 0090005785 posts to accounting document 9400000001. "
                    "Material document 4900008955 posts to accounting document 4900000004. "
                    "The incoming payment is accounting document 1400000000 with no SD document."
                ),
            },
            {
                "id": "parallel-ledger",
                "detail": "The same FI documents also exist on ledger 2L. The seed keeps 0L.",
            },
            {
                "id": "customer-master-encoding",
                "detail": "I_Customer in source/ is Windows-1252. The seed file is UTF-8.",
            },
        ],
    }

    out = ROOT / "correlation.json"
    out.write_text(json.dumps(correlation, indent=2) + "\n", encoding="utf-8")

    assert len(seed_orders) == 1
    assert len(seed_order_items) == 2
    assert delivery_ids == ["0080006423", "0080006426"], delivery_ids
    assert len(seed_delivery_items) == 4
    assert billing_ids == ["0090005785"], billing_ids
    assert len(seed_billing_items) == 2
    assert {r["MATERIALDOCUMENT"] for r in seed_gm} == {"4900008955"}
    assert len(seed_gm) == 2
    assert len(seed_je) == 9, len(seed_je)
    assert len(seed_gl) == 5, len(seed_gl)
    assert len(seed_customers) == 1
    assert customer["BPCUSTOMERFULLNAME"] == "Performance bike ltd"
    assert money(received) == "3240.00", money(received)
    assert money(ar_balance) == "0.00", money(ar_balance)
    assert receipt_doc == "1400000000"
    assert money(abs(revenue)) == "3240.00"
    assert money(cogs) == "1778.19", money(cogs)
    assert cleared_receivables and all(
        r["clearingAccountingDocument"] == "1400000000" for r in cleared_receivables
    )
    by_item = {r["salesOrderItem"]: r for r in rollup}
    assert by_item["000010"]["goodsIssuedQuantity"] == "15.000"
    assert by_item["000010"]["inOpenDeliveryQuantity"] == "61.000"
    assert by_item["000010"]["billedNetAmount"] == "2400.00"
    assert by_item["000020"]["goodsIssuedQuantity"] == "7.000"
    assert by_item["000020"]["billedNetAmount"] == "840.00"
    assert by_item["000020"]["notYetBilledQuantity"] == "15.000"

    print(f"wrote {out}")
    print(f"seed files: {len(list(SEED.glob('*.csv')))}")
    print(
        f"billed {money(abs(revenue))} {CURRENCY}; received {money(received)} via {receipt_doc}; "
        f"AR balance {money(ar_balance)}; COGS {money(cogs)}"
    )


if __name__ == "__main__":
    main()
