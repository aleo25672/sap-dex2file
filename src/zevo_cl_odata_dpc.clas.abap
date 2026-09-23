" OData data provider: executes ExtractCds and GetCdsMetadata via ZEVO_CL_ODATA_API.
CLASS zevo_cl_odata_dpc DEFINITION
  PUBLIC
  INHERITING FROM /iwbep/cl_mgw_push_abs_data
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS /iwbep/if_mgw_appl_srv_runtime~execute_action REDEFINITION.

  PRIVATE SECTION.
    METHODS read_param
      IMPORTING
        it_parameter TYPE /iwbep/t_mgw_name_value_pair
        iv_name      TYPE clike
      RETURNING
        VALUE(rv_value) TYPE string.
    METHODS raise_busi
      IMPORTING
        iv_message TYPE clike
      RAISING
        /iwbep/cx_mgw_busi_exception.
ENDCLASS.


CLASS zevo_cl_odata_dpc IMPLEMENTATION.

  METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.
    DATA(lv_action) = io_tech_request_context->get_function_import_name( ).
    DATA(lt_parameter) = io_tech_request_context->get_parameters( ).

    DATA ls_result TYPE zevo_cl_odata_mpc=>ts_result.
    DATA ls_resp   TYPE zevo_cl_odata_api=>ty_response.

    CASE to_upper( lv_action ).
      WHEN 'EXTRACTCDS'.
        DATA(lv_entity) = read_param( it_parameter = lt_parameter iv_name = 'EntityName' ).
        DATA(lv_filter) = read_param( it_parameter = lt_parameter iv_name = 'Filter' ).
        DATA(lv_format) = read_param( it_parameter = lt_parameter iv_name = 'Format' ).
        DATA(lv_delta)  = read_param( it_parameter = lt_parameter iv_name = 'DeltaSince' ).
        DATA(lv_skip_s) = read_param( it_parameter = lt_parameter iv_name = 'Skip' ).
        DATA(lv_top_s)  = read_param( it_parameter = lt_parameter iv_name = 'Top' ).

        DATA lv_skip TYPE i.
        DATA lv_top  TYPE i.
        IF lv_skip_s IS NOT INITIAL.
          lv_skip = lv_skip_s.
        ENDIF.
        IF lv_top_s IS NOT INITIAL.
          lv_top = lv_top_s.
        ELSE.
          lv_top = zevo_cl_extractor=>c_default_top.
        ENDIF.

        ls_resp = zevo_cl_odata_api=>extract_cds(
          iv_entity_name = lv_entity
          iv_filter      = lv_filter
          iv_format      = lv_format
          iv_delta_since = lv_delta
          iv_skip        = lv_skip
          iv_top         = lv_top ).

      WHEN 'GETCDSMETADATA'.
        lv_entity = read_param( it_parameter = lt_parameter iv_name = 'EntityName' ).
        lv_format = read_param( it_parameter = lt_parameter iv_name = 'Format' ).
        ls_resp = zevo_cl_odata_api=>get_cds_metadata(
          iv_entity_name = lv_entity
          iv_format      = lv_format ).

      WHEN OTHERS.
        super->/iwbep/if_mgw_appl_srv_runtime~execute_action(
          EXPORTING
            iv_action_name          = iv_action_name
            it_parameter            = it_parameter
            io_tech_request_context = io_tech_request_context
          IMPORTING
            er_data                 = er_data ).
        RETURN.
    ENDCASE.

    IF ls_resp-status <> 'S'.
      raise_busi( ls_resp-message ).
    ENDIF.

    ls_result-payload = ls_resp-payload.
    copy_data_to_ref(
      EXPORTING is_data = ls_result
      CHANGING  cr_data = er_data ).
  ENDMETHOD.

  METHOD read_param.
    DATA(lv_name) = to_upper( CONV string( iv_name ) ).
    LOOP AT it_parameter INTO DATA(ls_p).
      IF to_upper( CONV string( ls_p-name ) ) = lv_name.
        rv_value = ls_p-value.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD raise_busi.
    DATA(lo_msg) = mo_context->get_message_container( ).
    lo_msg->add_message_text_only(
      iv_msg_type = 'E'
      iv_msg_text = CONV bapi_msg( iv_message ) ).
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING
        message_container = lo_msg.
  ENDMETHOD.

ENDCLASS.
