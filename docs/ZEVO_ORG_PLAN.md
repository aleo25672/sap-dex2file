# ZEVO_ORG — Organizational structure service (plan)

**Status:** planning only — no CDS / SRVD / binding in this change.  
**Decision:** add a new typed OData V4 service for **canonical org masters**. Existing copies on other services **stay**.

---

## Intent

Extract a self-consistent **org catalog** for controlling, company, cost/profit centers, plant (+ storage location), purchasing, sales organization (+ shipping / sales office where useful) — so clients can resolve keys that appear as scalars on C2P / C2C / GL documents without treating any one scenario service as the org system of record.

User constraint (locked): *what we already have in other services stays — each service remains self-consistent.*

---

## Locked defaults

| Decision | Choice | Why |
|----------|--------|-----|
| Service definition / binding name | `ZEVO_ORG` | Parallel to `ZEVO_MD` / `ZEVO_C2P` / `ZEVO_C2C` / `ZEVO_GENERALLEDGER` |
| CDS prefix | `ZEVO_ORG_*` | Avoid `ZEVO_G_*` (reads as GL) and `ZEVO_O_*` (already C2C) |
| SQL view prefix | `ZEVOORG*` (≤16 chars, match existing style) | Same habit as `ZEVOFICCTR`, `ZEVOM…` |
| CDS form | Classic `define view`, explicit fields, one-way associations | Same as MD / GL / C2P / C2C |
| Overlap policy | **Keep** GL `CompanyCode` / `CostCenter` / `ProfitCenter`; **do not remove** | Scenario / FI services stay self-contained for `$expand` and local lookup |
| Plant home | **Canonical on `ZEVO_ORG`** | Org hierarchy (plant ↔ company / purch / sales) belongs here; MD Phase 2 Plant item becomes “optional lean / IC fields” only if still needed for BP context |
| Cross-service `$expand` | None | Clients join by key (same as [`CROSS_SERVICE_JOINS.md`](CROSS_SERVICE_JOINS.md)) |
| Time-dependent masters | Expose full keys (`ValidityEndDate` / start); **no** forced 0..1 FK expand where multiplicity breaks OData V4 | Same lesson as GL CostCenter / ProfitCenter |

---

## What already exists (inventory)

### On `ZEVO_GENERALLEDGER` (`ZEVO_FI_*`) — keep

| Entity set | Source | Notes |
|------------|--------|-------|
| `CompanyCode` | `I_CompanyCode` | Includes `ControllingArea` field; **no** ControllingArea entity set |
| `CostCenter` | `I_CostCenter` | Keys: CA + CC + `ValidityEndDate` |
| `ProfitCenter` | `I_ProfitCenter` | Keys: CA + PC + `ValidityEndDate` |
| `GLAccount`, `Ledger`, `AccountingDocType`, `HouseBank` | FI masters | Stay GL-only (chart / journal context — **not** ORG Phase 1) |

### On `ZEVO_MD` (`ZEVO_M_*`) — keep; Plant not shipped

- BP / roles / bank / Customer / Supplier / Product only.
- Plant listed as MD Phase 2 backlog — **rehomed** to ORG Phase 1 (canonical). MD may later add plant-related **IC / BP** fields without owning the Plant master.

### On scenario services — scalars only (keep)

| Service | Typical org scalars (no org entity sets) |
|---------|------------------------------------------|
| `ZEVO_C2P` | `CompanyCode`, `PurchasingOrganization`, `Plant`, `SupplyingPlant`, `StorageLocation`, … |
| `ZEVO_C2C` | `SalesOrganization`, `DistributionChannel`, `Plant`, `CompanyCode`, `ShippingPoint`, `SalesOffice`, `SalesGroup`, … |
| GM (both) | `Plant`, `StorageLocation`, `CompanyCode`, `ControllingArea`, `CostCenter`, `ProfitCenter`, … |
| GL lines | `BusinessArea` (scalar; usually **not** a Phase 1 ORG entity) |

---

## Service boundary

| Service | Owns |
|---------|------|
| **`ZEVO_ORG`** | Canonical org structure: controlling area, company code, cost/profit center, plant, **storage location**, purchasing org (+ group), sales org (+ distribution channel, division), **shipping point** / sales office when CDS allows, and **assignment / relation** views |
| `ZEVO_GENERALLEDGER` | Journal + **FI-local** org copies needed for line `$expand` / lookup |
| `ZEVO_MD` | Partner / product masters (not org hierarchy) |
| `ZEVO_C2P` / `ZEVO_C2C` | Documents + lean BP; org keys as fields |

