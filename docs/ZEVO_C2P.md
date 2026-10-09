# ZEVO_C2P — Contract-to-Payment service

Typed **OData V4** service (CDS service definition + Web API binding) for the P2P / contract-to-payment extract graph. This is **not** the generic V2 `ZEVO_CDS_EXTRACT_SRV` wrapper (`ExtractCds` / `CdsResult` payload).

| Item | Value |
|------|--------|
| Service definition | `ZEVO_C2P` (abapGit: `zevo_c2p.srvd.*`) |
| Service binding | Create in **ADT** as `ZEVO_C2P` — **OData V4 — Web API** (not shipped via abapGit; hand-written SRVB XML fails import) |
| Style | Read-only typed entity sets + navigation |
| CDS form | Classic `define view` with explicit field lists; delta field Semantics annotations are **inline** (no DDLX) |
| Out of scope (v1) | GL master / journal (`I_GLAccount*`), cost/profit center masters, product masters, ref-doc type texts |

---

## Entity sets (13)

| Entity set (OData) | CDS view entity | Source CDS |
|--------------------|-----------------|------------|
| `PurchaseRequisitionItem` | `ZEVO_C_PurchRequisitionItem` | `C_PurchaseRequisitionItemDEX` |
| `PurchaseContract` | `ZEVO_C_PurchaseContract` | `C_PurchaseContractDEX` |
| `PurchaseContractItem` | `ZEVO_C_PurchContractItem` | `C_PurchaseContractItemDEX` |
| `PurchaseContractHistory` | `ZEVO_C_PurchContractHist` | `C_PurchaseContractHistoryDEX` |
| `PurchaseOrder` | `ZEVO_C_PurchaseOrder` | `C_PurchaseOrderDEX` |
| `PurchaseOrderItem` | `ZEVO_C_PurchaseOrderItem` | `C_PurchaseOrderItemDEX` |
| `PurchaseOrderHistory` | `ZEVO_C_PurchaseOrderHist` | `C_PurchaseOrderHistoryDEX` |
| `PurchaseOrderAccountAssignment` | `ZEVO_C_PurOrdAcctAssgmt` | `C_PurOrdAccountAssignmentDEX` |
| `SupplierInvoice` | `ZEVO_C_SupplierInvoice` | `C_SupplierInvoiceDEX` |
| `SupplierInvoiceItem` | `ZEVO_C_SupplierInvItem` | `C_SupplierInvoiceItemDEX` |
| `GoodsMovementDocument` | `ZEVO_C_GoodsMovementDoc` | `I_GoodsMovementDocumentDEX` |
| `BusinessPartner` | `ZEVO_C_BusinessPartner` | `I_BusinessPartner` |
| `BusinessPartnerSupplier` | `ZEVO_C_BPSupplier` | `I_BusinessPartnerSupplierDEX` |

No purchase-requisition **header** CDS is used (none in the sample packs). PR is item-only.

---

Entity diagram for the sample chain, including the journal payment that is outside this service: [`CONTRACT_TO_PAYMENT_ER.md`](CONTRACT_TO_PAYMENT_ER.md).

## Navigations (`$expand`)

One-way associations only (avoids CDS activation cycles). Aligned with pack correlations; GL omitted.

| From | Navigation | To |
|------|------------|-----|
| `PurchaseContract` | `_Item`, `_Supplier`, `_BPSupplier` | items / BP / BP-supplier |
| `PurchaseContractItem` | `_History`, `_PurchaseOrderItem` | history / PO item |
| `PurchaseContractHistory` | `_PurchaseOrder`, `_PurchaseOrderItem` | release PO |
| `PurchaseOrder` | `_Item`, `_Supplier`, `_BPSupplier` | items / BP / BP-supplier |
| `PurchaseOrderItem` | `_History`, `_AccountAssignment` | history / acct assignment |
| `PurchaseOrderHistory` | `_GoodsMovement`, `_SupplierInvoice` | GR (type 1) / IR (type 2) |
| `PurchaseRequisitionItem` | `_PurchaseOrderItem`, `_PurchaseContractItem`, `_Supplier` | … |
| `SupplierInvoice` | `_Item`, `_InvoicingParty` | items / BP |
| `SupplierInvoiceItem` | `_GoodsMovement` | GR ref |
| `GoodsMovementDocument` | `_Supplier` | BP |
| `BusinessPartner` | `_BPSupplier` | supplier role |

**Note:** History → goods movement / invoice joins are on document numbers. Filter `PurchasingHistoryDocumentType` (`1` = GR, `2` = IR) when expanding from history.

