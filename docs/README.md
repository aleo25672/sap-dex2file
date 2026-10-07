# Session readme

Record of the work done in this session: four sample-data use cases, and the SAP GUI path used to take one live purchase requisition through approval, purchase order, goods receipt, supplier invoice, and payment.

Company code throughout the live process is **1710**.

## Repository use cases

ZEVO writes one CDS view per file. The use cases show how to correlate those files. Each one is a Word document with the sample rows inside it. The extracts and the correlated subset sit next to the document.

| Use case | Word document | Reference | Sample pack |
|----------|---------------|-----------|-------------|
| Contract to Payment | [CONTRACT_TO_PAYMENT.docx](CONTRACT_TO_PAYMENT.docx) | Contract **4600000041**, release PO **4500002146** | [samples/c2p](samples/c2p) |
| Order to Cash | [ORDER_TO_CASH.docx](ORDER_TO_CASH.docx) | Sales order **6321** (`0000006321`) | [samples/o2c](samples/o2c) |
| Requisition to Order | [REQUISITION_TO_ORDER.docx](REQUISITION_TO_ORDER.docx) | Requisition **10001624**, PO **4500002147** | [samples/r2o](samples/r2o) |
| Requisition to Payment | [REQUISITION_TO_PAYMENT.docx](REQUISITION_TO_PAYMENT.docx) | Requisition **10001634**, contract **4600000042**, PO **4500002148** | [samples/rtp](samples/rtp) |

The four Word documents use the same 13 chapters: Purpose, Document flow, Business partner, Source document, Follow-on document, Goods movement, Invoice, Accounting, Quantity and amount reconciliation, Clearing, How the documents are correlated, Extract calls for this reference, and Sample-data files.

Download a document from GitHub while signed in to an account that can read this private repository. On the file page, use **Download**.

- https://github.com/aleo25672/sap-dex2file/blob/main/docs/CONTRACT_TO_PAYMENT.docx
- https://github.com/aleo25672/sap-dex2file/blob/main/docs/ORDER_TO_CASH.docx
- https://github.com/aleo25672/sap-dex2file/blob/main/docs/REQUISITION_TO_ORDER.docx
- https://github.com/aleo25672/sap-dex2file/blob/main/docs/REQUISITION_TO_PAYMENT.docx

### Contract to Payment

Supplier **0001000559**, EVOLVER DOMESTIC SUPPLIER 1. Currency USD.

| Step | Document | Amount |
|------|----------|--------|
| Quantity contract 4600000041 | Items TG20, TG11, and unreleased TG10 | Targets 150, 200, and 100 |
| Release PO 4500002146 | Item 00020 orders 15 TG20; item 00010 orders 10 TG11 | 315.00 |
| Goods receipts | 5000002931 (3), 5000002940 (7), 5000002941 (3), movement 101 | Received quantity equals invoiced quantity |
| Supplier invoices | 5100001598 (120.00) and 5100001599 (40.50) | Journals 5100000000 and 5100000001 |
| Payment 1500000000 | Document type KZ, posting date 20261006 | 160.50. Vendor balance on 21100000 is 0.00 |

The logistics number and the FI number are different. Material document `5000002931` posts to accounting document `5000000001`. Supplier invoice `5100001598` posts to accounting document `5100000000`. Join on `ReferenceDocument`.

The first journal extract had no payment. The extract `I_GLAccountLineItemRawData` bounded `20261006_104841` added payment **1500000000**: credit G/L **0011002000** (external 11002000) and debit vendor **0021100000**. `ClearingAccountingDocument` on both invoice vendor lines is `1500000000`.

Rebuild the seed and the Word file from the repository root:

```bash
python3 docs/samples/c2p/build_seed.py
python3 docs/samples/c2p/build_use_case_docx.py
```

`source/` holds the extracts as received. `seed/` and `correlation.json` hold only the rows for this contract and PO. The journal source file is Windows-safe UTF-8. Two other source files in the Contract-to-Payment pack, business partner and goods-movement reference-document texts, are Windows-1252; the seed files are UTF-8.

### Order to Cash

Customer **0001000569**, Performance bike ltd. Sales organization 1710, distribution channel 10. Currency USD. Order net value **14,800.00**.

