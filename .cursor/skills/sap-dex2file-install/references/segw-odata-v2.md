# SEGW OData V2 — `ZEVO_CDS_EXTRACT` snippets

Use after helpers `ZEVO_CL_ODATA_*` are active. Keep generated `ZCL_ZEVO_CDS_EXTRACT_*` **out of Git** unless you intentionally version SEGW artifacts.

## Create project

| Field | Value |
|-------|--------|
| Project | `ZEVO_CDS_EXTRACT` |
| Project Type | **Service with SAP Annotations** |
| Generation Strategy | **Standard** |
| Package | same as `ZEVO_CL_*` (e.g. `$EVOLVER_DEX2F`) |

Generate Runtime Objects. Do **not** hand-create Entity Types / Function Imports in the SEGW tree.

## MPC_EXT → `DEFINE`

Class: **`ZCL_ZEVO_CDS_EXTRACT_MPC_EXT`** (not base `…_MPC`).

```abap
METHOD define.
  " Model is code-defined only. Do NOT call super->define( ) here:
  " SEGW tree leftovers / empty project DEFINE can leave ExtractCds missing.
  zevo_cl_odata_mpc=>define_model( model ).
ENDMETHOD.
```

Activate. After every **Generate Runtime Objects**, re-paste if wiped.

## DPC_EXT → redefine `EXECUTE_ACTION`

1. SE24 → **`ZCL_ZEVO_CDS_EXTRACT_DPC_EXT`** → Change.
2. Methods → `/IWBEP/IF_MGW_APPL_SRV_RUNTIME~EXECUTE_ACTION`.
3. Toolbar **Redefine Method** (document+pencil) — do **not** open `/IWBEP/CL_MGW_ABS_DATA`.
4. Paste:

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

  copy_data_to_ref(
    EXPORTING
      is_data = ls_result
    CHANGING
      cr_data = er_data ).

ENDMETHOD.
```

Activate **EXT only**. Do not use Enhance.

## Register

`/IWFND/MAINT_SERVICE` → Add **`ZEVO_CDS_EXTRACT_SRV`**:

- System alias: LOCAL / your GW alias
- **ICF Node = SAP Gateway OData V2** (not None)
- Model provider must be **`ZCL_ZEVO_CDS_EXTRACT_MPC_EXT`**

## Verify

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/$metadata
```

Must contain `FunctionImport` **`ExtractCds`** (and `GetCdsMetadata`). If missing: EXT wiped, SEGW tree conflict, or cache — `/IWFND/CACHE_CLEANUP`, then re-activate MPC_EXT.

Example extract:

```http
GET /sap/opu/odata/sap/ZEVO_CDS_EXTRACT_SRV/ExtractCds?EntityName='C_PurchaseOrderDEX'&Format='json'&Top=10
```
