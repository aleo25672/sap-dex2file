# ZEVO — next phases (planning backlog)

Phase 1 is live for **C2P**, **C2C**, **MD**, **GENERALLEDGER**, **V2 ExtractCds**, and **ZEVO_CDS_EXPLORER_2_FILE**. This note lists likely Phase 2 / 3 work. It is a backlog, not a commitment.

**Invariants to keep**

- Scenario services = documents + **lean** BP; masters on `ZEVO_MD`; journal on `ZEVO_GENERALLEDGER`.
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
| 2 | High | `Plant` (`I_Plant` + plant→CC); customer/supplier company-code views; IC sales-org / shipping customer; wider Product |
| 3 | Low | Address/email (watch privileged CDS); BP relationships / contacts |

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
| 2 | High | Client join matrix (docs↔MD↔GL); IC resale 1710↔1010 E2E smoke; SRVD ADT fallback + republish runbook |
| 3 | Medium | Unified delta strategy doc; default `$top` / date / ITT performance guidance; security review before any privileged association |

---

## Suggested order

1. **Cross-service join matrix** (docs only — highest leverage).  
2. **MD Phase 2** (Plant + IC fields).  
3. **C2C Phase 2** headers only if sources exist; otherwise deepen filters/examples.  
4. Explorer annotation scan when delivery/header DEX catalog gaps hurt discovery again.

## Defer / avoid

- Public entity set on process-flow DEX (`PRIVILEGED_ONLY`).  
- Moving full BP/bank/product back onto C2P/C2C.  
- Relying on cross-service `$expand`.  
- Assuming true CDC on ZEVO wrappers without SAP extraction annotations.
