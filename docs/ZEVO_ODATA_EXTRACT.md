# ZEVO OData CDS Extract Service

> **Also in the root README:** open [`README.md`](../README.md#odata-cds-extract-service) → section **OData CDS extract service** (same documentation). abapGit does not import `README.md` / `docs/` into SAP — read on GitHub.


Generic **OData V2** service that extracts any selectable CDS entity on **SAP S/4HANA Private Cloud** (or on‑premise), similar in spirit to report `ZEVO_CDS_EXPLORER_2_FILE`, but over HTTP.

| Capability | Supported |
|------------|-----------|
| Pass CDS entity name | Yes (`EntityName`) |
| OData `$filter` syntax | Yes (subset → OpenSQL `WHERE`) |
| JSON or XML payload | Yes (`Format=json\|xml`) |
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
  └─ GET .../ExtractCds?...                          ← paged data (json|xml inside Payload)
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
| `EntityName` | string | yes | CDS entity (e.g. `I_SalesOrderPartner`) |
| `Format` | string | no | `json` (default) or `xml` |

### Example

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/GetCdsMetadata
  ?EntityName='I_SalesOrderPartner'
  &$format=json
```

Optional CDS payload format:

```http
.../GetCdsMetadata?EntityName='I_SalesOrderPartner'&Format='xml'
```

### Response shape

Gateway returns entity `CdsResult` with property **`Payload`**. The Payload string is JSON or XML:

**JSON Payload (abbreviated):**

```json
{
  "entity": "I_SalesOrderPartner",
  "ddlName": "I_SALESORDERPARTNER",
  "dbTabName": "...",
  "deltaField": "LastChangeDateTime",
  "deltaCapable": true,
  "keyFields": ["SalesOrder", "PartnerFunction"],
  "fields": [
    {
      "name": "SalesOrder",
      "abapType": "C",
      "length": 10,
      "decimals": 0,
      "keyFlag": true,
      "description": "..."
    }
  ]
}
```

**Use this to:** build `$filter` expressions, know keys for stable paging, and learn the delta timestamp field name before calling `ExtractCds` with `DeltaSince`.

---

## Function import: `ExtractCds`

Runs `SELECT` on the CDS entity with optional filter, optional delta, and pagination. Returns rows inside `Payload` as JSON or XML.

### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `EntityName` | string | yes | CDS entity name |
| `Filter` | string | no | OData `$filter` expression (see below) |
| `Format` | string | no | `json` (default) or `xml` — **content of Payload**, not the OData envelope |
| `DeltaSince` | string | no | If set, only rows with change-ts **>** this value (caller-managed delta) |
| `Skip` | int32 | no | Offset (default `0`) |
| `Top` | int32 | no | Page size (default `1000`, max `10000`) |

### Examples

**Full page (JSON data):**

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds
  ?EntityName='I_SalesOrderPartner'
  &Format='json'
  &Skip=0
  &Top=500
  &$format=json
```

**With $filter:**

```http
GET .../ExtractCds
  ?EntityName='I_SalesOrderPartner'
  &Filter='PartnerFunction eq ''WE'''
  &Format='json'
  &Top=500
```

> In OData URLs, string literals use single quotes; embed a quote by doubling (`''`).

**Delta + pagination (caller keeps the watermark):**

```http
GET .../ExtractCds
  ?EntityName='C_PurchaseOrderItemDEX'
  &DeltaSince='20260101000000'
  &Skip=0
  &Top=1000
  &Format='json'
```

### Extract Payload (JSON)

```json
{
  "entity": "I_SalesOrderPartner",
  "format": "json",
  "rowCount": 500,
  "totalCount": 12345,
  "skip": 0,
  "top": 500,
  "deltaField": "LastChangeDateTime",
  "maxChangedAt": "20260923101530123456",
  "data": [ { "...": "..." } ]
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

### Extract Payload (XML)

```xml
<?xml version="1.0" encoding="utf-8"?>
<extract>
  <entity>I_SalesOrderPartner</entity>
  <format>xml</format>
  <rowCount>500</rowCount>
  <totalCount>12345</totalCount>
  <skip>0</skip>
  <top>500</top>
  <deltaField></deltaField>
  <maxChangedAt></maxChangedAt>
  <data>
    <item>...</item>
  </data>
</extract>
```

---

## Pagination protocol

Synchronous only: each HTTP call returns one page.

1. Call with `Skip=0`, `Top=1000` (or your size ≤ 10000).
2. Read `totalCount` and `rowCount` from Payload.
3. While `skip + rowCount < totalCount`, call again with `Skip = skip + top`.
4. Stop when a page returns `rowCount = 0` or `skip >= totalCount`.

Paging uses `ORDER BY` key fields (DDIC keys, else first component) + SQL `OFFSET` / `UP TO` for stable pages.

---

## Caller-managed delta

Unlike the file report (which writes `ZEVO_DELTA`), this service **never** persists high-water marks.

Recommended pattern:

1. `GetCdsMetadata` → confirm `deltaCapable` / `deltaField`.
2. Initial load: `ExtractCds` **without** `DeltaSince`, page through all rows; remember global max of `maxChangedAt` (or your own max over `data`).
3. Next run: pass that value as `DeltaSince`; page until done; update your store to the new max `maxChangedAt`.

`DeltaSince` accepts compact timestamps (digits); separators `-` `:` `T` `Z` `.` spaces are stripped before conversion to `TIMESTAMPL`.

If `DeltaSince` is set but the entity has no change-timestamp field → business error (status skipped / message explains).

---

## `$filter` support (v1)

Translated to OpenSQL `WHERE`. Field names must exist on the CDS entity (allowlisted via RTTI).

| Supported | Example |
|-----------|---------|
| `eq` `ne` `gt` `ge` `lt` `le` | `PartnerFunction eq 'WE'` |
| `and` / `or` | `A eq '1' and B gt '2'` |
| parentheses | `(A eq '1' or A eq '2') and B eq 'X'` |
| string literals | `'WE'`, embed quote as `''` |
| numeric literals | `10`, `3.14` |

| Not supported (rejected) |
|--------------------------|
| `contains` / `startswith` / `endswith` / `substringof` |
| `tolower` / `toupper` / `not` / `null` |
| `datetime'...'` literals (use quoted timestamps instead) |
| navigation / `/` paths |

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
| Formats | CSV / tab / xls | JSON / XML |
| Batch many CDS | One run, many files | One entity per call |

Use **files** for scheduled bulk DEX dumps; use **OData** for interactive / middleware / API integration with paging.

---

## ABAP API (without Gateway)

For unit tests or local checks after abapGit pull:

```abap
DATA(ls) = zevo_cl_odata_api=>get_cds_metadata(
  iv_entity_name = 'I_SalesOrderPartner'
  iv_format      = 'json' ).

ls = zevo_cl_odata_api=>extract_cds(
  iv_entity_name = 'I_SalesOrderPartner'
  iv_filter      = |PartnerFunction eq 'WE'|
  iv_format      = 'json'
  iv_skip        = 0
  iv_top         = 100 ).
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
