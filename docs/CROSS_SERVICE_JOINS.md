# Cross-service join matrix (C2P / C2C → MD → GL)

Clients **cannot** `$expand` across OData bindings. Join in the extractor / app using the keys below.

| Service | Binding base (CAL) |
|---------|-------------------|
| Documents P2P | `/sap/opu/odata4/sap/zevo_c2p/srvd_a2x/sap/zevo_c2p/0001/` |
| Documents OTC | `/sap/opu/odata4/sap/zevo_c2c/srvd_a2x/sap/zevo_c2c/0001/` |
| Masters | `/sap/opu/odata4/sap/zevo_md/srvd_a2x/sap/zevo_md/0001/` |
| Journal | `/sap/opu/odata4/sap/zevo_generalledger/srvd_a2x/sap/zevo_generalledger/0001/` |

**Within** a binding, use typed `$expand` (see [`ZEVO_C2P.md`](ZEVO_C2P.md), [`ZEVO_C2C.md`](ZEVO_C2C.md)). This page is only **between** services.

Always filter GL with `CompanyCode`, `FiscalYear`, and `SourceLedger` (e.g. `0L`) for volume.

---

## 1. Documents → Master Data (`ZEVO_MD`)

| From (C2P / C2C) | Field(s) | To (`ZEVO_MD`) | Key |
|------------------|----------|----------------|-----|
| C2P `PurchaseOrder` / contract / PR item | `Supplier` | `BusinessPartner` | `BusinessPartner` |
| C2P same | `Supplier` | `BusinessPartnerSupplier` | `BusinessPartner` |
| C2P same | `Supplier` | `Supplier` | `Supplier` |
| C2P `SupplierInvoice` | `InvoicingParty` | `BusinessPartner` / `Supplier` | same ID |
| C2C SO / delivery / billing / contract | `SoldToParty` | `BusinessPartner` | `BusinessPartner` |
| C2C same | `SoldToParty` | `BusinessPartnerCustomer` | `BusinessPartner` |
| C2C same | `SoldToParty` | `Customer` | `Customer` |
| C2C billing / delivery | `BillToParty` / `ShipToParty` / `PayerParty` | `BusinessPartner` (+ role/Customer as needed) | same ID |
| C2C `GoodsMovementDocument` | `Customer` | `BusinessPartner` / `Customer` | same ID |
| C2P `GoodsMovementDocument` | `Supplier` | `BusinessPartner` / `Supplier` | same ID |
| C2P / C2C document items / GM | `Material` or `Product` | `Product` | `Product` (= material) |

Lean BP on C2P/C2C is enough for display names via `$expand=_Supplier` / `_SoldToParty`. For bank, DEX role, plant/trading-partner, or rich `I_Supplier` / `I_Customer`, call **MD**.

```http
# After C2P PO Supplier = 0001000559
GET {md}/BusinessPartner?$filter=BusinessPartner eq '0001000559'
  &$expand=_BPSupplier($expand=_Supplier),_Bank

# After C2C SoldToParty = 0001000569
GET {md}/BusinessPartner?$filter=BusinessPartner eq '0001000569'
  &$expand=_BPCustomer($expand=_Customer),_Bank

GET {md}/Product?$filter=Product eq 'MZ-TG-Y240'
```

---

## 2. Documents → General Ledger (`ZEVO_GENERALLEDGER`)

GL entity set: `GLAccountLineItem`. Preferred link fields: `ReferenceDocumentType` + `ReferenceDocument` (+ `CompanyCode`, `FiscalYear`, `SourceLedger`).

Clearing: use `ClearingJournalEntry` / `ClearingJournalEntryFiscalYear` / `ClearingDate` (not deprecated `ClearingAccountingDocument*`).

### 2a. C2P → GL

| Business event | From C2P | GL filter |
|----------------|----------|-----------|
| Goods receipt | `GoodsMovementDocument.MaterialDocument` (+ year) | `ReferenceDocumentType eq 'MKPF'` and `ReferenceDocument eq '{MaterialDocument}'` |
| Supplier invoice (LIV) | `SupplierInvoice` (+ `FiscalYear`, `CompanyCode`) | `ReferenceDocumentType eq 'RMRP'` and `ReferenceDocument eq '{SupplierInvoice}'` |
| GR/IR / PO on journal | PO item | Often `PurchasingDocument` / `PurchasingDocumentItem` on the line |
| Vendor payment | Vendor open item cleared by payment | Line with `FinancialAccountType eq 'K'`; follow `ClearingJournalEntry` → re-query that `AccountingDocument` (type often `KZ`) |

Typical BLART on the FI side: GR → `WE`; invoice → `RE`; payment → `KZ`.

```http
# Invoice 5100001601 → FI lines
GET {gl}/GLAccountLineItem
  ?$filter=CompanyCode eq '1710' and FiscalYear eq '2026' and SourceLedger eq '0L'
    and ReferenceDocumentType eq 'RMRP' and ReferenceDocument eq '5100001601'
  &$expand=_GLAccount,_AccountingDocType,_CompanyCode

# Material document → FI (C2P GR or C2C GI)
GET {gl}/GLAccountLineItem
  ?$filter=CompanyCode eq '1710' and FiscalYear eq '2026' and SourceLedger eq '0L'
    and ReferenceDocumentType eq 'MKPF' and ReferenceDocument eq '5000002931'
```

### 2b. C2C → GL

