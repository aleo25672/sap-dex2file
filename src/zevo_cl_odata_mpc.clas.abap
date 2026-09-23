" OData model provider: function imports ExtractCds + GetCdsMetadata,
" entity type CdsResult (Payload string). Register as code-based model
" (see docs/ZEVO_ODATA_EXTRACT.md) or wire from SEGW MPC_EXT redefine DEFINE.
CLASS zevo_cl_odata_mpc DEFINITION
  PUBLIC
  INHERITING FROM /iwbep/cl_mgw_push_abs_model
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ts_extract_param,
        entityname TYPE c LENGTH 40,
        filter     TYPE string,
        format     TYPE c LENGTH 10,
        deltasince TYPE c LENGTH 30,
        skip       TYPE i,
        top        TYPE i,
      END OF ts_extract_param.
    TYPES:
      BEGIN OF ts_meta_param,
        entityname TYPE c LENGTH 40,
        format     TYPE c LENGTH 10,
      END OF ts_meta_param.
    TYPES:
      BEGIN OF ts_result,
        payload TYPE string,
      END OF ts_result.

    METHODS define REDEFINITION.
ENDCLASS.


CLASS zevo_cl_odata_mpc IMPLEMENTATION.

  METHOD define.
    DATA: lo_entity_type TYPE REF TO /iwbep/if_mgw_odata_entity_typ,
          lo_property    TYPE REF TO /iwbep/if_mgw_odata_property,
          lo_action      TYPE REF TO /iwbep/if_mgw_odata_action,
          lo_parameter   TYPE REF TO /iwbep/if_mgw_odata_parameter.

    model->set_schema_namespace( 'ZEVO_CDS_EXTRACT_SRV' ).
    model->set_soft_state_enabled( abap_true ).

    " --- Entity type returned by both function imports ---
    lo_entity_type = model->create_entity_type(
      iv_entity_type_name = 'CdsResult'
      iv_def_entity_set   = abap_true ).
    lo_entity_type->set_is_abstract( abap_false ).

    lo_property = lo_entity_type->create_property(
      iv_property_name  = 'Payload'
      iv_abap_fieldname = 'PAYLOAD' ).
    lo_property->set_is_key( abap_true ).
    lo_property->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_property->set_maxlength( 5000000 ).
    lo_property->set_nullable( abap_false ).
    lo_entity_type->bind_structure( 'ZEVO_CL_ODATA_MPC=>TS_RESULT' ).

    " --- ExtractCds ---
    lo_action = model->create_action( iv_action_name = 'ExtractCds' ).
    lo_action->set_http_method( 'GET' ).
    lo_action->set_return_entity_type( 'CdsResult' ).
    lo_action->set_return_multiplicity( /iwbep/if_mgw_med_odata_types=>gcs_cardinality-cardinality_1_1 ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'EntityName'
      iv_abap_fieldname = 'ENTITYNAME' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( 40 ).
    lo_parameter->set_nullable( abap_false ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'Filter'
      iv_abap_fieldname = 'FILTER' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( 5000 ).
    lo_parameter->set_nullable( abap_true ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'Format'
      iv_abap_fieldname = 'FORMAT' ).
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
      iv_abap_fieldname = 'SKIP' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_int32( ).
    lo_parameter->set_nullable( abap_true ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'Top'
      iv_abap_fieldname = 'TOP' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_int32( ).
    lo_parameter->set_nullable( abap_true ).

    lo_action->bind_input_structure( 'ZEVO_CL_ODATA_MPC=>TS_EXTRACT_PARAM' ).

    " --- GetCdsMetadata ---
    lo_action = model->create_action( iv_action_name = 'GetCdsMetadata' ).
    lo_action->set_http_method( 'GET' ).
    lo_action->set_return_entity_type( 'CdsResult' ).
    lo_action->set_return_multiplicity( /iwbep/if_mgw_med_odata_types=>gcs_cardinality-cardinality_1_1 ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'EntityName'
      iv_abap_fieldname = 'ENTITYNAME' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( 40 ).
    lo_parameter->set_nullable( abap_false ).

    lo_parameter = lo_action->create_input_parameter(
      iv_parameter_name = 'Format'
      iv_abap_fieldname = 'FORMAT' ).
    lo_parameter->/iwbep/if_mgw_odata_property~set_type_edm_string( ).
    lo_parameter->set_maxlength( 10 ).
    lo_parameter->set_nullable( abap_true ).

    lo_action->bind_input_structure( 'ZEVO_CL_ODATA_MPC=>TS_META_PARAM' ).
  ENDMETHOD.

ENDCLASS.
