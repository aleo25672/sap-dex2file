" Facade for OData function imports ExtractCds and GetCdsMetadata.
" Gateway DPC delegates here; keeps SEGW/DPC thin and testable in ABAP.
CLASS zevo_cl_odata_api DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_response,
        payload TYPE string,
        status  TYPE c LENGTH 1,  " S ok | E error | K skipped
        message TYPE string,
      END OF ty_response.

    CLASS-METHODS extract_cds
      IMPORTING
        iv_entity_name TYPE clike
        iv_filter      TYPE clike OPTIONAL
        iv_format      TYPE clike OPTIONAL
        iv_delta_since TYPE clike OPTIONAL
        iv_skip        TYPE i DEFAULT 0
        iv_top         TYPE i DEFAULT zevo_cl_extractor=>c_default_top
      RETURNING
        VALUE(rs_resp) TYPE ty_response.

    CLASS-METHODS get_cds_metadata
      IMPORTING
        iv_entity_name TYPE clike
        iv_format      TYPE clike OPTIONAL
      RETURNING
        VALUE(rs_resp) TYPE ty_response.
ENDCLASS.


CLASS zevo_cl_odata_api IMPLEMENTATION.

  METHOD extract_cds.
    CLEAR rs_resp.
    DATA(lv_entity) = condense( CONV string( iv_entity_name ) ).
    IF lv_entity IS INITIAL.
      rs_resp-status  = 'E'.
      rs_resp-message = 'EntityName is required'.
      RETURN.
    ENDIF.

    DATA(lv_format) = to_lower( condense( CONV string( iv_format ) ) ).
    IF lv_format IS INITIAL.
      lv_format = 'json'.
    ENDIF.
    IF lv_format <> 'json' AND lv_format <> 'xml'.
      rs_resp-status  = 'E'.
      rs_resp-message = |Format must be json or xml, got '{ lv_format }'|.
      RETURN.
    ENDIF.

    DATA(lt_fields) = zevo_cl_cds_meta=>get_field_names( lv_entity ).
    IF lt_fields IS INITIAL.
      rs_resp-status  = 'E'.
      rs_resp-message = |CDS entity '{ lv_entity }' not found or not selectable|.
      RETURN.
    ENDIF.

    DATA(lv_where) = ``.
    IF iv_filter IS NOT INITIAL.
      DATA(ls_parse) = NEW zevo_cl_filter_parser( )->parse(
        iv_filter  = iv_filter
        it_allowed = lt_fields ).
      IF ls_parse-status <> 'S'.
        rs_resp-status  = 'E'.
        rs_resp-message = ls_parse-message.
        RETURN.
      ENDIF.
      lv_where = ls_parse-where_sql.
    ENDIF.

    DATA(lv_delta) = abap_false.
    DATA(lv_ts) = ``.
    DATA lv_last TYPE timestampl.
    IF iv_delta_since IS NOT INITIAL.
      lv_delta = abap_true.
      lv_ts = zevo_cl_cds_meta=>get_delta_field( lv_entity ).
      IF lv_ts IS INITIAL.
        rs_resp-status  = 'K'.
        rs_resp-message = |Delta requested but no change-timestamp field on '{ lv_entity }'|.
        RETURN.
      ENDIF.
      DATA(lv_since) = condense( CONV string( iv_delta_since ) ).
      " Accept compact timestampl / ISO-ish digits
      REPLACE ALL OCCURRENCES OF `-` IN lv_since WITH ``.
      REPLACE ALL OCCURRENCES OF `:` IN lv_since WITH ``.
      REPLACE ALL OCCURRENCES OF `T` IN lv_since WITH ``.
      REPLACE ALL OCCURRENCES OF `Z` IN lv_since WITH ``.
      REPLACE ALL OCCURRENCES OF `.` IN lv_since WITH ``.
      REPLACE ALL OCCURRENCES OF ` ` IN lv_since WITH ``.
      TRY.
          lv_last = CONV timestampl( lv_since ).
        CATCH cx_root.
          rs_resp-status  = 'E'.
          rs_resp-message = |Invalid DeltaSince value '{ iv_delta_since }'|.
          RETURN.
      ENDTRY.
    ENDIF.

    DATA(ls_ex) = NEW zevo_cl_extractor( )->extract_ex(
      iv_entity   = lv_entity
      iv_where    = lv_where
      iv_delta    = lv_delta
      iv_ts_field = lv_ts
      iv_last     = lv_last
      iv_skip     = iv_skip
      iv_top      = iv_top ).

    IF ls_ex-status <> 'S'.
      rs_resp-status  = ls_ex-status.
      rs_resp-message = ls_ex-message.
      RETURN.
    ENDIF.

    rs_resp-payload = zevo_cl_serializer=>serialize_extract(
      iv_entity         = lv_entity
      iv_format         = lv_format
      ir_data           = ls_ex-data_ref
      iv_row_count      = ls_ex-row_count
      iv_total_count    = ls_ex-total_count
      iv_skip           = ls_ex-skip
      iv_top            = ls_ex-top
      iv_delta_field    = ls_ex-delta_field
      iv_max_changed_at = ls_ex-max_changed_at ).
    rs_resp-status  = 'S'.
    rs_resp-message = ls_ex-message.
  ENDMETHOD.

  METHOD get_cds_metadata.
    CLEAR rs_resp.
    DATA(lv_format) = to_lower( condense( CONV string( iv_format ) ) ).
    IF lv_format IS INITIAL.
      lv_format = 'json'.
    ENDIF.
    IF lv_format <> 'json' AND lv_format <> 'xml'.
      rs_resp-status  = 'E'.
      rs_resp-message = |Format must be json or xml, got '{ lv_format }'|.
      RETURN.
    ENDIF.

    DATA(ls_meta) = NEW zevo_cl_cds_meta( )->get_metadata( iv_entity_name ).
    IF ls_meta-status <> 'S'.
      rs_resp-status  = ls_meta-status.
      rs_resp-message = ls_meta-message.
      RETURN.
    ENDIF.

    rs_resp-payload = zevo_cl_serializer=>serialize_cds_meta(
      iv_entity        = ls_meta-entity
      iv_format        = lv_format
      iv_ddl_name      = ls_meta-ddl_name
      iv_db_tabname    = ls_meta-db_tabname
      iv_delta_field   = ls_meta-delta_field
      iv_delta_capable = ls_meta-delta_capable
      it_key_fields    = ls_meta-key_fields
      it_fields        = ls_meta-fields ).
    rs_resp-status  = 'S'.
    rs_resp-message = ls_meta-message.
  ENDMETHOD.

ENDCLASS.
