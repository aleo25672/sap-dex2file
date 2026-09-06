# sap-dex2file

ABAP tool for **S/4HANA** that discovers **CDS views** - **DEX** (data-extraction enabled)
and/or **API CDS** entities named like `I_*API*` - and downloads their data to a **file**:
a **full** load (`SELECT *`) or a **timestamp-based delta** (changes since the last run).

Companion to [`sap-dex2odata`](../sap-dex2odata) (which exposes views as OData services);
this one extracts straight to a file instead.

## Source types

On the selection screen, **Source type** chooses what to discover:

| Option | What is listed |
|--------|----------------|
| **DEX** | Released extraction-enabled views from `IXTRCTNENBLDVW` (unchanged behaviour) |
| **API CDS** | CDS DDL sources (`TADIR` object `DDLS`) whose names match the API pattern (default `I_*API*`, e.g. `I_PurchaseOrderAPI01`) |
| **Both** | Union of the two (DEX wins if the same entity appears in both) |

**Not listed:** OData service bindings such as `API_PURCHASEORDER_2` - those are not `DDLS`
objects, and names matching `API_*` are skipped as an extra guard.

Empty **API CDS pattern** defaults to `I_*API*`. The **DEX entity pattern** still filters DEX
views (and is ignored for API-only runs).

File extract (`SELECT *`) works for **both** DEX and API CDS. A view is **delta-capable** when a
change-timestamp field can be resolved (see below) and can then be run in delta mode.

## How delta works

Delta is **timestamp-based** (not true CDC). For each view, remember the **high-water timestamp**
of the last extraction, and next time only pull rows changed after it.

### 1. Finding the change-timestamp field
On discovery (`ZCL_DXF_CATALOG`), the tool resolves each view's **change-timestamp element** in
this order (first match wins):

1. Field annotated **`@Semantics.systemDateTime.lastChangedAt`** (`DDFIELDANNO`) - common on DEX
2. Field named **`LastChangeDateTime`** (`DD03L`) - common on API CDS views

If either is found, the view is **delta-capable** (grid columns *Delta?* / *Delta field*); otherwise
delta isn't possible for it.

### 2. The high-water store
The last extracted position per view is kept in table **`ZDXF_DELTA`**
(`VIEWNAME → LAST_TS`, plus who/when), read & written by `ZCL_DXF_DELTA_STORE`.

### 3. A run
When you extract with **Mode = Delta** (`ZCL_DXF_EXTRACTOR`):

1. Read the stored high-water `LAST_TS` for the view (a view never extracted → `0`).
2. Capture **"now"** at the *start* of the run - this becomes the **new** high-water.
3. `SELECT * FROM (entity) WHERE <ts field> > <LAST_TS>` - i.e. only rows changed since last time.
   *(First delta run, `LAST_TS = 0` → selects everything = an initial load.)*
4. Write the file. **Only after a successful write**, store the new high-water (step 2) back to
   `ZDXF_DELTA`. If the write fails, the marker is **not** advanced, so nothing is lost.

Because the new high-water is "now-at-start" (not the max timestamp seen), rows changed *during*
the run are simply re-read next time - safer than risking a gap.

A **Full** run also advances the marker (to "now"), so a subsequent **Delta** continues cleanly
from the full-load point.

### Resetting delta
- **Re-baseline:** run a **Full** load - it resets the marker to now; the next delta returns only
  later changes.
- **Re-extract everything as delta:** delete the view's row in `ZDXF_DELTA` (`SE16N`) → next delta
  sees `LAST_TS = 0` and selects all.

### Limits (be aware)
- ⚠️ **No deletes.** A timestamp filter only sees inserts/updates; deleted rows are not reported.
- ⚠️ **Needs a change-timestamp field.** Views with neither `@Semantics.systemDateTime.lastChangedAt`
  nor a `LastChangeDateTime` field are **full-only** (Delta is skipped with a reason).
- ✅ **No ODP RFC.** Deliberately avoids the ODP replication API (`RODPS_REPL_ODP_*`), which
  **SAP Note 3255746** restricts for custom use - so no gray-area dependency.
- The change-timestamp field's data type governs the `WHERE` literal; if a view's delta returns
  nothing or errors, its timestamp type may need a small tweak in `ZCL_DXF_EXTRACTOR`.

## Objects

| Object | Type | Purpose |
|--------|------|---------|
| `Z_DEX2FILE` | report | selection screen + `CL_SALV_TABLE` grid + extract/download |
| `ZCL_DXF_CATALOG` | class | discover DEX (`IXTRCTNENBLDVW`) and/or API CDS (`TADIR`/`DDLS`) + resolve delta field (annotation or `LastChangeDateTime`) |
| `ZCL_DXF_EXTRACTOR` | class | dynamic `SELECT * FROM (entity)` - full, or delta `WHERE ts > last` |
| `ZCL_DXF_FILE_WRITER` | class | serialize the table → delimited text → `gui_download` / `OPEN DATASET` |
| `ZCL_DXF_DELTA_STORE` | class | read/update the last-run high-water per view |
| `ZDXF_DELTA` | table | delta high-water per view (`VIEWNAME` → `LAST_TS`) |

