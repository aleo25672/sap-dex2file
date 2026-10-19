# ZEVO_C2C — Contract-to-Cash service

Typed **OData V4** service for the sales / contract-to-cash extract graph. This is **not** `ZEVO_C2P` (P2P), **not** `ZEVO_MD` (canonical masters), and **not** the V2 `ExtractCds` wrapper.

| Item | Value |
|------|--------|
| Service definition | `ZEVO_C2C` (abapGit: `zevo_c2c.srvd.*`) |
| Service binding | Create in **ADT** as `ZEVO_C2C` — **OData V4 — Web API** (not in abapGit) |
| CDS prefix | `ZEVO_O_*` |
| CDS form | Classic `define view`, explicit fields, one-way associations |
| Masters | Lean `BusinessPartner` for `$expand` only; roles / banks / product → [`ZEVO_MD`](ZEVO_MD.md) |
| Cash / AR journal | [`ZEVO_GENERALLEDGER`](ZEVO_GENERALLEDGER.md) |

---

## Entity sets (Phase 1)

| Entity set (OData) | CDS view | Source CDS |
|--------------------|----------|------------|
| `SalesContract` | `ZEVO_O_SalesContract` | `I_SalesContract` |
| `SalesContractItem` | `ZEVO_O_SalesContractItem` | `I_SalesContractItem` |
| `SalesDocumentItem` | `ZEVO_O_SalesDocumentItem` | `C_SalesDocumentItemDEX` |
| `SalesDocumentScheduleLine` | `ZEVO_O_SalesDocSchedLine` | `C_SalesDocumentSchedLineDEX` (not `…ScheduleLine…`; newer alt `…DEX_1`) |
| `OutboundDelivery` | `ZEVO_O_OutboundDelivery` | `C_OutboundDeliveryDEX` |
| `OutboundDeliveryItem` | `ZEVO_O_OutboundDelivItem` | `C_OutboundDeliveryItemDEX` |
| `BillingDocumentItem` | `ZEVO_O_BillingDocumentItem` | `I_BillingDocumentItemDEX` |
| `GoodsMovementDocument` | `ZEVO_O_GoodsMovementDoc` | `I_GoodsMovementDocumentDEX` (full DEX; **no CDS `WHERE`**) |
| `BusinessPartner` | `ZEVO_O_BusinessPartner` | `I_BusinessPartner` (lean) |

No separate sales-order **header** DEX — use `SalesDocumentItem` (filter `SDDocumentCategory eq 'C'`).  
No separate billing **header** DEX — header fields are on `BillingDocumentItem`.

### Recommended client filters

