# Session readme

Record of the work done in this session: four sample-data use cases, the SAP GUI path used to take one live purchase requisition through approval, purchase order, goods receipt, supplier invoice, and payment, and the master data checked so company code **1710** can sell stock to company code **1010**.

Company code throughout the live requisition process is **1710**. The intercompany scenario uses both **1710** and **1010**.

## Repository use cases

ZEVO writes one CDS view per file. The use cases show how to correlate those files. Each one is a Word document with the sample rows inside it. The extracts and the correlated subset sit next to the document.

| Use case | Word document | Reference | Sample pack |
|----------|---------------|-----------|-------------|
| Contract to Payment | [CONTRACT_TO_PAYMENT.docx](CONTRACT_TO_PAYMENT.docx) | Contract **4600000041**, release PO **4500002146** | [samples/c2p](samples/c2p) |
| Order to Cash | [ORDER_TO_CASH.docx](ORDER_TO_CASH.docx) | Sales order **6321** (`0000006321`) | [samples/o2c](samples/o2c) |
| Requisition to Payment 1 | [REQUISITION_TO_PAYMENT_1.docx](REQUISITION_TO_PAYMENT_1.docx) | Requisition **10001624**, PO **4500002147**. No contract | [samples/r2o](samples/r2o) |
| Requisition to Payment 2 | [REQUISITION_TO_PAYMENT_2.docx](REQUISITION_TO_PAYMENT_2.docx) | Requisition **10001634**, contract **4600000042**, PO **4500002148** | [samples/rtp](samples/rtp) |

The four Word documents use the same 13 chapters: Purpose, Document flow, Business partner, Source document, Follow-on document, Goods movement, Invoice, Accounting, Quantity and amount reconciliation, Clearing, How the documents are correlated, Extract calls for this reference, and Sample-data files.

Download a document from GitHub while signed in to an account that can read this private repository. On the file page, use **Download**.

- https://github.com/aleo25672/sap-dex2file/blob/main/docs/CONTRACT_TO_PAYMENT.docx
- https://github.com/aleo25672/sap-dex2file/blob/main/docs/ORDER_TO_CASH.docx
- https://github.com/aleo25672/sap-dex2file/blob/main/docs/REQUISITION_TO_PAYMENT_1.docx
- https://github.com/aleo25672/sap-dex2file/blob/main/docs/REQUISITION_TO_PAYMENT_2.docx

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

## Open periods for company codes 1710 and 1010

A posting date in October 2026 needs three calendars open in the company code that posts. They are independent. Finance can be open through 2030 while materials management is still in 2025 and Asset Accounting is still in 2019.

These programs are not in this system: **AJRW**, **FAA_FISCAL_YEAR_CHANGE**, **RAJAWE00**. Year-end closing is **RAJABS00**. The step that raises **Highest F.Year** is **FAGLGVTR**.

### 1. Finance posting periods — OB52

1. In **SE16**, table **T001**, read **OPVAR** for the company code. That is its posting period variant.
2. Run **OB52** and find that variant.
3. For account types **+**, **A**, **D**, **K**, **M**, **S**, and **V**, the first interval must include the posting period. For a calendar year, period **1** through **12** of the fiscal year. The second interval is special periods **13** through **16**.

Company code **1010** uses variant **1010**. On the screen we checked, every account type was already open from period **1 / 2000** through period **12 / 2030**, and special periods **13 / 2000** through **16 / 2030**. **2026** is inside that range, so **OB52** was left unchanged. Check company code **1710** the same way before relying on it. The asset invoice in **1710** was blocked by the asset year, not by **OB52**.

### 2. Materials management period — MMRV, then MMPV

1. Run **MMRV** for the company code. **Current period** is the open materials period. **Previous period** is also open when **Allow posting to previous per.** is selected.
2. A goods movement whose posting date is outside those two periods is rejected. Roll the period forward with **MMPV**.
3. In **MMPV**, enter the company code in **From** and **To**. Enter the period you want to become the new current period, and its fiscal year. Leave **Date** empty. Select **Close period**. Execute.
4. **MMPV** moves one month at a time. Repeat until **MMRV** shows the month you need.
5. The message **The specified year is not the current calendar year** is a warning. Execute anyway when you are rolling an old period forward.

