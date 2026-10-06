" OData model TYPES + DEFINE_MODEL helper for SEGW MPC_EXT.
" Types of Edm properties come from BIND_STRUCTURE / BIND_INPUT_STRUCTURE
" (no SET_TYPE_EDM_* calls — those methods are not uniformly visible on all GW SPs).
"
" Call from MPC_EXT->DEFINE as:
"   zevo_cl_odata_mpc=>define_model( model ).
" Prefer NOT calling super->define( ) when the SEGW tree is empty — leftover
" project entities make create_entity_type fail and leave ExtractCds missing.
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
        id      TYPE c LENGTH 32,  " surrogate OData key (GUID, not Payload)
        payload TYPE string,
      END OF ts_result.

    CLASS-METHODS define_model
      IMPORTING
        io_model TYPE REF TO /iwbep/if_mgw_odata_model
      RAISING
        /iwbep/cx_mgw_med_exception.
ENDCLASS.


CLASS zevo_cl_odata_mpc IMPLEMENTATION.

  METHOD define_model.
    DATA lo_entity_type TYPE REF TO /iwbep/if_mgw_odata_entity_typ.
    DATA lo_property    TYPE REF TO /iwbep/if_mgw_odata_property.
    DATA lo_action      TYPE REF TO /iwbep/if_mgw_odata_action.
    DATA lo_parameter   TYPE REF TO /iwbep/if_mgw_odata_parameter.
    DATA lx_med         TYPE REF TO /iwbep/cx_mgw_med_exception.

    io_model->set_schema_namespace( 'ZEVO_CDS_EXTRACT_SRV' ).

    " Get-or-create entity (SEGW tree / prior DEFINE may already have it).
    TRY.
        lo_entity_type = io_model->get_entity_type( iv_entity_name = 'CdsResult' ).
      CATCH /iwbep/cx_mgw_med_exception INTO lx_med.
        lo_entity_type = io_model->create_entity_type(
          iv_entity_type_name = 'CdsResult'
          iv_def_entity_set   = abap_true ).
    ENDTRY.

    " Id = key (short); Payload = content (not key).
    TRY.
        lo_property = lo_entity_type->create_property(
          iv_property_name  = 'Id'
          iv_abap_fieldname = 'ID' ).
      CATCH /iwbep/cx_mgw_med_exception INTO lx_med.
        lo_property = lo_entity_type->get_property( iv_property_name = 'Id' ).
    ENDTRY.
    lo_property->set_is_key( abap_true ).
    lo_property->set_nullable( abap_false ).

    TRY.
        lo_property = lo_entity_type->create_property(
          iv_property_name  = 'Payload'
          iv_abap_fieldname = 'PAYLOAD' ).
      CATCH /iwbep/cx_mgw_med_exception INTO lx_med.
        lo_property = lo_entity_type->get_property( iv_property_name = 'Payload' ).
    ENDTRY.
    lo_property->set_is_key( abap_false ).
    lo_property->set_nullable( abap_false ).

    lo_entity_type->bind_structure( iv_structure_name = 'ZEVO_CL_ODATA_MPC=>TS_RESULT' ).

    " --- ExtractCds ---
    TRY.
        lo_action = io_model->create_action( iv_action_name = 'ExtractCds' ).
        lo_action->set_http_method( 'GET' ).
        lo_action->set_return_entity_type( 'CdsResult' ).
        lo_action->set_return_multiplicity( '1' ).

        lo_parameter = lo_action->create_input_parameter(
          iv_parameter_name = 'EntityName'
          iv_abap_fieldname = 'ENTITYNAME' ).
        lo_parameter->set_nullable( abap_false ).

        lo_parameter = lo_action->create_input_parameter(
          iv_parameter_name = 'Filter'
          iv_abap_fieldname = 'FILTER_EXPR' ).
        lo_parameter->set_nullable( abap_true ).

        lo_parameter = lo_action->create_input_parameter(
          iv_parameter_name = 'Format'
          iv_abap_fieldname = 'FORMAT_CD' ).
        lo_parameter->set_nullable( abap_true ).

        lo_parameter = lo_action->create_input_parameter(
          iv_parameter_name = 'DeltaSince'
          iv_abap_fieldname = 'DELTASINCE' ).
        lo_parameter->set_nullable( abap_true ).

        lo_parameter = lo_action->create_input_parameter(
          iv_parameter_name = 'Skip'
          iv_abap_fieldname = 'SKIP_ROWS' ).
        lo_parameter->set_nullable( abap_true ).

        lo_parameter = lo_action->create_input_parameter(
          iv_parameter_name = 'Top'
          iv_abap_fieldname = 'TOP_ROWS' ).
        lo_parameter->set_nullable( abap_true ).

        lo_action->bind_input_structure( iv_structure_name = 'ZEVO_CL_ODATA_MPC=>TS_EXTRACT_PARAM' ).
      CATCH /iwbep/cx_mgw_med_exception INTO lx_med.
        " Action already present from a previous DEFINE — keep existing.
    ENDTRY.

    " --- GetCdsMetadata ---
    TRY.
        lo_action = io_model->create_action( iv_action_name = 'GetCdsMetadata' ).
        lo_action->set_http_method( 'GET' ).
        lo_action->set_return_entity_type( 'CdsResult' ).
        lo_action->set_return_multiplicity( '1' ).

        lo_parameter = lo_action->create_input_parameter(
          iv_parameter_name = 'EntityName'
          iv_abap_fieldname = 'ENTITYNAME' ).
        lo_parameter->set_nullable( abap_false ).

        lo_parameter = lo_action->create_input_parameter(
          iv_parameter_name = 'Format'
          iv_abap_fieldname = 'FORMAT_CD' ).
        lo_parameter->set_nullable( abap_true ).

        lo_action->bind_input_structure( iv_structure_name = 'ZEVO_CL_ODATA_MPC=>TS_META_PARAM' ).
      CATCH /iwbep/cx_mgw_med_exception INTO lx_med.
        " Action already present.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
