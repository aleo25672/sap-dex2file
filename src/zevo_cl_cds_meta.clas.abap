" Resolve CDS entity metadata for OData GetCdsMetadata: fields, keys,
" DDLNAME / DBTABNAME, and change-timestamp field (same priority as catalog).
CLASS zevo_cl_cds_meta DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_field  TYPE zevo_cl_serializer=>ty_field_meta.
    TYPES ty_fields TYPE zevo_cl_serializer=>ty_fields_meta.

    TYPES:
      BEGIN OF ty_meta,
        entity         TYPE string,
        ddl_name       TYPE string,
        db_tabname     TYPE string,
        delta_field    TYPE string,
        delta_capable  TYPE abap_bool,
        key_fields     TYPE stringtab,
        fields         TYPE ty_fields,
        status         TYPE c LENGTH 1,  " S ok | E error
        message        TYPE string,
      END OF ty_meta.

    METHODS get_metadata
      IMPORTING iv_entity TYPE clike
      RETURNING VALUE(rs_meta) TYPE ty_meta.

    CLASS-METHODS get_delta_field
      IMPORTING iv_entity TYPE clike
      RETURNING VALUE(rv_field) TYPE string.

    CLASS-METHODS get_field_names
      IMPORTING iv_entity TYPE clike
      RETURNING VALUE(rt_fields) TYPE zevo_cl_filter_parser=>ty_fields.
ENDCLASS.


