# ZEVO_C2P — Contract-to-Payment service

Typed **OData V4** service (CDS service definition + Web API binding) for the P2P / contract-to-payment extract graph. This is **not** the generic V2 `ZEVO_CDS_EXTRACT_SRV` wrapper (`ExtractCds` / `CdsResult` payload).

| Item | Value |
|------|--------|
| Service definition | `ZEVO_C2P` |
| Service binding | `ZEVO_C2P` (**OData V4 — Web API**) |
| Style | Read-only typed entity sets + navigation |
| Min platform | S/4HANA **2022+** (CDS view entity `*` select list) |
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

## Navigations (`$expand`)

Aligned with `docs/samples/*/correlation.json` (GL edges omitted).

| From | Navigation | To |
|------|------------|-----|
| `PurchaseContract` | `_Item`, `_Supplier`, `_BPSupplier` | items / BP / BP-supplier |
| `PurchaseContractItem` | `_Header`, `_History`, `_PurchaseOrderItem` | header / history / PO item |
| `PurchaseContractHistory` | `_ContractItem`, `_PurchaseOrder`, `_PurchaseOrderItem` | item / release PO |
| `PurchaseOrder` | `_Item`, `_Supplier`, `_BPSupplier` | items / BP / BP-supplier |
| `PurchaseOrderItem` | `_Header`, `_History`, `_AccountAssignment`, `_PurchaseRequisitionItem`, `_PurchaseContractItem` | … |
| `PurchaseOrderHistory` | `_PurchaseOrderItem`, `_GoodsMovement`, `_SupplierInvoice` | GR (hist type 1) / IR (hist type 2) |
| `PurchaseOrderAccountAssignment` | `_PurchaseOrderItem` | PO item |
| `PurchaseRequisitionItem` | `_PurchaseOrderItem`, `_PurchaseContractItem`, `_Supplier` | … |
| `SupplierInvoice` | `_Item`, `_InvoicingParty` | items / BP |
| `SupplierInvoiceItem` | `_Header`, `_PurchaseOrderItem`, `_GoodsMovement` | … |
| `GoodsMovementDocument` | `_PurchaseOrderItem`, `_Supplier` | … |
| `BusinessPartner` | `_BPSupplier` | supplier role |
| `BusinessPartnerSupplier` | `_BusinessPartner` | BP |

**Note:** History → goods movement / invoice associations are equality joins on document numbers. Clients should still filter `PurchasingHistoryDocumentType` (`1` = GR, `2` = IR) when expanding from history.

---

## Activate & publish (ADT)

1. **abapGit** — Pull this branch; activate all `ZEVO_C_*` DDLS / DDLX and `ZEVO_C2P` (SRVD).
2. If `*` in a view entity fails to activate, the system is below S/4 2022 — expand the select list from the base CDS in ADT.
3. If an association field name fails (e.g. `PrmthbReferenceDocumentFsclyr`), open the source CDS in ADT and correct the element name on `ZEVO_C_SupplierInvItem`.
4. **Service Binding** — Create / open `ZEVO_C2P`:
   - Binding type: **OData V4 - Web API**
   - Service definition: `ZEVO_C2P`
   - **Publish** the local service group
5. URL shape (after publish; host/group may vary):

```text
/sap/opu/odata4/sap/zevo_c2p/srvd_a2x/sap/zevo_c2p/0001/
```

6. Authorizations — same CDS access control as the underlying SAP views (`#CHECK` on the Z wrappers).

> The checked-in `zevo_c2p.srvb.xml` is a skeleton for the intended binding. **Publish** must be done in ADT / Gateway on the system; abapGit does not publish the service group.

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
  &$expand=Item($expand=History,AccountAssignment),Supplier
```

OData V4 navigation names in URLs are the **association aliases without underscore** or as defined in `$metadata` (SADL usually exposes `_Item` as `Item` or `_Item` — check `$metadata` after publish and use the NavigationProperty Name exactly).

### Requisition → PO item

```http
GET {base}/PurchaseRequisitionItem
  ?$filter=PurchaseRequisition eq '0010001624'
  &$expand=PurchaseOrderItem
```

### Contract → items → release history

```http
GET {base}/PurchaseContract
  ?$filter=PurchaseContract eq '4600000041'
  &$expand=Item($expand=History,PurchaseOrderItem)
```

---

## Delta protocol (v1)

True OData `$deltatoken` / CDC is **not** enabled on these consumption wrappers (no change-data-capture mapping to DB tables). v1 delta is **caller-managed**, same idea as V2 `DeltaSince`:

| Entity set | Prefer filter field | DDLX annotation |
|------------|--------------------|-----------------|
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
