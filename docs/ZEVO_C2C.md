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
| `SalesDocumentScheduleLine` | `ZEVO_O_SalesDocSchedLine` | `C_SalesDocumentScheduleLineDEX` |
| `OutboundDelivery` | `ZEVO_O_OutboundDelivery` | `C_OutboundDeliveryDEX` |
| `OutboundDeliveryItem` | `ZEVO_O_OutboundDelivItem` | `C_OutboundDeliveryItemDEX` |
| `BillingDocumentItem` | `ZEVO_O_BillingDocumentItem` | `I_BillingDocumentItemDEX` |
| `GoodsMovementDocument` | `ZEVO_O_GoodsMovementDoc` | `I_GoodsMovementDocumentDEX` |
| `BusinessPartner` | `ZEVO_O_BusinessPartner` | `I_BusinessPartner` (lean) |

No separate sales-order **header** DEX — use `SalesDocumentItem` (filter `SDDocumentCategory eq 'C'`).  
No separate billing **header** DEX — header fields are on `BillingDocumentItem`.

### Recommended client filters

| Entity set | Filter |
|------------|--------|
| `SalesDocumentItem` / schedule lines | `SDDocumentCategory eq 'C'` (orders) |
| `OutboundDelivery` | CDS already restricts category `J`; optional `DeliveryDocumentTypeCode eq 'LF'` |
| `BillingDocumentItem` | CDS already restricts invoice categories (`M`/`N`/`O`/`P`/…) |
| `GoodsMovementDocument` | Sales/delivery scope, e.g. `DeliveryDocument ne ''` or `SalesOrder ne ''` / movement type `601` |

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

1. abapGit pull `main` — activate all `ZEVO_O_*` + SRVD `ZEVO_C2C`.  
2. ADT: New Service Binding **`ZEVO_C2C`**, type **OData V4 - Web API**, definition `ZEVO_C2C` → Activate → Publish.  
3. URL shape: `/sap/opu/odata4/sap/zevo_c2c/srvd_a2x/sap/zevo_c2c/0001/`  
4. **Uncheck** abapGit delete of SRVB/G4BA `ZEVO_C2C` on later pulls.

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

- Delivery DEX sources are **CDS view entities** with extraction annotations; they may be absent from `RSODPABAPCDSVIEW` / released `IXTRCTNENBLDVW` rows. Typed OData and OpenSQL still work (verified via ADT Data Preview).  
- Billing alt for classic ODP: `C_BillingDocumentItemBasicDEX` (`CSDBILDOCITMBCDX`) — Phase 1 uses the richer `I_BillingDocumentItemDEX`.  
- Product / customer role / bank → [`ZEVO_MD`](ZEVO_MD.md).
