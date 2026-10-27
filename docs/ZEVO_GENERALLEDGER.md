# ZEVO_GENERALLEDGER — General Ledger service

Typed **OData V4** service for G/L line items (`I_GLAccountLineItemRawData`) plus **FI organizational masters** (company, G/L account, cost/profit center, ledger, document type, house bank).

This is **not** `ZEVO_C2P` (P2P graph) and **not** the V2 `ExtractCds` wrapper. Supplier/customer **masters** stay in C2P / OTC; lines only carry `Supplier` / `Customer` IDs for the external tool to join.

| Item | Value |
|------|--------|
| Service definition | `ZEVO_GENERALLEDGER` (`zevo_generalledger.srvd.*`) |
| Service binding | `ZEVO_GENERALLEDGER` — **OData V4 — Web API** (`src/zevo_generalledger.srvb.xml`); abapGit ≥ 1.133.0 (root README prerequisite) |
| CDS form | Classic `define view`, explicit fields, one-way associations |
| Activation notes | `GLAccount` cast to `abap.char(10)` (SAKO search-help). `GLAccountType` aliased to `GLAccountTypeCode` (OData V4 EDM clash with entity type `GLAccountType`). `I_GLAccount` is company-code dependent — keys include `CompanyCode` so `_GLAccount` expand stays 0..1. No direct `Ledger` column on this stack — use key `SourceLedger` and nav `_Ledger`. `I_HouseBank` / `I_ProfitCenter` omit fields not on the local CDS. |

---

## Entity sets (Phase 1)

| Entity set | CDS view | Source CDS |
|------------|----------|------------|
| `GLAccountLineItem` | `ZEVO_FI_GLAcctLineItem` | `I_GLAccountLineItemRawData` |
| `CompanyCode` | `ZEVO_FI_CompanyCode` | `I_CompanyCode` |
| `GLAccount` | `ZEVO_FI_GLAccount` | `I_GLAccount` |
| `CostCenter` | `ZEVO_FI_CostCenter` | `I_CostCenter` |
| `ProfitCenter` | `ZEVO_FI_ProfitCenter` | `I_ProfitCenter` |
| `Ledger` | `ZEVO_FI_Ledger` | `I_Ledger` |
| `AccountingDocType` | `ZEVO_FI_AccountingDocType` | `I_AccountingDocumentType` |
| `HouseBank` | `ZEVO_FI_HouseBank` | `I_HouseBank` |

### Navigations from `GLAccountLineItem`

| Nav | To |
|-----|-----|
| `_CompanyCode` | company master |
| `_GLAccount` | G/L account (company + chart + account) |
| `_Ledger` | ledger (`SourceLedger`) |
| `_AccountingDocType` | journal document type (BLART) |
| `_HouseBank` | house bank (company + house bank) |

`CostCenter` / `ProfitCenter` are **fields only** on the line (no `$expand`). Their entity sets stay in the service for separate lookup — time-dependent keys make a unique FK association invalid for OData V4 (`@ObjectModel.foreignKey.association`).

No `_Supplier` / `_Customer` — use C2P/OTC with the ID fields on the line.

### Navigation example (`$expand`)

SADL keeps the CDS underscore — use `_GLAccount`, not `GLAccount`.

```http
GET https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_generalledger/srvd_a2x/sap/zevo_generalledger/0001/GLAccountLineItem
  ?$filter=CompanyCode eq '1710' and FiscalYear eq '2026' and SourceLedger eq '0L'
    and PostingDate ge 2026-10-01 and PostingDate le 2026-10-31
  &$expand=_GLAccount,_CompanyCode,_Ledger,_AccountingDocType
  &$top=100
```

One-line (browser / Postman):

```text
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_generalledger/srvd_a2x/sap/zevo_generalledger/0001/GLAccountLineItem?$filter=CompanyCode%20eq%20'1710'%20and%20FiscalYear%20eq%20'2026'%20and%20SourceLedger%20eq%20'0L'%20and%20PostingDate%20ge%202026-10-01%20and%20PostingDate%20le%202026-10-31&$expand=_GLAccount,_CompanyCode,_Ledger,_AccountingDocType&$top=100
```

Each line returns nested `_GLAccount` (company + chart + account), `_CompanyCode`, `_Ledger` (from `SourceLedger`), and `_AccountingDocType`. Optional: add `_HouseBank` when the line has a house bank.

Lookup without expand (same keys as the nav):

```http
GET {base}/GLAccount
  ?$filter=CompanyCode eq '1710' and ChartOfAccounts eq 'YCOA' and GLAccount eq '0011002000'
```

---

## Activate & publish

