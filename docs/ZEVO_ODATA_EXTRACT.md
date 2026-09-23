# ZEVO OData CDS Extract Service

> **Also in the root README:** open [`README.md`](../README.md#odata-cds-extract-service) → section **OData CDS extract service** (same documentation). abapGit does not import `README.md` / `docs/` into SAP — read on GitHub.


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

## Architecture

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

### Objects

| Object | Role |
|--------|------|
| `ZEVO_CL_ODATA_MPC` | `DEFINE_MODEL` helper (call from SEGW MPC_EXT) |
| `ZEVO_CL_ODATA_DPC` | `EXECUTE_ACTION` helper (call from SEGW DPC_EXT) |
| `ZEVO_CL_ODATA_API` | Facade used by DPC helper (also callable from ABAP tests) |
| `ZEVO_CL_FILTER_PARSER` | OData `$filter` → OpenSQL `WHERE` |
| `ZEVO_CL_CDS_META` | Per-entity metadata + delta-field resolution |
| `ZEVO_CL_SERIALIZER` | Envelope JSON/XML |
| `ZEVO_CL_EXTRACTOR` | `extract` (file report) + `extract_ex` (OData paging) |

Default page size: **1000**. Hard max `Top`: **10000** (`ZEVO_CL_EXTRACTOR=>C_MAX_TOP`).

---

## Gateway activation (S/4 Private Cloud)

**Full SEGW walkthrough** (exact class names, SE24 steps, paste-ready `DEFINE` / `EXECUTE_ACTION` code, `/IWFND/MAINT_SERVICE`, smoke tests):

→ See root **[README.md — Gateway activation](../README.md#gateway-activation-s4-private-cloud)**.

Short checklist:

1. Pull/activate `ZEVO_CL_*` from abapGit.
2. `SEGW` project `ZEVO_CDS_EXTRACT` → **Generate Runtime Objects**.
3. Edit **`ZCL_ZEVO_CDS_EXTRACT_MPC_EXT`→`DEFINE`** (not the base `…_MPC`).
4. Redefine **`ZCL_ZEVO_CDS_EXTRACT_DPC_EXT`→`EXECUTE_ACTION`**.
5. `/IWFND/MAINT_SERVICE` → activate `ZEVO_CDS_EXTRACT_SRV`.
6. Test `$metadata`.

`ZEVO_CL_ODATA_MPC` / `ZEVO_CL_ODATA_DPC` are helpers only (no Gateway inheritance).

---

## Service metadata

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/$metadata
```

Returns the OData EDMX for this service: entity `CdsResult`, function imports `ExtractCds` and `GetCdsMetadata`, and their parameters. Use this so clients discover **how to call the service** (not the shape of an arbitrary CDS).

Also available:

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/
```

(service document).

---

## Function import: `GetCdsMetadata`

Returns field list, keys, DDL/SQL names, and delta-field info for **one** CDS entity.

### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `EntityName` | string | yes | CDS entity (examples use `C_PurchaseOrderDEX`) |
| `Format` | string | no | `json` (default) or `xml` |

### URL cookbook (`C_PurchaseOrderDEX`)

All examples below use the same CDS. Copy-paste into Gateway Client.

> Use **`Skip` / `Top`**, not `$skip` / `$top`. `$format=json` = HTTP body; `Format=` = Payload content.

#### 1. Service `$metadata`

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

#### 3. Full JSON envelope (first 10 POs)

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Format='json'
  &Skip='0'
  &Top='10'
  &$format=json
```

#### 4. Rows only (`jsonrows`)

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Format='jsonrows'
  &Skip='0'
  &Top='10'
  &$format=json
```

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

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Filter='CompanyCode eq ''1710'''
  &Format='jsonrows'
  &Skip='0'
  &Top='10'
  &$format=json
```

#### 6. Delta load

Initial (store `maxChangedAt`):

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &Format='json'
  &Skip='0'
  &Top='1000'
  &$format=json
```

Incremental:

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderDEX'
  &DeltaSince='20171008232647'
  &Format='json'
  &Skip='0'
  &Top='1000'
  &$format=json
```

Delta + company filter + rows only:

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

> **P2P (PO → Item → History → GR / IR):** see [`docs/P2P_OData_Extract_Call_Flow.docx`](P2P_OData_Extract_Call_Flow.docx).

#### 7. Multiple CDS (header → items → history)

**Yes — as several `ExtractCds` calls.** No `$expand` / navigation and no SQL join across CDS views. Each call targets **one** entity; the client links related extracts via keys from the header result.

| Step | CDS | Role |
|------|-----|------|
| A | `C_PurchaseOrderDEX` | Headers (filter company + date) |
| B | `C_PurchaseOrderItemDEX` | Items for those PO numbers |
| C | `C_PurchaseOrderHistoryDEX` | History for those PO numbers |

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

Collect distinct `purchaseorder` from `d.Payload`.

**Step B — items** (`or` chain; no `in` operator):

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderItemDEX'
  &Filter='PurchaseOrder eq ''4500000001'' or PurchaseOrder eq ''4500000002'''
  &Format='jsonrows'
  &Skip='0'
  &Top='1000'
  &$format=json
```

**Step C — history:**

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='C_PurchaseOrderHistoryDEX'
  &Filter='PurchaseOrder eq ''4500000001'' or PurchaseOrder eq ''4500000002'''
  &Format='jsonrows'
  &Skip='0'
  &Top='1000'
  &$format=json
```

Keep `or` batches modest (e.g. 20–50 POs). Page Step A if needed; verify field names with `GetCdsMetadata` on each entity. See the root README cookbook §7 for a client sketch and limits.

### Response shape

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

## Function import: `ExtractCds`

Runs `SELECT` on the CDS entity with optional filter, optional delta, and pagination. Returns rows inside `Payload` as JSON or XML.

### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `EntityName` | string | yes | CDS entity name |
| `Filter` | string | no | OData `$filter` expression (see below) |
| `Format` | string | no | `json` (default), `xml`, `jsonrows`, or `xmlrows` — **content of Payload**, not the OData envelope |
| `DeltaSince` | string | no | Caller watermark: only rows with change-ts **>** this value (see [Caller-managed delta](#caller-managed-delta)) |
| `Skip` | string | no | Offset (default `0`) — quoted, e.g. `Skip='0'` (`Edm.String`) |
| `Top` | string | no | Page size (default `1000`, max `10000`) — quoted, e.g. `Top='500'` |

| `Format` value | `Payload` content |
|----------------|-------------------|
| `json` (default) | Full extract envelope (entity, counts, `data` array, …) |
| `xml` | Same envelope as XML |
| `jsonrows` | **Rows only** — a JSON array `[ {...}, ... ]` |
| `xmlrows` | **Rows only** — `<data><item>…</item>…</data>` |

> Use `json` / `xml` when you need `totalCount` for paging or `maxChangedAt` for delta. Use `jsonrows` / `xmlrows` when the client only wants the row payload.

### Examples

See [URL cookbook](#url-cookbook-c_purchaseorderdex) (§3–§6). All use **`C_PurchaseOrderDEX`**.

### Extract Payload (JSON)

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

### Extract Payload (`Format=jsonrows`)

```json
[ { "purchaseorder": "4500000001", "companycode": "1710", "...": "..." }, { "...": "..." } ]
```

No envelope — `Payload` is the array alone.

### Extract Payload (XML)

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

### Extract Payload (`Format=xmlrows`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<data>
  <item>...</item>
</data>
```

---

## Pagination protocol

Synchronous only: each HTTP call returns one page.

1. Call with `Skip='0'`, `Top='1000'` (or your size ≤ 10000) and `Format='json'` (or `xml`) so the envelope includes counts.
2. Read `totalCount` and `rowCount` from Payload.
3. While `skip + rowCount < totalCount`, call again with `Skip = skip + top`.
4. Stop when a page returns `rowCount = 0` or `skip >= totalCount`.

`Format=jsonrows` / `xmlrows` omit paging metadata — use them when you already know the page size or do not need `totalCount`.

Paging uses `ORDER BY` key fields (DDIC keys, else first component) + SQL `OFFSET` / `UP TO` for stable pages.

---

## Caller-managed delta

`DeltaSince` and `LastChangeDateTime` are **not the same thing** — they work as a pair.

| Concept | What it is |
|---------|------------|
| **Change-timestamp field** (e.g. `LastChangeDateTime`) | A **column on the CDS**. Discovered automatically; echoed as `deltaField` in metadata / extract envelope. You never pass the field name on extract. |
| **`DeltaSince`** | Your **watermark** on the request. When set, the service adds `deltaField > '<DeltaSince>'` to the SQL `WHERE`. |

Unlike the file report (which writes `ZEVO_DELTA`), this service **never** persists high-water marks — you store and pass them back.

### How the field is chosen

`GetCdsMetadata` / extract look up (in order):

1. `@Semantics.systemDateTime.lastChangedAt`
2. `@Semantics.systemDateTime.localInstanceLastChangedAt`
3. Element / DDIC field named `LastChangeDateTime`

If none is found → `deltaCapable: false`. Passing `DeltaSince` then returns a skipped/business error.

### What the SQL does

With `DeltaSince='20260101120000'` and `deltaField = LastChangeDateTime`:

```sql
... WHERE LastChangeDateTime > '20260101120000'
```

Comparison is **strictly greater than** — a row equal to the watermark is not returned again.

`DeltaSince` accepts compact timestamps (digits). Separators `-` `:` `T` `Z` `.` and spaces are stripped before conversion to `TIMESTAMPL` (e.g. `2026-01-01T12:00:00Z` → `20260101120000`).

### Recommended pattern

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
  &DeltaSince='20260923101530123456'
  &Format='json'
  &Skip='0'
  &Top='1000'
  &$format=json
```

Only rows with `LastChangeDateTime > 20260923101530123456` are returned.

### Format choice for delta

| Goal | Format |
|------|--------|
| Need `totalCount` / `maxChangedAt` / `deltaField` in Payload | `json` or `xml` |
| Already own the watermark; want only row objects | `jsonrows` or `xmlrows` |

```http
# Envelope (recommended while learning / paging by totalCount)
...&DeltaSince='20260101120000'&Format='json'

# Rows only — Payload is [ {...}, ... ]; you track watermark yourself
...&DeltaSince='20260101120000'&Format='jsonrows'

# Rows only as XML
...&DeltaSince='20260101120000'&Format='xmlrows'
```

### Combined with `$filter`

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

## `$filter` support (v1)

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
| `in (...)` (use `or` chains instead — see cookbook §7 multi-CDS) |
| `datetime'...'` literals (use quoted timestamps / dates instead) |
| navigation / `/` paths / `$expand` (one CDS per call) |

Invalid filters return a Gateway **business exception** with a clear message.

---

## Authorization & security

- Gateway user needs rights to call the service and to **read** the CDS (DCL applies on `SELECT`).
- `$filter` cannot reference unknown fields (allowlist).
- `Top` is capped to limit memory / response size.
- Prefer technical users with least privilege per CDS family.
- Large `Payload` strings: keep `Top` modest (e.g. 500–2000) for Gateway / HTTP timeouts.

---

## Comparison with `ZEVO_CDS_EXPLORER_2_FILE`

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

## ABAP API (without Gateway)

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

## Activation order (abapGit)

1. Existing objects (`ZEVO_DELTA`, file-extractor classes, report) if not already active  
2. `ZEVO_CL_FILTER_PARSER`  
3. `ZEVO_CL_SERIALIZER`  
4. `ZEVO_CL_CDS_META`  
5. `ZEVO_CL_EXTRACTOR` (updated)  
6. `ZEVO_CL_ODATA_API`  
7. `ZEVO_CL_ODATA_MPC` / `ZEVO_CL_ODATA_DPC` (need Gateway `/IWBEP/*` in the system)  
8. Register & activate service (`/IWFND/MAINT_SERVICE`)

---

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| MPC/DPC activate errors on `/IWBEP/*` | Gateway not in system, or method names differ by SP — adjust MPC `DEFINE` |
| `$metadata` 404 | Service not registered / ICF node inactive |
| Entity not selectable | Wrong name, parameterized CDS, or no auth |
| Empty `data` but `totalCount` > 0 | `Skip` beyond end |
| Delta returns nothing | Wrong `DeltaSince` format, or no rows newer than watermark |
| `ExtractCds` segment / function import not found | `MPC_EXT->DEFINE` missing or wiped after SEGW generate — call `zevo_cl_odata_mpc=>define_model( model )` **without** `super->define( )`; `/IWFND/CACHE_CLEANUP`; confirm `$metadata` has `ExtractCds` |
| Filter error “not part of CDS” | Typo / wrong case — use names from `GetCdsMetadata` |
| Gateway timeout | Lower `Top`, page more |
| Huge Payload truncated | Lower `Top`; check GW string length settings |

---

## Out of scope (v1)

- CDS catalog / discovery entity set  
- Writing `ZEVO_DELTA` from OData  
- Async extract jobs  
- Full OData `$filter` grammar  
- OData V4 / RAP unbound actions  
- Per-CDS generated entity sets (use `sap-dex2odata` style if you need that)

---

## License

Same as the repository ([LICENSE](../LICENSE)).
