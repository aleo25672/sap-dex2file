" Resolve CDS entity metadata for OData GetCdsMetadata: fields, keys,
" DDLNAME / DBTABNAME, and change-timestamp field (same priority as catalog;
" CREATIONDATE|CREATIONTIME as last resort).
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

    " CREATIONDATE|CREATIONTIME when both exist and no timestamp field.
    CLASS-METHODS creation_pair_token
      IMPORTING iv_entity TYPE clike
      RETURNING VALUE(rv_token) TYPE string.

    " DOCUMENTDATE when present; never for master-data CDS.
    CLASS-METHODS document_date_token
      IMPORTING iv_entity TYPE clike
      RETURNING VALUE(rv_token) TYPE string.

    CLASS-METHODS is_master_data
      IMPORTING iv_entity TYPE clike
      RETURNING VALUE(rv_master) TYPE abap_bool.
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
        IF ls_comp-name IS INITIAL OR ls_comp-name(1) = '.'.
          CONTINUE.
        ENDIF.
        DATA ls_f TYPE ty_field.
        ls_f-name = ls_comp-name.
        APPEND ls_f TO rs_meta-fields.
      ENDLOOP.
    ELSE.
      LOOP AT lt_dfies INTO DATA(ls_dfies).
        " .NODE* entries are DDIC hierarchy placeholders, not OpenSQL fields
        IF ls_dfies-fieldname IS INITIAL OR ls_dfies-fieldname(1) = '.'.
          CONTINUE.
        ENDIF.
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
        RETURN.
      ENDIF.
    ENDIF.

    rv_field = creation_pair_token( iv_entity ).
    IF rv_field IS INITIAL AND is_master_data( iv_entity ) = abap_false.
      rv_field = document_date_token( iv_entity ).
    ENDIF.
  ENDMETHOD.

  METHOD creation_pair_token.
    DATA lt_dfies TYPE STANDARD TABLE OF dfies WITH DEFAULT KEY.
    DATA ls_date  TYPE dfies.
    DATA ls_time  TYPE dfies.
    DATA lv_tab   TYPE ddobjname.
    DATA lv_cd    TYPE dd03l-fieldname.
    DATA lv_ct    TYPE dd03l-fieldname.
    DATA lr_line  TYPE REF TO data.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lv_has_d TYPE abap_bool.
    DATA lv_has_t TYPE abap_bool.

    CLEAR rv_token.
    DATA(lv_up) = to_upper( condense( CONV string( iv_entity ) ) ).
    IF lv_up IS INITIAL.
      RETURN.
    ENDIF.

    lv_tab = lv_up.
    CALL FUNCTION 'DDIF_FIELDINFO_GET'
      EXPORTING
        tabname   = lv_tab
      TABLES
        dfies_tab = lt_dfies
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc = 0 AND lt_dfies IS NOT INITIAL.
      READ TABLE lt_dfies INTO ls_date WITH KEY fieldname = 'CREATIONDATE'.
      IF sy-subrc = 0.
        READ TABLE lt_dfies INTO ls_time WITH KEY fieldname = 'CREATIONTIME'.
        IF sy-subrc = 0.
          rv_token = ls_date-fieldname && '|' && ls_time-fieldname.
          RETURN.
        ENDIF.
      ENDIF.
    ENDIF.

    SELECT SINGLE fieldname FROM dd03l
      WHERE upper( tabname ) = @lv_up
        AND fieldname = 'CREATIONDATE'
        AND as4local = 'A'
      INTO @lv_cd.
    SELECT SINGLE fieldname FROM dd03l
      WHERE upper( tabname ) = @lv_up
        AND fieldname = 'CREATIONTIME'
        AND as4local = 'A'
      INTO @lv_ct.
    IF lv_cd IS NOT INITIAL AND lv_ct IS NOT INITIAL.
      rv_token = lv_cd && '|' && lv_ct.
      RETURN.
    ENDIF.

    TRY.
        CREATE DATA lr_line TYPE (lv_up).
        lo_struct = CAST cl_abap_structdescr(
                      cl_abap_typedescr=>describe_by_data_ref( lr_line ) ).
        lv_has_d = abap_false.
        lv_has_t = abap_false.
        LOOP AT lo_struct->get_components( ) INTO DATA(ls_comp).
          IF to_upper( CONV string( ls_comp-name ) ) = 'CREATIONDATE'.
            lv_has_d = abap_true.
          ENDIF.
          IF to_upper( CONV string( ls_comp-name ) ) = 'CREATIONTIME'.
            lv_has_t = abap_true.
          ENDIF.
        ENDLOOP.
        IF lv_has_d = abap_true AND lv_has_t = abap_true.
          rv_token = 'CREATIONDATE|CREATIONTIME'.
        ENDIF.
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.

  METHOD document_date_token.
    DATA lt_dfies TYPE STANDARD TABLE OF dfies WITH DEFAULT KEY.
    DATA ls_dfies TYPE dfies.
    DATA lv_tab   TYPE ddobjname.
    DATA lv_name  TYPE dd03l-fieldname.
    DATA lr_line  TYPE REF TO data.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.

    CLEAR rv_token.
    DATA(lv_up) = to_upper( condense( CONV string( iv_entity ) ) ).
    IF lv_up IS INITIAL.
      RETURN.
    ENDIF.

    lv_tab = lv_up.
    CALL FUNCTION 'DDIF_FIELDINFO_GET'
      EXPORTING
        tabname   = lv_tab
      TABLES
        dfies_tab = lt_dfies
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc = 0.
      READ TABLE lt_dfies INTO ls_dfies WITH KEY fieldname = 'DOCUMENTDATE'.
      IF sy-subrc = 0.
        rv_token = ls_dfies-fieldname.
        RETURN.
      ENDIF.
    ENDIF.

    SELECT SINGLE fieldname FROM dd03l
      WHERE upper( tabname ) = @lv_up
        AND fieldname = 'DOCUMENTDATE'
        AND as4local = 'A'
      INTO @lv_name.
    IF sy-subrc = 0 AND lv_name IS NOT INITIAL.
      rv_token = lv_name.
      RETURN.
    ENDIF.

    TRY.
        CREATE DATA lr_line TYPE (lv_up).
        lo_struct = CAST cl_abap_structdescr(
                      cl_abap_typedescr=>describe_by_data_ref( lr_line ) ).
        LOOP AT lo_struct->get_components( ) INTO DATA(ls_comp).
          IF to_upper( CONV string( ls_comp-name ) ) = 'DOCUMENTDATE'.
            rv_token = 'DOCUMENTDATE'.
            RETURN.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.

  METHOD is_master_data.
    DATA lv_dc TYPE c LENGTH 40.
    CLEAR rv_master.
    DATA(lv_up) = to_upper( condense( CONV string( iv_entity ) ) ).
    IF lv_up IS INITIAL.
      RETURN.
    ENDIF.
    SELECT SINGLE value FROM ddheadanno
      WHERE upper( strucobjn ) = @lv_up
        AND upper( name ) = 'OBJECTMODEL.USAGETYPE.DATACLASS'
      INTO @DATA(lv_val).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    lv_dc = to_upper( CONV string( lv_val ) ).
    REPLACE ALL OCCURRENCES OF `#` IN lv_dc WITH space.
    REPLACE ALL OCCURRENCES OF `'` IN lv_dc WITH space.
    CONDENSE lv_dc NO-GAPS.
    rv_master = xsdbool( lv_dc = 'MASTER' ).
  ENDMETHOD.

  METHOD get_field_names.
    CLEAR rt_fields.
    TRY.
        DATA lr_line TYPE REF TO data.
        CREATE DATA lr_line TYPE (iv_entity).
        DATA(lo_struct) = CAST cl_abap_structdescr(
                            cl_abap_typedescr=>describe_by_data_ref( lr_line ) ).
        LOOP AT lo_struct->get_components( ) INTO DATA(ls_comp).
          IF ls_comp-name IS INITIAL OR ls_comp-name(1) = '.'.
            CONTINUE.
          ENDIF.
          IF ls_comp-as_include = abap_true.
            CONTINUE.
          ENDIF.
          INSERT to_upper( CONV string( ls_comp-name ) ) INTO TABLE rt_fields.
        ENDLOOP.
      CATCH cx_root.
        RETURN.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
