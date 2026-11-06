---
name: sap-dex2file-install
description: Step-by-step install of sap-dex2file on a new SAP S/4HANA system via abapGit — package, pull, activate CDS/SRVD/SRVB, SEGW OData V2 ExtractCds, smoke tests. Use when installing or onboarding ZEVO on a greenfield system, setting up a new SAP landscape, or the user asks how to make the repo work in SAP.
---

# Install sap-dex2file on a new SAP system

Guide the user through a **full greenfield install**. Prefer this skill over paraphrasing random README fragments. Point them at `README.md` / `docs/COMPAT_S4_2023.md` for deep links; keep chat answers as a short checklist plus the next concrete click.

## When to use

- New S/4 system, CAL appliance, or package rebuild
- “How do I install / pull / activate ZEVO?”
- First-time SEGW `ZEVO_CDS_EXTRACT` wiring
- Choosing `main` vs `compat/s4-2023`

## Outcomes after a successful install

| Piece | Ready when |
|-------|------------|
| File extract | `SE38` → `ZEVO_CDS_EXPLORER_2_FILE` runs |
| OData V2 | `$metadata` on `ZEVO_CDS_EXTRACT_SRV` contains **`ExtractCds`** |
| OData V4 | Five bindings published; each `…/0001/$metadata` returns 200 |

abapGit only syncs **`src/`**. Read docs on GitHub / a git clone — they are not imported into SAP.

---

## 0. Pick the Git branch

| System | Branch | Notes |
|--------|--------|-------|
| S/4HANA **2025** / fuller DEX stack (`S4CORE` 109+) | **`main`** | Fullest CDS field lists |
| S/4HANA **2023** (`S4CORE` **108**) | **`compat/s4-2023`** | Substituted sources/fields; see `docs/COMPAT_S4_2023.md` |

Confirm release: system status / component **`S4CORE`** version (`108` = 2023).

Do **not** mix branches in one package without a clear wipe/repull plan.

---

## 1. abapGit ≥ 1.133.0

From **1.133.0**, pull **publishes** OData V4 bindings. Older abapGit creates bindings unpublished.

1. Run `ZABAPGIT_STANDALONE` → **About** / Debug Info → *abapGit version*.
2. If older than **1.133.0**, upgrade **before** the ZEVO pull:

**Already have Standalone (recommended):**

1. Keep a copy of the report as fallback.
2. abapGit → **+ New Online** → `https://github.com/abapGit/build.git` → existing package (e.g. **`$ABAPGIT`** — **not** the ZEVO package).
3. If `ZABAPGIT_STANDALONE` lives in another package, move it (`SE38` → Goto → Object Directory Entry) into the build package, pull again.
4. Pull → Activate → About shows ≥ 1.133.0.

**No abapGit yet:** SE38 upload of `zabapgit_standalone.prog.abap` using the **back-end / text-based** editor only (GUI/ADT paste of ~37k lines fails). Then switch to build.git for later upgrades.

### Package hierarchy pitfall

abapGit rejects nesting: if repo **build** is on `$EVOLVER` and ZEVO is on `$EVOLVER_DEX2F`, you get *Repository build already contains $EVOLVER_DEX2F*.

Fix: put Standalone/`build` in a **sibling** package (`$ABAPGIT`), **or** set **Ignore subpackages = Yes** on the build repo local settings.

---

## 2. Trust GitHub (`STRUST`) + PAT

1. Export GitHub (+ `api.github.com` if needed) cert chain from the browser.
2. `STRUST` → **SSL Client (Anonymous)** → Change → import each cert → Add to Certificate List → Save. Soft-restart ICM if needed.
3. Private repo: GitHub **PAT** with `repo` (or fine-grained read). In abapGit: **Username** = GitHub user, **Password** = **PAT**.

---

## 3. Create the ZEVO package

- Local: `$EVOLVER_DEX2F` / `$ZEVO` (named `$…` — abapGit blocks literal `$TMP`).
- Transportable: normal `Z…` package + transport.

One package for all ZEVO objects is fine for a first install.

---

## 4. Clone / pull

abapGit → **+ New Online**:

| Field | Value |
|-------|--------|
| URL | `https://github.com/aleo25672/sap-dex2file.git` |
| Branch | `main` **or** `compat/s4-2023` |
| Package | package from §3 |

Pull. On the pull dialog:

- **Keep** DDLS / SRVD / SRVB / G4BA / classes / report / `ZEVO_DELTA`.
- **Uncheck Delete local** for SEGW/Gateway locals you still need (`ZEVO_CDS_EXTRACT_*`, SICF, …) on later pulls.

---

## 5. Activate (order)

Mass-activate is OK if the tool resolves deps; otherwise:

1. Table **`ZEVO_DELTA`**
2. Classes **`ZEVO_CL_*`** (Gateway `/IWBEP/*` needed for OData helpers)
3. Report **`ZEVO_CDS_EXPLORER_2_FILE`** (type must be **Executable program**, first statement `REPORT …`)
4. All **`ZEVO_*` DDLS** (C2P / C2C / FI / MD / ORG sets together if cycles)
5. Service definitions **`ZEVO_C2P`**, **`ZEVO_C2C`**, **`ZEVO_GENERALLEDGER`**, **`ZEVO_MD`**, **`ZEVO_ORG`**
6. Service bindings **`SRVB`** (+ **`G4BA`** if present) — auto-publish with abapGit ≥ 1.133.0

If DDLS activation fails on 108, you are likely on the wrong branch — switch to **`compat/s4-2023`**.

If `SRVB` deserialize fails: create each binding in **ADT** (name = definition, **OData V4 - Web API** → Activate → **Publish**). Prefer committing only abapGit-serialized `SRVB`/`G4BA` from a working system — never hand-write binding XML.

If SRVD import fails: recreate definition in ADT from `src/zevo_*.srvd.srvdsrv`.

---

## 6. OData V4 — confirm published

Bindings and paths:

| Binding | Path after publish |
|---------|-------------------|
| `ZEVO_C2P` | `/sap/opu/odata4/sap/zevo_c2p/srvd_a2x/sap/zevo_c2p/0001/` |
| `ZEVO_C2C` | `/sap/opu/odata4/sap/zevo_c2c/srvd_a2x/sap/zevo_c2c/0001/` |
| `ZEVO_GENERALLEDGER` | `/sap/opu/odata4/sap/zevo_generalledger/srvd_a2x/sap/zevo_generalledger/0001/` |
| `ZEVO_MD` | `/sap/opu/odata4/sap/zevo_md/srvd_a2x/sap/zevo_md/0001/` |
| `ZEVO_ORG` | `/sap/opu/odata4/sap/zevo_org/srvd_a2x/sap/zevo_org/0001/` |

If URL missing: ADT → open binding → Activate → Unpublish → **Publish**.

Smoke: `GET {base}/$metadata` (HTTPS, SAP user). Authorizations follow CDS DCL on the Z wrappers.

---

## 7. OData V2 — SEGW `ZEVO_CDS_EXTRACT` (once per system)

Helpers (`ZEVO_CL_ODATA_*`) come from Git. **SEGW stubs stay local** — do not commit `ZCL_ZEVO_CDS_EXTRACT_*` unless intentional.

Detailed paste snippets: [references/segw-odata-v2.md](references/segw-odata-v2.md).

Checklist:

1. Activate helpers (`ZEVO_CL_ODATA_MPC`, `ZEVO_CL_ODATA_DPC`, `ZEVO_CL_ODATA_API`, …).
2. **`SEGW`** → Create project **`ZEVO_CDS_EXTRACT`**  
   - Project Type: **Service with SAP Annotations**  
   - Generation Strategy: **Standard**  
   - Same package as helpers  
   - Leave entity tree **empty** (model comes from ABAP).
3. Right-click project → **Generate Runtime Objects**.
4. **`ZCL_ZEVO_CDS_EXTRACT_MPC_EXT`→`DEFINE`**: call `zevo_cl_odata_mpc=>define_model( model )` — **no** `super->define( )`.
5. **`ZCL_ZEVO_CDS_EXTRACT_DPC_EXT`**: **Redefine** `EXECUTE_ACTION` (never edit `/IWBEP/CL_MGW_ABS_DATA`) → call `zevo_cl_odata_dpc=>execute_action` + `copy_data_to_ref`.
6. **`/IWFND/MAINT_SERVICE`** → Add **`ZEVO_CDS_EXTRACT_SRV`**  
   - ICF Node = **SAP Gateway OData V2** (not None)  
   - Confirm ICF active.
7. Smoke: `$metadata` must contain **`ExtractCds`**. Clear `/IWFND/CACHE_CLEANUP` if stale.

**After every SEGW Generate Runtime Objects**, re-check EXT methods — generate often wipes them.

---

## 8. File report smoke

`SE38` / `SA38` → `ZEVO_CDS_EXPLORER_2_FILE` → Display list (DEX) → optional small extract.

---

## 9. Later pulls

1. abapGit → Pull chosen branch → mass-activate changes.
2. Uncheck **Delete local** for SEGW/SICF and for ADT-only locals you still need.
3. Re-wire MPC_EXT / DPC_EXT if Generate was re-run.
4. Upgrade abapGit itself only via **build.git**, not by pasting Standalone source.

---

## Agent behaviour

When the user is mid-install:

1. Ask (or infer) **S4CORE / branch** and **abapGit version** if unknown.
2. Give **the next 1–3 steps only**, not the whole skill every turn.
3. On activation errors: paste-matching → branch mismatch vs missing DEX vs wrong field — prefer `compat/s4-2023` on 108.
4. On *ExtractCds* 404: MPC_EXT wiped / cache / wrong model provider class — see SEGW reference.
5. Never invent `SRVB` XML; never register `ZEVO_CL_ODATA_MPC` as the Gateway model provider.