Same pattern as C2P — see root README **[OData V4 General Ledger](../README.md#odata-v4-general-ledger-zevo_generalledger)** and [abapGit ≥ 1.133.0](../README.md#prerequisite--abapgit-version).

1. abapGit pull `main` — activate all `ZEVO_FI_*` + SRVD `ZEVO_GENERALLEDGER` + SRVB (`zevo_generalledger.srvb.xml`).
2. ADT fallback if binding missing: New Service Binding **`ZEVO_GENERALLEDGER`**, type **OData V4 - Web API** → Activate → Publish.
3. URL shape:

```text
/sap/opu/odata4/sap/zevo_generalledger/srvd_a2x/sap/zevo_generalledger/0001/
```

---

## Reference document type (`ReferenceDocumentType` / AWTYP)

Origin of the journal entry (what created the posting):

| Value | Meaning | Typical `ReferenceDocument` |
|-------|---------|-------------------------------|
| `RMRP` | Supplier invoice (MM invoice receipt) | Supplier invoice number |
| `MKPF` | Material document (goods movement) | Material document |
| `BKPF` / `BKPFF` | FI-native / direct FI posting | Accounting / FI reference |
| `VBRK` | SD billing document | Billing document |

### Join recipes (external tool + C2P)

```text
# Supplier invoice → FI lines
ReferenceDocumentType eq 'RMRP' and ReferenceDocument eq '{SupplierInvoice}'
(+ CompanyCode, FiscalYear, SourceLedger)

# Vendor line → payment / clearing
ClearingJournalEntry + ClearingDate (+ ClearingJournalEntryFiscalYear)
→ re-query GLAccountLineItem by AccountingDocument = clearing journal entry
```

(Older names `ClearingAccountingDocument` / `ClearingDocFiscalYear` are deprecated on the SAP view.)

`FinancialAccountType`: `K` = supplier, `D` = customer, `S` = G/L (and others per customizing).

---

## Accounting document type (`AccountingDocumentType` / BLART)

Journal **document type** (number range / operation) — not the same as `ReferenceDocumentType`.

| Code | Typical meaning |
|------|-----------------|
| `RE` | Invoice receipt (MM LIV → FI) |
| `WE` | Goods receipt (PO-related) |
| `WA` | Goods issue / other inventory postings |
| `KR` | Vendor invoice (FI AP) |
| `KZ` | Vendor payment |
| `KG` | Vendor credit memo |
| `DR` | Customer invoice |
| `DZ` | Customer payment |
| `SA` | G/L account document |
| `AA` | Asset posting |
| `AF` | Depreciation posting |
| `AB` | Accounting document (often clearing / special) |

Texts are customizing (`T003` / `T003T`). Entity set `AccountingDocType` exposes the code; expand `_AccountingDocType` from the line when needed.

**Example:** invoice `5100001601` → FI `5100000003` with `ReferenceDocumentType = RMRP` and often `AccountingDocumentType = RE`; payment clearing doc often `KZ`.

---

## Delta and date filters

| Field | Role |
|-------|------|
| `LastChangeDateTime` | Preferred caller-managed delta (`@Semantics.systemDateTime.lastChangedAt`) |
| `CreationDateTime` / `CreationDate` | Created watermark / filter |
| `PostingDate` | Business period filter |
| `ClearingDate` | When the open item was cleared |
| `ClearingJournalEntry` | Payment / clearing journal entry number |
| `FiscalYear`, `CompanyCode`, `SourceLedger` | Always filter these for volume (`SourceLedger` is the ledger key; expand `_Ledger` for master) |

```http
GET {base}/GLAccountLineItem
  ?$filter=CompanyCode eq '1710' and FiscalYear eq '2026' and SourceLedger eq '0L'
    and PostingDate ge 2026-10-01 and PostingDate le 2026-10-31
  &$top=100

GET {base}/CostCenter
  ?$filter=ControllingArea eq 'A000' and CostCenter eq '0017100100'

GET {base}/GLAccountLineItem
  ?$filter=CompanyCode eq '1710' and FiscalYear eq '2026' and SourceLedger eq '0L'
    and LastChangeDateTime gt 2026-10-12T00:00:00Z
  &$orderby=LastChangeDateTime asc

GET {base}/GLAccountLineItem
  ?$filter=CompanyCode eq '1710' and FiscalYear eq '2026' and SourceLedger eq '0L'
    and ReferenceDocumentType eq 'RMRP' and ReferenceDocument eq '5100001601'
```

For `$expand` examples, see [Navigation example](#navigation-example-expand) above.

---

## Out of scope (Phase 1)

- Payment-run payee IBAN entities  
- Tax master / tax line entities  
- BP / supplier / customer expands  
- Full unbound ACDOCA column list  

---

## Relation to other services

Full key matrix and pack recipes: [`CROSS_SERVICE_JOINS.md`](CROSS_SERVICE_JOINS.md).

| | `ZEVO_C2P` | `ZEVO_C2C` | `ZEVO_MD` | `ZEVO_GENERALLEDGER` |
|--|------------|------------|----------|----------------------|
| Focus | P2P documents + lean BP | OTC documents + lean BP | Full BP / roles / bank / product | Journal lines + FI org masters |
| Doc → journal | `SupplierInvoice` → `RMRP`; GM → `MKPF` | `BillingDocument` → `VBRK`; GI → `MKPF` | — | Filter `ReferenceDocumentType` + `ReferenceDocument` |
| Partner masters | Lean `_Supplier` only | Lean `_SoldToParty` only | Full BP / roles / bank | IDs on line only (`Supplier` / `Customer`) |
| Banks | — | — | `BusinessPartnerBank` | `HouseBank` + clearing fields |
| Join across bindings | Client-side | Client-side | Client-side | Client-side |
