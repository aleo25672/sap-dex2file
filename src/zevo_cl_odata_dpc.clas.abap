" OData action helper for ExtractCds / GetCdsMetadata.
" No inheritance from /IWBEP/* — call EXECUTE_ACTION from your SEGW DPC_EXT.
CLASS zevo_cl_odata_dpc DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS execute_action
      IMPORTING
        iv_action_name TYPE clike
        it_parameter   TYPE /iwbep/t_mgw_name_value_pair
      EXPORTING
        es_result      TYPE zevo_cl_odata_mpc=>ts_result
        ev_ok          TYPE abap_bool
        ev_message     TYPE string.

  PRIVATE SECTION.
    CLASS-METHODS read_param
      IMPORTING
        it_parameter TYPE /iwbep/t_mgw_name_value_pair
        iv_name      TYPE clike
      RETURNING
        VALUE(rv_value) TYPE string.
ENDCLASS.


CLASS zevo_cl_odata_dpc IMPLEMENTATION.

  METHOD execute_action.
    DATA lv_action TYPE string.
    DATA ls_resp   TYPE zevo_cl_odata_api=>ty_response.
    DATA lv_entity TYPE string.
    DATA lv_filter TYPE string.
    DATA lv_format TYPE string.
    DATA lv_delta  TYPE string.
    DATA lv_skip_s TYPE string.
    DATA lv_top_s  TYPE string.
    DATA lv_skip   TYPE i.
    DATA lv_top    TYPE i.
    DATA lv_ts     TYPE timestampl.

    CLEAR es_result.
    ev_ok = abap_false.
    CLEAR ev_message.

    lv_action = iv_action_name.
    lv_action = to_upper( lv_action ).

    CASE lv_action.
      WHEN 'EXTRACTCDS'.
        lv_entity = read_param( it_parameter = it_parameter iv_name = 'EntityName' ).
        lv_filter = read_param( it_parameter = it_parameter iv_name = 'Filter' ).
        IF lv_filter IS INITIAL.
          lv_filter = read_param( it_parameter = it_parameter iv_name = 'Filter_Expr' ).
        ENDIF.
        lv_format = read_param( it_parameter = it_parameter iv_name = 'Format' ).
        IF lv_format IS INITIAL.
          lv_format = read_param( it_parameter = it_parameter iv_name = 'Format_Cd' ).
        ENDIF.
        lv_delta  = read_param( it_parameter = it_parameter iv_name = 'DeltaSince' ).
        lv_skip_s = read_param( it_parameter = it_parameter iv_name = 'Skip' ).
        IF lv_skip_s IS INITIAL.
          lv_skip_s = read_param( it_parameter = it_parameter iv_name = 'Skip_Rows' ).
        ENDIF.
        lv_top_s = read_param( it_parameter = it_parameter iv_name = 'Top' ).
        IF lv_top_s IS INITIAL.
          lv_top_s = read_param( it_parameter = it_parameter iv_name = 'Top_Rows' ).
        ENDIF.

        IF lv_skip_s IS NOT INITIAL.
          lv_skip = lv_skip_s.
        ENDIF.
        IF lv_top_s IS NOT INITIAL.
          lv_top = lv_top_s.
        ELSE.
          lv_top = 1000.
        ENDIF.

        ls_resp = zevo_cl_odata_api=>extract_cds(
          iv_entity_name = lv_entity
          iv_filter      = lv_filter
          iv_format      = lv_format
          iv_delta_since = lv_delta
          iv_skip        = lv_skip
          iv_top         = lv_top ).

      WHEN 'GETCDSMETADATA'.
        lv_entity = read_param( it_parameter = it_parameter iv_name = 'EntityName' ).
        lv_format = read_param( it_parameter = it_parameter iv_name = 'Format' ).
        IF lv_format IS INITIAL.
          lv_format = read_param( it_parameter = it_parameter iv_name = 'Format_Cd' ).
        ENDIF.
        ls_resp = zevo_cl_odata_api=>get_cds_metadata(
          iv_entity_name = lv_entity
          iv_format      = lv_format ).

      WHEN OTHERS.
        ev_message = |Unknown function import '{ iv_action_name }'|.
        RETURN.
    ENDCASE.

    IF ls_resp-status <> 'S'.
      ev_message = ls_resp-message.
      RETURN.
    ENDIF.

    " Surrogate key for CdsResult — keeps Gateway __metadata.id/uri short.
    TRY.
        es_result-id = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        " Fallback if UUID service unavailable: compact timestamp.
        GET TIME STAMP FIELD lv_ts.
        es_result-id = |{ lv_ts }|.
        CONDENSE es_result-id NO-GAPS.
    ENDTRY.
    es_result-payload = ls_resp-payload.
    ev_ok = abap_true.
    ev_message = ls_resp-message.
  ENDMETHOD.

  METHOD read_param.
    DATA lv_name TYPE string.
    DATA lv_pnam TYPE string.
    FIELD-SYMBOLS <ls_p> TYPE any.
    FIELD-SYMBOLS <name> TYPE any.
    FIELD-SYMBOLS <value> TYPE any.

    lv_name = iv_name.
    lv_name = to_upper( lv_name ).
    LOOP AT it_parameter ASSIGNING <ls_p>.
      ASSIGN COMPONENT 'NAME' OF STRUCTURE <ls_p> TO <name>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      lv_pnam = <name>.
      lv_pnam = to_upper( lv_pnam ).
      IF lv_pnam = lv_name.
        ASSIGN COMPONENT 'VALUE' OF STRUCTURE <ls_p> TO <value>.
        IF sy-subrc = 0.
          rv_value = <value>.
        ENDIF.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
