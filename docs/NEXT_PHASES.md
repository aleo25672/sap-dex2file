# ZEVO — next phases (planning backlog)

Phase 1 is live for **C2P**, **C2C**, **MD**, **GENERALLEDGER**, **V2 ExtractCds**, and **ZEVO_CDS_EXPLORER_2_FILE**. This note lists likely Phase 2 / 3 work. It is a backlog, not a commitment.

**Invariants to keep**

- Scenario services = documents + **lean** BP; partner/product masters on `ZEVO_MD`; journal on `ZEVO_GENERALLEDGER`; **canonical org** planned on `ZEVO_ORG` (see [`ZEVO_ORG_PLAN.md`](ZEVO_ORG_PLAN.md)) — existing FI org copies on GL **stay**.
- One-way **FK `$expand`** on document numbers (C2P / C2C). Do **not** expose `C_SDDocMultiLevelProcFlowDEX` (`PRIVILEGED_ONLY`).
- Goods movement = full `I_GoodsMovementDocumentDEX`; client filters (PO vs delivery / `601` / `WL`).
- No cross-binding `$expand` — clients join across services.

---

## Phase 1 — shipped (summary)

| Service | What shipped |
|---------|----------------|
| `ZEVO_C2P` | 12 entity sets; lean BP; PO→History→GR/IR; full GM |
| `ZEVO_C2C` | 9 entity sets; SO→delivery/billing FK expand; SchedLine; lean BP |
| `ZEVO_MD` | Full BP, roles, bank, Customer/Supplier, Product subset |
| `ZEVO_GENERALLEDGER` | GL lines + FI org masters + expands |
| V2 `ExtractCds` | Any CDS; `$filter`; Skip/Top; DeltaSince; json/xml |
| Explorer | DEX/API catalog; full/delta/bounded; Include non-released DEX |

---

## `ZEVO_C2P`

| Phase | Priority | Candidates |
|-------|----------|------------|
| 2 | High | PO schedule lines DEX if needed; invoice→payment via GL join recipes; history type cookbook; optional GM date bounds |
| 3 | Medium | PR header if DEX appears; ref-doc texts; true CDC if SAP enables on wrappers |

## `ZEVO_C2C`

| Phase | Priority | Candidates |
|-------|----------|------------|
| 2 | High | SO / billing **header** only if a stable source appears; contract→SO expand; WL/`601` client recipes |
| 3 | Medium | `_1` DEX migration; return/credit-memo filter packs; avoid privileged process-flow entity set |

## `ZEVO_MD`

| Phase | Priority | Candidates |
|-------|----------|------------|
| 2 | High | Customer/supplier company-code views; IC sales-org / shipping customer (if not on ORG); wider Product. **Plant master → `ZEVO_ORG`** (not MD) |
| 3 | Low | Address/email (watch privileged CDS); BP relationships / contacts |

## `ZEVO_ORG` (planned — not shipped)

Plan: [`ZEVO_ORG_PLAN.md`](ZEVO_ORG_PLAN.md). Prefix `ZEVO_ORG_*`. Overlaps with GL org masters are intentional.

| Phase | Priority | Candidates |
|-------|----------|------------|
| 1 | High | **Masters + relationships together**: ControllingArea, CompanyCode, CostCenter, ProfitCenter, Plant, StorageLocation, PurchasingOrganization (+ Group), SalesOrganization, DistributionChannel, Division, ShippingPoint, SalesOffice/Group if released; **and** Plant↔PurchOrg, SalesArea, Sales↔Plant, ShippingPoint↔Plant (see plan) |
| 2 | Low | CC/PC hierarchy nodes; optional BusinessArea / CreditControlArea; join-matrix recipes for org keys |

## `ZEVO_GENERALLEDGER`

| Phase | Priority | Candidates |
|-------|----------|------------|
| 2 | High | Join recipes (C2P `RMRP`/`RE`/`KZ`, C2C `RV`/`DZ`); CC/PC expand if keys allow; open-item/clearing CDS if stable |
| 3 | Medium | Published join matrix across bindings; 0L vs 2L sample packs |

## V2 `ExtractCds`

| Phase | Priority | Candidates |
|-------|----------|------------|
| 2 | Medium | Richer `$filter`; discovery entity set; OData write to `ZEVO_DELTA` |
| 3 | Low | Async jobs; V4 unbound-action equivalent |

## Explorer `ZEVO_CDS_EXPLORER_2_FILE`

| Phase | Priority | Candidates |
|-------|----------|------------|
| 2 | Medium | Annotation scan for DEX missing from `IXTRCTNENBLDVW`; ALV flag for `PRIVILEGED_ONLY` |

## Cross-cutting

| Phase | Priority | Candidates |
|-------|----------|------------|
| 2 | High | ~~Client join matrix~~ → [`CROSS_SERVICE_JOINS.md`](CROSS_SERVICE_JOINS.md); IC resale 1710↔1010 E2E smoke; SRVD ADT fallback + republish runbook |
| 3 | Medium | Unified delta strategy doc; default `$top` / date / ITT performance guidance; security review before any privileged association |

---

## Suggested order

1. ~~**Cross-service join matrix**~~ — done: [`CROSS_SERVICE_JOINS.md`](CROSS_SERVICE_JOINS.md).  
2. **`ZEVO_ORG` Phase 1** — plan locked in [`ZEVO_ORG_PLAN.md`](ZEVO_ORG_PLAN.md); implement when green-lit (**masters + assignment edges** in one ship).  
3. **MD Phase 2** (company-code / IC partner fields; not Plant master).  
4. **C2C Phase 2** headers only if sources exist; otherwise deepen filters/examples.  
5. Explorer annotation scan when delivery/header DEX catalog gaps hurt discovery again.

## Defer / avoid

- Public entity set on process-flow DEX (`PRIVILEGED_ONLY`).  
- Moving full BP/bank/product back onto C2P/C2C.  
- Relying on cross-service `$expand`.  
- Assuming true CDC on ZEVO wrappers without SAP extraction annotations.