## Using `Z_DEX2FILE`

Run in SAP GUI (`SE38` / `SA38`).

Selection screen:

| Field | Meaning |
|-------|---------|
| **Source type** | *DEX* / *API CDS* / *Both* |
| **DEX entity pattern** | case-sensitive filter for DEX views; plain text = contains, `*` = wildcard, blank = all |
| **API CDS pattern** | name filter for API CDS (`*` = wildcard); **empty = `I_*API*`** |
| **Data class** | *All* / *Master data* / *Transactional* - from `@ObjectModel.usageType.dataClass`, **not** the `I_`/`C_` prefix |
| **Action** | *Display list only* / *Extract to file* - runs on the filtered set |
| **Mode** | *Full load* / *Delta (change timestamp)* |
| **Target** | *Local frontend (download)* / *Application server (AL11)* |
| **Format** | *CSV* / *Tab (.txt)* / *Excel (tab, .xls)* |
| **CSV delimiter** | separator for CSV (default `;`) |
| **Folder / server dir** | frontend folder (e.g. `C:\temp\`) or an app-server path (e.g. `/tmp/`) |
| **Logical file name** | a logical file name from transaction **`FILE`**; when set, it resolves the path via `FILE_GET_NAME` (server) and **overrides** the folder |
| **Max rows** | cap per view (`0` = unlimited) - guard for frontend download limits |

- **Display** → grid of views: entity, description, **source (DEX/API)**, data class, CDC flag,
  delta timestamp field, delta-capable, last delta position. (ALV **Export** is enabled via
  `set_all`.)
- **Extract** → per view: extract (full/delta) → download `<entity>_<full|delta>_<date>_<time>.<ext>`
  → advance the delta marker (only after a successful download) → **results grid** (entity, mode,
  rows, file, status, message). Delta requested but no timestamp field → skipped (`K`).

## Notes

- **Format**: CSV and tab are native. "Excel" writes **tab-delimited** content with an `.xls`
  extension (Excel opens it) - a true `.xlsx` would need a library like abap2xlsx.
- **Target**: *Local frontend* uses `gui_download` (dialog only). *Application server* uses
  `OPEN DATASET` - it writes to the given AL11 directory, works in **background jobs**, and needs
  `S_DATASET` authorization.
- **Logical file name** (transaction `FILE`): configure a logical file name once (its physical
  path/name can use `<PARAM_1>` = entity, `<PARAM_2>` = FULL/DELTA, plus `<DATE>`/`<TIME>`/`<SYSID>`
  etc.). The report resolves it per view with `FILE_GET_NAME`. This is the recommended way to keep
  paths out of the code / consistent across systems; it implies the app-server target.
- **Parameterized views** can't be `SELECT`ed without parameter values; extraction of such a view
  returns an error row rather than dumping (caught in `ZCL_DXF_EXTRACTOR`).
- Release dependencies to confirm: tables `IXTRCTNENBLDVW`, `DDFIELDANNO`, `DD03L`, `TADIR`; the
  exact annotation `NAME` for `Semantics.systemDateTime.lastChangedAt`; and that API entities expose
  `LastChangeDateTime` in DDIC (`DD03L`) when the annotation is absent.

## Installing & importing with abapGit

This repo is serialized in [abapGit](https://abapgit.org) format (`src/` layout, prefix folder
logic).

### 1. One-time prerequisites

- **abapGit installed** - report `ZABAPGIT_STANDALONE` (paste the standalone source, activate, run).
- **GitHub TLS trusted** in `STRUST` (SSL Client Standard) and a **Personal Access Token** (this is
  a private repo). See the [`sap-dex2odata` README](../sap-dex2odata/README.md#installing--importing-with-abapgit)
  for the detailed one-time steps (cert import + PAT).

### 2. Create a target package

- **Local / testing:** create a `$`-prefixed package, e.g. **`$DEX2FILE`** (`SE80` → dropdown
  *Package* → type the name → *Create*). `$` packages are local - no software component, no
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

1. **`ZDXF_DELTA`** (table) - first, because the classes reference it.
2. `ZCL_DXF_*` classes.
3. `Z_DEX2FILE` (report).

Then run `Z_DEX2FILE` in `SE38` / `SA38`.

### 5. Getting later updates

When the repo changes: open it in abapGit → **Pull** → mass-activate the changed objects.

## License

See [LICENSE](LICENSE).