Company code **1010** started at current period **11 / 2025**, previous period **10 / 2025**, last period of the previous year **12 / 2024**. To post a goods movement in October 2026, the last **MMPV** entry is period **10**, fiscal year **2026**. The sequence is **12 / 2025**, then **01 / 2026** through **10 / 2026**. Period **9 / 2026** only opens September.

Check **MMRV** for company code **1710** the same way before a goods receipt dated in 2026.

### 3. Asset fiscal year — OAAQ, AFAB, RAJABS00, FAGLGVTR

1. Run **OAAQ**. Open the company code and ledger **0L**. Read **Highest F.Year** and **Cl.FY** on each depreciation area. An asset posting in 2026 fails while **Highest F.Year** is below **2026**. The message is **You cannot post to asset in company code … fiscal year 2026**.
2. The next year to close is the year after **Cl.FY** on area **01**.
3. Run **AFAB** for that company code and fiscal year, through period **12**. A test run can be online. The update run must be **Program → Execute in Background**. Online update returns **This processing can only be carried out as background processing**. Follow the job in **SM37** until it is **Finished**.
4. Run **RAJABS00** for that year with **Test Run** selected.
   - **Contains assets with depreciation not posted completely** means **AFAB** is still required. Do not remove the test flag.
   - **Other error** = **No** and an empty detail list means the test is clean. **Close carried out** stays **No** on a test. Run **RAJABS00** again with **Test Run** cleared.
5. If one depreciation area is still behind the others, tick **Select** on that row in **OAAQ** and choose **Close** (the button above the table, next to **Reopen**).
6. Run **FAGLGVTR** and carry balances into the next year. This raises **Highest F.Year** by one. Warnings that did not block **1710**: predictive ledgers **0C** and **0E** are skipped; postings during the run may lead to incorrect results; `ACDOCA-GLACCOUNT_TYPE` differs from G/L master data.
7. Refresh **OAAQ**. Repeat the close and the carryforward, one year at a time, until **Highest F.Year** is **2026**. The last close is fiscal year **2025**. The last carryforward is **into 2026**.
8. Repeat for ledger **2L** when that ledger is posted.

#### Company code 1710

| Check | Starting point | What we did |
|-------|----------------|-------------|
| Asset ledger **0L** | **Highest F.Year 2024**. Area **01** closed through **2022**. Areas **90**–**93** closed through **2024**. | **AFAB** for the open year (40 assets, no errors), then **RAJABS00**. Area **01** closed through **2023**, then **Close** on area **01** through **2024**. **FAGLGVTR** raised **Highest F.Year** from **2024** to **2025**. Carry forward once more **into 2026** and confirm both ledgers before an asset invoice dated in 2026. |
| Finance **OB52** | Not the error on the asset invoice. | Confirm the variant in **T001-OPVAR** and that 2026 is inside the open interval. |
| Materials **MMRV** | Not checked in this session. | Run **MMRV** before a 2026 goods receipt and roll forward with **MMPV** if the current period is earlier. |

The goods receipt of an asset can post before the asset year is open. The invoice posts the asset value, and that is where fiscal year **2026** was rejected.

#### Company code 1010

