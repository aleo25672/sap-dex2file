# sap-dex2file

ABAP tools for **S/4HANA** to extract CDS data in several ways:

1. **File extract** — report `ZEVO_CDS_EXPLORER_2_FILE` discovers DEX / API CDS views and downloads **full**, **delta**, or **bounded (date/time window)** extracts to CSV/tab/AL11.
2. **OData V2 extract** — Gateway service with function imports `ExtractCds` / `GetCdsMetadata`: pass a CDS name + OData `$filter`, paginate with `Skip`/`Top`, optional caller-managed delta, return **JSON or XML**.
3. **OData V4 C2P** — typed service + binding `ZEVO_C2P` for the P2P document graph + **lean** `BusinessPartner` for `$expand` (full BP/bank/roles on `ZEVO_MD`).
4. **OData V4 C2C** — typed service + binding `ZEVO_C2C` for the sales / contract-to-cash graph + lean BP (`ZEVO_O_*`).
5. **OData V4 General Ledger** — typed service + binding `ZEVO_GENERALLEDGER` for G/L line items and FI org masters (company, G/L account, cost/profit center, ledger, document type, house bank).
6. **OData V4 Master Data** — typed service + binding `ZEVO_MD` for cross-scenario masters (BP + supplier/customer roles + bank, product).

