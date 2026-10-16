# ZEVO_MD — Master Data service

Typed **OData V4** service for **cross-scenario masters**: business partner (full) + supplier/customer **DEX roles** + rich `I_Customer` / `I_Supplier` + bank + product.

This is **not** `ZEVO_C2P` / `ZEVO_C2C` (documents) and **not** `ZEVO_GENERALLEDGER` (journal + FI org). Scenario services may keep a **lean** BP for `$expand`; **canonical** partner/bank/product reads use this service.

| Item | Value |
|------|--------|
| Service definition | `ZEVO_MD` (`zevo_md.srvd.*`) |
| Service binding | Create in **ADT** as `ZEVO_MD` — **OData V4 — Web API** (not in abapGit) |
| CDS prefix | `ZEVO_M_*` |
| CDS form | Classic `define view`, explicit fields, one-way associations |

---

## Entity sets (Phase 1)

| Entity set | CDS view | Source CDS |
|------------|----------|------------|
| `BusinessPartner` | `ZEVO_M_BusinessPartner` | `I_BusinessPartner` |
| `BusinessPartnerSupplier` | `ZEVO_M_BPSupplier` | `I_BusinessPartnerSupplierDEX` |
| `BusinessPartnerCustomer` | `ZEVO_M_BPCustomer` | `I_BusinessPartnerCustomerDEX` |
| `BusinessPartnerBank` | `ZEVO_M_BPBank` | `I_BusinessPartnerBank` |
| `Supplier` | `ZEVO_M_Supplier` | `I_Supplier` (rich / extensive) |
| `Customer` | `ZEVO_M_Customer` | `I_Customer` (rich / extensive) |
| `Product` | `ZEVO_M_Product` | `I_Product` |

### Navigations

| From | Nav | To |
|------|-----|-----|
| `BusinessPartner` | `_BPSupplier` | supplier DEX role |
| `BusinessPartner` | `_BPCustomer` | customer DEX role |
| `BusinessPartner` | `_Bank` | bank details |
| `BusinessPartnerSupplier` | `_Supplier` | rich `I_Supplier` |
| `BusinessPartnerCustomer` | `_Customer` | rich `I_Customer` |

`ProductType` → `ProductTypeCode` (EDM clash). Nested expand example:

```http
GET {base}/BusinessPartner
  ?$filter=BusinessPartner eq '0001000559'
  &$expand=_BPSupplier($expand=_Supplier),_BPCustomer($expand=_Customer),_Bank
```

### Intercompany / plant–company link fields (Phase 1)

| Relationship | Field(s) | Entity set | Source |
|--------------|----------|------------|--------|
| Supplier represents a plant | `SupplierPlant`, `SupplierIsPlantRelevant` | `BusinessPartnerSupplier` (+ also on `Supplier`) | DEX / `I_Supplier` |
| Customer represents a plant | `Plant` | `BusinessPartnerCustomer` | DEX |
| Customer represents a company | `TradingPartner` ← `CustomerTradingPartnerId` | `BusinessPartnerCustomer` | DEX |
| Supplier represents a company | `TradingPartner` | `Supplier` | `I_Supplier` |
| Company code of a plant | — | Phase 2 `Plant` | `I_Plant` + assign plant→CC |
| Companies that can post to partner | — | Phase 2 company-code views | LFB1 / KNB1 |
| Plant shipping customer / IC sales-org customer | — | Phase 2 on `Plant` / sales org | T001W / TVKO |

---

## Relation to other services

| Service | Owns |
|---------|------|
| `ZEVO_MD` | Full BP, DEX roles, rich Customer/Supplier, bank, product |
| `ZEVO_C2P` | P2P documents + lean BP for expand (supplier context) |
| `ZEVO_C2C` (planned) | SD documents + lean BP for expand (customer context) |
| `ZEVO_GENERALLEDGER` | Journal lines + FI org masters (company, G/L, cost center, …) |

Clients join scenario document IDs (`Supplier`, `SoldToParty`, `Material` / `Product`) to `ZEVO_MD` entity sets.

---

## Activate & publish (ADT)

Same pattern as C2P / GL — see root README.

1. abapGit pull `main` — activate all `ZEVO_M_*` + SRVD `ZEVO_MD`.
2. **Do not** delete local SRVB/G4BA if you recreate the binding later.
3. ADT: New Service Binding **`ZEVO_MD`**, type **OData V4 - Web API**, definition `ZEVO_MD` → Activate → Publish.
4. URL shape:

```text
/sap/opu/odata4/sap/zevo_md/srvd_a2x/sap/zevo_md/0001/
```

---

## Sample queries

```http
GET {base}/$metadata

GET {base}/BusinessPartner
  ?$filter=BusinessPartner eq '0001000559'
  &$expand=_BPSupplier($expand=_Supplier),_BPCustomer($expand=_Customer),_Bank

GET {base}/Supplier?$filter=Supplier eq '0001000559'
GET {base}/Customer?$filter=Customer eq '0001000569'

GET {base}/BusinessPartnerBank
  ?$filter=BPBankDetailsChangeDate ge 2026-10-01

GET {base}/Product
  ?$filter=Product eq 'MZ-TG-Y240'
  &$top=20
```

Full host example (CAL):

```text
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_md/srvd_a2x/sap/zevo_md/0001/$metadata
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_md/srvd_a2x/sap/zevo_md/0001/BusinessPartner?$filter=BusinessPartner%20eq%20'0001000559'&$expand=_BPSupplier($expand=_Supplier),_BPCustomer($expand=_Customer),_Bank
```

---

## Activation notes

- DEX roles = BP key + plant identity; `Customer` / `Supplier` = extensive classic masters.
- Customer DEX: `Plant`; `CustomerTradingPartnerId` as `TradingPartner`.
- Supplier DEX: `SupplierPlant`; supplier **company** trading partner on `I_Supplier.TradingPartner` via `$expand=_Supplier`.
- Trim unknown `I_Supplier` / `I_Customer` / `I_Product` elements if activation complains (`ProductVolume` / `VolumeUnit` and supplier `Language` omitted on this stack).
- C2P still exposes its own BP/supplier/bank until a later lean migration.

---

## Out of scope (Phase 1)

- Plant / sales-area product views  
- BP address / identification / contact person entities  
- Slimming C2P BP (separate change after consumers move)  
- FI org masters (stay on `ZEVO_GENERALLEDGER`)  