| Step | Document | What happened |
|------|----------|----------------|
| Sales order 0000006321 | Type TA, customer PO PO.51026.569 | 76 × MZ-TG-Y240 at 160.00 and 22 × MZ-TG-Y200 at 120.00 |
| Delivery 0080006423 | First partial delivery | 15 Y240 and 7 Y200, picked and goods issued |
| Goods issue 4900008955 | Movement 601, journal 4900000004 | Stock to cost of goods sold, 1,778.19 |
| Billing 0090005785 | Type F2, journal 9400000001 | Net 3,240.00 (2,400.00 + 840.00) |
| Receipt 1400000000 | Type DZ, posting date 20261006 | 3,240.00 clears receivable 12120000. Balance 0.00 |
| Delivery 0080006426 | Created 20261006 | Remaining 61 Y240 and 15 Y200. Not picked, issued, or billed |

Gross margin on the billed part is **1,461.81**. **11,560.00** of the order is still to be delivered and billed.

Billing document `0090005785` posts to accounting document `9400000001`. Material document `4900008955` posts to accounting document `4900000004`. The incoming payment has no sales-document number; the billing receivable points at it through `ClearingAccountingDocument`.

```bash
python3 docs/samples/o2c/build_seed.py
python3 docs/samples/o2c/build_use_case_docx.py
```

`I_Customer` in `source/` is Windows-1252. `I_GLAccount` for this pack is read from the Contract-to-Payment full extract.

## Live process: requisition 10001624 through payment

This part was done in the SAP system, not by a new extract. The chain was:

**Purchase requisition approved → purchase order → goods receipt → supplier invoice posted.**

Payment of that invoice is transaction **F-53**, described at the end. The session confirmed the invoice post. It did not confirm a payment document number.

### 1. Approve the purchase requisition

Purchase requisition **10001624**.

| Item | Account assignment | Material | Quantity |
|------|--------------------|----------|----------|
| 10 | A (asset) | LAPTOP MACBOOK PRO | 20 PC |
| 20 | A (asset) | KEYBOARD | 20 PC |

The **Approval Details** tab showed **Release of Purchase Requisition Item**, first **Ready**, then **In Process**. Processor and recipient: **Franz Musterman**.

What did not work:

