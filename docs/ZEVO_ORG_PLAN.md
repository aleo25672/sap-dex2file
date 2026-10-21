# ZEVO_ORG — Organizational structure service (plan)

**Status:** Phase 1 **implemented** in abapGit (`ZEVO_ORG_*` + `zevo_org.srvd.*`) — ADT binding still created locally.  
**Reference:** [`ZEVO_ORG.md`](ZEVO_ORG.md).  
**Decision:** canonical org masters + relationships. Existing copies on other services **stay**.

---

## Intent

Extract a self-consistent **org catalog** — nodes **and** enterprise-structure assignment edges — for controlling, company, cost/profit centers, plant (+ storage location), purchasing, sales organization (+ shipping / sales office where useful) — so clients can resolve keys that appear as scalars on C2P / C2C / GL documents and rebuild the allow-list graph without treating any one scenario service as the org system of record.

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
| First ship scope | **Masters + relationship tables together** | One coherent org graph — do not split assignments into a later phase |
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

**Relationship / assignment tables:** none in ZEVO today.

---

## Service boundary

| Service | Owns |
|---------|------|
| **`ZEVO_ORG`** | Canonical org **nodes** and **assignment edges**: controlling area, company code, cost/profit center, plant, storage location, purchasing org (+ group), sales org (+ distribution channel, division), shipping point / sales office when CDS allows, plus purch/sales/plant/shipping **relationship** entity sets |
| `ZEVO_GENERALLEDGER` | Journal + **FI-local** org copies needed for line `$expand` / lookup |
| `ZEVO_MD` | Partner / product masters (not org hierarchy) |
| `ZEVO_C2P` / `ZEVO_C2C` | Documents + lean BP; org keys as fields |

Duplicate entity set names across bindings are OK (different service roots). Document which service is **canonical** for extract jobs that want a single org dump → **`ZEVO_ORG`**.

---

## Phase 1 — full org graph (implement next)

Ship **masters and relationship tables in one go**. Confirm each candidate **Released** / present on the target S/4 stack (View Browser or explorer) before coding; skip missing / `PRIVILEGED_ONLY` without renaming the service.

### 1a. Master entity sets (nodes)

| Entity set | Proposed CDS | Source (candidate) | Keys / notes |
|------------|--------------|--------------------|--------------|
| `ControllingArea` | `ZEVO_ORG_ControllingArea` | `I_ControllingArea` | Missing today on GL |
| `CompanyCode` | `ZEVO_ORG_CompanyCode` | `I_CompanyCode` | Mirror GL fields; optional `_ControllingArea` if 0..1 holds |
| `CostCenter` | `ZEVO_ORG_CostCenter` | `I_CostCenter` | Same keys as GL; richer field list OK |
| `ProfitCenter` | `ZEVO_ORG_ProfitCenter` | `I_ProfitCenter` | Same keys as GL |
| `Plant` | `ZEVO_ORG_Plant` | `I_Plant` | Canonical plant; include company-code / address fields available on local CDS |
| `StorageLocation` | `ZEVO_ORG_StorageLocation` | `I_StorageLocation` | Plant + StorageLocation — on PO/PR/GM today |
| `PurchasingOrganization` | `ZEVO_ORG_PurchasingOrg` | `I_PurchasingOrganization` | May carry CompanyCode when assigned |
| `PurchasingGroup` | `ZEVO_ORG_PurchasingGroup` | `I_PurchasingGroup` | Drop if not released |
| `SalesOrganization` | `ZEVO_ORG_SalesOrg` | `I_SalesOrganization` | Typically carries CompanyCode |
| `DistributionChannel` | `ZEVO_ORG_DistChannel` | `I_DistributionChannel` | |
| `Division` | `ZEVO_ORG_Division` | `I_Division` | Drop if not released |
| `ShippingPoint` | `ZEVO_ORG_ShippingPoint` | `I_ShippingPoint` | On delivery / schedule line |
| `SalesOffice` | `ZEVO_ORG_SalesOffice` | `I_SalesOffice` if present | On contract / delivery |
| `SalesGroup` | `ZEVO_ORG_SalesGroup` | `I_SalesGroup` if present | Often with sales office |
| `LoadingPoint` | `ZEVO_ORG_LoadingPoint` | loading-point CDS if present | Optional; skip if unused |
| `WarehouseNumber` | `ZEVO_ORG_WarehouseNumber` | LE warehouse CDS if present | LE only — not EWM bins |

