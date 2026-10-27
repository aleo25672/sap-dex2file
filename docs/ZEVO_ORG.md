# ZEVO_ORG — Organizational structure service

Typed **OData V4** service for the **canonical org catalog**: controlling / company / cost & profit centers, plant (+ storage location + valuation area), purchasing & sales org units, and **enterprise-structure assignment** entity sets.

Scenario documents keep org keys as scalars on `ZEVO_C2P` / `ZEVO_C2C`. FI-local copies of CompanyCode / CostCenter / ProfitCenter **stay** on `ZEVO_GENERALLEDGER`. Partner / product stay on `ZEVO_MD`.

| Item | Value |
|------|--------|
| Service definition | `ZEVO_ORG` (`zevo_org.srvd.*`) |
| Service binding | `ZEVO_ORG` — **OData V4 — Web API**. ADT bootstrap, or abapGit `SRVB` after Standalone upgrade (root README §1b / §1c) |
| CDS prefix | `ZEVO_ORG_*` |
| CDS form | Classic `define view`, explicit fields, one-way associations |
| Plan | [`ZEVO_ORG_PLAN.md`](ZEVO_ORG_PLAN.md) |

---

## Entity sets (Phase 1)

### Masters (nodes)

| Entity set | CDS view | Source CDS |
|------------|----------|------------|
| `ControllingArea` | `ZEVO_ORG_ControllingArea` | `I_ControllingArea` |
| `CompanyCode` | `ZEVO_ORG_CompanyCode` | `I_CompanyCode` |
| `CostCenter` | `ZEVO_ORG_CostCenter` | `I_CostCenter` |
| `ProfitCenter` | `ZEVO_ORG_ProfitCenter` | `I_ProfitCenter` |
| `ValuationArea` | `ZEVO_ORG_ValuationArea` | `I_ValuationArea` (Plant → company code) |
| `Plant` | `ZEVO_ORG_Plant` | `I_Plant` |
| `StorageLocation` | `ZEVO_ORG_StorageLocation` | `I_StorageLocation` |
| `PurchasingOrganization` | `ZEVO_ORG_PurchasingOrg` | `I_PurchasingOrganization` |
| `PurchasingGroup` | `ZEVO_ORG_PurchasingGroup` | `I_PurchasingGroup` |
| `SalesOrganization` | `ZEVO_ORG_SalesOrg` | `I_SalesOrganization` |
| `DistributionChannel` | `ZEVO_ORG_DistChannel` | `I_DistributionChannel` |
| `Division` | `ZEVO_ORG_Division` | `I_Division` |
| `ShippingPoint` | `ZEVO_ORG_ShippingPoint` | `I_ShippingPoint` |
| `SalesOffice` | `ZEVO_ORG_SalesOffice` | `I_SalesOffice` |
| `SalesGroup` | `ZEVO_ORG_SalesGroup` | `I_SalesGroup` |

### Relationships (edges)

| Entity set | CDS view | Source CDS | Classic |
|------------|----------|------------|---------|
| `PlantPurchasingOrganization` | `ZEVO_ORG_PlantPurchOrg` | `I_PlantPurchasingOrganization` | T024W |
| `SalesArea` | `ZEVO_ORG_SalesArea` | `I_SalesArea` | TVTA |
| `SalesAreaPlant` | `ZEVO_ORG_SalesAreaPlant` | `tvkwz` (no released `I_*` on stack) | TVKWZ |
| `ShippingPointPlant` | `ZEVO_ORG_ShipPointPlant` | `tvswz` (no released `I_*` on stack) | TVSWZ |

### Texts (language-dependent)

Confirmed on stack DEX catalog. Filter e.g. `Language eq 'E'`.

| Entity set | CDS view | Source CDS | Keys / name fields |
|------------|----------|------------|--------------------|
| `CostCenterText` | `ZEVO_ORG_CostCenterText` | `I_CostCenterText` | Language + CA + CC + ValidityEndDate → `CostCenterName`, `CostCenterDescription` |
| `ProfitCenterText` | `ZEVO_ORG_ProfitCenterText` | `I_ProfitCenterText` | Language + CA + PC + ValidityEndDate → `ProfitCenterName`, `ProfitCenterLongName` |
| `SalesOrganizationText` | `ZEVO_ORG_SalesOrgText` | `I_SalesOrganizationText` | SalesOrganization + Language → `SalesOrganizationName` |
| `DistributionChannelText` | `ZEVO_ORG_DistChannelText` | `I_DistributionChannelText` | DistributionChannel + Language → `DistributionChannelName` |
| `DivisionText` | `ZEVO_ORG_DivisionText` | `I_DivisionText` | Division + Language → `DivisionName` |
| `ShippingPointText` | `ZEVO_ORG_ShippingPointText` | `I_ShippingPointText` | ShippingPoint + Language → `ShippingPointName` |
| `SalesOfficeText` | `ZEVO_ORG_SalesOfficeText` | `I_SalesOfficeText` | SalesOffice + Language → `SalesOfficeName` |
| `SalesGroupText` | `ZEVO_ORG_SalesGroupText` | `I_SalesGroupText` | SalesGroup + Language → `SalesGroupName` |

Masters that already carry a language-independent `*Name` (no Text set): CompanyCode, ControllingArea, Plant, StorageLocation, PurchasingOrganization, PurchasingGroup.

### Navigations (safe 0..1 only)