> **Where to read the OData docs:** start at [OData CDS extract service](#odata-cds-extract-service) (V2), [OData V4 C2P](#odata-v4-c2p-service-zevo_c2p), [OData V4 C2C](#odata-v4-contract-to-cash-zevo_c2c), [OData V4 General Ledger](#odata-v4-general-ledger-zevo_generalledger), and [OData V4 Master Data](#odata-v4-master-data-zevo_md).  
> V2: [`docs/ZEVO_ODATA_EXTRACT.md`](docs/ZEVO_ODATA_EXTRACT.md). C2P: [`docs/ZEVO_C2P.md`](docs/ZEVO_C2P.md). C2C: [`docs/ZEVO_C2C.md`](docs/ZEVO_C2C.md). GL: [`docs/ZEVO_GENERALLEDGER.md`](docs/ZEVO_GENERALLEDGER.md). MD: [`docs/ZEVO_MD.md`](docs/ZEVO_MD.md).  
> **Note:** abapGit only syncs `src/` — `README.md` / `docs/` are **not** imported into SAP; read them on GitHub or in a git clone.

Companion historically referenced as [`sap-dex2odata`](../sap-dex2odata); the generic OData extract now lives **in this repo**.

## Contents

| Section | What |
|---------|------|
| **[OData CDS extract service](#odata-cds-extract-service)** | V2 `ExtractCds`, `GetCdsMetadata`, [URL cookbook](#url-cookbook-c_purchaseorderdex) |
| **[OData V4 C2P (`ZEVO_C2P`)](#odata-v4-c2p-service-zevo_c2p)** | Typed V4 Web API — supported CDS, add-new steps, Eclipse/ADT publish |
| [C2P reference](docs/ZEVO_C2P.md) | Navigations, delta fields, URL cookbook |
| **[OData V4 C2C (`ZEVO_C2C`)](#odata-v4-contract-to-cash-zevo_c2c)** | Sales contract → order item → delivery → billing + lean BP |
| [C2C reference](docs/ZEVO_C2C.md) | Entity sets, filters, sample URLs |
| **[OData V4 General Ledger (`ZEVO_GENERALLEDGER`)](#odata-v4-general-ledger-zevo_generalledger)** | G/L lines + FI masters, `$expand`, sample URLs, binding pitfalls |
| [GL reference](docs/ZEVO_GENERALLEDGER.md) | `RMRP` / `RE`/`KZ` meanings, clearing joins, delta fields |
| **[OData V4 Master Data (`ZEVO_MD`)](#odata-v4-master-data-zevo_md)** | Cross-scenario BP (full) + roles + bank + product |
| [MD reference](docs/ZEVO_MD.md) | Entity sets, expands, publish URL |
| [P2P call flow (Word)](docs/P2P_OData_Extract_Call_Flow.docx) | PO → Item → History → GR / IR extract sequence |
| [Contract to Payment (Word)](docs/CONTRACT_TO_PAYMENT.docx) | Contract 4600000041 → PO 4500002146 → GR → invoice → payment 1500000000, with sample data |
| [Order to Cash (Word)](docs/ORDER_TO_CASH.docx) | Sales order 6321 → delivery → goods issue → billing 0090005785 → receipt 1400000000, with sample data |
| [Requisition to Payment 1 (Word)](docs/REQUISITION_TO_PAYMENT_1.docx) | Requisition 10001624 → PO 4500002147 → invoice 5100001600 → payment 1500000001. No contract |
| [Requisition to Payment 2 (Word)](docs/REQUISITION_TO_PAYMENT_2.docx) | Requisition 10001634 → contract 4600000042 → PO 4500002148 → invoice 5100001601 → payment 1500000002 |
| [Intercompany resale (Word)](docs/INTERCOMPANY_RESALE.docx) | Company 1710 sells TG11 to company 1010. Case 1 keeps the differences. Case 2 buys, then resells at 25.00 EUR |
| [Session readme](docs/README.md) | Use cases plus the live path from requisition 10001624 through invoice and payment |
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

The method lives on the SAP superclass chain (`/IWBEP/CL_MGW_ABS_DATA`). You must **redefine** it on **`ZCL_ZEVO_CDS_EXTRACT_DPC_EXT`**. Do **not** change `/IWBEP/CL_MGW_ABS_DATA` (that triggers repair / transportable workbench requests).

If `DPC_EXT` is in a local `$…` package (e.g. `$ZEVOLVER_DEX2F`, software component **LOCAL**), redefining on EXT does **not** need a transportable request.

##### SE24 (Class Builder)

1. **SE24** → class **`ZCL_ZEVO_CDS_EXTRACT_DPC_EXT`** → **Display ↔ Change** (Change mode).
2. **Methods** tab → select  
   **`/IWBEP/IF_MGW_APPL_SRV_RUNTIME~EXECUTE_ACTION`**.
3. Click **Redefine Method** (toolbar icon: document with pencil — hover tooltip *“Redefine Method”*).  
   It is **not** always labelled as text; do **not** click **Sourcecode** first.
4. If you instead see  
   *“…EXECUTE_ACTION is implemented in class /IWBEP/CL_MGW_ABS_DATA”*  
   → you opened the inherited implementation. **Continue** / Back, then use **Redefine Method** again on the EXT class.
5. After redefine, click **Sourcecode**. The editor must stay on **`ZCL_ZEVO_CDS_EXTRACT_DPC_EXT`** (not `/IWBEP/…`).
6. Paste the implementation below → **Activate**.

Menu alternatives if the icon is hard to find: **Method → Redefine** or **Edit → Redefine method**.

##### ADT (Eclipse) alternative

1. Open **`ZCL_ZEVO_CDS_EXTRACT_DPC_EXT`**.
2. **Outline** → `/IWBEP/IF_MGW_APPL_SRV_RUNTIME~EXECUTE_ACTION` → right‑click → **Redefine Method**  
   (or **Ctrl+1** → Redefine).
3. Paste the implementation → Activate.

Or in source-based class editor, add in the definition:

```abap
  METHODS /iwbep/if_mgw_appl_srv_runtime~execute_action REDEFINITION.
```

then implement `METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action. … ENDMETHOD.`

##### Implementation to paste

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

Activate **`ZCL_ZEVO_CDS_EXTRACT_DPC_EXT`** only. Do **not** use **Enhance** for this step.

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

1. **`/IWFND/MAINT_SERVICE`** — Add **`ZEVO_CDS_EXTRACT_SRV`** (system alias LOCAL / your GW alias).
   - On the **Add Service** dialog, under **ICF Node**, select **SAP Gateway OData V2** (not **None**). That creates the SICF node so URLs under `/sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/` work.
   - Package: use your local package (e.g. `$ZEVOLVER_DEX2F`) or **Local Object** as appropriate.
   - Leave **Enable OAuth for Service** unchecked unless you intentionally use OAuth.
   - After add: confirm the ICF node is active, assign role/auth as needed.
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
> **Contract to Payment:** quantity contract `4600000041` and release PO `4500002146`, with the sample rows in the document — [`docs/CONTRACT_TO_PAYMENT.docx`](docs/CONTRACT_TO_PAYMENT.docx).  
> **Order to Cash:** sales order `6321` through delivery, billing `0090005785`, and customer receipt `1400000000` — [`docs/ORDER_TO_CASH.docx`](docs/ORDER_TO_CASH.docx).  
> **Intercompany resale:** company 1710 sells TG11 to company 1010 in two posted scenarios — [`docs/INTERCOMPANY_RESALE.docx`](docs/INTERCOMPANY_RESALE.docx).

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
4. Pair `CREATIONDATE` + `CREATIONTIME` (returned as `CREATIONDATE|CREATIONTIME`; **not** for master-data CDS)
5. `DOCUMENTDATE` (date-only; **not** for master-data CDS)

If none is found → `deltaCapable: false`. Passing `DeltaSince` then returns a skipped/business error.
A date+time pair is filtered as
`CREATIONDATE > d OR CREATIONDATE = d AND CREATIONTIME > t`.
`DOCUMENTDATE` is filtered as `DOCUMENTDATE > YYYYMMDD`.

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
| `$metadata` 404 | Service not registered / ICF node inactive / Add Service used **ICF Node = None** (use **SAP Gateway OData V2**) |
| Entity not selectable | Wrong name, parameterized CDS, or no auth |
| Empty `data` but `totalCount` > 0 | `Skip` beyond end |
| Delta returns nothing | Wrong `DeltaSince` format, or no rows newer than watermark |
| `ExtractCds` segment / function import not found | `MPC_EXT->DEFINE` missing or wiped after SEGW generate — paste `define_model( model )` **without** `super->define( )`; clear `/IWFND/CACHE_CLEANUP`; confirm `$metadata` contains `ExtractCds` |
| Transportable request when editing `EXECUTE_ACTION` | You opened `/IWBEP/CL_MGW_ABS_DATA` — **Redefine** on `ZCL_ZEVO_CDS_EXTRACT_DPC_EXT` first (SE24: document+pencil *Redefine Method*), then Sourcecode; do not change the SAP class |
| Filter error “not part of CDS” | Typo / wrong case — use names from `GetCdsMetadata` |
| OpenSQL parser: `(` / “blank may be missing” | Old parser/extractor wrapped dynamic WHERE / `ORDER BY (cols)`. Pull **PR branch `cursor/filter-sql-parens-e01b`** (or merge PR #18) — not on `main` until merged — and activate `ZEVO_CL_FILTER_PARSER` + `ZEVO_CL_EXTRACTOR` |
| OpenSQL: `"COMPANYCODE" is not valid here` | Confirm field via `GetCdsMetadata`; skip `.NODE*` names; activate latest extractor/parser |
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

## OData V4 C2P service (`ZEVO_C2P`)

Typed **OData V4 Web API** for the contract-to-payment / P2P graph (12 entity sets + `$expand`). This is **not** the V2 `ExtractCds` wrapper. Canonical partner / bank / product masters live on [`ZEVO_MD`](#odata-v4-master-data-zevo_md); C2P keeps a **lean** `BusinessPartner` for document `$expand` only.

| Item | Value |
|------|--------|
| CDS projections | 12 × `ZEVO_C_*` (classic `define view`, explicit fields, one-way associations) |
| Service definition | `ZEVO_C2P` — in abapGit (`zevo_c2p.srvd.srvdsrv` + `.xml`) |
| Service binding | **Create in ADT only** as `ZEVO_C2P` — **OData V4 - Web API** (not shipped via abapGit; hand-written SRVB XML fails import) |
| Reference | Navigations, delta, more URLs — [`docs/ZEVO_C2P.md`](docs/ZEVO_C2P.md) |

### Supported CDS (12)

Each OData entity set is a thin Z projection over an SAP CDS. Clients call the **entity set** name; abapGit ships the **`ZEVO_C_*`** DDLS.

| Entity set (OData) | Z CDS (`ZEVO_C_*`) | Source CDS |
|--------------------|--------------------|------------|
| `PurchaseRequisitionItem` | `ZEVO_C_PurchRequisitionItem` | `C_PurchaseRequisitionItemDEX` |
| `PurchaseContract` | `ZEVO_C_PurchaseContract` | `C_PurchaseContractDEX` |
| `PurchaseContractItem` | `ZEVO_C_PurchContractItem` | `C_PurchaseContractItemDEX` |
| `PurchaseContractHistory` | `ZEVO_C_PurchContractHist` | `C_PurchaseContractHistoryDEX` |
| `PurchaseOrder` | `ZEVO_C_PurchaseOrder` | `C_PurchaseOrderDEX` |
| `PurchaseOrderItem` | `ZEVO_C_PurchaseOrderItem` | `C_PurchaseOrderItemDEX` |
| `PurchaseOrderHistory` | `ZEVO_C_PurchaseOrderHist` | `C_PurchaseOrderHistoryDEX` |
| `PurchaseOrderAccountAssignment` | `ZEVO_C_PurOrdAcctAssgmt` | `C_PurOrdAccountAssignmentDEX` |
| `SupplierInvoice` | `ZEVO_C_SupplierInvoice` | `C_SupplierInvoiceDEX` |
| `SupplierInvoiceItem` | `ZEVO_C_SupplierInvItem` | `C_SupplierInvoiceItemDEX` |
| `GoodsMovementDocument` | `ZEVO_C_GoodsMovementDoc` | `I_GoodsMovementDocumentDEX` (full DEX; **no CDS `WHERE`**) |
| `BusinessPartner` | `ZEVO_C_BusinessPartner` | `I_BusinessPartner` (lean: id/name/block/delta) |

Out of scope for this service: PR **header**, GL/journal, cost/profit center, product masters, ref-doc texts, and **full BP / supplier role / bank** (use [`ZEVO_MD`](#odata-v4-master-data-zevo_md)).

**Goods movements (C2P):** `ZEVO_C_GoodsMovementDoc` selects from **`I_GoodsMovementDocumentDEX` with no `WHERE` clause** — the entity set is the **full** DEX (not clipped to PO history). For P2P extracts, clients must `$filter` PO-related rows, e.g. `PurchaseOrder ne ''` or `PurchaseOrder eq '…'`, or expand `_GoodsMovement` from `PurchaseOrderHistory` with `PurchasingHistoryDocumentType eq '1'`. Details: [`docs/ZEVO_C2P.md`](docs/ZEVO_C2P.md#goods-movements--full-dex-filter-for-po).

### Add a new CDS to `ZEVO_C2P`

Use this when extending the typed V4 graph (same pattern as other `ZEVO_C_*` document views).

#### 1. In the Git repo

1. Add a classic CDS projection, e.g. `src/zevo_c_<short>.ddls.asddls` + matching `.ddls.xml`:
   - `define view ZEVO_C_<Name> as select from <SourceCds>`
   - **Explicit field list** (no `SELECT *`)
   - Contiguous **keys** that are not `@Consumption.hidden` on the source
   - Optional **one-way** `association` from an existing `ZEVO_C_*` (avoid cycles)
   - Inline `@Semantics…` on the delta/date field if useful
   - Alias any property that would equal `{EntitySet}Type` → e.g. `FooType as FooTypeCode`
   - Strip disallowed conversion exits (`cast(… as abap.char(n))` or a Z DTEL without the exit)
2. Expose it in [`src/zevo_c2p.srvd.srvdsrv`](src/zevo_c2p.srvd.srvdsrv):

```cds
expose ZEVO_C_<Name> as <EntitySetName>;
```

3. If another view should navigate to it, add the association + expose the association element on that view (e.g. `_Supplier` → lean `BusinessPartner`).
4. Update this table, [`docs/ZEVO_C2P.md`](docs/ZEVO_C2P.md) (entity set + nav + delta field), and a sample URL if helpful.
5. Merge to **`main`**.

#### 2. On the SAP system (abapGit + ADT)

1. **abapGit → Pull** `main`.
2. On the pull dialog:
   - **Keep** checked: new DDLS (**Add local object**), changed DDLS (**Delete and recreate** / overwrite), **SRVD** `ZEVO_C2P` (**Overwrite**).
   - If abapGit offers **Delete local** for obsolete DDLS no longer in Git, allow those deletes (do **not** keep old C2P bank/role views).
   - **Uncheck** anything that would **Delete local** the **SRVB** / **G4BA** `ZEVO_C2P` (binding is ADT-only, not in Git).
   - **Uncheck** deletes for local SEGW/Gateway objects (`ZEVO_CDS_EXTRACT_*`, SICF, …).
3. **Mass-activate** the new/changed `ZEVO_C_*` views and service definition `ZEVO_C2P`.
4. Open service binding **`ZEVO_C2P`** in ADT → **Activate** (**Cmd+F3** / **Ctrl+F3**).
5. **Unpublish** then **Publish** (or Publish again) so the local endpoint picks up the new entity set.
6. Confirm in the binding tree and in `$metadata` that the new entity set (and nav, if any) appear.

#### 3. Quick test / smoke

```http
GET {base}/$metadata
GET {base}/PurchaseOrder?$filter=PurchaseOrder eq '4500002146'&$expand=_Supplier
GET {base}/BusinessPartner?$filter=BusinessPartner eq '1000559'
# expect 404 — masters live on ZEVO_MD:
GET {base}/BusinessPartnerBank
```

Full checklist: [`docs/ZEVO_C2P.md`](docs/ZEVO_C2P.md#smoke-tests-lean-bp).

### A. Eclipse + ADT on Mac (one-time)

Service definition / binding / CDS activation for V4 is done in **ABAP Development Tools (ADT)**, not SEGW.

1. Install a current **Eclipse IDE** for Enterprise Java / RCP (or the ADT “Eclipse with ADT” package from SAP).
2. Install **ABAP Development Tools**:
   - **Help → Install New Software…**
   - Add the ADT update site for your Eclipse version (see [SAP ADT tools](https://tools.hana.ondemand.com/)).
   - Select **ABAP Development Tools for SAP HANA** (and UI5 tools only if you want them) → install → restart Eclipse.
3. Connect to the S/4 system over VPN (e.g. SAP CAL landscape). Example host used in this project: **`10.0.0.19`**.
4. **New → ABAP Project** (or import a system connection):
   - Connection type: application server / group as provided by your landscape.
   - Host: `10.0.0.19` (or your CAL hostname).
   - Instance / system ID / client / user as for SAP GUI.
   - HTTPS port is typically **`44300`** on CAL appliances.
5. Optional landscape XML: if ADT asks for a landscape / message-server file, point it at the same system you use in SAP GUI (same host/ports). Save credentials in the secure storage if prompted.
6. Confirm the project opens under Project Explorer (e.g. `[S4H] …`) and you can browse `$TMP` / your Z package.

### B. Pull CDS + service definition (abapGit)

1. In SAP GUI (or ADT), open **abapGit** on the package that already holds ZEVO objects (e.g. `$ZEVO` / `$ZEVOLVER_DEX2F`).
2. **Pull** branch **`main`** from `https://github.com/aleo25672/sap-dex2file.git`.
3. Activate (mass-activate is fine; resolve cycles by activating the whole `ZEVO_C_*` set together):
   1. All **`ZEVO_C_*`** DDLS (12 views).
   2. Service definition **`ZEVO_C2P`**.
4. If SRVD import fails: in ADT create service definition **`ZEVO_C2P`** and paste the expose list from [`src/zevo_c2p.srvd.srvdsrv`](src/zevo_c2p.srvd.srvdsrv).

> **Not in the repo (on purpose):** DDLX metadata extensions and `zevo_c2p.srvb.xml` — they broke abapGit import. Delta Semantics are **inline** on the views. The **service binding** is created only in ADT (next step).

### C. Create + publish the service binding (ADT)

1. In the ABAP project: **New → Other… → ABAP Repository Object → Service Binding** (or search “Service Binding”).
2. Fields:
   - **Name:** `ZEVO_C2P`
   - **Description:** e.g. `ZEVO C2P Web API`
   - **Binding Type:** **OData V4 - Web API**
   - **Service Definition:** `ZEVO_C2P`
3. Finish → open the binding editor.
4. **Activate** the binding (**Ctrl+F3** / **Cmd+F3**, or File → Activate).  
   Publish stays disabled until activate succeeds. The yellow bar *“To enable publish… activate the Service Binding”* clears after a good activate.
5. Click **Publish** on the local service endpoint. Status becomes **Published**.
6. Note the **Service URL**, e.g.:

```text
/sap/opu/odata4/sap/zevo_c2p/srvd_a2x/sap/zevo_c2p/0001/
```

Full example (CAL HTTPS):

```text
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_c2p/srvd_a2x/sap/zevo_c2p/0001/
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_c2p/srvd_a2x/sap/zevo_c2p/0001/$metadata
```

Browser will prompt for SAP user/password. Authorizations follow the underlying CDS DCL (`#CHECK` on the Z wrappers).

### D. Design choices that keep V4 binding green

These are already applied on `main`. If you recreate views by hand, keep them:

| Topic | What we do | Why |
|-------|------------|-----|
| CDS form | Classic `define view` + **explicit field lists** (no `SELECT *`) | Activation / abapGit compatibility on this stack |
| Associations | **One-way** only | Avoid CDS activation cycles |
| Goods movement keys | `MaterialDocumentYear` / `MaterialDocument` / `MaterialDocumentItem` | DEX `MaterialDocumentKey*` are `@Consumption.hidden` and block OData V4 binding |
| `RealEstateObject` | `cast(… as abap.char(8))` (or Z DTEL without `IMKEY` if you adopt that PR) | Binding rejects conversion exit **IMKEY** |
| Document / BP “type” fields | Alias to `*TypeCode` (`PurchaseOrderTypeCode`, …) | OData V4 entity type is `{EntitySet}Type` — property name must not collide (`/IWBEP/CM_V4_MED/082`) |
| Navigation in URLs | `$expand=_Item`, `_Supplier`, … | SADL keeps the CDS underscore; `$expand=Item` fails |

### E. Sample queries

POs created on/after 1 Oct 2026 with items:

```http
GET https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_c2p/srvd_a2x/sap/zevo_c2p/0001/PurchaseOrder
  ?$filter=CreationDate ge 2026-10-01
  &$expand=_Item
  &$orderby=CreationDate desc
```

Header → items → history / account assignment + supplier:

```http
GET .../PurchaseOrder
  ?$filter=CreationDate ge 2026-10-01
  &$expand=_Item($expand=_History,_AccountAssignment),_Supplier
  &$orderby=CreationDate desc
```

Lean supplier on a PO (full bank / role → [`ZEVO_MD`](#odata-v4-master-data-zevo_md)):

```http
GET .../PurchaseOrder?$filter=PurchaseOrder eq '4500002146'&$expand=_Supplier
GET .../BusinessPartner?$filter=BusinessPartner eq '1000559'
```

PO-related goods movements only (entity set is otherwise the full DEX):

```http
GET .../GoodsMovementDocument?$filter=PurchaseOrder%20ne%20''&$top=1000&$count=true
GET .../GoodsMovementDocument?$filter=PurchaseOrder%20eq%20'4500002146'
GET .../PurchaseOrderHistory?$filter=PurchaseOrder%20eq%20'4500002146'%20and%20PurchasingHistoryDocumentType%20eq%20'1'&$expand=_GoodsMovement
```

Smoke tests (lean BP / removed masters): [`docs/ZEVO_C2P.md`](docs/ZEVO_C2P.md#smoke-tests-lean-bp).  
More examples (delta, contract, PR): [`docs/ZEVO_C2P.md`](docs/ZEVO_C2P.md).

### F. Troubleshooting (V4 binding / metadata)

| Symptom | Fix |
|---------|-----|
| Binding: *Key field `MaterialDocumentKey*` must not be annotated as `CONSUMPTION.HIDDEN`* | Pull latest `main` — GM view uses Year/Document/Item keys |
| Binding: *Do not use conversion exit IMKEY for property REALESTATEOBJECT* | Pull latest — field is cast (or Z DTEL without IMKEY) |
| Activate binding first / Publish grayed out | **Activate** the Service Binding object, then **Publish** |
| `$metadata`: *Property `PurchaseOrderType` has the same EDM name as entity type `PurchaseOrderType`* | Pull latest — properties aliased to `*TypeCode` |
| `$expand`: *invalid property `Item`* | Use `_Item` (and `_History`, `_AccountAssignment`, `_Supplier`) |
| `$expand=_Bank` / `BusinessPartnerBank` on C2P | **Expected gone** — use [`ZEVO_MD`](#odata-v4-master-data-zevo_md) |
| SRVD / SRVB will not import via abapGit | SRVD source is `.srvdsrv`; create **binding only in ADT** — do not check in hand-written SRVB XML |
| abapGit wants to **Delete local** SRVB / G4BA `ZEVO_C2P` | **Uncheck** — binding/service group stay local; only pull SRVD + DDLS |
| New entity missing after pull | Activate SRVD + binding, then **Unpublish → Publish**; confirm name in `$metadata` |

After CDS changes: follow **[Add a new CDS](#add-a-new-cds-to-zevo_c2p)** (pull → activate → republish binding → `$metadata`).

---

## OData V4 General Ledger (`ZEVO_GENERALLEDGER`)

Typed **OData V4 Web API** for G/L journal lines (`I_GLAccountLineItemRawData`) plus FI org masters. This is **not** `ZEVO_C2P` (P2P graph) and **not** the V2 `ExtractCds` wrapper. Supplier/customer / BP **masters** live on [`ZEVO_MD`](#odata-v4-master-data-zevo_md); lines only carry `Supplier` / `Customer` IDs for an external tool to join.

| Item | Value |
|------|--------|
| CDS projections | `ZEVO_FI_*` (classic `define view`, explicit fields, one-way associations) |
| Service definition | `ZEVO_GENERALLEDGER` — in abapGit (`zevo_generalledger.srvd.*`) |
| Service binding | **Create in ADT only** as `ZEVO_GENERALLEDGER` — **OData V4 - Web API** (not in abapGit) |
| Reference | `RMRP`/`MKPF`, `RE`/`KZ`, clearing joins — [`docs/ZEVO_GENERALLEDGER.md`](docs/ZEVO_GENERALLEDGER.md) |

Eclipse / abapGit / ADT habits match **[C2P](#odata-v4-c2p-service-zevo_c2p)** (sections A–C). Use binding name **`ZEVO_GENERALLEDGER`** and activate all **`ZEVO_FI_*`** + the SRVD.

### Entity sets (8)

| Entity set (OData) | Z CDS (`ZEVO_FI_*`) | Source CDS |
|--------------------|---------------------|------------|
| `GLAccountLineItem` | `ZEVO_FI_GLAcctLineItem` | `I_GLAccountLineItemRawData` |
| `CompanyCode` | `ZEVO_FI_CompanyCode` | `I_CompanyCode` |
| `GLAccount` | `ZEVO_FI_GLAccount` | `I_GLAccount` |
| `CostCenter` | `ZEVO_FI_CostCenter` | `I_CostCenter` |
| `ProfitCenter` | `ZEVO_FI_ProfitCenter` | `I_ProfitCenter` |
| `Ledger` | `ZEVO_FI_Ledger` | `I_Ledger` |
| `AccountingDocType` | `ZEVO_FI_AccountingDocType` | `I_AccountingDocumentType` |
| `HouseBank` | `ZEVO_FI_HouseBank` | `I_HouseBank` |

### Navigations from `GLAccountLineItem`

| Nav | To | Join |
|-----|----|------|
| `_CompanyCode` | `CompanyCode` | `CompanyCode` |
| `_GLAccount` | `GLAccount` | `CompanyCode` + `ChartOfAccounts` + `GLAccount` |
| `_Ledger` | `Ledger` | `SourceLedger` = `Ledger` |
| `_AccountingDocType` | `AccountingDocType` | `AccountingDocumentType` (BLART) |
| `_HouseBank` | `HouseBank` | `CompanyCode` + `HouseBank` |

`CostCenter` / `ProfitCenter` are **scalar fields only** on the line (no `$expand`) — masters are time-dependent, so a unique 0..1 FK is invalid for OData V4. Query their entity sets separately. No `_Supplier` / `_Customer` navs.

### Service URL + metadata

```text
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_generalledger/srvd_a2x/sap/zevo_generalledger/0001/
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_generalledger/srvd_a2x/sap/zevo_generalledger/0001/$metadata
```

- `GET {base}/` → service document (entity-set list JSON)
- `GET {base}/$metadata` → full EDMX (XML). Use `Accept: application/xml` if a client defaults to JSON.

### Sample queries

Always filter `CompanyCode` + `FiscalYear` + `SourceLedger` for volume. `SourceLedger` is the ledger key on the line (e.g. `0L`); expand `_Ledger` for the master.

**Lines by company / FY / ledger / posting-date range + masters:**

```http
GET https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_generalledger/srvd_a2x/sap/zevo_generalledger/0001/GLAccountLineItem
  ?$filter=CompanyCode eq '1710' and FiscalYear eq '2026' and SourceLedger eq '0L'
    and PostingDate ge 2026-10-01 and PostingDate le 2026-10-31
  &$expand=_GLAccount,_CompanyCode,_Ledger,_AccountingDocType
  &$top=100
```

One-line (browser / Postman):

```text
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_generalledger/srvd_a2x/sap/zevo_generalledger/0001/GLAccountLineItem?$filter=CompanyCode%20eq%20'1710'%20and%20FiscalYear%20eq%20'2026'%20and%20SourceLedger%20eq%20'0L'%20and%20PostingDate%20ge%202026-10-01%20and%20PostingDate%20le%202026-10-31&$expand=_GLAccount,_CompanyCode,_Ledger,_AccountingDocType&$top=100
```

**Fiscal period** (e.g. October = `010`):

```http
GET {base}/GLAccountLineItem
  ?$filter=CompanyCode eq '1710' and FiscalYear eq '2026' and SourceLedger eq '0L'
    and FiscalPeriod eq '010'
  &$top=100
```

**Ledger master / G/L account lookup / delta / invoice → FI:**

```http
GET {base}/Ledger
GET {base}/Ledger('0L')

GET {base}/GLAccount
  ?$filter=CompanyCode eq '1710' and ChartOfAccounts eq 'YCOA' and GLAccount eq '0011002000'

GET {base}/GLAccountLineItem
  ?$filter=CompanyCode eq '1710' and FiscalYear eq '2026' and SourceLedger eq '0L'
    and LastChangeDateTime gt 2026-10-12T00:00:00Z
  &$orderby=LastChangeDateTime asc

GET {base}/GLAccountLineItem
  ?$filter=CompanyCode eq '1710' and FiscalYear eq '2026' and SourceLedger eq '0L'
    and ReferenceDocumentType eq 'RMRP' and ReferenceDocument eq '5100001601'
```

SADL keeps the CDS underscore — `$expand=_GLAccount` works; `$expand=GLAccount` does not. Optional: add `_HouseBank` when the line has a house bank.

### Design choices that keep V4 binding green

Already on `main`:

| Topic | What we do | Why |
|-------|------------|-----|
| CDS form | Classic `define view` + explicit fields (no `SELECT *`) | Activation / abapGit on this stack |
| `GLAccount` / `OffsettingAccount` | `cast(… as abap.char(10))` | Avoid search-help **SAKO** without company context |
| Ledger on the line | Key `SourceLedger` only; nav `_Ledger` | No direct `Ledger` column on `I_GLAccountLineItemRawData` here |
| `GLAccount` keys | `CompanyCode` + `ChartOfAccounts` + `GLAccount` | `I_GLAccount` is company-code dependent; chart+account alone breaks `$expand` (0..1 multiplicity) |
| `GLAccountType` | Alias `GLAccountTypeCode` | EDM clash with entity type `GLAccountType` (`/IWBEP/CM_V4_MED/082`) |
| Clearing / WBS | `ClearingJournalEntry`, `ClearingJournalEntryFiscalYear`, `WBSElementInternalID` | Successors to deprecated `ClearingAccountingDocument` / `ClearingDocFiscalYear` / `WBSElement` |
| Cost / profit center | Fields only — no `_CostCenter` / `_ProfitCenter` | Time-dependent masters → non-unique FK for OData V4 |
| Navigation in URLs | `$expand=_GLAccount`, `_CompanyCode`, … | SADL keeps the CDS underscore |

### Troubleshooting (GL binding / metadata / expand)

| Symptom | Fix |
|---------|-----|
| `$metadata`: *Property `GLAccountType` has the same EDM name as entity type `GLAccountType`* | Pull latest — property is `GLAccountTypeCode` |
| `$expand`: *More than one item returned for navigation property with 0-to-1 multiplicity* | Pull latest — `GLAccount` keys include `CompanyCode`; or omit `$expand=_GLAccount` until republished |
| Binding: non-unique CostCenter / ProfitCenter FK | Pull latest — those navs were removed; use scalar fields + entity sets |
| Activation: unknown `Ledger` column | Use `SourceLedger` + `_Ledger` |
| Activation: deprecated clearing / WBS elements | Use `ClearingJournalEntry*` + `WBSElementInternalID` |
| New fields missing after pull | Activate `ZEVO_FI_*` + SRVD + binding → **Unpublish → Publish** → reload `$metadata` |
| abapGit wants to **Delete local** SRVB / G4BA `ZEVO_GENERALLEDGER` | **Uncheck** — binding stays local |

After CDS changes: pull → activate → republish binding → `$metadata`. More domain detail (`RMRP`/`RE`/`KZ`, clearing → payment): [`docs/ZEVO_GENERALLEDGER.md`](docs/ZEVO_GENERALLEDGER.md).

---

## OData V4 Contract-to-Cash (`ZEVO_C2C`)

Typed **OData V4 Web API** for the sales / contract-to-cash graph (9 entity sets + `$expand`). Canonical partner / bank / product masters live on [`ZEVO_MD`](#odata-v4-master-data-zevo_md); C2C keeps a **lean** `BusinessPartner` for document `$expand` only. Cash / AR journal lines stay on [`ZEVO_GENERALLEDGER`](#odata-v4-general-ledger-zevo_generalledger).

| Item | Value |
|------|--------|
| CDS projections | 9 × `ZEVO_O_*` (classic `define view`, explicit fields, one-way associations) |
| Service definition | `ZEVO_C2C` — in abapGit (`zevo_c2c.srvd.*`) |
| Service binding | **Create in ADT only** as `ZEVO_C2C` — **OData V4 - Web API** |
| Reference | [`docs/ZEVO_C2C.md`](docs/ZEVO_C2C.md) |

### Supported CDS (9)

| Entity set (OData) | Z CDS | Source CDS |
|--------------------|-------|------------|
| `SalesContract` | `ZEVO_O_SalesContract` | `I_SalesContract` |
| `SalesContractItem` | `ZEVO_O_SalesContractItem` | `I_SalesContractItem` |
| `SalesDocumentItem` | `ZEVO_O_SalesDocumentItem` | `C_SalesDocumentItemDEX` |
| `SalesDocumentScheduleLine` | `ZEVO_O_SalesDocSchedLine` | `C_SalesDocumentSchedLineDEX` |
| `OutboundDelivery` | `ZEVO_O_OutboundDelivery` | `C_OutboundDeliveryDEX` |
| `OutboundDeliveryItem` | `ZEVO_O_OutboundDelivItem` | `C_OutboundDeliveryItemDEX` |
| `BillingDocumentItem` | `ZEVO_O_BillingDocumentItem` | `I_BillingDocumentItemDEX` |
| `GoodsMovementDocument` | `ZEVO_O_GoodsMovementDoc` | `I_GoodsMovementDocumentDEX` (full DEX; **no CDS `WHERE`**) |
| `BusinessPartner` | `ZEVO_O_BusinessPartner` | `I_BusinessPartner` (lean) |

### Source / filter discoveries (Phase 1)

| Topic | Finding |
|-------|---------|
| Sales order header DEX | **None** — use item DEX `C_SalesDocumentItemDEX` (+ schedule `C_SalesDocumentSchedLineDEX`); client filter `SDDocumentCategory eq 'C'` for orders |
| Sales contract | `I_SalesContract` / `I_SalesContractItem` (API CDS; ADT Data Preview OK) |
| Outbound delivery | Prefer **`C_OutboundDeliveryDEX`** / **`C_OutboundDeliveryItemDEX`** (extraction-annotated view entities over `I_DeliveryDocument*`). SAP source already has `where SDDocumentCategory = 'J'`. Optional client filter `DeliveryDocumentTypeCode eq 'LF'` |
| Delivery vs ODP | Those `C_OutboundDelivery*DEX` may appear in `DDDDLSRC` and work in OpenSQL / typed OData, yet be **absent** from `RSODPABAPCDSVIEW` and from released `IXTRCTNENBLDVW` — ODP activate tools won’t see them; explorer **Include non-released DEX** only helps rows that exist in `IXTRCTNENBLDVW` |
| Billing | Item-centric: Phase 1 uses **`I_BillingDocumentItemDEX`** (rich; SAP `where` on invoice categories). Classic ODP-friendly alt: `C_BillingDocumentItemBasicDEX` (`CSDBILDOCITMBCDX`) |
| `I_DeliveryDocument*` | Suitable for samples / API; **not** chosen for C2C bulk path |
| Goods movement | Same DEX as C2P — see below |

### Goods movements (C2C) — no CDS filter

`ZEVO_O_GoodsMovementDoc` selects from **`I_GoodsMovementDocumentDEX` with no `WHERE` clause** (same approach as C2P). The entity set returns the **full** DEX.

| Service | CDS `WHERE` on GM? | Client `$filter` for scenario |
|---------|-------------------|-------------------------------|
| **C2P** | **None** | PO-related: `PurchaseOrder ne ''` / specific PO / history type `1` + `$expand=_GoodsMovement` |
| **C2C** | **None** | Sales/delivery: e.g. `DeliveryDocument ne ''`, `SalesOrder ne ''`, and/or `GoodsMovementType eq '601'` |

```http
GET .../GoodsMovementDocument?$filter=DeliveryDocument%20ne%20''&$top=1000&$count=true
GET .../GoodsMovementDocument?$filter=SalesOrder%20ne%20''%20and%20GoodsMovementType%20eq%20'601'
```

### Client filters (documents)

| Entity set | Filter |
|------------|--------|
| `SalesDocumentItem` / schedule | `SDDocumentCategory eq 'C'` (orders; DEX also has quotations `B`, …) |
| `OutboundDelivery` | SAP CDS already `J`; optional `DeliveryDocumentTypeCode eq 'LF'` |
| `BillingDocumentItem` | SAP CDS already invoice categories (`M`/`N`/`O`/`P`/…) |
| `GoodsMovementDocument` | **Client-only** — see table above |

Eclipse / abapGit / ADT habits match **[C2P](#odata-v4-c2p-service-zevo_c2p)**. Binding name **`ZEVO_C2C`**; activate all **`ZEVO_O_*`** DDLS **before** SRVD; **never** let abapGit delete local SRVB/G4BA `ZEVO_C2C`.

**If abapGit says `SRVDSRV ZEVO_C2C does not exist`:** another pull will not create it — open ADT → New → Service Definition **`ZEVO_C2C`** → paste [`src/zevo_c2c.srvd.srvdsrv`](src/zevo_c2c.srvd.srvdsrv) → Activate (all `ZEVO_O_*` must already be active) → New Binding **`ZEVO_C2C`** (OData V4 Web API) → Publish.

```text
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_c2c/srvd_a2x/sap/zevo_c2c/0001/$metadata
```

More detail: [`docs/ZEVO_C2C.md`](docs/ZEVO_C2C.md).

---

## OData V4 Master Data (`ZEVO_MD`)

Typed **OData V4 Web API** for **cross-scenario masters**: full business partner, DEX supplier/customer roles, rich `I_Customer` / `I_Supplier`, bank, and product. Scenario services (`ZEVO_C2P`, `ZEVO_C2C`) keep **lean BP** for document `$expand`; **canonical** partner/bank/product reads use this service. FI org masters stay on [`ZEVO_GENERALLEDGER`](#odata-v4-general-ledger-zevo_generalledger).

| Item | Value |
|------|--------|
| CDS projections | `ZEVO_M_*` (classic `define view`, explicit fields, one-way associations) |
| Service definition | `ZEVO_MD` — in abapGit (`zevo_md.srvd.*`) |
| Service binding | **Create in ADT only** as `ZEVO_MD` — **OData V4 - Web API** |
| Reference | [`docs/ZEVO_MD.md`](docs/ZEVO_MD.md) |

Eclipse / abapGit / ADT habits match **[C2P](#odata-v4-c2p-service-zevo_c2p)**. Use binding name **`ZEVO_MD`** and activate all **`ZEVO_M_*`** + the SRVD.

### Entity sets (7)

| Entity set (OData) | Z CDS | Source CDS |
|--------------------|-------|------------|
| `BusinessPartner` | `ZEVO_M_BusinessPartner` | `I_BusinessPartner` |
| `BusinessPartnerSupplier` | `ZEVO_M_BPSupplier` | `I_BusinessPartnerSupplierDEX` |
| `BusinessPartnerCustomer` | `ZEVO_M_BPCustomer` | `I_BusinessPartnerCustomerDEX` |
| `BusinessPartnerBank` | `ZEVO_M_BPBank` | `I_BusinessPartnerBank` |
| `Supplier` | `ZEVO_M_Supplier` | `I_Supplier` |
| `Customer` | `ZEVO_M_Customer` | `I_Customer` |
| `Product` | `ZEVO_M_Product` | `I_Product` |

Navigations: BP → `_BPSupplier` / `_BPCustomer` / `_Bank`; role → `_Supplier` / `_Customer`.  
`ProductType` → `ProductTypeCode` (EDM name clash).

### Service URL + samples

```text
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_md/srvd_a2x/sap/zevo_md/0001/
https://10.0.0.19:44300/sap/opu/odata4/sap/zevo_md/srvd_a2x/sap/zevo_md/0001/$metadata
```

```http
GET {base}/BusinessPartner
  ?$filter=BusinessPartner eq '0001000559'
  &$expand=_BPSupplier($expand=_Supplier),_BPCustomer($expand=_Customer),_Bank

GET {base}/BusinessPartnerBank
  ?$filter=BPBankDetailsChangeDate ge 2026-10-01

GET {base}/Product?$filter=Product eq 'MZ-TG-Y240'
```

### Design notes

| Topic | Choice |
|-------|--------|
| vs C2P BP | MD = extensive / canonical; C2P = lean BP for document `$expand` only |
| vs C2C | C2C lean BP general data only; roles/banks/product from MD |
| DEX vs `I_*` | DEX = BP key + plant identity; `Customer`/`Supplier` = rich classic masters |
| Customer DEX | `Plant`; `CustomerTradingPartnerId` as `TradingPartner` |
| Supplier DEX | `SupplierPlant`; company `TradingPartner` on `I_Supplier` via `_Supplier` |
| Product | Phase 1 field subset on `I_Product`; trim if activation fails |

---

## Source types

On the selection screen, **Source type** chooses what to discover:

| Option | What is listed |
|--------|----------------|
| **DEX** | Extraction-enabled views from `IXTRCTNENBLDVW`. Default: **`IsSAPReleasedView` only**. Check **Include non-released DEX** to list all catalog rows (ALV column **SAP released**). |
| **API CDS** | CDS DDL sources (`TADIR` object `DDLS`) whose names match the API pattern (default `I_*API*`, e.g. `I_PurchaseOrderAPI01`) |
| **Both** | Union of the two (DEX wins if the same entity appears in both) |

**Not listed:** OData service bindings such as `API_PURCHASEORDER_2` - those are not `DDLS`
objects, and names matching `API_*` are skipped as an extra guard. Views that exist only in
`DDDDLSRC` (never registered in `IXTRCTNENBLDVW`) still need OpenSQL / typed OData / a later
annotation-scan enhancement — the non-released checkbox does not invent catalog rows.

Empty **API CDS** selection defaults to pattern `I_*API*`. Use select-options to pick
single entities, multiple values, or `*` wildcards (option CP). Entity select-options are
**case-sensitive** (`LOWER CASE` - no automatic uppercase); enter the CDS name in the same
case as in the system (TADIR / API names are usually uppercase).

File extract (`SELECT *`) works for **both** DEX and API CDS. A view is **delta-capable** when a
change-timestamp field **or** a `CREATIONDATE`+`CREATIONTIME` pair can be resolved (see below)
and can then be run in delta / bounded mode.

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
4. Pair **`CREATIONDATE` + `CREATIONTIME`** (token `CREATIONDATE|CREATIONTIME`) when no
   timestamp field exists — e.g. `I_GoodsMovementDocumentDEX`. **Not used for master-data**
   CDS (`@ObjectModel.usageType.dataClass: #MASTER`)
5. Field **`DOCUMENTDATE`** (date-only watermark) when no timestamp / creation pair exists —
   **also not used for master-data** CDS

If found, the view is **delta-capable**. The display list shows the field (or pair token) in
column **Delta field** and marks **Delta capable**; otherwise those columns stay empty.
Delta on a date+time pair uses
`CREATIONDATE > d OR (CREATIONDATE = d AND CREATIONTIME > t)` (and `>=` / `<=` for Bounded).
Delta on `DOCUMENTDATE` uses `DOCUMENTDATE > YYYYMMDD` (day granularity).

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
- ⚠️ **Needs a change-timestamp or CREATIONDATE+CREATIONTIME.** Views with neither are **full-only**
  (Delta is skipped with a reason; Bounded falls back to a full extract).
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

## Bounded (date/time) extraction

Where a view is **delta-capable** (it has the `@Semantics.systemDateTime.lastChangedAt` field),
**Mode = Bounded** extracts rows whose change-timestamp falls in an explicit **date/time window**
instead of "since the last run":

- `SELECT * … WHERE <ts field> >= <from> [AND <ts field> <= <to>]`.
- Enter **From** / **To** as date + time on the selection screen, in **UTC** (to match the UTC
  change-timestamp stored by CDS). A blank **To time** means end-of-day (inclusive); a blank
  **To date** means open-ended (`>= from`); a blank **From** means open-ended (`<= to`). At least
  one of From / To is required when **Action = Extract to file** (the window is ignored and
  input-disabled for **Display list**).
- Views **without** a change-timestamp field are **not skipped**: Bounded falls back to a **full** extract (result mode / file tag `full`; message notes the fallback). Delta mode still skips those views (`K`).
- A bounded run is **ad-hoc**: it does **not** read or advance the `ZEVO_DELTA` high-water, so it
  never disturbs the delta baseline. (Full and Delta still advance the marker.)
- Same caveats as Delta: **no deletes** (timestamp filter sees inserts/updates only), and the
  timestamp field's data type governs the `WHERE` literal format.

## Objects

| Object | Type | Purpose |
|--------|------|---------|
| `ZEVO_CDS_EXPLORER_2_FILE` | report | selection screen + `CL_SALV_TABLE` grid + extract/download |
| `ZEVO_CL_CATALOG` | class | discover DEX (`IXTRCTNENBLDVW`) and/or API CDS (`TADIR`/`DDLS`) + resolve delta field (annotation or `LastChangeDateTime`) + map `DDLNAME` / `DBTABNAME` via `DDLDEPENDENCY` |
| `ZEVO_CL_EXTRACTOR` | class | dynamic `SELECT * FROM (entity)` - full, delta `WHERE ts > last`, or bounded `WHERE ts >= from [AND ts <= to]`; `extract_ex` adds filter + Skip/Top |
| `ZEVO_CL_FILE_WRITER` | class | serialize the table → delimited text → `gui_download` / `OPEN DATASET` |
| `ZEVO_CL_DELTA_STORE` | class | read/update the last-run high-water per view |
| `ZEVO_DELTA` | table | delta high-water per view (`VIEWNAME` → `LAST_TS`) — **file report only** |
| `ZEVO_CL_FILTER_PARSER` | class | OData `$filter` → OpenSQL `WHERE` |
| `ZEVO_CL_SERIALIZER` | class | CDS extract / metadata → JSON or XML envelope |
| `ZEVO_CL_CDS_META` | class | per-entity fields, keys, DDL/DBTAB, delta field |
| `ZEVO_CL_ODATA_API` | class | facade for `ExtractCds` / `GetCdsMetadata` |
| `ZEVO_CL_ODATA_MPC` | class | SEGW helper: `DEFINE_MODEL` (no Gateway inheritance) |
| `ZEVO_CL_ODATA_DPC` | class | SEGW helper: `EXECUTE_ACTION` (no Gateway inheritance) |
| `ZEVO_C_*` (12) | CDS view (`define view`) | C2P document projections + lean BP with associations |
| `ZEVO_C2P` | service definition | exposes the 12 C2P entity sets |
| `ZEVO_C2P` | service binding | create + publish in ADT (OData V4 Web API; not in abapGit) |
| `ZEVO_O_*` (9) | CDS view (`define view`) | C2C sales document projections + lean BP |
| `ZEVO_C2C` | service definition | exposes the 9 C2C entity sets |
| `ZEVO_C2C` | service binding | create + publish in ADT (OData V4 Web API; not in abapGit) |
| `ZEVO_FI_*` | CDS view (`define view`) | General Ledger line + FI org masters |
| `ZEVO_GENERALLEDGER` | service definition | exposes GL line item + FI masters |
| `ZEVO_GENERALLEDGER` | service binding | create + publish in ADT (OData V4 Web API; not in abapGit) |
| `ZEVO_M_*` | CDS view (`define view`) | Cross-scenario masters (BP, DEX roles, Customer/Supplier, bank, product) |
| `ZEVO_MD` | service definition | exposes master-data entity sets |
| `ZEVO_MD` | service binding | create + publish in ADT (OData V4 Web API; not in abapGit) |

Full OData documentation: see **[OData CDS extract service](#odata-cds-extract-service)** above (also [`docs/ZEVO_ODATA_EXTRACT.md`](docs/ZEVO_ODATA_EXTRACT.md)).  
OData V4 C2P: **[section above](#odata-v4-c2p-service-zevo_c2p)** · [`docs/ZEVO_C2P.md`](docs/ZEVO_C2P.md).  
OData V4 C2C: **[section above](#odata-v4-contract-to-cash-zevo_c2c)** · [`docs/ZEVO_C2C.md`](docs/ZEVO_C2C.md).  
OData V4 General Ledger: **[section above](#odata-v4-general-ledger-zevo_generalledger)** · [`docs/ZEVO_GENERALLEDGER.md`](docs/ZEVO_GENERALLEDGER.md).  
OData V4 Master Data: **[section above](#odata-v4-master-data-zevo_md)** · [`docs/ZEVO_MD.md`](docs/ZEVO_MD.md).

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
| **Mode** | *Full load* / *Delta (change timestamp)* / *Bounded (date/time range)* |
| **Date/time window** | *From* / *To* date + time for **Bounded** mode (UTC). Required (and input-enabled) only when **Action = Extract to file** and **Mode = Bounded**; ignored for Display list. Dates are `sy-datum` (native calendar, user date format — not `YYYYMMDD`). |
| **Target** | *Local frontend (download)* / *Application server (AL11)* — **background jobs require AL11 or logical file** |
| **Format** | *CSV* / *Tab (.txt)* / *Excel (tab, .xls)* |
| **CSV delimiter** | separator for CSV (default `;`) |
| **Folder / server dir** | frontend folder (e.g. `C:\temp\`) or an app-server path (e.g. `/tmp/`) |
| **Logical file name** | a logical file name from transaction **`FILE`**; when set, it resolves the path via `FILE_GET_NAME` (server) and **overrides** the folder |
| **Max rows** | cap per view (`0` = unlimited) - guard for frontend download limits |

Filled filters are combined with **AND** (empty = ignore that dimension). `*` / `+` wildcards are supported.

- **Display** → grid of views: entity, **DDLNAME**, **DBTABNAME**, description, **source (DEX/API)**, data class, CDC flag,
  **Delta field** (timestamp or `CREATIONDATE|CREATIONTIME`), **Delta capable**,
  **Last changed on/at** (from `VRSD` version directory — useful to compare `A_*` vs `A_*_2`),
  last delta position. (ALV **Export** is enabled via `set_all`.)
- **Extract** → per view: extract (full/delta) → download `<entity>_<full|delta>_<date>_<time>.<ext>`
  → advance the delta marker (only after a successful download) → **results grid** (entity, mode,
  rows, file, status, message). Delta requested but no timestamp / creation pair → skipped (`K`).

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

## Development environment (abaplint)

ABAP runs on an SAP system, so the code can't execute on a plain workstation/CI runner.
For local development and CI this repo uses [**abaplint**](https://abaplint.org) — a
Node.js static analyzer that **parses** and **syntax-checks** the ABAP source (and applies
code-quality rules) **without** a SAP system.

### Prerequisites
- **Node.js** ≥ 18 (includes `npm`).

### Install & run
```bash
npm install          # installs abaplint (dev dependency, pinned in package.json)
npm run lint         # parse + syntax-check + rules over src/**  (exit 0 = clean)
npm run lint:summary # same, condensed summary output
npm run lint:json    # machine-readable JSON (for CI)
```

`npm install` writes to `node_modules/` (git-ignored); `package.json`, `package-lock.json`
and `abaplint.json` are tracked but listed in `.abapgit.xml` `IGNORE`, so abapGit never tries
to serialize them as ABAP objects.

### Configuration (`abaplint.json`)
- **Target release:** `v757` (S/4HANA on-premise), `language: Normal`.
- 150 rules stay active — including `parser_error` and `check_syntax`, which resolve the repo's
  own objects (`ZEVO_CDS_EXPLORER_2_FILE`, `ZEVO_CL_*`, `ZEVO_DELTA`). Standard SAP artifacts
  (`cl_salv_table`, `IXTRCTNENBLDVW`, `DDFIELDANNO`, …) are treated as *voids*, so no SAP
  library is required.
- 41 rules are **deliberately disabled** because they conflict with this project's design or
  conventions, e.g. `select_performance`/`select_add_order_by`/`dangerous_statement`/
  `no_dynamic_stuff` (dynamic `SELECT *` is the whole point), `no_prefixes`/`local_variable_names`/
  `types_naming`/`method_parameter_names` (the codebase's naming conventions), `xml_bom` (abapGit
  writes no BOM), plus subjective formatting/complexity rules (`align_type_expressions`, `use_new`,
  `nesting`, …) and SQL-style rules the extractors use deliberately (`sql_escape_host_variables`,
  `strict_sql`, `db_operation_in_loop`). See the `false` entries in `abaplint.json` for the full list.

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
3. `ZEVO_CL_CATALOG` then `ZEVO_CDS_EXPLORER_2_FILE`. The report calls `GET_VIEWS` dynamically so it still activates if the class is one pull behind; activate the class for **Include non-released DEX** to take effect.
4. For **OData V2** (`ExtractCds`): register/activate per **[OData CDS extract service](#odata-cds-extract-service)** above.
5. For **OData V4 C2P**: activate all `ZEVO_C_*` DDLS + service definition `ZEVO_C2P`, then create/publish the binding in **Eclipse ADT** per **[OData V4 C2P service](#odata-v4-c2p-service-zevo_c2p)** above.
6. For **OData V4 C2C**: activate all `ZEVO_O_*` DDLS + service definition `ZEVO_C2C`, then create/publish binding **`ZEVO_C2C`** (OData V4 Web API) per **[OData V4 Contract-to-Cash](#odata-v4-contract-to-cash-zevo_c2c)** above. If SRVD is missing (`SRVDSRV ZEVO_C2C does not exist`), create the definition in ADT from `src/zevo_c2c.srvd.srvdsrv`.
7. For **OData V4 General Ledger**: activate all `ZEVO_FI_*` DDLS + service definition `ZEVO_GENERALLEDGER`, then create/publish binding **`ZEVO_GENERALLEDGER`** (OData V4 Web API) per **[OData V4 General Ledger](#odata-v4-general-ledger-zevo_generalledger)** above.
8. For **OData V4 Master Data**: activate all `ZEVO_M_*` DDLS + service definition `ZEVO_MD`, then create/publish binding **`ZEVO_MD`** (OData V4 Web API) per **[OData V4 Master Data](#odata-v4-master-data-zevo_md)** above.

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
