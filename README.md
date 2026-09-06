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

Empty **API CDS** selection defaults to pattern `I_*API*`. Use select-options to pick
single entities, multiple values, or `*` wildcards (option CP). Entity select-options are
**case-sensitive** (`LOWER CASE` - no automatic uppercase); enter the CDS name in the same
case as in the system (TADIR / API names are usually uppercase).

File extract (`SELECT *`) works for **both** DEX and API CDS. A view is **delta-capable** when a
change-timestamp field can be resolved (see below) and can then be run in delta mode.

## How delta works

Delta is **timestamp-based** (not true CDC). For each view, remember the **high-water timestamp**
of the last extraction, and next time only pull rows changed after it.

### 1. Finding the change-timestamp field
On discovery (`ZCL_DXF_CATALOG`), the tool resolves each view's **change-timestamp element** in
this order (first match wins):

1. Field annotated **`@Semantics.systemDateTime.lastChangedAt`** (`DDFIELDANNO`) - common on DEX
2. Field annotated **`@Semantics.systemDateTime.localInstanceLastChangedAt`**
3. Field named **`LastChangeDateTime`** via annotations, `DD03L`, CDS→SQL mapping
   (`DDLDEPENDENCY`), or `DDIF_FIELDINFO_GET` - common on API / `A_*` projection views

If found, the view is **delta-capable**. The display list shows the field name in column
**LastChangeDateTime** and marks **Has change TS**; otherwise those columns stay empty and
delta isn't possible for that view.

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
- ⚠️ **Needs a change-timestamp field.** Views with neither a last-changed annotation
  nor a `LastChangeDateTime` field are **full-only** (Delta is skipped with a reason).
- ✅ **No ODP RFC.** Deliberately avoids the ODP replication API (`RODPS_REPL_ODP_*`), which
  **SAP Note 3255746** restricts for custom use - so no gray-area dependency.
- The change-timestamp field's data type governs the `WHERE` literal; if a view's delta returns
  nothing or errors, its timestamp type may need a small tweak in `ZCL_DXF_EXTRACTOR`.

## Objects

| Object | Type | Purpose |
|--------|------|---------|
| `Z_CDS_EXPLORER_2_FILE` | report | selection screen + `CL_SALV_TABLE` grid + extract/download |
| `ZCL_DXF_CATALOG` | class | discover DEX (`IXTRCTNENBLDVW`) and/or API CDS (`TADIR`/`DDLS`) + resolve delta field (annotation or `LastChangeDateTime`) |
| `ZCL_DXF_EXTRACTOR` | class | dynamic `SELECT * FROM (entity)` - full, or delta `WHERE ts > last` |
| `ZCL_DXF_FILE_WRITER` | class | serialize the table → delimited text → `gui_download` / `OPEN DATASET` |
| `ZCL_DXF_DELTA_STORE` | class | read/update the last-run high-water per view |
| `ZDXF_DELTA` | table | delta high-water per view (`VIEWNAME` → `LAST_TS`) |

## Using `Z_CDS_EXPLORER_2_FILE`

Run in SAP GUI (`SE38` / `SA38`).

Selection screen:

| Field | Meaning |
|-------|---------|
| **Source type** | *DEX* / *API CDS* / *Both* |
| **DEX entity** | select-options (**case-sensitive**): one / multiple / `*` wildcards; blank = all DEX |
| **API CDS entity** | select-options (**case-sensitive**): one / multiple / `*` wildcards; **blank = `I_*API*`** |
| **Data class** | *All* / *Master data* / *Transactional* - from `@ObjectModel.usageType.dataClass`, **not** the `I_`/`C_` prefix |
| **Action** | *Display list only* / *Extract to file* - runs on the filtered set |
| **Mode** | *Full load* / *Delta (change timestamp)* |
| **Target** | *Local frontend (download)* / *Application server (AL11)* — **background jobs require AL11 or logical file** |
| **Format** | *CSV* / *Tab (.txt)* / *Excel (tab, .xls)* |
| **CSV delimiter** | separator for CSV (default `;`) |
| **Folder / server dir** | frontend folder (e.g. `C:\temp\`) or an app-server path (e.g. `/tmp/`) |
| **Logical file name** | a logical file name from transaction **`FILE`**; when set, it resolves the path via `FILE_GET_NAME` (server) and **overrides** the folder |
| **Max rows** | cap per view (`0` = unlimited) - guard for frontend download limits |

- **Display** → grid of views: entity, description, **source (DEX/API)**, data class, CDC flag,
  **LastChangeDateTime** (field name when present), **Has change TS**,
  **Last changed on/at** (from `VRSD` version directory — useful to compare `A_*` vs `A_*_2`),
  last delta position. (ALV **Export** is enabled via `set_all`.)
- **Extract** → per view: extract (full/delta) → download `<entity>_<full|delta>_<date>_<time>.<ext>`
  → advance the delta marker (only after a successful download) → **results grid** (entity, mode,
  rows, file, status, message). Delta requested but no timestamp field → skipped (`K`).

## External file interface

Use this path when an **external application** should consume full/delta extracts
(no OData required).

### Recommended setup
1. Prefer **Source = DEX** and entities with **Has change TS**.
2. **Action = Extract to file**, **Target = Application server (AL11)** (or a **logical file name**).
3. Save a selection-screen **variant**.
4. Schedule the variant in **SM36** (background job).
5. Let the external app pick up files via **SFTP / NFS / shared folder**.

Background jobs **cannot** use local GUI download or Display-list ALV. If the job is started
with Target = Local frontend and no logical file name, the report raises an error.

### File naming
Data files (when Folder / server dir is used):

```text
<ENTITY>_<full|delta>_<YYYYMMDD>_<HHMMSS>.<csv|txt|xls>
```

Example: `C_PURCHASEORDERITEMDEX_delta_20260906_221530.csv`

All entities in one run share the same timestamp stamp. A logical file name from transaction
`FILE` can override the physical path/name (`<PARAM_1>` = entity, `<PARAM_2>` = FULL/DELTA).

### Run summary (`.ok`)
After each extract, the report also writes a sidecar summary next to the data files:

```text
zdxf_run_<YYYYMMDD>_<HHMMSS>.ok
```

Contents (line-oriented, easy to parse):

```text
run_date=20260906
run_time=221530
sysid=S4H
uname=INTERFACE
mode=DELTA
status=S
entities=3
ok=3
error=0
skipped=0
rows_total=120
entity;mode;rows;status;file;message
C_PURCHASEORDERITEMDEX;DELTA;40;S;/usr/sap/interface/.../C_PURCHASEORDERITEMDEX_delta_....csv;
...
```

`status`: `S` = all ok, `P` = partial (some errors), `E` = all failed.  
External apps should wait for the `.ok` file, then load the listed data files.

### Operating model
1. **Initial load:** job variant with **Mode = Full**.
2. **Ongoing:** job variant with **Mode = Delta** (same entities / folder).
3. After successful pickup, archive or delete consumed files (and the matching `.ok`).

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
- Release dependencies to confirm: tables `IXTRCTNENBLDVW`, `DDFIELDANNO`, `DD03L`, `DDLDEPENDENCY`,
  `TADIR`; FM `DDIF_FIELDINFO_GET`; the exact annotation `NAME` values for last-changed semantics;
  and that API / `A_*` entities expose `LastChangeDateTime` when the annotation is absent.

## Installing & importing with abapGit

This repo is serialized in [abapGit](https://abapgit.org) format (`src/` layout, prefix folder
logic).

### 1. Install abapGit (one-time)

1. Download the standalone report from [abapGit releases](https://github.com/abapGit/abapGit/releases)
   (`zabapgit_standalone.prog.abap` / copy source).
2. In the SAP system create report **`ZABAPGIT_STANDALONE`** (SE38), paste the source, activate.
3. Run `ZABAPGIT_STANDALONE`.

### 2. Trust GitHub TLS in `STRUST` (one-time)

abapGit talks to GitHub over HTTPS. The SAP system must trust the GitHub certificate chain.

1. In a browser open `https://github.com` (and ideally also `https://api.github.com`).
2. Export the **server certificate** and its **intermediate / root** certificates
   (browser certificate viewer → Certification path → export each node as Base64 `.cer` / `.pem`).
3. In SAP run transaction **`STRUST`**.
4. Open **SSL client SSL Client (Anonymous)** (double-click the PSE node).
5. Switch to **Change**.
6. For each exported certificate:
   - **Import certificate**
   - **Add to Certificate List**
7. **Save** the PSE.
8. Repeat for **`api.github.com`** if clone/pull with authentication still fails TLS.
9. Optional: in **SMICM** → *Restart* ICM (or soft restart) if the new certificates are not picked up.

If HTTPS still fails, check **SMICM** trace / **SM59** SSL errors and confirm the cipher suite
profile allows TLS 1.2+ (Basis/admin).

### 3. GitHub Personal Access Token (private repo)

This repository is private. Create a GitHub **Personal Access Token (classic)** with at least
**`repo`** scope (or a fine-grained token with read access to this repository).

In abapGit, when credentials are requested:
- **Username** = your GitHub username
- **Password** = the **PAT** (not your GitHub login password)

### 4. Create a target package

- **Local / testing:** create a `$`-prefixed package, e.g. **`$DEX2FILE`** (`SE80` → dropdown
  *Package* → type the name → *Create*). `$` packages are local - no software component, no
  transport prompt. *(abapGit blocks the literal `$TMP`, so use a named `$…` package.)*
- **Transportable:** a normal `Z…` package with software component **`HOME`** and a transport
  request.

### 5. Clone / pull from GitHub

In abapGit: **+ New Online** →
- **URL:** `https://github.com/aleo25672/sap-dex2file.git`
- **Branch:** `main`
- **Package:** your package from step 4
- Credentials when prompted: GitHub user + **PAT**

After clone, objects appear as new → **Pull**.

### 6. Activate

Activate in this order (or select all and mass-activate so dependencies resolve):

1. **`ZDXF_DELTA`** (table) - first, because the classes reference it.
2. `ZCL_DXF_*` classes.
3. `Z_CDS_EXPLORER_2_FILE` (report).

Then run `Z_CDS_EXPLORER_2_FILE` in `SE38` / `SA38`.

If activation says **"The REPORT/PROGRAM statement is missing, or the program type is INCLUDE"**:

1. `SE38` → `Z_CDS_EXPLORER_2_FILE` → **Attributes** → **Type** must be **Executable program (1)**, not Include.
2. Open the source and confirm the first statement is `REPORT Z_CDS_EXPLORER_2_FILE.`
3. If type/source still wrong after a rename or partial pull: **delete** the program in `SE80`/`SE38`, then abapGit **Pull** again so it is recreated as type 1 with full source.

### 7. Getting later updates

When the repo changes: open it in abapGit → **Pull** → mass-activate the changed objects.

## License

See [LICENSE](LICENSE).