Duplicate entity set names across bindings are OK (different service roots). Document which service is **canonical** for extract jobs that want a single org dump → **`ZEVO_ORG`**.

---

## Phase 1 — core masters (implement next)

Candidates (confirm **Released** / present on the target S/4 stack via View Browser or explorer before coding each wrapper):

| Entity set | Proposed CDS | Source (candidate) | Keys / notes |
|------------|--------------|--------------------|--------------|
| `ControllingArea` | `ZEVO_ORG_ControllingArea` | `I_ControllingArea` | Missing today on GL |
| `CompanyCode` | `ZEVO_ORG_CompanyCode` | `I_CompanyCode` | Mirror GL fields; optional `_ControllingArea` if 0..1 holds |
| `CostCenter` | `ZEVO_ORG_CostCenter` | `I_CostCenter` | Same keys as GL; richer field list OK |
| `ProfitCenter` | `ZEVO_ORG_ProfitCenter` | `I_ProfitCenter` | Same keys as GL |
| `Plant` | `ZEVO_ORG_Plant` | `I_Plant` | Canonical plant; include company-code / address fields available on local CDS |
| `StorageLocation` | `ZEVO_ORG_StorageLocation` | `I_StorageLocation` | Keys typically Plant + StorageLocation — on PO/PR/GM today |
| `PurchasingOrganization` | `ZEVO_ORG_PurchasingOrg` | `I_PurchasingOrganization` | |
| `PurchasingGroup` | `ZEVO_ORG_PurchasingGroup` | `I_PurchasingGroup` | Drop if not released on stack |
| `SalesOrganization` | `ZEVO_ORG_SalesOrg` | `I_SalesOrganization` | |
| `DistributionChannel` | `ZEVO_ORG_DistChannel` | `I_DistributionChannel` | |
| `Division` | `ZEVO_ORG_Division` | `I_Division` | Drop if not released on stack |
| `ShippingPoint` | `ZEVO_ORG_ShippingPoint` | `I_ShippingPoint` | On delivery / schedule line; include if released |

### Phase 1 navigations (only where FK is unique)

Prefer the GL pattern: expand when safe; otherwise scalar + separate entity set.

| From | Nav | When |
|------|-----|------|
| `CompanyCode` | `_ControllingArea` | If company→CA is many-to-one on local CDS |
| `CostCenter` | `_CompanyCode` / `_ProfitCenter` | Only if keys allow unique 0..1; else omit |
| `Plant` | `_CompanyCode` | If plant→CC unique on `I_Plant` |
| `StorageLocation` | `_Plant` | Plant + SLoc → plant is many-to-one |

No document-side expands from C2P/C2C into ORG.

### Phase 1 out of scope

- GL account / ledger / house bank / accounting doc type (stay GL).
- BP / product (stay MD).
- Hierarchy node CDS (cost center / profit center standard hierarchy) — Phase 3.
- Removing or thinning `ZEVO_FI_*` org entity sets.
- EWM warehouse complex / storage bin (warehouse *execution*, not classic org) unless a thin `WarehouseNumber` lands in Phase 2.

---

## Other org elements (catalog — phased)

Elements that often sit next to Plant / sales / FI. Include when CDS is released **and** documents already expose the key (or clients need the catalog).

| Element | Candidate source | Phase | Why / when |
|---------|------------------|-------|------------|
| **Storage location** | `I_StorageLocation` | **1** | On C2P items + GM; classic plant child |
| **Shipping point** | `I_ShippingPoint` | **1** | On C2C delivery / schedule line |
| Sales office | `I_SalesOffice` (if present) | 2 | On contract / delivery headers |
| Sales group | `I_SalesGroup` (if present) | 2 | On contract; often paired with sales office |
| Loading point | `I_LoadingPoint` / plant-dependent | 2 | Logistics; only if used in extract |
| Warehouse number (LE) | `I_WarehouseNumber` or successor | 2 | Only if LE WM still in scope; not EWM bins |
| Sales area (composite) | assignment CDS | 2 | SalesOrg + DistChannel + Division |
| Purch org ↔ company / plant | assignment CDS | 2 | Resolve purch org on PO to company/plant |
| Credit control area | `I_CreditControlArea` if released | 3 | FI/credit; rarely on current ZEVO docs |
| Business area | `I_BusinessArea` if released | 3 | Scalar on GL / acct assignment; legacy in many landscapes — optional |
| Segment | often field on ProfitCenter | — | Prefer field on `ProfitCenter`, not separate Phase 1 set |
| Valuation area | usually = Plant | — | Do not duplicate Plant |
| MRP area | MRP CDS if released | 3 | Planning; out unless PP extract appears |
| Activity type | `I_ActivityType` | 3 | CO master adjacent to CC — optional later |
| HR personnel area | HR CDS | — | Out of ZEVO scope for now |

