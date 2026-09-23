" Facade for OData function imports ExtractCds and GetCdsMetadata.
" Gateway DPC / ZEVO_CL_ODATA_DPC delegates here.
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
        iv_top         TYPE i DEFAULT 1000
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
    DATA lv_entity TYPE string.
    DATA lv_format TYPE string.
    DATA lt_fields TYPE zevo_cl_filter_parser=>ty_fields.
    DATA lo_parser TYPE REF TO zevo_cl_filter_parser.
    DATA ls_parse  TYPE zevo_cl_filter_parser=>ty_result.
    DATA lv_where  TYPE string.
    DATA lv_delta  TYPE abap_bool.
    DATA lv_ts     TYPE string.
    DATA lv_last   TYPE timestampl.
    DATA lv_since  TYPE string.
    DATA lo_extr   TYPE REF TO zevo_cl_extractor.
    DATA ls_ex     TYPE zevo_cl_extractor=>ty_result_ex.
    DATA lv_top    TYPE i.

    CLEAR rs_resp.
    lv_entity = iv_entity_name.
    CONDENSE lv_entity.
    IF lv_entity IS INITIAL.
      rs_resp-status  = 'E'.
      rs_resp-message = 'EntityName is required'.
      RETURN.
    ENDIF.

    lv_format = iv_format.
    CONDENSE lv_format.
    lv_format = to_lower( lv_format ).
    IF lv_format IS INITIAL.
      lv_format = 'json'.
    ENDIF.
    IF lv_format <> 'json' AND lv_format <> 'xml'.
      rs_resp-status  = 'E'.
      rs_resp-message = |Format must be json or xml, got '{ lv_format }'|.
      RETURN.
    ENDIF.

    lt_fields = zevo_cl_cds_meta=>get_field_names( lv_entity ).
    IF lt_fields IS INITIAL.
      rs_resp-status  = 'E'.
      rs_resp-message = |CDS entity '{ lv_entity }' not found or not selectable|.
      RETURN.
    ENDIF.

    CLEAR lv_where.
    IF iv_filter IS NOT INITIAL.
      CREATE OBJECT lo_parser.
      ls_parse = lo_parser->parse(
        iv_filter  = iv_filter
        it_allowed = lt_fields ).
      IF ls_parse-status <> 'S'.
        rs_resp-status  = 'E'.
        rs_resp-message = ls_parse-message.
        RETURN.
      ENDIF.
      lv_where = ls_parse-where_sql.
    ENDIF.

    lv_delta = abap_false.
    CLEAR lv_ts.
    CLEAR lv_last.
    IF iv_delta_since IS NOT INITIAL.
      lv_delta = abap_true.
      lv_ts = zevo_cl_cds_meta=>get_delta_field( lv_entity ).
      IF lv_ts IS INITIAL.
        rs_resp-status  = 'K'.
        rs_resp-message = |Delta requested but no change-timestamp field on '{ lv_entity }'|.
        RETURN.
      ENDIF.
      lv_since = iv_delta_since.
      CONDENSE lv_since.
      REPLACE ALL OCCURRENCES OF `-` IN lv_since WITH ``.
      REPLACE ALL OCCURRENCES OF `:` IN lv_since WITH ``.
      REPLACE ALL OCCURRENCES OF `T` IN lv_since WITH ``.
      REPLACE ALL OCCURRENCES OF `Z` IN lv_since WITH ``.
      REPLACE ALL OCCURRENCES OF `.` IN lv_since WITH ``.
      REPLACE ALL OCCURRENCES OF ` ` IN lv_since WITH ``.
      TRY.
          lv_last = lv_since.
        CATCH cx_sy_conversion_no_number
              cx_sy_conversion_overflow
              cx_root.
          rs_resp-status  = 'E'.
          rs_resp-message = |Invalid DeltaSince value '{ iv_delta_since }'|.
          RETURN.
      ENDTRY.
    ENDIF.

    lv_top = iv_top.
    IF lv_top <= 0.
      lv_top = 1000.
    ENDIF.

    CREATE OBJECT lo_extr.
    ls_ex = lo_extr->extract_ex(
      iv_entity   = lv_entity
      iv_where    = lv_where
      iv_delta    = lv_delta
      iv_ts_field = lv_ts
      iv_last     = lv_last
      iv_skip     = iv_skip
      iv_top      = lv_top ).

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
    DATA lv_format TYPE string.
    DATA lo_meta   TYPE REF TO zevo_cl_cds_meta.
    DATA ls_meta   TYPE zevo_cl_cds_meta=>ty_meta.

    CLEAR rs_resp.
    lv_format = iv_format.
    CONDENSE lv_format.
    lv_format = to_lower( lv_format ).
    IF lv_format IS INITIAL.
      lv_format = 'json'.
    ENDIF.
    IF lv_format <> 'json' AND lv_format <> 'xml'.
      rs_resp-status  = 'E'.
      rs_resp-message = |Format must be json or xml, got '{ lv_format }'|.
      RETURN.
    ENDIF.

    CREATE OBJECT lo_meta.
    ls_meta = lo_meta->get_metadata( iv_entity_name ).
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
