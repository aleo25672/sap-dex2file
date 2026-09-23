" OData model provider helpers: function imports ExtractCds + GetCdsMetadata,
" entity type CdsResult (Payload string).
" No inheritance from /IWBEP/* so the class activates even before SEGW wiring.
" Call DEFINE_MODEL from your SEGW MPC_EXT=>DEFINE (pass the MODEL attribute).
CLASS zevo_cl_odata_mpc DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    " ABAP field names avoid reserved words FILTER / FORMAT.
    TYPES:
      BEGIN OF ts_extract_param,
        entityname  TYPE c LENGTH 40,
        filter_expr TYPE c LENGTH 5000,
        format_cd   TYPE c LENGTH 10,
        deltasince  TYPE c LENGTH 30,
        skip_rows   TYPE c LENGTH 10,
        top_rows    TYPE c LENGTH 10,
      END OF ts_extract_param.
    TYPES:
      BEGIN OF ts_meta_param,
        entityname TYPE c LENGTH 40,
        format_cd  TYPE c LENGTH 10,
      END OF ts_meta_param.
    TYPES:
      BEGIN OF ts_result,
        payload TYPE string,
      END OF ts_result.

    CLASS-METHODS define_model
      IMPORTING
        io_model TYPE REF TO /iwbep/if_mgw_odata_model.
ENDCLASS.


CLASS zevo_cl_odata_mpc IMPLEMENTATION.

  METHOD define_model.
    DATA lo_entity_type TYPE REF TO /iwbep/if_mgw_odata_entity_typ.
    DATA lo_property    TYPE REF TO /iwbep/if_mgw_odata_property.
    DATA lo_action      TYPE REF TO /iwbep/if_mgw_odata_action.
    DATA lo_parameter   TYPE REF TO /iwbep/if_mgw_odata_parameter.

    io_model->set_schema_namespace( 'ZEVO_CDS_EXTRACT_SRV' ).

    lo_entity_type = io_model->create_entity_type(
      iv_entity_type_name = 'CdsResult'
      iv_def_entity_set   = abap_true ).

    lo_property = lo_entity_type->create_property(
      iv_property_name  = 'Payload'
      iv_abap_fieldname = 'PAYLOAD' ).
    lo_property->set_is_key( abap_true ).
    lo_property->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_property->set_maxlength( 1000000 ).
    lo_property->set_nullable( abap_false ).
    lo_entity_type->bind_structure( iv_structure_name = 'ZEVO_CL_ODATA_MPC=>TS_RESULT' ).

    " --- ExtractCds ---
    lo_action = io_model->create_action( iv_action_name = 'ExtractCds' ).
    lo_action->set_http_method( 'GET' ).
    lo_action->set_return_entity_type( 'CdsResult' ).
    lo_action->set_return_multiplicity( '1' ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'EntityName'
      iv_abap_fieldname = 'ENTITYNAME' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( 40 ).
    lo_parameter->set_nullable( abap_false ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'Filter'
      iv_abap_fieldname = 'FILTER_EXPR' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( 5000 ).
    lo_parameter->set_nullable( abap_true ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'Format'
      iv_abap_fieldname = 'FORMAT_CD' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( 10 ).
    lo_parameter->set_nullable( abap_true ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'DeltaSince'
      iv_abap_fieldname = 'DELTASINCE' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( 30 ).
    lo_parameter->set_nullable( abap_true ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'Skip'
      iv_abap_fieldname = 'SKIP_ROWS' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( 10 ).
    lo_parameter->set_nullable( abap_true ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'Top'
      iv_abap_fieldname = 'TOP_ROWS' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( 10 ).
    lo_parameter->set_nullable( abap_true ).

    lo_action->bind_input_structure( iv_structure_name = 'ZEVO_CL_ODATA_MPC=>TS_EXTRACT_PARAM' ).

    " --- GetCdsMetadata ---
    lo_action = io_model->create_action( iv_action_name = 'GetCdsMetadata' ).
    lo_action->set_http_method( 'GET' ).
    lo_action->set_return_entity_type( 'CdsResult' ).
    lo_action->set_return_multiplicity( '1' ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'EntityName'
      iv_abap_fieldname = 'ENTITYNAME' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( 40 ).
    lo_parameter->set_nullable( abap_false ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'Format'
      iv_abap_fieldname = 'FORMAT_CD' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( 10 ).
    lo_parameter->set_nullable( abap_true ).

    lo_action->bind_input_structure( iv_structure_name = 'ZEVO_CL_ODATA_MPC=>TS_META_PARAM' ).
  ENDMETHOD.

ENDCLASS.