- The release button on the requisition returned **Item 00010 not covered by a release strategy**. This requisition uses flexible workflow, so that classic release button has nothing to release.
- Transaction **SBWP** returned **You are not authorized to use transaction SBWP** (message **S#077**) for the logged-on user.
- Double-clicking the inbox row opens the requisition. That screen has no **Approve** button.

What worked: the inbox list titled **Release PR Item**, with one row per item:

- `Approve Purchase Requisition 10001624 00010`
- `Approve Purchase Requisition 10001624 00020`

Select the row with a single click. **Approve** is on that inbox row (toolbar tooltip, or the preview links under the list). Approving both items released the requisition. The purchase order and the goods receipt were then posted.

### 2. Supplier invoice, first attempt

Posting the invoice failed with:

**You cannot post to asset in company code 1710 fiscal year 2026.**

Account assignment **A** posts the invoice value to a fixed asset. The goods receipt can succeed; the value hits the asset at invoice verification. Asset Accounting for company code **1710**, ledger **0L**, had **Highest F.Year 2024**, so 2026 was not open.

Book depreciation area **01** was closed only through **2022**. Areas **90** to **93** were closed through **2024**.

### 3. Open the asset year

These transactions and programs are not in this system: **AJRW**, **FAA_FISCAL_YEAR_CHANGE**, **RAJAWE00**.

**AJAB** / program **RAJABS00** is year-end closing. It does not raise **Highest F.Year**. A test close of 2024 reported that 2024 was already closed for ledger **0L**, and that the closed year on depreciation area **01** was invalid.

The close of the missing year succeeded in this order:

1. **AFAB** for company code **1710**, for the fiscal year being closed, through period **12**. The test run processed 40 assets with no errors. The update run must be started with **Program → Execute in Background**. Online execution returns **This processing can only be carried out as background processing**. Follow the job in **SM37**.
2. **RAJABS00** test run. The first test stopped with **Contains assets with depreciation not posted completely**. After depreciation was posted, **Other error** was **No** and the detail list was empty.
3. **RAJABS00** again for the same year with **Test Run** cleared. Area **01** then showed closed fiscal year **2023** (last day 12/31/2023).
4. Area **01** was closed through **2024** from the asset company-code screen: tick **Select** on row **1 Book Depreciation**, then **Close** (the button above the table, next to **Reopen**).

**FAGLGVTR** (balance carryforward) then raised **Highest F.Year** from **2024** to **2025**. The log had no errors. Warnings that can be ignored for this step:

- Predictive ledgers **0C** and **0E** are not included in the carryforward.
- Postings to 2024 during the run may lead to incorrect results.
- `ACDOCA-GLACCOUNT_TYPE` in ledgers **0L** and **2L** differs from G/L master data.

Carry forward once more, into **2026**, and confirm **Highest F.Year** is **2026** in transaction **OAAQ** (ledger **0L** and ledger **2L**) before posting an asset invoice dated in 2026.

The supplier invoice was posted after this year-opening work.

### 4. Pay the invoice

Transaction **F-53**, Post Outgoing Payment.

1. Company code **1710**, posting date, and the invoice currency.
2. Bank G/L **11002000**. That is the account credited on the earlier vendor payment in this company code.
3. Payment amount and the vendor from the invoice. The purchase-order item showed vendor **1000579**.
4. **Process open items**, select the invoice, and post when the balance is **0**.

The payment document type is **KZ**. It debits the vendor and clears the invoice.

## Requisition to Order

Added from the extract run `20261007_121746`. Purchase requisition **0010001624** (LAPTOP MACBOOK PRO 20 × 2,000.00 and KEYBOARD 20 × 150.00, account assignment A) is purchase order **4500002147**, total **43,000.00** USD, supplier **0001000579** (Office equipment supplier domestic 1). Both items are assigned to asset **000000600004** and G/L **0016014000**. Goods receipts and invoice **5100001600** (21,500.00, reference SUPP.INV.0003) cover 10 of 20 on each item.

```bash
python3 docs/samples/r2o/build_seed.py
python3 docs/samples/r2o/build_use_case_docx.py
```

## Requisition to Payment

Extract run `20261007_142521`. Purchase order **4500002148** is a release of contract **4600000042**, created from requisition **0010001634**. Supplier **0001000579**, Office equipment supplier domestic 1. Account assignment **K**, cost center **0017100100**, G/L **0054400000**.

| Step | Document | Values |
|------|----------|--------|
| Requisition 0010001634 | Processing status K | Paper 1,000 at 5.00 and toner 100 at 25.00 |
| Contract 4600000042 | Type CWK, valid through 20271231 | Same quantities. Prices 4.90 and 24.20 |
| Purchase order 4500002148 | Release on 20261007 | 20 paper (98.00) and 5 toner (121.00). Total 219.00 |
| Goods receipt 5000002952 | Movement 101, 20261009 | The full release quantity |
| Invoice 5100001601 | SUPP.INV.0004, posted 20261012 | Item amounts 98.00 and 121.00. Header gross 221.00 |

The requisition item does not store the contract number. The purchase-order item and the contract history do. The contract still has 980 paper and 95 toner not released. This extract set has no journal file, so the payment that would clear invoice **5100001601** is not in the sample.

```bash
python3 docs/samples/rtp/build_seed.py
python3 docs/samples/rtp/build_use_case_docx.py
```

## File map

```text
docs/CONTRACT_TO_PAYMENT.docx          Contract-to-Payment use case
docs/CONTRACT_TO_PAYMENT.md            Same walkthrough in markdown
docs/ORDER_TO_CASH.docx                Order-to-Cash use case
docs/REQUISITION_TO_ORDER.docx         Requisition-to-Order use case
docs/REQUISITION_TO_PAYMENT.docx       Requisition-to-Payment use case, via contract 4600000042
docs/samples/c2p/                      Contract 4600000041 / PO 4500002146
docs/samples/o2c/                      Sales order 6321
docs/samples/r2o/                      Requisition 10001624 / PO 4500002147
docs/samples/rtp/                      Requisition 10001634 / contract 4600000042 / PO 4500002148
docs/README.md                         This file
```