| Check | Starting point | Result |
|-------|----------------|--------|
| Finance variant **1010** | **OB52** intervals **1 / 2000–12 / 2030** and special periods **13–16** for account types **+**, **A**, **D**, **K**, **M**, **S**, **V**. | Already covered 2026. No change. |
| Materials | **MMRV** current period **11 / 2025**, previous **10 / 2025**, previous-year last period **12 / 2024**. Posting to the previous period is allowed. | Roll **MMPV** one month at a time. Last entry for an October 2026 goods movement is period **10 / 2026**. |
| Asset ledger **0L** | **Highest F.Year 2019**. Areas **01** (book depreciation) and **15** (local tax) closed through **12/31/2017**. Fiscal year variant **K4**. | The 2018 close test was clean with no depreciation error. Close each year with **RAJABS00**, then **FAGLGVTR** into the next year. Finished state: **Highest F.Year 2026**, areas **01** and **15** closed through **12/31/2025**. |
| Asset ledger **2L** | Present in the **OAAQ** tree. | Confirm **Highest F.Year 2026** before a posting updates that ledger. |

## Intercompany resale: buy in 1710, sell to 1010 with a markup

Company code **1710** buys trading good **TG11** from US vendor **1000559** (EVOLVER DOMESTIC SUPPLIER 1, stored as **0001000559**) into plant **1710**, then sells that piece to company code **1010**, plant **1010**. The transfer price is the purchase price plus **10%**.

| | Purchase | Resale |
|--|----------|--------|
| Buyer | Company **1710** | Company **1010** |
| Seller | Vendor **1000559** | Company **1710** sales order to customer **10411010**. Company **1010** buys from vendor **BP1710** |
| Material | **TG11**, Trad.Good 11, PD, Reg.Trading | Same piece |
| Quantity | **1 PC** | **1 PC** |
| Plant / storage location | **1710 / 171A** | Supply **1710 / 171A**, receive **1010** |
| Price | **13.50 USD**, the price on PO **4500002146** item 00010 | **14.85 USD** (13.50 × 1.10) |
| Markup in 1710 | | **1.35 USD** |

**TG20** from the same vendor is a serial-number material. **TG11** is the material for this run. Create a new purchase order. Leave PO **4500002146** unchanged so the contract-to-payment sample stays intact.

Company **1710** posts in **USD**. Company **1010** posts in **EUR**. The sales order and the customer invoice are in **USD** at **14.85**. The purchase order in **1010** uses **USD** when the header allows it. When that currency stays **EUR**, convert **14.85 USD** at the exchange rate on the purchase-order header.

The resale document in company **1710** is a sales order. Create it in **VA01**. The delivery and the customer invoice follow that sales order. Billing type is **F2**, the same type as billing document **0090005785**.

The master data below was checked in transaction **BP**. These documents have not been posted yet.

### Who is the vendor and who is the customer

| Role | Business partner | What it represents | Who uses it |
|------|------------------|--------------------|-------------|
| Vendor | **BP1710**, Plant 1, Palo Alto CA 94304 | Supplying plant **1710** | Company code **1010** on the purchase order |
| Customer | **10411010**, Werk 1010 als Geschäftspartner, 69190 Walldorf | Receiving plant **1010** | Company code **1710** on the sales order, the delivery, and the invoice |

Supplier **BP1010** (name WERK 1, supplier plant 1010 in the business-partner extract) is a separate partner. The customer assigned to plant 1010 in the system is **10411010**.

### Vendor BP1710

| Where | What is on the screen |
|-------|------------------------|
| Role **Supplier**, **Supplier: General Data**, Additional General Data | **Plant 1710**, Plant 1 US. Account group **SUPL**. |
| Role **Supplier (Fin. Accounting)** | Company code **1010** is open. Customer and supplier on that view are both **BP1710**. |
| Role **Supplier**, purchasing organization **1010** | Order currency **EUR**. Payment terms **0001** (pay immediately without deduction). Incoterms **EXW**, location **Vendor**. Minimum order value **0.00**. |

Company code **1010** can order from this vendor and post the vendor invoice. The same supplier row in the extract has `SUPPLIERPLANT` **1710**.

### Customer 10411010

| Where | What is on the screen |
|-------|------------------------|
| Role **Customer**, **Customer: General Data** | **Plant 1010**. Delivery date rule **On Requested Date or Later**. |
| Role **FI Customer** (`FLCU00`, Customer Fin. Accounting) | This role was missing. It was added for company code **1710**. Customer and supplier on that view are both **10411010**. |