| From | Nav | To |
|------|-----|-----|
| `CompanyCode` | `_ControllingArea` | controlling area |
| `CostCenter` | `_CompanyCode`, `_ControllingArea`, `_Text` | company / CA / texts |
| `ProfitCenter` | `_ControllingArea`, `_Text` | CA / texts |
| `SalesOrganization` | `_CompanyCode`, `_Text` | company / texts |
| `DistributionChannel` | `_Text` | texts |
| `Division` | `_Text` | texts |
| `ShippingPoint` | `_Text` | texts |
| `SalesOffice` | `_Text` | texts |
| `SalesGroup` | `_Text` | texts |
| `ValuationArea` | `_CompanyCode` | company (plant→CC path) |
| `Plant` | `_ValuationArea` | valuation area (+ expand `_CompanyCode`) |
| `StorageLocation` | `_Plant` | plant |
| `PurchasingOrganization` | `_CompanyCode` | company when assigned |
| `PlantPurchasingOrganization` | `_Plant`, `_PurchasingOrganization` | ends of the edge |
| `SalesArea` | `_SalesOrganization`, `_DistributionChannel`, `_Division` | sales-area parts |
| `SalesAreaPlant` | `_Plant`, `_SalesOrganization` | ends of the edge |
| `ShippingPointPlant` | `_Plant`, `_ShippingPoint` | ends of the edge |

Language texts always use generic **`_Text`**: `$expand=_Text($filter=Language eq 'E')`.

Plant → company code: `$expand=_ValuationArea($expand=_CompanyCode)`.

---

## Activate & publish (ADT)

Same pattern as MD / GL / C2P.

1. abapGit pull — activate all `ZEVO_ORG_*` + SRVD `ZEVO_ORG`.
2. **Do not** delete local SRVB/G4BA if you recreate the binding later.
3. ADT: New Service Binding **`ZEVO_ORG`**, type **OData V4 - Web API**, definition `ZEVO_ORG` → Activate → Publish.
4. URL shape:

```text
/sap/opu/odata4/sap/zevo_org/srvd_a2x/sap/zevo_org/0001/
```

### Activation notes

| If activate fails on… | Likely cause | Fix |
|-----------------------|--------------|-----|
| Field name unknown | Element missing on local CDS | Omit the field (same habit as GL HouseBank / ProfitCenter) |
| `I_PurchasingGroup` / `I_SalesOffice` / `I_SalesGroup` missing | Not on stack / not released | Remove that DDLS + `expose` from SRVD |
| Assignment edges | No released `I_*` for TVKWZ / TVSWZ on this stack | Wrappers select from `tvkwz` / `tvswz` directly |
| `PurchasingOrganizationName` / `StorageLocationName` / `ControllingAreaName` | Text only on `*_Text` view | Drop the name field; keep the key |
| EDM clash on `*Type` properties | OData V4 entity type suffix | Alias to `*TypeCode` if needed |

Confirm candidates with explorer / `GetCdsMetadata` before fighting the binder.

---

## Sample queries

```http
GET {base}/$metadata

GET {base}/ControllingArea
GET {base}/CompanyCode?$filter=CompanyCode eq '1710'
  &$expand=_ControllingArea

GET {base}/CostCenter?$filter=ControllingArea eq 'A000'
  &$expand=_Text($filter=Language eq 'E')&$top=100
GET {base}/ProfitCenter?$filter=ControllingArea eq 'A000'
  &$expand=_Text($filter=Language eq 'E')&$top=100
GET {base}/SalesOrganization?$expand=_Text($filter=Language eq 'E')
GET {base}/DistributionChannel?$expand=_Text($filter=Language eq 'E')
GET {base}/ShippingPoint?$expand=_Text($filter=Language eq 'E')
GET {base}/Plant?$filter=Plant eq '1710'
  &$expand=_ValuationArea($expand=_CompanyCode)

GET {base}/StorageLocation?$filter=Plant eq '1710'
GET {base}/PurchasingOrganization
GET {base}/PlantPurchasingOrganization?$filter=Plant eq '1710'
  &$expand=_PurchasingOrganization

GET {base}/SalesOrganization
GET {base}/SalesArea
GET {base}/SalesAreaPlant?$filter=SalesOrganization eq '1710'
GET {base}/ShippingPoint
GET {base}/ShippingPointPlant?$filter=Plant eq '1710'

GET {base}/CostCenterText?$filter=Language eq 'E' and ControllingArea eq 'A000'&$top=50
GET {base}/SalesOrganizationText?$filter=Language eq 'E'
GET {base}/DistributionChannelText?$filter=Language eq 'E'
GET {base}/ShippingPointText?$filter=Language eq 'E'
```

One-line base (demo host pattern):

```text
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_org/srvd_a2x/sap/zevo_org/0001/
```

---

## Relation to other services

| Service | Owns |
|---------|------|
| **`ZEVO_ORG`** | Canonical org nodes + assignment edges |
| `ZEVO_GENERALLEDGER` | Journal + FI-local CompanyCode / CostCenter / ProfitCenter (kept) |
| `ZEVO_MD` | BP / product — not Plant |
| `ZEVO_C2P` / `ZEVO_C2C` | Documents; org keys as scalars |

Clients join document scalars (`Plant`, `PurchasingOrganization`, `SalesOrganization`, `StorageLocation`, `ShippingPoint`, …) to ORG entity sets. Full matrix: [`CROSS_SERVICE_JOINS.md`](CROSS_SERVICE_JOINS.md).

---

## Out of scope (Phase 1)

- GL account / ledger / house bank / accounting document type  
- BP / product  
- CC/PC hierarchy nodes  
- EWM warehouse bins  
- Removing GL org entity sets  
