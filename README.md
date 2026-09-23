# sap-dex2file

ABAP tools for **S/4HANA** to extract CDS data in two ways:

1. **File extract** — report `ZEVO_CDS_EXPLORER_2_FILE` discovers DEX / API CDS views and downloads **full** or **delta** extracts to CSV/tab/AL11.
2. **OData extract** — Gateway service with function imports `ExtractCds` / `GetCdsMetadata`: pass a CDS name + OData `$filter`, paginate with `Skip`/`Top`, optional caller-managed delta, return **JSON or XML**.

> **Where to read the OData docs:** start at [OData CDS extract service](#odata-cds-extract-service) in this same README (full guide below). A copy also lives in [`docs/ZEVO_ODATA_EXTRACT.md`](docs/ZEVO_ODATA_EXTRACT.md).  
> **Note:** abapGit only syncs `src/` — `README.md` / `docs/` are **not** imported into SAP; read them on GitHub or in a git clone.

Companion historically referenced as [`sap-dex2odata`](../sap-dex2odata); the generic OData extract now lives **in this repo**.

## Contents

| Section | What |
|---------|------|
| **[OData CDS extract service](#odata-cds-extract-service)** | `ExtractCds`, `GetCdsMetadata`, [URL cookbook](#url-cookbook-c_purchaseorderdex) (`C_PurchaseOrderDEX`), filter, paging, delta |
| [P2P call flow (Word)](docs/P2P_OData_Extract_Call_Flow.docx) | PO → Item → History → GR / IR extract sequence |
| [Source types](#source-types) | DEX / API CDS / Both (file report) |
| [How delta works](#how-delta-works) | Timestamp delta for the **file** report (`ZEVO_DELTA`) |
| [Naming convention](#naming-convention) / [Objects](#objects) | `ZEVO*` inventory |
| [Using ZEVO_CDS_EXPLORER_2_FILE](#using-zevo_cds_explorer_2_file) | Selection screen & file extract |
| [External file interface](#external-file-interface) | AL11 / jobs / `.ok` sidecar |
| [Installing & importing with abapGit](#installing--importing-with-abapgit) | Pull & activate |

---

## OData CDS extract service

Generic **OData V2** service that extracts any selectable CDS entity on **SAP S/4HANA Private Cloud** (or on‑premise), similar in spirit to report `ZEVO_CDS_EXPLORER_2_FILE`, but over HTTP.

| Capability | Supported |
|------------|-----------|
| Pass CDS entity name | Yes (`EntityName`) |
| OData `$filter` syntax | Yes (subset → OpenSQL `WHERE`) |
| JSON or XML payload | Yes (`Format=json\|xml\|jsonrows\|xmlrows`) |
| Pagination | Yes (`Skip` / `Top` + `totalCount`) |
| Delta | Yes — **caller-managed** via `DeltaSince` (no `ZEVO_DELTA` table writes) |
| Service `$metadata` | Yes (standard Gateway) |
| CDS field metadata | Yes (`GetCdsMetadata`) |
| CDS discovery list | **No** (by design) |
| Async / background jobs | **No** (synchronous HTTP + pagination) |

Companion to the file extractor in this same repository. Business logic lives in ABAP classes; Gateway MPC/DPC expose it as function imports.

---

### Architecture

```text
Client
  │
  ├─ GET .../ZEVO_CDS_EXTRACT_SRV/$metadata          ← service contract
  ├─ GET .../GetCdsMetadata?...                      ← CDS fields / keys / delta field
  └─ GET .../ExtractCds?...                          ← paged data (json|xml|jsonrows|xmlrows inside Payload)
         │
         ▼
  ZEVO_CL_ODATA_DPC  →  ZEVO_CL_ODATA_API
                           ├─ ZEVO_CL_FILTER_PARSER   ($filter → OpenSQL)
                           ├─ ZEVO_CL_CDS_META        (fields, keys, delta field)
                           ├─ ZEVO_CL_EXTRACTOR       (SELECT + Skip/Top + COUNT)
                           └─ ZEVO_CL_SERIALIZER      (JSON / XML envelope)
```

#### Objects

| Object | Role |
|--------|------|
| `ZEVO_CL_ODATA_MPC` | Model helper — `DEFINE_MODEL` (call from SEGW MPC_EXT) |
| `ZEVO_CL_ODATA_DPC` | Action helper — `EXECUTE_ACTION` (call from SEGW DPC_EXT) |
| `ZEVO_CL_ODATA_API` | Facade used by DPC helper (also callable from ABAP tests) |
| `ZEVO_CL_FILTER_PARSER` | OData `$filter` → OpenSQL `WHERE` |
| `ZEVO_CL_CDS_META` | Per-entity metadata + delta-field resolution |
| `ZEVO_CL_SERIALIZER` | Envelope JSON/XML |
| `ZEVO_CL_EXTRACTOR` | `extract` (file report) + `extract_ex` (OData paging) |

Default page size: **1000**. Hard max `Top`: **10000** (`ZEVO_CL_EXTRACTOR=>C_MAX_TOP`).

---

### Gateway activation (S/4 Private Cloud)

abapGit ships the **helper classes** (`ZEVO_CL_ODATA_*`). You still create a **SEGW** project once and wire the generated stubs.

| Object (after Generate Runtime) | Role | Edit? |
|----------------------------------|------|-------|
| `ZCL_ZEVO_CDS_EXTRACT_MPC` | Generated model base | **No** — never change (SEGW overwrites) |
| `ZCL_ZEVO_CDS_EXTRACT_MPC_EXT` | Model extension | **Yes** — call `DEFINE_MODEL` here |
| `ZCL_ZEVO_CDS_EXTRACT_DPC` | Generated data base | **No** |
| `ZCL_ZEVO_CDS_EXTRACT_DPC_EXT` | Data extension | **Yes** — call `EXECUTE_ACTION` here |
| `ZEVO_CDS_EXTRACT_SRV` | OData service | Register in `/IWFND/MAINT_SERVICE` |
| `ZEVO_CDS_EXTRACT_MDL` | Model | Registered with the service |

`ZEVO_CL_ODATA_MPC` / `ZEVO_CL_ODATA_DPC` do **not** inherit Gateway bases; SEGW stubs call them.

> **abapGit:** keep generated `ZCL_ZEVO_CDS_EXTRACT_*` (and any `ZCL_ZEVO_GL_*`) **out of** this repo unless you intentionally want SEGW artifacts in Git. They often show as *Delete local object* in abapGit — that means “local only, not on GitHub”. Skip those deletes if you still need the service.

#### Step-by-step (SEGW)

1. **abapGit** — Pull `main`, activate all `ZEVO_CL_*` (especially `ZEVO_CL_ODATA_MPC`, `ZEVO_CL_ODATA_DPC`, `ZEVO_CL_ODATA_API`).
2. **`SEGW`** — Create project **`ZEVO_CDS_EXTRACT`** (same package as the helpers, or your Z package). Use **Change** mode (not Display).
3. Right-click the project → **Generate Runtime Objects**. You should see success for MPC / MPC_EXT / DPC / DPC_EXT / `ZEVO_CDS_EXTRACT_SRV` / `ZEVO_CDS_EXTRACT_MDL`.
4. You do **not** need to hand-maintain Entity Types in the SEGW tree for this design — the model is filled in ABAP via `DEFINE_MODEL`.

#### Wire `ZCL_ZEVO_CDS_EXTRACT_MPC_EXT` → `DEFINE`

1. **SE24** → class **`ZCL_ZEVO_CDS_EXTRACT_MPC_EXT`** → Change.  
   *(Not `…_MPC` — that base class says “NEVER MODIFY”.)*
2. Method **`DEFINE`** — replace body with:

```abap
METHOD define.
  " Model is code-defined only. Do NOT call super->define( ) here:
  " SEGW tree leftovers / empty project DEFINE can leave ExtractCds missing.
  zevo_cl_odata_mpc=>define_model( model ).
ENDMETHOD.
```

3. Activate `ZCL_ZEVO_CDS_EXTRACT_MPC_EXT`.

> **After every SEGW “Generate Runtime Objects”:** re-open `MPC_EXT->DEFINE` and `DPC_EXT->EXECUTE_ACTION`. Generate often resets EXT methods to empty stubs — paste the snippets again if needed.

#### Wire `ZCL_ZEVO_CDS_EXTRACT_DPC_EXT` → `EXECUTE_ACTION`

1. **SE24** → class **`ZCL_ZEVO_CDS_EXTRACT_DPC_EXT`** → Change.
2. Methods tab → find  
   **`/IWBEP/IF_MGW_APPL_SRV_RUNTIME~EXECUTE_ACTION`**.  
   If it only exists on the superclass: **Redefine** that method, then open source.
3. Paste this implementation:

```abap
METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.

  DATA: ls_result TYPE zevo_cl_odata_mpc=>ts_result,
        lv_ok     TYPE abap_bool,
        lv_msg    TYPE string,
        lv_name   TYPE /iwbep/mgw_tech_name,
        lt_param  TYPE /iwbep/t_mgw_name_value_pair,
        lo_msg    TYPE REF TO /iwbep/if_message_container.

  lv_name  = io_tech_request_context->get_function_import_name( ).
  lt_param = io_tech_request_context->get_parameters( ).

  zevo_cl_odata_dpc=>execute_action(
    EXPORTING
      iv_action_name = lv_name
      it_parameter   = lt_param
    IMPORTING
      es_result      = ls_result
      ev_ok          = lv_ok
      ev_message     = lv_msg ).

  IF lv_ok = abap_false.
    lo_msg = mo_context->get_message_container( ).
    lo_msg->add_message_text_only(
      iv_msg_type = 'E'
      iv_msg_text = CONV bapi_msg( lv_msg ) ).
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING
        message_container = lo_msg.
  ENDIF.

  " Return CdsResult (Id + Payload) to the Gateway response
  copy_data_to_ref(
    EXPORTING
      is_data = ls_result
    CHANGING
      cr_data = er_data ).

ENDMETHOD.
```

4. Activate `ZCL_ZEVO_CDS_EXTRACT_DPC_EXT`.

What the DPC method does:

| Step | Meaning |
|------|---------|
| `get_function_import_name` | Which import ran (`ExtractCds` / `GetCdsMetadata`) |
| `get_parameters` | URL params (`EntityName`, `Filter`, `Format`, …) |
| `zevo_cl_odata_dpc=>execute_action` | Runs extract / metadata via `ZEVO_CL_ODATA_API`; fills `Id` (GUID) + `Payload` |
| `copy_data_to_ref` | Puts `ls_result` into the OData response |

#### After model changes (Id key)

If you already generated the service with **`Payload` as key**, pull the updated helpers then:

1. Activate `ZEVO_CL_ODATA_MPC` / `ZEVO_CL_ODATA_DPC`.
2. Activate `ZCL_ZEVO_CDS_EXTRACT_MPC_EXT` (re-runs `DEFINE_MODEL` → `Id` key + `Payload` property).
3. **SEGW** → project **`ZEVO_CDS_EXTRACT`** → **Generate Runtime Objects** (so stubs pick up the new entity shape if needed).
4. Clear Gateway metadata cache if `$metadata` still shows the old key (`/IWFND/CACHE_CLEANUP` or soft-state / browser cache).
5. Re-test `$metadata` — `CdsResult` should list **`Id`** (Key) and **`Payload`**, and you must find **`FunctionImport Name="ExtractCds"`**.

#### Troubleshooting: `Resource not found for the segment 'ExtractCds'` / function import not found

The HTTP URL is fine — the **service model has no function imports**. Typical causes after SEGW generate:

1. **`MPC_EXT->DEFINE` was wiped** by Generate Runtime Objects → paste the `DEFINE` snippet above (no `super->define`) and activate.
2. **`DEFINE_MODEL` raised** (old `CdsResult` in SEGW tree conflicting) → in **SEGW** project `ZEVO_CDS_EXTRACT`, delete any hand-created Entity Types / Function Imports from the tree (keep the project empty; model comes from ABAP). Activate `MPC_EXT` again.
3. **Stale metadata cache** → `/IWFND/CACHE_CLEANUP` (or soft-state), then reload `$metadata` and **Ctrl+F** `ExtractCds`.
4. Confirm **`/IWFND/MAINT_SERVICE`**: service uses model provider **`ZCL_ZEVO_CDS_EXTRACT_MPC_EXT`** (not the base `…_MPC` alone, and not `ZEVO_CL_ODATA_MPC`).

Until `$metadata` contains `ExtractCds`, extract URLs will keep returning 404/500.

#### Register & test

1. **`/IWFND/MAINT_SERVICE`** — Add **`ZEVO_CDS_EXTRACT_SRV`** (system alias LOCAL / your GW alias), activate ICF node, assign role/auth as needed.
2. Run the [URL cookbook](#url-cookbook-c_purchaseorderdex) below (all examples use **`C_PurchaseOrderDEX`**).

#### Path B — optional note

Prefer Path A (SEGW stubs). Do **not** register `ZEVO_CL_ODATA_MPC` itself as the Gateway model provider class (it does not inherit `/IWBEP/CL_MGW_*`).

---

### URL cookbook (`C_PurchaseOrderDEX`)

All extract / metadata examples in this guide use the same CDS entity. Copy-paste into Gateway Client (`/IWFND/GW_CLIENT`).

> String literals in OData URLs use single quotes; embed a quote by doubling (`''`).  
> Use **`Skip` / `Top`** (function-import params), not `$skip` / `$top`.  
> `$format=json` is the **HTTP** body format; `Format=` is the **Payload** content mode.

#### 1. Service `$metadata` (EDMX — must list `ExtractCds` / `GetCdsMetadata` and `CdsResult` with `Id` key)

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/$metadata
```

#### 2. CDS field metadata

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/GetCdsMetadata
  ?EntityName='C_PurchaseOrderDEX'
  &Format='json'
  &$format=json
```

Use this to learn field names for `$filter`, keys for paging, and `deltaField` / `deltaCapable` before delta extracts.

#### 3. Full JSON envelope (first 10 POs — includes `totalCount`, `data`, …)

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Format='json'
  &Skip='0'
  &Top='10'
  &$format=json
```

Parse: `JSON.parse(d.Payload)` → object with `.data` (array), `.totalCount`, etc.

#### 4. Rows only (`jsonrows` — Payload is just the array)

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Format='jsonrows'
  &Skip='0'
  &Top='10'
  &$format=json
```

Parse: `JSON.parse(d.Payload)` → array of 10 PO objects. Gateway still returns `d.Id` + short `__metadata`.

#### 5. Filter by company code

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Filter='CompanyCode eq ''1710'''
  &Format='json'
  &Skip='0'
  &Top='10'
  &$format=json
```

Rows only + filter:

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Filter='CompanyCode eq ''1710'''
  &Format='jsonrows'
  &Skip='0'
  &Top='10'
  &$format=json
```

Combine filters with `and` / `or`, e.g. `CompanyCode eq '1710' and PurchasingOrganization eq '1710'` (remember to double quotes in the URL).

#### 6. Delta load (caller-managed watermark)

**Initial full page** (store max of `maxChangedAt` from the envelope across pages):

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Format='json'
  &Skip='0'
  &Top='1000'
  &$format=json
```

**Incremental** (only rows with `LastChangeDateTime` / `deltaField` **>** watermark — use `Format=json` to read the new `maxChangedAt`):

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &DeltaSince='20171008232647'
  &Format='json'
  &Skip='0'
  &Top='1000'
  &$format=json
```

**Delta + company filter + rows only** (you already own the watermark):

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Filter='CompanyCode eq ''1710'''
  &DeltaSince='20171008232647'
  &Format='jsonrows'
  &Skip='0'
  &Top='500'
  &$format=json
```

See [Caller-managed delta](#caller-managed-delta) for how `DeltaSince` relates to `LastChangeDateTime`.

> **P2P (PO → Item → History → GR / IR):** full call sequence as a Word doc — [`docs/P2P_OData_Extract_Call_Flow.docx`](docs/P2P_OData_Extract_Call_Flow.docx).

#### 7. Multiple CDS (header → items → history)

**Yes — as several `ExtractCds` calls.** The service has **no** `$expand` / navigation and **no** SQL join across CDS views. Each call targets **one** entity. The client orchestrates “related” extracts using keys from the header result.

Typical PO document set:

| Step | CDS | Role |
|------|-----|------|
| A | `C_PurchaseOrderDEX` | Headers (filter company + date) |
| B | `C_PurchaseOrderItemDEX` | Items for those PO numbers |
| C | `C_PurchaseOrderHistoryDEX` | History for those PO numbers |

Confirm field names with `GetCdsMetadata` on each entity (e.g. `PurchaseOrder`, `CompanyCode`, `PurchaseOrderDate`).

**Step A — headers** (`CompanyCode` + `PurchaseOrderDate >= 2026-01-01`):

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Filter='CompanyCode eq ''1710'' and PurchaseOrderDate ge ''2026-01-01'''
  &Format='jsonrows'
  &Skip='0'
  &Top='100'
  &$format=json
```

Parse `d.Payload` and collect distinct `purchaseorder` values (e.g. `4500000001`, `4500000002`).

**Step B — items** for those POs (`or` chain; there is no `in` operator):

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderItemDEX'
  &Filter='PurchaseOrder eq ''4500000001'' or PurchaseOrder eq ''4500000002'''
  &Format='jsonrows'
  &Skip='0'
  &Top='1000'
  &$format=json
```

**Step C — history** for the same POs:

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderHistoryDEX'
  &Filter='PurchaseOrder eq ''4500000001'' or PurchaseOrder eq ''4500000002'''
  &Format='jsonrows'
  &Skip='0'
  &Top='1000'
  &$format=json
```

**Client sketch:**

```javascript
const headers = JSON.parse(
  (await extract('C_PurchaseOrderDEX',
    "CompanyCode eq '1710' and PurchaseOrderDate ge '2026-01-01'")).d.Payload
);
const pos = [...new Set(headers.map(h => h.purchaseorder))];
const poFilter = pos.map(po => `PurchaseOrder eq '${po}'`).join(' or ');

const items = JSON.parse(
  (await extract('C_PurchaseOrderItemDEX', poFilter)).d.Payload
);
const history = JSON.parse(
  (await extract('C_PurchaseOrderHistoryDEX', poFilter)).d.Payload
);
```

**Limits / tips**

| Topic | Guidance |
|-------|----------|
| Joins / `$expand` | Not supported — always separate calls |
| `in (...)` | Not supported — use `or` (keep batches modest, e.g. 20–50 POs per call) |
| Many headers | Page Step A with `Skip`/`Top`; for each page, run B/C |
| Same company/date on children | If item/history CDS also have `CompanyCode` / date fields, you can filter children the same way **without** building a PO `or` list — still separate calls |
| Field names | Always verify with `GetCdsMetadata` — DEX views can differ by release |

Optional discovery for children:

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/GetCdsMetadata
  ?EntityName='C_PurchaseOrderItemDEX'
  &Format='json'
  &$format=json

GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/GetCdsMetadata
  ?EntityName='C_PurchaseOrderHistoryDEX'
  &Format='json'
  &$format=json
```

---

### Service metadata

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/$metadata
```

Returns the OData EDMX for this service: entity `CdsResult` (`Id` key + `Payload`), function imports `ExtractCds` and `GetCdsMetadata`, and their parameters. Use this so clients discover **how to call the service** (not the shape of an arbitrary CDS). See [URL cookbook](#url-cookbook-c_purchaseorderdex) item 1.

Also available:

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/
```

(service document).

---

### Function import: `GetCdsMetadata`

Returns field list, keys, DDL/SQL names, and delta-field info for **one** CDS entity.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `EntityName` | string | yes | CDS entity (examples use `C_PurchaseOrderDEX`) |
| `Format` | string | no | `json` (default) or `xml` — content of Payload |

#### Example

See [URL cookbook §2](#2-cds-field-metadata).

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/GetCdsMetadata
  ?EntityName='C_PurchaseOrderDEX'
  &Format='json'
  &$format=json
```

#### Response shape

Gateway returns entity **`CdsResult`**:

| Property | Role |
|----------|------|
| **`Id`** | Surrogate **key** (32-char GUID). Keeps `__metadata.id` / `uri` short. |
| **`Payload`** | Extract / metadata content (JSON or XML string). **Not** the key. |

Example HTTP body after extract (`Format=jsonrows`):

```json
{
  "d": {
    "__metadata": {
      "id": ".../CdsResultCollection('A1B2C3D4...')",
      "uri": ".../CdsResultCollection('A1B2C3D4...')",
      "type": "ZEVO_CDS_EXTRACT_SRV.CdsResult"
    },
    "Id": "A1B2C3D4E5F6...",
    "Payload": "[ { \"purchaseorder\": \"4500000001\", \"...\": \"...\" } ]"
  }
}
```

Clients: `JSON.parse(response.d.Payload)` — ignore `__metadata` and `Id`.

For **GetCdsMetadata**, the Payload string is JSON or XML like:

**JSON Payload (abbreviated):**

```json
{
  "entity": "C_PurchaseOrderDEX",
  "ddlName": "C_PURCHASEORDERDEX",
  "dbTabName": "...",
  "deltaField": "LastChangeDateTime",
  "deltaCapable": true,
  "keyFields": ["PurchaseOrder"],
  "fields": [
    {
      "name": "PurchaseOrder",
      "abapType": "C",
      "length": 10,
      "decimals": 0,
      "keyFlag": true,
      "description": "..."
    },
    {
      "name": "CompanyCode",
      "abapType": "C",
      "length": 4,
      "decimals": 0,
      "keyFlag": false,
      "description": "..."
    }
  ]
}
```

**Use this to:** build `$filter` expressions (e.g. `CompanyCode`), know keys for stable paging, and learn the delta timestamp field name before calling `ExtractCds` with `DeltaSince`.

---

### Function import: `ExtractCds`

Runs `SELECT` on the CDS entity with optional filter, optional delta, and pagination. Returns rows inside `Payload` as JSON or XML.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `EntityName` | string | yes | CDS entity name |
| `Filter` | string | no | OData `$filter` expression (see below) |
| `Format` | string | no | `json` (default), `xml`, `jsonrows`, or `xmlrows` — **content of Payload**, not the OData envelope |
| `DeltaSince` | string | no | Caller watermark: only rows with change-ts **>** this value (see [Caller-managed delta](#caller-managed-delta)) |
| `Skip` | string | no | Offset (default `0`) — pass as **quoted** string, e.g. `Skip='0'` (`Edm.String`) |
| `Top` | string | no | Page size (default `1000`, max `10000`) — pass as **quoted** string, e.g. `Top='500'` |

| `Format` value | `Payload` content |
|----------------|-------------------|
| `json` (default) | Full extract envelope (entity, counts, `data` array, …) |
| `xml` | Same envelope as XML |
| `jsonrows` | **Rows only** — a JSON array `[ {...}, ... ]` |
| `xmlrows` | **Rows only** — `<data><item>…</item>…</data>` |

> Use `json` / `xml` when you need `totalCount` for paging or `maxChangedAt` for delta. Use `jsonrows` / `xmlrows` when the client only wants the row payload.

#### Examples

All HTTP examples use **`C_PurchaseOrderDEX`** — see the [URL cookbook](#url-cookbook-c_purchaseorderdex):

| Need | Cookbook |
|------|----------|
| `$metadata` | §1 |
| Field list / delta capability | §2 `GetCdsMetadata` |
| Full envelope (first 10) | §3 `Format=json` |
| Rows only | §4 `Format=jsonrows` |
| Filter `CompanyCode` | §5 |
| Delta / incremental | §6 |
| Multi-CDS (header → item → history) | §7 |

#### Extract Payload (JSON)

```json
{
  "entity": "C_PurchaseOrderDEX",
  "format": "json",
  "rowCount": 10,
  "totalCount": 2215,
  "skip": 0,
  "top": 10,
  "deltaField": "LastChangeDateTime",
  "maxChangedAt": "20171008232647.2795840",
  "data": [ { "purchaseorder": "4500000001", "companycode": "1710", "...": "..." } ]
}
```

| Field | Meaning |
|-------|---------|
| `rowCount` | Rows in **this page** |
| `totalCount` | Rows matching filter (+ delta), all pages |
| `skip` / `top` | Echo of paging params (top may be capped) |
| `deltaField` | Field used for delta (empty if not delta) |
| `maxChangedAt` | Max change-ts **in this page** — store for next `DeltaSince` |
| `data` | Array of row objects |

#### Extract Payload (`Format=jsonrows`)

```json
[ { "purchaseorder": "4500000001", "companycode": "1710", "...": "..." }, { "...": "..." } ]
```

No envelope — `Payload` is the array alone.

#### Extract Payload (XML)

```xml
<?xml version="1.0" encoding="utf-8"?>
<extract>
  <entity>C_PurchaseOrderDEX</entity>
  <format>xml</format>
  <rowCount>10</rowCount>
  <totalCount>2215</totalCount>
  <skip>0</skip>
  <top>10</top>
  <deltaField></deltaField>
  <maxChangedAt></maxChangedAt>
  <data>
    <item>...</item>
  </data>
</extract>
```

#### Extract Payload (`Format=xmlrows`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<data>
  <item>...</item>
</data>
```

---

### Pagination protocol

Synchronous only: each HTTP call returns one page.

1. Call with `Skip='0'`, `Top='1000'` (or your size ≤ 10000) and `Format='json'` (or `xml`) so the envelope includes counts.
2. Read `totalCount` and `rowCount` from Payload.
3. While `skip + rowCount < totalCount`, call again with `Skip = skip + top`.
4. Stop when a page returns `rowCount = 0` or `skip >= totalCount`.

`Format=jsonrows` / `xmlrows` omit paging metadata — use them when you already know the page size or do not need `totalCount`.

Paging uses `ORDER BY` key fields (DDIC keys, else first component) + SQL `OFFSET` / `UP TO` for stable pages.

---

### Caller-managed delta

`DeltaSince` and `LastChangeDateTime` are **not the same thing** — they work as a pair.

| Concept | What it is |
|---------|------------|
| **Change-timestamp field** (e.g. `LastChangeDateTime`) | A **column on the CDS**. Discovered automatically; echoed as `deltaField` in metadata / extract envelope. You never pass the field name on extract. |
| **`DeltaSince`** | Your **watermark** on the request. When set, the service adds `deltaField > '<DeltaSince>'` to the SQL `WHERE`. |

Unlike the file report (which writes `ZEVO_DELTA`), this service **never** persists high-water marks — you store and pass them back.

#### How the field is chosen

`GetCdsMetadata` / extract look up (in order):

1. `@Semantics.systemDateTime.lastChangedAt`
2. `@Semantics.systemDateTime.localInstanceLastChangedAt`
3. Element / DDIC field named `LastChangeDateTime`

If none is found → `deltaCapable: false`. Passing `DeltaSince` then returns a skipped/business error.

#### What the SQL does

With `DeltaSince='20260101120000'` and `deltaField = LastChangeDateTime`:

```sql
... WHERE LastChangeDateTime > '20260101120000'
```

Comparison is **strictly greater than** — a row equal to the watermark is not returned again.

`DeltaSince` accepts compact timestamps (digits). Separators `-` `:` `T` `Z` `.` and spaces are stripped before conversion to `TIMESTAMPL` (e.g. `2026-01-01T12:00:00Z` → `20260101120000`).

#### Recommended pattern

1. **Discover** — call `GetCdsMetadata`; confirm `deltaCapable` and note `deltaField`.

```http
GET .../GetCdsMetadata?EntityName='C_PurchaseOrderDEX'&Format='json'&$format=json
```

```json
{
  "entity": "C_PurchaseOrderDEX",
  "deltaField": "LastChangeDateTime",
  "deltaCapable": true,
  "...": "..."
}
```

2. **Initial load** — omit `DeltaSince`; page with `Format='json'` (or `xml`) so the envelope includes `maxChangedAt` / `totalCount`. Keep the **global max** of `maxChangedAt` across pages (or max the change-ts column yourself over `data`).

```http
GET .../ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Format='json'
  &Skip='0'
  &Top='1000'
  &$format=json
```

Envelope fields that matter for delta:

| Field | Meaning |
|-------|---------|
| `deltaField` | Column used for the predicate (e.g. `LastChangeDateTime`) |
| `maxChangedAt` | Max of that column **on this page** — candidate for next `DeltaSince` |

3. **Incremental run** — pass the stored watermark as `DeltaSince`; page until done; update your store to the new global max `maxChangedAt`.

```http
GET .../ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &DeltaSince='20171008232647'
  &Format='json'
  &Skip='0'
  &Top='1000'
  &$format=json
```

Only rows with `LastChangeDateTime > 20171008232647` are returned.

#### Format choice for delta

| Goal | Format |
|------|--------|
| Need `totalCount` / `maxChangedAt` / `deltaField` in Payload | `json` or `xml` |
| Already own the watermark; want only row objects | `jsonrows` or `xmlrows` |

```http
# Envelope (recommended while learning / paging by totalCount)
...&DeltaSince='20171008232647'&Format='json'

# Rows only — Payload is [ {...}, ... ]; you track watermark yourself
...&DeltaSince='20171008232647'&Format='jsonrows'

# Rows only as XML
...&DeltaSince='20171008232647'&Format='xmlrows'
```

#### Combined with `$filter`

Filter and delta are **AND**ed:

```http
GET .../ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Filter='CompanyCode eq ''1710'''
  &DeltaSince='20171008232647'
  &Format='json'
  &Top='500'
```

→ roughly `WHERE ( CompanyCode = '1710' ) AND LastChangeDateTime > '20171008232647'`.

---

### `$filter` support (v1)

Translated to OpenSQL `WHERE`. Field names must exist on the CDS entity (allowlisted via RTTI).

| Supported | Example |
|-----------|---------|
| `eq` `ne` `gt` `ge` `lt` `le` | `CompanyCode eq '1710'` |
| `and` / `or` | `A eq '1' and B gt '2'` |
| parentheses | `(A eq '1' or A eq '2') and B eq 'X'` |
| string literals | `'WE'`, embed quote as `''` |
| numeric literals | `10`, `3.14` |

| Not supported (rejected) |
|--------------------------|
| `contains` / `startswith` / `endswith` / `substringof` |
| `tolower` / `toupper` / `not` / `null` |
| `in (...)` (use `or` chains instead — see [multi-CDS](#7-multiple-cds-header--items--history)) |
| `datetime'...'` literals (use quoted timestamps / dates instead) |
| navigation / `/` paths / `$expand` (one CDS per call) |

Invalid filters return a Gateway **business exception** with a clear message.

---

### Authorization & security

- Gateway user needs rights to call the service and to **read** the CDS (DCL applies on `SELECT`).
- `$filter` cannot reference unknown fields (allowlist).
- `Top` is capped to limit memory / response size.
- Prefer technical users with least privilege per CDS family.
- Large `Payload` strings: keep `Top` modest (e.g. 500–2000) for Gateway / HTTP timeouts.

---

### Comparison with `ZEVO_CDS_EXPLORER_2_FILE`

| Topic | File report | OData service |
|-------|-------------|----------------|
| Transport | AL11 / GUI file | HTTP JSON/XML |
| Discovery grid | Yes | No |
| Filter | Selection screen | OData `$filter` |
| Delta store | `ZEVO_DELTA` table | Caller-managed |
| Pagination | Max rows only | `Skip` / `Top` + `totalCount` |
| Formats | CSV / tab / xls | JSON / XML envelope, or `jsonrows` / `xmlrows` |
| Batch many CDS | One run, many files | One entity per call |

Use **files** for scheduled bulk DEX dumps; use **OData** for interactive / middleware / API integration with paging.

---

### ABAP API (without Gateway)

For unit tests or local checks after abapGit pull:

```abap
DATA(ls) = zevo_cl_odata_api=>get_cds_metadata(
  iv_entity_name = 'C_PurchaseOrderDEX'
  iv_format      = 'json' ).

ls = zevo_cl_odata_api=>extract_cds(
  iv_entity_name = 'C_PurchaseOrderDEX'
  iv_filter      = |CompanyCode eq '1710'|
  iv_format      = 'jsonrows'
  iv_skip        = 0
  iv_top         = 10 ).
" ls-payload / ls-status / ls-message
```

---

### Activation order (abapGit)

1. Existing objects (`ZEVO_DELTA`, file-extractor classes, report) if not already active  
2. `ZEVO_CL_FILTER_PARSER`  
3. `ZEVO_CL_SERIALIZER`  
4. `ZEVO_CL_CDS_META`  
5. `ZEVO_CL_EXTRACTOR` (updated)  
6. `ZEVO_CL_ODATA_API`  
7. `ZEVO_CL_ODATA_MPC` / `ZEVO_CL_ODATA_DPC` (need Gateway `/IWBEP/*` in the system)  
8. Register & activate service (`/IWFND/MAINT_SERVICE`)

---

### Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| MPC/DPC activate errors on `/IWBEP/*` | Gateway not in system, or method names differ by SP — adjust MPC `DEFINE` |
| `$metadata` 404 | Service not registered / ICF node inactive |
| Entity not selectable | Wrong name, parameterized CDS, or no auth |
| Empty `data` but `totalCount` > 0 | `Skip` beyond end |
| Delta returns nothing | Wrong `DeltaSince` format, or no rows newer than watermark |
| `ExtractCds` segment / function import not found | `MPC_EXT->DEFINE` missing or wiped after SEGW generate — paste `define_model( model )` **without** `super->define( )`; clear `/IWFND/CACHE_CLEANUP`; confirm `$metadata` contains `ExtractCds` |
| Filter error “not part of CDS” | Typo / wrong case — use names from `GetCdsMetadata` |
| Gateway timeout | Lower `Top`, page more |
| Huge Payload truncated | Lower `Top`; check GW string length settings |

---

### Out of scope (v1)

- CDS catalog / discovery entity set  
- Writing `ZEVO_DELTA` from OData  
- Async extract jobs  
- Full OData `$filter` grammar  
- OData V4 / RAP unbound actions  
- Per-CDS generated entity sets (use `sap-dex2odata` style if you need that)

---

---

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
On discovery (`ZEVO_CL_CATALOG`), the tool resolves each view's **change-timestamp element** in
this order (first match wins):

1. Field annotated **`@Semantics.systemDateTime.lastChangedAt`** (`DDFIELDANNO`) - common on DEX
2. Field annotated **`@Semantics.systemDateTime.localInstanceLastChangedAt`**
3. Field named **`LastChangeDateTime`** via annotations, `DD03L`, CDS→SQL mapping
   (`DDLDEPENDENCY`), or `DDIF_FIELDINFO_GET` - common on API / `A_*` projection views

If found, the view is **delta-capable**. The display list shows the field name in column
**LastChangeDateTime** and marks **Has change TS**; otherwise those columns stay empty and
delta isn't possible for that view.

### 2. The high-water store
The last extracted position per view is kept in table **`ZEVO_DELTA`**
(`VIEWNAME → LAST_TS`, plus who/when), read & written by `ZEVO_CL_DELTA_STORE`.

### 3. A run
When you extract with **Mode = Delta** (`ZEVO_CL_EXTRACTOR`):

1. Read the stored high-water `LAST_TS` for the view (a view never extracted → `0`).
2. Capture **"now"** at the *start* of the run - this becomes the **new** high-water.
3. `SELECT * FROM (entity) WHERE <ts field> > <LAST_TS>` - i.e. only rows changed since last time.
   *(First delta run, `LAST_TS = 0` → selects everything = an initial load.)*
4. Write the file. **Only after a successful write**, store the new high-water (step 2) back to
   `ZEVO_DELTA`. If the write fails, the marker is **not** advanced, so nothing is lost.

Because the new high-water is "now-at-start" (not the max timestamp seen), rows changed *during*
the run are simply re-read next time - safer than risking a gap.

A **Full** run also advances the marker (to "now"), so a subsequent **Delta** continues cleanly
from the full-load point.

### Resetting delta
- **Re-baseline:** run a **Full** load - it resets the marker to now; the next delta returns only
  later changes.
- **Re-extract everything as delta:** delete the view's row in `ZEVO_DELTA` (`SE16N`) → next delta
  sees `LAST_TS = 0` and selects all.

### Limits (be aware)
- ⚠️ **No deletes.** A timestamp filter only sees inserts/updates; deleted rows are not reported.
- ⚠️ **Needs a change-timestamp field.** Views with neither a last-changed annotation
  nor a `LastChangeDateTime` field are **full-only** (Delta is skipped with a reason).
- ✅ **No ODP RFC.** Deliberately avoids the ODP replication API (`RODPS_REPL_ODP_*`), which
  **SAP Note 3255746** restricts for custom use - so no gray-area dependency.
- The change-timestamp field's data type governs the `WHERE` literal; if a view's delta returns
  nothing or errors, its timestamp type may need a small tweak in `ZEVO_CL_EXTRACTOR`.

## Naming convention

All custom ABAP objects use the **`ZEVO`** prefix:

| Kind | Pattern | Example |
|------|---------|---------|
| Report | `ZEVO_*` | `ZEVO_CDS_EXPLORER_2_FILE` |
| Class | `ZEVO_CL_*` | `ZEVO_CL_CATALOG` |
| Table | `ZEVO_*` | `ZEVO_DELTA` |

## Objects

| Object | Type | Purpose |
|--------|------|---------|
| `ZEVO_CDS_EXPLORER_2_FILE` | report | selection screen + `CL_SALV_TABLE` grid + extract/download |
| `ZEVO_CL_CATALOG` | class | discover DEX (`IXTRCTNENBLDVW`) and/or API CDS (`TADIR`/`DDLS`) + resolve delta field (annotation or `LastChangeDateTime`) + map `DDLNAME` / `DBTABNAME` via `DDLDEPENDENCY` |
| `ZEVO_CL_EXTRACTOR` | class | dynamic `SELECT * FROM (entity)` - full, or delta `WHERE ts > last`; `extract_ex` adds filter + Skip/Top |
| `ZEVO_CL_FILE_WRITER` | class | serialize the table → delimited text → `gui_download` / `OPEN DATASET` |
| `ZEVO_CL_DELTA_STORE` | class | read/update the last-run high-water per view |
| `ZEVO_DELTA` | table | delta high-water per view (`VIEWNAME` → `LAST_TS`) — **file report only** |
| `ZEVO_CL_FILTER_PARSER` | class | OData `$filter` → OpenSQL `WHERE` |
| `ZEVO_CL_SERIALIZER` | class | CDS extract / metadata → JSON or XML envelope |
| `ZEVO_CL_CDS_META` | class | per-entity fields, keys, DDL/DBTAB, delta field |
| `ZEVO_CL_ODATA_API` | class | facade for `ExtractCds` / `GetCdsMetadata` |
| `ZEVO_CL_ODATA_MPC` | class | SEGW helper: `DEFINE_MODEL` (no Gateway inheritance) |
| `ZEVO_CL_ODATA_DPC` | class | SEGW helper: `EXECUTE_ACTION` (no Gateway inheritance) |

Full OData documentation: see **[OData CDS extract service](#odata-cds-extract-service)** above (also [`docs/ZEVO_ODATA_EXTRACT.md`](docs/ZEVO_ODATA_EXTRACT.md)).

## Using `ZEVO_CDS_EXPLORER_2_FILE`

Run in SAP GUI (`SE38` / `SA38`).

Selection screen:

| Field | Meaning |
|-------|---------|
| **Source type** | *DEX* / *API CDS* / *Both* |
| **CDS entity** | select-options (**case-sensitive**): entity name; blank = all for the source |
| **DDLNAME** | select-options (**case-sensitive**): CDS DDL source name (`DDLDEPENDENCY-DDLNAME`) |
| **DBTABNAME** | select-options (**case-sensitive**): SQL/DDIC view name (`DDLDEPENDENCY` object type `VIEW`) |
| **API CDS entity** | select-options (**case-sensitive**): used when Source includes API; **blank = `I_*API*`** |
| **Data class** | *All* / *Master data* / *Transactional* - from `@ObjectModel.usageType.dataClass`, **not** the `I_`/`C_` prefix |
| **Action** | *Display list only* / *Extract to file* - runs on the filtered set |
| **Mode** | *Full load* / *Delta (change timestamp)* |
| **Target** | *Local frontend (download)* / *Application server (AL11)* — **background jobs require AL11 or logical file** |
| **Format** | *CSV* / *Tab (.txt)* / *Excel (tab, .xls)* |
| **CSV delimiter** | separator for CSV (default `;`) |
| **Folder / server dir** | frontend folder (e.g. `C:\temp\`) or an app-server path (e.g. `/tmp/`) |
| **Logical file name** | a logical file name from transaction **`FILE`**; when set, it resolves the path via `FILE_GET_NAME` (server) and **overrides** the folder |
| **Max rows** | cap per view (`0` = unlimited) - guard for frontend download limits |

Filled filters are combined with **AND** (empty = ignore that dimension). `*` / `+` wildcards are supported.

- **Display** → grid of views: entity, **DDLNAME**, **DBTABNAME**, description, **source (DEX/API)**, data class, CDC flag,
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
zevo_run_<YYYYMMDD>_<HHMMSS>.ok
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
  returns an error row rather than dumping (caught in `ZEVO_CL_EXTRACTOR`).
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

- **Local / testing:** create a `$`-prefixed package, e.g. **`$ZEVO`** (`SE80` → dropdown
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

1. **`ZEVO_DELTA`** (table) - first, because the classes reference it.
2. `ZEVO_CL_*` classes (including OData helpers; MPC/DPC need Gateway `/IWBEP/*`).
3. `ZEVO_CDS_EXPLORER_2_FILE` (report).
4. For the OData service: register/activate per **[OData CDS extract service](#odata-cds-extract-service)** above.

After a rename from older `Z_CDS_*` / `ZCL_DXF_*` / `ZDXF_*` objects: delete the old objects (or let abapGit remove them), then pull/activate the `ZEVO*` ones.

Then run `ZEVO_CDS_EXPLORER_2_FILE` in `SE38` / `SA38`.

If activation says **"The REPORT/PROGRAM statement is missing, or the program type is INCLUDE"**:

1. `SE38` → `ZEVO_CDS_EXPLORER_2_FILE` → **Attributes** → **Type** must be **Executable program (1)**, not Include.
2. Open the source and confirm the first statement is `REPORT ZEVO_CDS_EXPLORER_2_FILE.`
3. If type/source still wrong after a rename or partial pull: **delete** the program in `SE80`/`SE38`, then abapGit **Pull** again so it is recreated as type 1 with full source.

### 7. Getting later updates

When the repo changes: open it in abapGit → **Pull** → mass-activate the changed objects.

## License

See [LICENSE](LICENSE).