On **Customer: Account Management** the reconciliation account first shown was **12100100**, Receivables Domestic - One Time Accounts. Save **12120000** instead. That is the receivable cleared by customer receipt **1400000000** in company code **1710**. On **Customer: Payment Transactions**, enter payment terms **0001**, then save.

Journal lines in company **1710** already carry customer **0010411010** with plant **1710**. That is this same business partner.

### Still required before the resale

1. On **10411010**, role **Customer**, **Sales Areas**: sales organization **1710**, distribution channel **10**, division **00**, payment terms **0001**, and no billing block. Sold-to, ship-to, bill-to, and payer are **10411010**.
2. **MM03** for **TG11**, Sales org. **1710**, distribution channel **10**. The sales views have to exist before **VA01**. Plant **1710** already has the material. Plant **1010** needs it too: when **MM03** has no plant **1010**, extend it with **MM01**, copy plant **1710**, views Purchasing, General Plant Data / Storage, and Accounting. Use a storage location that exists in plant **1010**.
3. **MM03**, plant **1710**, Accounting 1. Read the material price. The sales-order price is that price plus 10%. The last invoice price is **13.50 USD**, so the sales price is **14.85 USD** when the material price is still 13.50.
4. **MMRV** for both company codes. The posting date **13.10.2026** has to fall in the current or previous materials period. Company **1010** started at **11/2025**; roll it with **MMPV** through period **10/2026** as described above. Company **1710** has not been checked. The purchase goods receipt and the sales goods issue both post in **1710**, so check **1710** first.

### 1. Buy TG11 in company 1710

**ME21N**

- Vendor **1000559**, document type **NB**, purchasing organization **1710**, purchasing group **001**, company code **1710**.
- Material **TG11**, quantity **1**, net price **13.50 USD**, delivery date **13.10.2026**.
- Plant **1710**, storage location **171A**. Leave account assignment and item category empty so the piece goes into stock.
- Save and keep the purchase-order number.

**MIGO.** Goods receipt for that purchase order. Movement **101**, plant **1710**, storage location **171A**. Post.

**MIRO.** Invoice date and posting date **13.10.2026**, company code **1710**, the purchase-order number, amount **13.50 USD**. Post. Reference the invoice so it stays distinct from **5100001599**.

**F-53**, company code **1710**, bank G/L **11002000**, vendor **1000559**, amount **13.50**. Process open items, select this invoice, and post. Document type **KZ**.

### 2. Sales order in company 1710

**VA01**

- Order type **OR** (standard order, stored as type **TA**, the same type as sales order **6321**).
- Sales organization **1710**, distribution channel **10**, division **00**.
- Sold-to party **10411010**.
- Customer reference: the purchase-order number from company **1010**, once that order exists. Create the sales order first and come back to this field, or enter the purchase order first and put its number here before saving.
- Material **TG11**, order quantity **1**, plant **1710**.
- Item price **14.85 USD**. On the item **Conditions** tab, set condition **PR00** to **14.85** when the proposed price is different.
- Save and keep the sales-order number.

**VL01N.** Shipping point **1710**, the sales-order number. Picking quantity **1**, storage location **171A**. **Post Goods Issue**. Movement **601** issues the piece from plant **1710** at the material price (**13.50** when that is still the valuation price).

**VF01.** Enter the delivery number. Billing type **F2**. Save. The receivable posts to customer **10411010** in company code **1710** for **14.85 USD**. Revenue is **14.85** and the stock relief is **13.50**, so the markup is **1.35**.

### 3. Purchase order in company 1010

**ME21N**

- Vendor **BP1710**, document type **NB**, purchasing organization **1010**, purchasing group **001**, company code **1010**.
- Header currency **USD**, net price **14.85**. When the currency remains **EUR**, read the exchange rate on the header and enter the euro amount of **14.85 USD**.
- Material **TG11**, quantity **1**, delivery date **13.10.2026**, plant **1010**, the **1010** storage location.
- Leave the item category empty. This is a standard purchase, with vendor **BP1710** standing for company **1710**.
- Your reference, or the item text: the sales-order number from **VA01**.
- Save.