| Entity set | Filter |
|------------|--------|
| `SalesDocumentItem` / schedule lines | `SDDocumentCategory eq 'C'` (orders) |
| `OutboundDelivery` | SAP source CDS already restricts category `J`; optional `DeliveryDocumentTypeCode eq 'LF'` |
| `BillingDocumentItem` | SAP source CDS already restricts invoice categories (`M`/`N`/`O`/`P`/…) |
| `GoodsMovementDocument` | **Client-only** — see [Goods movements](#goods-movements--full-dex-no-cds-where) |

### Goods movements — full DEX, no CDS `WHERE`

`ZEVO_O_GoodsMovementDoc` selects from **`I_GoodsMovementDocumentDEX` with no `WHERE` clause** (same as C2P’s `ZEVO_C_GoodsMovementDoc`).

| Service | ZEVO CDS filter on GM | Client `$filter` for scenario |
|---------|----------------------|-------------------------------|
| C2P | **None** | `PurchaseOrder ne ''` / specific PO / history type `1` + `$expand` |
| C2C | **None** | e.g. `DeliveryDocument ne ''`, `SalesOrder ne ''`, `GoodsMovementType eq '601'` |

```http
GET {base}/GoodsMovementDocument
  ?$filter=DeliveryDocument ne ''
  &$top=1000&$count=true

GET {base}/GoodsMovementDocument
  ?$filter=SalesOrder ne '' and GoodsMovementType eq '601'
```

---

## Source discoveries (Phase 1)

| Topic | Finding |
|-------|---------|
| No SO header DEX | Item DEX `C_SalesDocumentItemDEX` + schedule `C_SalesDocumentSchedLineDEX` (SAP abbreviates Sched; `_1` successor on some releases) |
| Contract | `I_SalesContract` / `I_SalesContractItem` |
| Delivery bulk | `C_OutboundDeliveryDEX` / `C_OutboundDeliveryItemDEX` (not `I_DeliveryDocument*` for bulk). View entities; OpenSQL/Data Preview OK; may be missing from `RSODPABAPCDSVIEW` / released `IXTRCTNENBLDVW` |
| Billing | `I_BillingDocumentItemDEX` (Phase 1); alt classic `C_BillingDocumentItemBasicDEX` (`CSDBILDOCITMBCDX`) for ODP |
| Explorer | **Include non-released DEX** lists non-released `IXTRCTNENBLDVW` rows only — does not invent views absent from that catalog |

---

## Navigations (`$expand`)

| From | Navigation | To |
|------|------------|-----|
| `SalesContract` | `_Item`, `_SoldToParty` | items / lean BP |
| `SalesContractItem` | `_SoldToParty` | lean BP |
| `SalesDocumentItem` | `_ScheduleLine`, `_SoldToParty` | schedule / lean BP |
| `OutboundDelivery` | `_Item`, `_SoldToParty`, `_ShipToParty` | items / lean BP |
| `OutboundDeliveryItem` | `_SoldToParty`, `_ShipToParty` | lean BP |
| `BillingDocumentItem` | `_SoldToParty`, `_BillToParty` | lean BP |
| `GoodsMovementDocument` | `_Customer` | lean BP |

Document-type properties that would clash with OData V4 entity type names are aliased to `*TypeCode`.

---

## Activate & publish (ADT)

1. abapGit pull `main`.
2. Mass-activate all **`ZEVO_O_*`** DDLS first (schedule source must be `C_SalesDocumentSchedLineDEX`, not `…ScheduleLine…`).
3. Activate service definition **`ZEVO_C2C`**.
4. ADT: New Service Binding **`ZEVO_C2C`**, type **OData V4 - Web API**, definition `ZEVO_C2C` → Activate → Publish.
5. URL shape: `/sap/opu/odata4/sap/zevo_c2c/srvd_a2x/sap/zevo_c2c/0001/`
6. **Uncheck** abapGit delete of SRVB/G4BA `ZEVO_C2C` on later pulls.

### If abapGit says `SRVDSRV ZEVO_C2C does not exist`

Pull does **not** always create SRVD on this stack (same as early C2P). The service **definition** must exist before the binding. Do this once in ADT (do not wait for another pull to invent it):

1. Confirm all **`ZEVO_O_*`** DDLS are **active** (especially `ZEVO_O_SalesDocSchedLine` → source `C_SalesDocumentSchedLineDEX`).
2. Eclipse ADT → **New** → **Service Definition** → name **`ZEVO_C2C`**, same package as other ZEVO objects.
3. Replace the template with the full contents of [`src/zevo_c2c.srvd.srvdsrv`](../src/zevo_c2c.srvd.srvdsrv).
4. **Activate** the SRVD (errors here almost always mean a still-inactive `ZEVO_O_*`).
5. **New** → **Service Binding** `ZEVO_C2C` → **OData V4 - Web API** → Activate → Publish.
6. Later abapGit pulls: **Overwrite** SRVD `ZEVO_C2C`; **never** delete local SRVB/G4BA.

---

## Sample queries

```http
GET {base}/$metadata

GET {base}/SalesDocumentItem
  ?$filter=SDDocumentCategory eq 'C' and SalesDocument eq '0000006321'
  &$expand=_ScheduleLine,_SoldToParty

GET {base}/OutboundDelivery
  ?$filter=OutboundDelivery eq '0080000000'
  &$expand=_Item,_SoldToParty

GET {base}/BillingDocumentItem
  ?$filter=BillingDocument eq '0090005785'
  &$expand=_SoldToParty

GET {base}/GoodsMovementDocument
  ?$filter=DeliveryDocument ne '' and GoodsMovementType eq '601'
  &$top=100
```

Full host example (CAL):

```text
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_c2c/srvd_a2x/sap/zevo_c2c/0001/$metadata
```

---

## Notes

- Delivery DEX: extraction-annotated **view entities**; typed OData / OpenSQL work even when ODP catalogs omit them.  
- Billing: Phase 1 = `I_BillingDocumentItemDEX`; classic ODP alt = `C_BillingDocumentItemBasicDEX`.  
- Product / customer role / bank → [`ZEVO_MD`](ZEVO_MD.md).  
- Sample pack path: SO **6321** → delivery → GI → billing **0090005785** → receipt (GL) — [`ORDER_TO_CASH.docx`](ORDER_TO_CASH.docx).