**Activation tip:** mass-activate all `ZEVO_C_*` together after pull. Goods movement keys are `MaterialDocumentYear`, `MaterialDocument`, `MaterialDocumentItem` (not `MaterialDocumentKey*`, which are `@Consumption.hidden` on the SAP DEX and block OData V4 binding). `ZEVO_C_PurOrdAcctAssgmt` exposes `RealEstateObject` as `cast(… as abap.char(8))` so OData V4 Web API binding does not inherit conversion exit `IMKEY`. Document-type fields that would collide with OData V4 entity type names (`PurchaseOrderType`, `PurchaseContractType`, `BusinessPartnerType`) are aliased to `*TypeCode`.

---

## Activate & publish (ADT)

End-to-end setup (Eclipse install, CAL/`10.0.0.19`, abapGit pull, binding activate → publish, sample URLs, pitfalls) lives in the root README:

**[OData V4 C2P service (`ZEVO_C2P`)](../README.md#odata-v4-c2p-service-zevo_c2p)**

Short checklist:

1. **abapGit** — Pull `main`; mass-activate all 13 `ZEVO_C_*` DDLS + service definition `ZEVO_C2P`.
2. If SRVD import fails: create `ZEVO_C2P` in ADT and paste from `src/zevo_c2p.srvd.srvdsrv`.
3. **ADT** — New Service Binding `ZEVO_C2P`, type **OData V4 - Web API**, definition `ZEVO_C2P` → **Activate** → **Publish**.
4. URL shape: `/sap/opu/odata4/sap/zevo_c2p/srvd_a2x/sap/zevo_c2p/0001/`

> DDLX (`*_D`) and `zevo_c2p.srvb.xml` are **not** in the repo — they broke abapGit import. Delta Semantics are inline on the views; create/publish the binding in ADT.

---

## URL cookbook

Replace `{base}` with the published service root.

### Metadata

```http
GET {base}/$metadata
```

### Entity set (page)

```http
GET {base}/PurchaseOrder?$top=100&$skip=0&$count=true
```

### Filter + select + orderby

```http
GET {base}/PurchaseOrder
  ?$filter=CompanyCode eq '1710' and CreationDate ge 2026-10-01
  &$select=PurchaseOrder,Supplier,CreationDate,LastChangeDateTime
  &$orderby=LastChangeDateTime desc
  &$top=100
```

### Expand (header → items → history)

```http
GET {base}/PurchaseOrder
  ?$filter=PurchaseOrder eq '4500002146'
  &$expand=_Item($expand=_History,_AccountAssignment),_Supplier
```

OData V4 navigation names match the CDS association aliases **with** the leading underscore (`_Item`, `_Supplier`, …). Confirm in `$metadata` (`NavigationProperty Name=`).

### Requisition → PO item

```http
GET {base}/PurchaseRequisitionItem
  ?$filter=PurchaseRequisition eq '0010001624'
  &$expand=_PurchaseOrderItem
```

### Contract → items → release history

```http
GET {base}/PurchaseContract
  ?$filter=PurchaseContract eq '4600000041'
  &$expand=_Item($expand=_History,_PurchaseOrderItem)
```

---

## Delta protocol (v1)

True OData `$deltatoken` / CDC is **not** enabled on these consumption wrappers (no change-data-capture mapping to DB tables). v1 delta is **caller-managed**, same idea as V2 `DeltaSince`:

| Entity set | Prefer filter field | Inline annotation on the view |
|------------|--------------------|-------------------------------|
| PO / contract / PR item / acct assignment | `LastChangeDateTime` | `@Semantics.systemDateTime.lastChangedAt` |
| PO history / supplier invoice / goods movement | `PostingDate` | `@Semantics.businessDate.at` |
| Business partner | `LastChangeDate` | `@Semantics.systemDate.lastChangedAt` |
| Contract history / BP supplier | _(none)_ | full or key-based sync |

Example — PO changes since a watermark:

```http
GET {base}/PurchaseOrder
  ?$filter=LastChangeDateTime gt 2026-10-07T00:00:00Z
  &$orderby=LastChangeDateTime asc
  &$top=1000
  &$count=true
```

Client stores the max `LastChangeDateTime` (or `PostingDate`) from the page and uses it as the next watermark. Paginate with `$skip` / `$top` until complete.

Optional later: add CDC-enabled extract views if you need server-driven `@odata.deltaLink`.

---

## Relation to V2 `ZEVO_CDS_EXTRACT_SRV`

| | V2 extract | V4 `ZEVO_C2P` |
|--|------------|---------------|
| Contract | Function imports + `CdsResult`/`Payload` | Typed entity sets |
| Any CDS by name | Yes | No — fixed C2P set |
| `$expand` | No | Yes (navs above) |
| Filter | Custom `Filter` param → OpenSQL | Native OData V4 `$filter` |
| Delta | `DeltaSince` param | `$filter` on delta fields |
| GL / journal | Possible via `EntityName` | Separate service (not in v1) |

Keep V2 for ad-hoc CDS extracts; use V4 `ZEVO_C2P` for the stable P2P graph.