**MIGO.** Goods receipt for this purchase order. Movement **101**, plant **1010**. Post. Plant **1010** takes the piece into stock at the transfer price.

**MIRO.** Invoice date and posting date **13.10.2026**, company code **1010**, this purchase-order number, amount **14.85 USD** or its euro equivalent. Post. This credits vendor **BP1710**. Match the amount to billing document **F2**.

### 4. Clear the intercompany pair

- Company **1010**, transaction **F-53**: pay vendor **BP1710** for the transfer-price invoice.
- Company **1710**, transaction **F-28**: post the incoming payment from customer **10411010** for **14.85 USD**. Bank G/L **11002000**.

## Requisition to Payment 1

No contract. Extract run `20261007_121746`, journal `20261007_143416`. Purchase requisition **0010001624** (LAPTOP MACBOOK PRO 20 × 2,000.00 and KEYBOARD 20 × 150.00, account assignment A) is purchase order **4500002147**, total **43,000.00** USD, supplier **0001000579**. Both items are assigned to asset **000000600004** and G/L **0016014000**. Goods receipts and invoice **5100001600** (21,500.00, reference SUPP.INV.0003, journal **5100000002**) cover 10 of 20 on each item. Payment **1500000001** (KZ, 20261013) clears that vendor line. Ten of each item remain open.

```bash
python3 docs/samples/r2o/build_seed.py
python3 docs/samples/r2o/build_use_case_docx.py
```

## Requisition to Payment 2

With a contract. Extract run `20261007_142521`. Purchase order **4500002148** is a release of contract **4600000042**, created from requisition **0010001634**. Supplier **0001000579**, Office equipment supplier domestic 1. Account assignment **K**, cost center **0017100100**, G/L **0054400000**.

| Step | Document | Values |
|------|----------|--------|
| Requisition 0010001634 | Processing status K | Paper 1,000 at 5.00 and toner 100 at 25.00 |
| Contract 4600000042 | Type CWK, valid through 20271231 | Same quantities. Prices 4.90 and 24.20 |
| Purchase order 4500002148 | Release on 20261007 | 20 paper (98.00) and 5 toner (121.00). Total 219.00 |
| Goods receipt 5000002952 | Movement 101, 20261009 | The full release quantity |
| Invoice 5100001601 | SUPP.INV.0004, journal 5100000003 | Item amounts 98.00 and 121.00, plus 2.00. Header gross 221.00 |
| Payment 1500000002 | Type KZ, 20261013 | 221.00. Clears the vendor line. Balance 0.00 |

The requisition item does not store the contract number. The purchase-order item and the contract history do. The contract still has 980 paper and 95 toner not released. Goods receipt 5000002952 posts to accounting document **5000000004** (expense 54400000, GR/IR 21120000). Journal extract `I_GLAccountLineItemRawData` bounded `20261007_143416`.

```bash
python3 docs/samples/rtp/build_seed.py
python3 docs/samples/rtp/build_use_case_docx.py
```

## File map

```text
docs/CONTRACT_TO_PAYMENT.docx          Contract-to-Payment use case
docs/CONTRACT_TO_PAYMENT.md            Same walkthrough in markdown
docs/ORDER_TO_CASH.docx                Order-to-Cash use case
docs/REQUISITION_TO_PAYMENT_1.docx     Requisition to Payment 1, no contract
docs/REQUISITION_TO_PAYMENT_2.docx     Requisition to Payment 2, via contract 4600000042
docs/samples/c2p/                      Contract 4600000041 / PO 4500002146
docs/samples/o2c/                      Sales order 6321
docs/samples/r2o/                      Requisition 10001624 / PO 4500002147
docs/samples/rtp/                      Requisition 10001634 / contract 4600000042 / PO 4500002148
docs/README.md                         This file
```