CLASS zevo_cl_cds_meta IMPLEMENTATION.

  METHOD get_metadata.
    CLEAR rs_meta.
    DATA(lv_entity) = condense( CONV string( iv_entity ) ).
    IF lv_entity IS INITIAL.
      rs_meta-status  = 'E'.
      rs_meta-message = 'EntityName is required'.
      RETURN.
    ENDIF.
    rs_meta-entity = lv_entity.

    TRY.
        DATA lr_line TYPE REF TO data.
        CREATE DATA lr_line TYPE (lv_entity).
      CATCH cx_root INTO DATA(lx_create).
        rs_meta-status  = 'E'.
        rs_meta-message = |CDS entity '{ lv_entity }' is not selectable: { lx_create->get_text( ) }|.
        RETURN.
    ENDTRY.

    " DDLNAME / DBTABNAME via DDLDEPENDENCY
    DATA(lv_up) = to_upper( lv_entity ).
    SELECT SINGLE ddlname FROM ddldependency
      WHERE objecttype = 'STOB'
        AND upper( objectname ) = @lv_up
      INTO @DATA(lv_ddl).
    IF sy-subrc <> 0.
      SELECT SINGLE ddlname FROM ddldependency
        WHERE objecttype = 'STOB'
          AND upper( ddlname ) = @lv_up
        INTO @lv_ddl.
    ENDIF.
    IF lv_ddl IS NOT INITIAL.
      rs_meta-ddl_name = lv_ddl.
      SELECT SINGLE objectname FROM ddldependency
        WHERE ddlname = @lv_ddl
          AND objecttype = 'VIEW'
        INTO @DATA(lv_db).
      IF sy-subrc = 0.
        rs_meta-db_tabname = lv_db.
      ENDIF.
    ENDIF.

    rs_meta-delta_field   = get_delta_field( lv_entity ).
    rs_meta-delta_capable = xsdbool( rs_meta-delta_field IS NOT INITIAL ).

    DATA lt_dfies TYPE STANDARD TABLE OF dfies WITH DEFAULT KEY.
    DATA(lv_tab) = COND ddobjname(
      WHEN rs_meta-db_tabname IS NOT INITIAL THEN CONV ddobjname( rs_meta-db_tabname )
      ELSE CONV ddobjname( lv_entity ) ).

    CALL FUNCTION 'DDIF_FIELDINFO_GET'
      EXPORTING
        tabname   = lv_tab
      TABLES
        dfies_tab = lt_dfies
      EXCEPTIONS
        OTHERS    = 1.

    IF sy-subrc <> 0 OR lt_dfies IS INITIAL.
      " RTTI fallback
      DATA(lo_struct) = CAST cl_abap_structdescr(
                          cl_abap_typedescr=>describe_by_data_ref( lr_line ) ).
      LOOP AT lo_struct->get_components( ) INTO DATA(ls_comp).
        DATA ls_f TYPE ty_field.
        ls_f-name = ls_comp-name.
        APPEND ls_f TO rs_meta-fields.
      ENDLOOP.
    ELSE.
      LOOP AT lt_dfies INTO DATA(ls_dfies).
        CLEAR ls_f.
        ls_f-name        = ls_dfies-fieldname.
        ls_f-abap_type   = ls_dfies-inttype.
        ls_f-length      = ls_dfies-leng.
        ls_f-decimals    = ls_dfies-decimals.
        ls_f-key_flag    = xsdbool( ls_dfies-keyflag = abap_true ).
        ls_f-description = ls_dfies-fieldtext.
        APPEND ls_f TO rs_meta-fields.
        IF ls_dfies-keyflag = abap_true.
          APPEND CONV string( ls_dfies-fieldname ) TO rs_meta-key_fields.
        ENDIF.
      ENDLOOP.
    ENDIF.

    rs_meta-status  = 'S'.
    rs_meta-message = |{ lines( rs_meta-fields ) } field(s)|.
  ENDMETHOD.

  METHOD get_delta_field.
    DATA(lv_up) = to_upper( condense( CONV string( iv_entity ) ) ).
    IF lv_up IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE lfieldname FROM ddfieldanno
      WHERE upper( strucobjn ) = @lv_up
        AND upper( name ) = 'SEMANTICS.SYSTEMDATETIME.LASTCHANGEDAT'
      INTO @DATA(lv_field).
    IF sy-subrc = 0 AND lv_field IS NOT INITIAL.
      rv_field = lv_field.
      RETURN.
    ENDIF.

    SELECT SINGLE lfieldname FROM ddfieldanno
      WHERE upper( strucobjn ) = @lv_up
        AND upper( name ) = 'SEMANTICS.SYSTEMDATETIME.LOCALINSTANCELASTCHANGEDAT'
      INTO @lv_field.
    IF sy-subrc = 0 AND lv_field IS NOT INITIAL.
      rv_field = lv_field.
      RETURN.
    ENDIF.

    SELECT SINGLE lfieldname FROM ddfieldanno
      WHERE upper( strucobjn ) = @lv_up
        AND upper( lfieldname ) = 'LASTCHANGEDATETIME'
      INTO @lv_field.
    IF sy-subrc = 0 AND lv_field IS NOT INITIAL.
      rv_field = lv_field.
      RETURN.
    ENDIF.

    SELECT SINGLE fieldname FROM dd03l
      WHERE upper( tabname ) = @lv_up
        AND fieldname = 'LASTCHANGEDATETIME'
        AND as4local = 'A'
      INTO @DATA(lv_dd03).
    IF sy-subrc = 0.
      rv_field = lv_dd03.
      RETURN.
    ENDIF.

    " Via SQL view mapped from DDL
    SELECT SINGLE objectname FROM ddldependency
      WHERE objecttype = 'VIEW'
        AND ( upper( ddlname ) = @lv_up OR upper( objectname ) = @lv_up )
      INTO @DATA(lv_view).
    IF sy-subrc = 0.
      DATA(lv_view_up) = to_upper( CONV string( lv_view ) ).
      SELECT SINGLE fieldname FROM dd03l
        WHERE upper( tabname ) = @lv_view_up
          AND fieldname = 'LASTCHANGEDATETIME'
          AND as4local = 'A'
        INTO @lv_dd03.
      IF sy-subrc = 0.
        rv_field = lv_dd03.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD get_field_names.
    CLEAR rt_fields.
    TRY.
        DATA lr_line TYPE REF TO data.
        CREATE DATA lr_line TYPE (iv_entity).
        DATA(lo_struct) = CAST cl_abap_structdescr(
                            cl_abap_typedescr=>describe_by_data_ref( lr_line ) ).
        LOOP AT lo_struct->get_components( ) INTO DATA(ls_comp).
          INSERT to_upper( CONV string( ls_comp-name ) ) INTO TABLE rt_fields.
        ENDLOOP.
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