| Business event | From C2C | GL filter |
|----------------|----------|-----------|
| Goods issue | `GoodsMovementDocument.MaterialDocument` | `ReferenceDocumentType eq 'MKPF'` and `ReferenceDocument eq '{MaterialDocument}'` (COGS; often carries `SalesDocument`) |
| Customer billing | `BillingDocumentItem.BillingDocument` | `ReferenceDocumentType eq 'VBRK'` and `ReferenceDocument eq '{BillingDocument}'` (pack also has FI `AccountingDocument` on billing header samples — not on C2C item view) |
| Customer payment | Receivable cleared | Customer line (`FinancialAccountType eq 'D'`); `ClearingJournalEntry` → payment doc (type often `DZ`) |

```http
# Billing 0090005785 → FI (receivable / revenue)
GET {gl}/GLAccountLineItem
  ?$filter=CompanyCode eq '1710' and FiscalYear eq '2026' and SourceLedger eq '0L'
    and ReferenceDocumentType eq 'VBRK' and ReferenceDocument eq '0090005785'

# GI 4900008955 → COGS lines
GET {gl}/GLAccountLineItem
  ?$filter=CompanyCode eq '1710' and FiscalYear eq '2026' and SourceLedger eq '0L'
    and ReferenceDocumentType eq 'MKPF' and ReferenceDocument eq '4900008955'
```

### 2c. GL → MD (optional)

| From GL line | To MD |
|--------------|-------|
| `Supplier` | `BusinessPartner` / `Supplier` |
| `Customer` | `BusinessPartner` / `Customer` |
| `Product` / material on line (if filled) | `Product` |

FI org masters (`CompanyCode`, `GLAccount`, `CostCenter`, …) stay on **GL** entity sets for FI-local lookup / `$expand`, not MD. Canonical full-org extract is planned on **`ZEVO_ORG`** (keeps GL copies) — see [`ZEVO_ORG_PLAN.md`](ZEVO_ORG_PLAN.md).

---

## 3. End-to-end recipes (sample packs)

### P2P — contract → pay (C2P pack)

| Step | Service | Entity / filter | Example ID |
|------|---------|-----------------|------------|
| 1 | C2P | `PurchaseOrder` + `$expand=_Item,_Supplier` | `4500002146` |
| 2 | C2P | `PurchaseOrderHistory` type `1` + `$expand=_GoodsMovement` | GR mats e.g. `5000002931` |
| 3 | C2P | History type `2` / `SupplierInvoice` | e.g. `5100001598` |
| 4 | MD | `BusinessPartner` + `_BPSupplier,_Bank` | `0001000559` |
| 5 | GL | `RMRP` + invoice | → FI doc (e.g. `5100000000`) |
| 6 | GL | Vendor line → `ClearingJournalEntry` | payment `1500000000` / `KZ` |

### OTC — order → cash (C2C pack)

| Step | Service | Entity / filter | Example ID |
|------|---------|-----------------|------------|
| 1 | C2C | `SalesDocumentItem` + `$expand=_OutboundDeliveryItem,_BillingDocumentItem,_SoldToParty` | SO `0000006321` (2 items) |
| 2 | C2C | Delivery / GI | Delivery `0080006423`, mat doc `4900008955`, type `601` / `WL` |
| 3 | C2C | `BillingDocumentItem` | `0090005785` |
| 4 | MD | `BusinessPartner` + `_BPCustomer,_Bank` | `0001000569` |
| 5 | MD | `Product` | `MZ-TG-Y240`, `MZ-TG-Y200` |
| 6 | GL | `VBRK` + billing | FI `9400000001` |
| 7 | GL | `MKPF` + GI | COGS journal `4900000004` |
| 8 | GL | Receivable → `ClearingJournalEntry` | payment `1400000000` / `DZ` |

Pack detail: [`CONTRACT_TO_PAYMENT`](CONTRACT_TO_PAYMENT.md) / [`ORDER_TO_CASH.docx`](ORDER_TO_CASH.docx); machine keys in `docs/samples/*/correlation.json` → `joinKeys`.

---

## 4. Quick matrix (cheat sheet)

| Need | Call | Join on |
|------|------|---------|
| Rich supplier / bank from PO | MD | `Supplier` = `BusinessPartner` |
| Rich customer from SO/billing | MD | `SoldToParty` = `BusinessPartner` / `Customer` |
| Product text / attributes | MD | `Material`/`Product` = `Product` |
| FI for supplier invoice | GL | `RMRP` + `SupplierInvoice` |
| FI for billing | GL | `VBRK` + `BillingDocument` |
| FI for material doc (GR/GI) | GL | `MKPF` + `MaterialDocument` |
| Payment that cleared AP/AR | GL | `ClearingJournalEntry` on open item → that `AccountingDocument` |
| G/L account master | GL | `CompanyCode` + `ChartOfAccounts` + `GLAccount` |

---

## 5. Anti-patterns

| Avoid | Why |
|-------|-----|
| `$expand` from C2P into MD/GL | Different service bindings |
| Expecting process-flow DEX for SO→delivery | `PRIVILEGED_ONLY`; use C2C FK expands |
| Matching `SupplierInvoice` to `AccountingDocument` by equal number | Different number ranges; use `RMRP` |
| Using deprecated `ClearingAccountingDocument` | Prefer `ClearingJournalEntry*` on current GL view |
| Pulling full BP/bank into C2P/C2C again | Belongs on MD |

---

## Related

- [`ZEVO_C2P.md`](ZEVO_C2P.md) · [`ZEVO_C2C.md`](ZEVO_C2C.md) · [`ZEVO_MD.md`](ZEVO_MD.md) · [`ZEVO_GENERALLEDGER.md`](ZEVO_GENERALLEDGER.md)  
- [`NEXT_PHASES.md`](NEXT_PHASES.md) — join matrix was Phase 2 cross-cutting item #1  