### 1b. Relationship entity sets (edges)

Some links are already a **field on a master** — those do **not** need a separate relation entity. True n:m / composite assignments get their own sets.

#### Covered by master fields (no extra entity)

| Relationship | Where it usually lives | Notes |
|--------------|------------------------|-------|
| Company code → controlling area | `CompanyCode.ControllingArea` | On `I_CompanyCode` / GL copy today |
| Plant → company code | `Plant` / valuation area → CC | Often on `I_Plant`; confirm locally |
| Purchasing org → company code | `PurchasingOrganization.CompanyCode` | Optional in IMG — blank = cross-company purch |
| Sales org → company code | `SalesOrganization.CompanyCode` | Typically on `I_SalesOrganization` |
| Storage location → plant | key of `StorageLocation` | Plant + SLoc |

#### Dedicated assignment entity sets

| Entity set (proposed) | Candidate CDS | Classic / IMG meaning | Keys (typical) |
|-----------------------|---------------|------------------------|----------------|
| `PlantPurchasingOrganization` | `I_PlantPurchasingOrganization` | Purch org ↔ plant (**required** MM; T024W) | PurchasingOrganization + Plant |
| `SalesArea` | `I_SalesArea` | Sales org + dist. channel + division (TVTA) | SalesOrganization + DistributionChannel + Division |
| `SalesOrgDistributionChannel` | dist-channel assign CDS if separate from SalesArea | Dist. channel → sales org (TVKOV) | SalesOrganization + DistributionChannel |
| `SalesOrgDivision` | division assign CDS if separate | Division → sales org (TVKOS) | SalesOrganization + Division |
| `SalesAreaPlant` | `tvkwz` (no released `I_*`) | Sales org + dist. channel → plant (TVKWZ) | SalesOrganization + DistributionChannel + Plant |
| `ShippingPointPlant` | `tvswz` (no released `I_*`) | Shipping point ↔ plant (TVSWZ) | Plant + ShippingPoint |
| `PurchasingOrgCompanyCode` | only if **not** a field on purch-org master | Purch org → company (OX01 / T024E) | PurchasingOrganization (+ CompanyCode) |

If a dedicated CDS is missing, do **not** wrap unreleased config tables; document the gap and keep using master fields + document scalars.

### Why include relationships in Phase 1

- Clients building an org graph need **edges**, not only nodes (e.g. which plants a purch org may buy for).
- Document keys alone do not list allowed combinations.
- Prefer **entity sets + client join** over inventing multi-parent `$expand` graphs.

### Navigations (only where FK is unique)

Prefer the GL pattern: expand when safe; otherwise scalar + separate entity set.

| From | Nav | When |
|------|-----|------|
| `CompanyCode` | `_ControllingArea` | If company→CA is many-to-one on local CDS |
| `CostCenter` | `_CompanyCode` / `_ProfitCenter` | Only if keys allow unique 0..1; else omit |
| `Plant` | `_CompanyCode` | If plant→CC unique on `I_Plant` |
| `StorageLocation` | `_Plant` | Plant + SLoc → plant is many-to-one |

No document-side expands from C2P/C2C into ORG. Assignment entity sets are queried / joined by key (same pattern as document↔master joins).

### Phase 1 out of scope