---

## Phase 2 — assignments & sales satellites

Add **relation** and remaining sales/logistics masters when stable CDS exists (names illustrative — pick real `I_*` after discovery):

| Theme | Examples |
|-------|----------|
| Purchasing | Purchasing org ↔ company code; plant ↔ purchasing org |
| Sales area | Sales org + distribution channel + division (composite); sales area ↔ company code |
| Sales satellites | Sales office, sales group |
| Plant logistics | Loading point; LE warehouse number if needed |
| IC helpers | Fields that today sit in MD Phase 2 backlog (plant shipping customer, IC sales-org customer) — prefer ORG if they hang off Plant / SalesOrganization |

Discovery gate: run explorer / `GetCdsMetadata` on candidates; skip `PRIVILEGED_ONLY`.

---

## Phase 3 — hierarchies & polish

- Cost / profit center **hierarchy** nodes if released composite CDS is usable.
- Optional: credit control area, business area, activity type (only if clients need them).
- Optional richer texts / language-dependent names.
- Smoke pack + join recipes: document org keys → ORG entity sets in [`CROSS_SERVICE_JOINS.md`](CROSS_SERVICE_JOINS.md).
- Performance: org masters are small — default `$top` less critical than documents; still document filter by `ControllingArea` / `CompanyCode` / `SalesOrganization` / `Plant`.

---

## Implementation checklist (when green-lit)

1. abapGit: `ZEVO_ORG_*` DDLS + `zevo_org.srvd.*` (mirror `ZEVO_MD` / GL).
2. ADT: binding `ZEVO_ORG`, OData V4 Web API → Activate → Publish.
3. Docs: `docs/ZEVO_ORG.md` (entity table, samples, activation) + README section + NEXT_PHASES “shipped”.
4. Update MD Phase 2 row: Plant canonical on ORG; MD keeps IC/partner-adjacent work.
5. Update join matrix: “canonical org → `ZEVO_ORG`”; GL copies remain valid for FI-local joins.
6. Smoke URLs (company `1710`, CA `A000`, sales/purch org as on demo).

### Suggested smoke (draft)

```http
GET {base}/$metadata
GET {base}/ControllingArea
GET {base}/CompanyCode?$filter=CompanyCode eq '1710'
GET {base}/CostCenter?$filter=ControllingArea eq 'A000'&$top=50
GET {base}/Plant?$filter=Plant eq '1710'
GET {base}/StorageLocation?$filter=Plant eq '1710'
GET {base}/PurchasingOrganization
GET {base}/SalesOrganization
GET {base}/DistributionChannel
GET {base}/ShippingPoint
```

Base shape (same family as other V4 services):

```text
/sap/opu/odata4/sap/zevo_org/srvd_a2x/sap/zevo_org/0001/
```

---

## Client guidance

| Job | Use |
|-----|-----|
| Full org extract / hierarchy bootstrap | **`ZEVO_ORG`** |
| Journal line + company / G/L expand | `ZEVO_GENERALLEDGER` (existing) |
| Resolve `PurchasingOrganization` / `SalesOrganization` / `Plant` / `StorageLocation` / `ShippingPoint` on a document | Join document scalar(s) → **`ZEVO_ORG`** entity set (`StorageLocation` needs Plant + SLoc) |
| Partner / product | `ZEVO_MD` |

Do **not** expect `$expand` from C2P/C2C/GL into ORG.

---

## Open only at implement time (not blocking the plan)

1. Exact field lists per local CDS (omit missing elements like GL did for HouseBank / ProfitCenter).
2. Whether `I_PurchasingGroup` / `I_Division` / `I_ShippingPoint` / `I_SalesOffice` exist and are released on the demo stack — include or skip without changing the service name.
3. Sales-area composite: one entity set vs three masters + assignment entity — decide after metadata check.
4. Whether business area is worth a Phase 3 entity set on this landscape (many S/4 systems barely use it).

---

## Relation to next-phases backlog

Until ORG Phase 1 ships, treat this plan as the **org-structure track** ahead of (or instead of) MD Plant as the plant master. See [`NEXT_PHASES.md`](NEXT_PHASES.md).
