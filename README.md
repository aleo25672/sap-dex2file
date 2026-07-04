# sap-dex2file

ABAP tool for **S/4HANA** that discovers **data-extraction (DEX) CDS views** and downloads their
data to a **file** — a **full** load or a **timestamp-based delta** (changes since the last run).

Companion to [`sap-dex2odata`](../sap-dex2odata) (which exposes the same views as OData services);
this one extracts straight to a file instead.

## How delta works (and its limits)

Delta is **timestamp-based**, not true CDC: for a view that has a change-timestamp element
(annotated `@Semantics.systemDateTime.lastChangedAt`), a delta run selects rows whose timestamp is
newer than the **last run's high-water**, which the tool stores per view.

- ✅ No dependency on the ODP replication API (`RODPS_REPL_ODP_*`), which **SAP Note 3255746
  restricts** for custom use.
- ⚠️ Needs a change-timestamp field (views without one are full-only).
- ⚠️ Does **not** capture deletes.
- The high-water is captured at the **start** of a run, so concurrent changes are re-read next
  time (never silently lost).

## Objects

| Object | Type | Purpose |
|--------|------|---------|
| `Z_DEX2FILE` | report | selection screen + `CL_SALV_TABLE` grid + extract/download |
| `ZCL_DXF_CATALOG` | class | discover DEX views (`IXTRCTNENBLDVW`) + detect the delta timestamp field (`DDFIELDANNO`) |
| `ZCL_DXF_EXTRACTOR` | class | dynamic `SELECT * FROM (entity)` — full, or delta `WHERE ts > last` |
| `ZCL_DXF_FILE_WRITER` | class | serialize the table → delimited text → `gui_download` |
| `ZCL_DXF_DELTA_STORE` | class | read/update the last-run high-water per view |
| `ZDXF_DELTA` | table | delta high-water per view (`VIEWNAME` → `LAST_TS`) |

## Using `Z_DEX2FILE`

Run in SAP GUI (`SE38` / `SA38`).

Selection screen:

| Field | Meaning |
|-------|---------|
| **CDS entity pattern** | case-sensitive; plain text = contains, `*` = wildcard, blank = all |
| **Action** | *Display list only* / *Extract to file* — runs on the filtered set |
| **Mode** | *Full load* / *Delta (change timestamp)* |
| **Format** | *CSV* / *Tab (.txt)* / *Excel (tab, .xls)* |
| **CSV delimiter** | separator for CSV (default `;`) |
| **Download folder** | frontend folder (e.g. `C:\temp\`) |
| **Max rows** | cap per view (`0` = unlimited) — guard for frontend download limits |

- **Display** → grid of views: entity, description, CDC flag, delta timestamp field, delta-capable,
  last delta position. (ALV **Export** is enabled via `set_all`.)
- **Extract** → per view: extract (full/delta) → download `<entity>_<full|delta>_<date>_<time>.<ext>`
  → advance the delta marker (only after a successful download) → **results grid** (entity, mode,
  rows, file, status, message). Delta requested but no timestamp field → skipped (`K`).

## Notes

- **Format**: CSV and tab are native. "Excel" writes **tab-delimited** content with an `.xls`
  extension (Excel opens it) — a true `.xlsx` would need a library like abap2xlsx.
- **Parameterized views** can't be `SELECT`ed without parameter values; extraction of such a view
  returns an error row rather than dumping (caught in `ZCL_DXF_EXTRACTOR`).
- Release dependencies to confirm: tables `IXTRCTNENBLDVW`, `DDFIELDANNO`; and the exact annotation
  `NAME` for `Semantics.systemDateTime.lastChangedAt`.

## Installing & importing with abapGit

This repo is serialized in [abapGit](https://abapgit.org) format (`src/` layout, prefix folder
logic).

### 1. One-time prerequisites

- **abapGit installed** — report `ZABAPGIT_STANDALONE` (paste the standalone source, activate, run).
- **GitHub TLS trusted** in `STRUST` (SSL Client Standard) and a **Personal Access Token** (this is
  a private repo). See the [`sap-dex2odata` README](../sap-dex2odata/README.md#installing--importing-with-abapgit)
  for the detailed one-time steps (cert import + PAT).

### 2. Create a target package

- **Local / testing:** create a `$`-prefixed package, e.g. **`$DEX2FILE`** (`SE80` → dropdown
  *Package* → type the name → *Create*). `$` packages are local — no software component, no
  transport prompt. *(abapGit blocks the literal `$TMP`, so use a named `$…` package.)*
- **Transportable:** a normal `Z…` package with software component **`HOME`** and a transport
  request.

### 3. Clone the repo

In abapGit: **+ New Online** →
- URL: `https://github.com/aleo25672/sap-dex2file.git`
- Branch: `main`
- Package: your package from step 2
- Credentials when prompted: **User** = your GitHub user, **Password** = your **PAT**.

### 4. Pull & activate

After clone, the objects show as new → **Pull**. Then **activate**, in this order (or select all
and mass-activate so dependencies resolve):

1. **`ZDXF_DELTA`** (table) — first, because the classes reference it.
2. `ZCL_DXF_*` classes.
3. `Z_DEX2FILE` (report).

Then run `Z_DEX2FILE` in `SE38` / `SA38`.

### 5. Getting later updates

When the repo changes: open it in abapGit → **Pull** → mass-activate the changed objects.

## License

See [LICENSE](LICENSE).