- GL account / ledger / house bank / accounting doc type (stay GL).
- BP / product (stay MD).
- Hierarchy node CDS (cost center / profit center standard hierarchy) — Phase 2.
- Credit control area, business area, activity type, MRP area — Phase 2 optional / out unless needed.
- Removing or thinning `ZEVO_FI_*` org entity sets.
- EWM warehouse complex / storage bin (execution, not classic org).

### Discovery checklist (implement time)

```text
# Explorer / GetCdsMetadata — search patterns
PlantPurchasingOrganization / PurchasingOrganization*Plant
SalesArea
ShippingPoint*Plant
SalesOrganization*Plant / DistributionChannel*Plant
SalesOffice / SalesGroup / LoadingPoint / WarehouseNumber
```

---

## Other org elements (later / out)

| Element | Candidate source | Phase | Why / when |
|---------|------------------|-------|------------|
| Credit control area | `I_CreditControlArea` if released | 2 | FI/credit; rarely on current ZEVO docs |
| Business area | `I_BusinessArea` if released | 2 | Scalar on GL / acct assignment; optional |
| Segment | field on ProfitCenter | — | Prefer field, not separate set |
| Valuation area | usually = Plant | — | Do not duplicate Plant |
| MRP area | MRP CDS if released | 2 | Planning; out unless PP extract appears |
| Activity type | `I_ActivityType` | 2 | CO adjacent to CC — optional |
| HR personnel area | HR CDS | — | Out of ZEVO scope for now |
| CC/PC hierarchy nodes | hierarchy CDS if released | 2 | Standard hierarchy extract |

---

## Phase 2 — hierarchies & optional FI polish

- Cost / profit center **hierarchy** nodes if released composite CDS is usable.
- Optional: credit control area, business area, activity type (only if clients need them).
- Optional richer texts / language-dependent names.
- Smoke pack + join recipes: document org keys → ORG entity sets in [`CROSS_SERVICE_JOINS.md`](CROSS_SERVICE_JOINS.md).
- Performance: org masters are small — still document filter by `ControllingArea` / `CompanyCode` / `SalesOrganization` / `Plant`.

---

## Implementation checklist (when green-lit)

1. abapGit: `ZEVO_ORG_*` DDLS + `zevo_org.srvd.*` (masters **and** assignment views) — mirror `ZEVO_MD` / GL.
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
GET {base}/PlantPurchasingOrganization?$filter=Plant eq '1710'
GET {base}/SalesOrganization
GET {base}/SalesArea
GET {base}/DistributionChannel
GET {base}/ShippingPoint
GET {base}/ShippingPointPlant
```

Base shape (same family as other V4 services):

```text
/sap/opu/odata4/sap/zevo_org/srvd_a2x/sap/zevo_org/0001/
```

---

## Client guidance

| Job | Use |
|-----|-----|
| Full org extract / hierarchy bootstrap | **`ZEVO_ORG`** (masters + assignment entity sets) |
| Journal line + company / G/L expand | `ZEVO_GENERALLEDGER` (existing) |
| Resolve document org scalars | Join → master entity set |
| Resolve allowed purch org ↔ plant / sales area / shipping↔plant | Join → **assignment** entity set |
| Partner / product | `ZEVO_MD` |

Do **not** expect `$expand` from C2P/C2C/GL into ORG.

---

## Open only at implement time (not blocking the plan)

1. Exact field lists per local CDS (omit missing elements like GL did for HouseBank / ProfitCenter).
2. Which of `I_PurchasingGroup` / `I_Division` / `I_ShippingPoint` / `I_SalesOffice` / `I_SalesGroup` / assignment CDS exist and are released — include or skip without changing the service name.
3. Whether channel/division assigns are folded into `SalesArea` only, or also exposed as separate entity sets.
4. Whether business area is worth a Phase 2 entity set on this landscape.

---

## Relation to next-phases backlog

Until ORG Phase 1 ships, treat this plan as the **org-structure track** ahead of (or instead of) MD Plant as the plant master. See [`NEXT_PHASES.md`](NEXT_PHASES.md).
