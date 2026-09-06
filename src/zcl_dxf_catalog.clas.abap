" Discover CDS views for file extraction and detect the change-timestamp
" field used for timestamp-based delta.
"   - DEX : released extraction-enabled views from IXTRCTNENBLDVW
"   - API : CDS DDL sources (TADIR object DDLS) named like I_*API*
"           (example I_PurchaseOrderAPI01). OData bindings like
"           API_PURCHASEORDER_2 are not listed.
"   - Delta field (first match wins):
"       1. @Semantics.systemDateTime.lastChangedAt (DDFIELDANNO)
"       2. field named LastChangeDateTime (DD03L)
CLASS zcl_dxf_catalog DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_view,
        entity_name    TYPE c LENGTH 60,
        description    TYPE c LENGTH 60,
        source_type    TYPE c LENGTH 3,
        family         TYPE c LENGTH 20,
        is_cdc_enabled TYPE abap_bool,
        delta_field    TYPE c LENGTH 30,
        delta_capable  TYPE abap_bool,
        last_delta_ts  TYPE timestampl,
        reason         TYPE string,
      END OF ty_view,
      ty_views TYPE STANDARD TABLE OF ty_view WITH DEFAULT KEY.

    METHODS get_views
      IMPORTING
        iv_name_pattern TYPE clike OPTIONAL
        iv_api_pattern  TYPE clike OPTIONAL
        iv_source       TYPE clike DEFAULT 'D'
        iv_dataclass    TYPE clike DEFAULT space
        io_delta_store  TYPE REF TO zcl_dxf_delta_store OPTIONAL
      RETURNING
        VALUE(rt_views) TYPE ty_views.
ENDCLASS.


CLASS zcl_dxf_catalog IMPLEMENTATION.

  METHOD get_views.

    TYPES: BEGIN OF ty_map,
             ent_up TYPE string,
             field  TYPE c LENGTH 30,
           END OF ty_map.
    TYPES: BEGIN OF ty_dc,
             ent_up TYPE string,
             dclass TYPE c LENGTH 20,
           END OF ty_dc.
    TYPES: BEGIN OF ty_lab,
             ent_up TYPE string,
             label  TYPE c LENGTH 60,
           END OF ty_lab.

    DATA lt_tsmap   TYPE SORTED TABLE OF ty_map WITH NON-UNIQUE KEY ent_up.
    DATA lt_lcdtmap TYPE SORTED TABLE OF ty_map WITH NON-UNIQUE KEY ent_up.
    DATA lt_dcmap   TYPE SORTED TABLE OF ty_dc  WITH NON-UNIQUE KEY ent_up.
    DATA lt_labmap  TYPE SORTED TABLE OF ty_lab WITH NON-UNIQUE KEY ent_up.

    DATA lv_source  TYPE string.
    DATA lv_dex_pat TYPE string.
    DATA lv_api_pat TYPE string.
    DATA lv_ent_up  TYPE string.
    DATA lv_name    TYPE string.
    DATA lv_dc      TYPE string.
    DATA lv_lab     TYPE string.
    DATA ls_out     TYPE ty_view.
    DATA ls_m       TYPE ty_map.
    DATA ls_dcm     TYPE ty_dc.
    DATA ls_lbl     TYPE ty_lab.

    lv_source = to_upper( condense( CONV string( iv_source ) ) ).
    IF lv_source IS INITIAL.
      lv_source = 'D'.
    ENDIF.

    " Annotation: @Semantics.systemDateTime.lastChangedAt
    SELECT strucobjn, lfieldname
      FROM ddfieldanno
      WHERE upper( name ) = 'SEMANTICS.SYSTEMDATETIME.LASTCHANGEDAT'
      INTO TABLE @DATA(lt_ts).

    LOOP AT lt_ts INTO DATA(ls_ts).
      ls_m-ent_up = to_upper( ls_ts-strucobjn ).
      ls_m-field  = ls_ts-lfieldname.
      INSERT ls_m INTO TABLE lt_tsmap.
    ENDLOOP.

    " Field name LastChangeDateTime
    SELECT tabname, fieldname
      FROM dd03l
      WHERE fieldname = 'LASTCHANGEDATETIME'
        AND as4local  = 'A'
      INTO TABLE @DATA(lt_lcdt).

    LOOP AT lt_lcdt INTO DATA(ls_lcdt).
      ls_m-ent_up = to_upper( ls_lcdt-tabname ).
      ls_m-field  = ls_lcdt-fieldname.
      INSERT ls_m INTO TABLE lt_lcdtmap.
    ENDLOOP.

    SELECT strucobjn, value AS dclass
      FROM ddheadanno
      WHERE upper( name ) = 'OBJECTMODEL.USAGETYPE.DATACLASS'
      INTO TABLE @DATA(lt_dc).

    LOOP AT lt_dc INTO DATA(ls_dc).
      lv_dc = to_upper( CONV string( ls_dc-dclass ) ).
      REPLACE ALL OCCURRENCES OF `#` IN lv_dc WITH ``.
      REPLACE ALL OCCURRENCES OF `'` IN lv_dc WITH ``.
      CONDENSE lv_dc.
      ls_dcm-ent_up = to_upper( ls_dc-strucobjn ).
      ls_dcm-dclass = lv_dc.
      INSERT ls_dcm INTO TABLE lt_dcmap.
    ENDLOOP.

    SELECT strucobjn, value AS label
      FROM ddheadanno
      WHERE upper( name ) = 'ENDUSERTEXT.LABEL'
      INTO TABLE @DATA(lt_lab).

    LOOP AT lt_lab INTO DATA(ls_lab).
      lv_lab = CONV string( ls_lab-label ).
      REPLACE ALL OCCURRENCES OF `'` IN lv_lab WITH ``.
      CONDENSE lv_lab.
      ls_lbl-ent_up = to_upper( ls_lab-strucobjn ).
      ls_lbl-label  = lv_lab.
      INSERT ls_lbl INTO TABLE lt_labmap.
    ENDLOOP.

    " ------------------------------------------------------------------
    " DEX
    " ------------------------------------------------------------------
    IF lv_source = 'D' OR lv_source = 'B'.
      lv_dex_pat = condense( CONV string( iv_name_pattern ) ).
      IF lv_dex_pat IS INITIAL.
        lv_dex_pat = '%'.
      ELSEIF lv_dex_pat CA '*'.
        REPLACE ALL OCCURRENCES OF '*' IN lv_dex_pat WITH '%'.
      ELSE.
        lv_dex_pat = |%{ lv_dex_pat }%|.
      ENDIF.

      SELECT dataextractionviewname,
             dataextractionviewdescription,
             deltachgdatacaptureissupported
        FROM ixtrctnenbldvw
        WHERE issapreleasedview = @abap_true
          AND dataextractionviewname LIKE @lv_dex_pat
        ORDER BY dataextractionviewname
        INTO TABLE @DATA(lt_dex).

      LOOP AT lt_dex INTO DATA(ls_dex).
        CLEAR ls_out.
        ls_out-entity_name    = ls_dex-dataextractionviewname.
        ls_out-description    = ls_dex-dataextractionviewdescription.
        ls_out-source_type    = 'DEX'.
        ls_out-is_cdc_enabled = ls_dex-deltachgdatacaptureissupported.

        lv_ent_up = to_upper( ls_dex-dataextractionviewname ).

        READ TABLE lt_dcmap INTO ls_dcm WITH KEY ent_up = lv_ent_up.
        IF sy-subrc = 0.
          ls_out-family = ls_dcm-dclass.
        ENDIF.

        IF ( iv_dataclass = 'M' AND ls_out-family <> 'MASTER' )
        OR ( iv_dataclass = 'T' AND ls_out-family <> 'TRANSACTIONAL' ).
          CONTINUE.
        ENDIF.

        READ TABLE lt_tsmap INTO ls_m WITH KEY ent_up = lv_ent_up.
        IF sy-subrc = 0 AND ls_m-field IS NOT INITIAL.
          ls_out-delta_field   = ls_m-field.
          ls_out-delta_capable = abap_true.
        ELSE.
          READ TABLE lt_lcdtmap INTO ls_m WITH KEY ent_up = lv_ent_up.
          IF sy-subrc = 0 AND ls_m-field IS NOT INITIAL.
            ls_out-delta_field   = ls_m-field.
            ls_out-delta_capable = abap_true.
          ENDIF.
        ENDIF.

        IF io_delta_store IS BOUND.
          ls_out-last_delta_ts = io_delta_store->get_last( ls_out-entity_name ).
        ENDIF.

        APPEND ls_out TO rt_views.
      ENDLOOP.
    ENDIF.

    " ------------------------------------------------------------------
    " API CDS
    " ------------------------------------------------------------------
    IF lv_source = 'A' OR lv_source = 'B'.
      lv_api_pat = condense( CONV string( iv_api_pattern ) ).
      IF lv_api_pat IS INITIAL.
        lv_api_pat = 'I_*API*'.
      ENDIF.
      IF lv_api_pat CA '*'.
        REPLACE ALL OCCURRENCES OF '*' IN lv_api_pat WITH '%'.
      ELSE.
        lv_api_pat = |%{ lv_api_pat }%|.
      ENDIF.

      SELECT obj_name
        FROM tadir
        WHERE pgmid  = 'R3TR'
          AND object = 'DDLS'
          AND obj_name LIKE @lv_api_pat
        ORDER BY obj_name
        INTO TABLE @DATA(lt_api).

      LOOP AT lt_api INTO DATA(ls_api).
        lv_name = CONV string( ls_api-obj_name ).
        IF to_upper( lv_name ) CP 'API_*'.
          CONTINUE.
        ENDIF.

        lv_ent_up = to_upper( lv_name ).
        READ TABLE rt_views TRANSPORTING NO FIELDS
             WITH KEY entity_name = lv_name.
        IF sy-subrc = 0.
          CONTINUE.
        ENDIF.
        READ TABLE rt_views TRANSPORTING NO FIELDS
             WITH KEY entity_name = lv_ent_up.
        IF sy-subrc = 0.
          CONTINUE.
        ENDIF.

        CLEAR ls_out.
        ls_out-entity_name = lv_name.
        ls_out-source_type = 'API'.

        READ TABLE lt_labmap INTO ls_lbl WITH KEY ent_up = lv_ent_up.
        IF sy-subrc = 0.
          ls_out-description = ls_lbl-label.
        ENDIF.

        READ TABLE lt_dcmap INTO ls_dcm WITH KEY ent_up = lv_ent_up.
        IF sy-subrc = 0.
          ls_out-family = ls_dcm-dclass.
        ENDIF.

        IF ( iv_dataclass = 'M' AND ls_out-family <> 'MASTER' )
        OR ( iv_dataclass = 'T' AND ls_out-family <> 'TRANSACTIONAL' ).
          CONTINUE.
        ENDIF.

        READ TABLE lt_tsmap INTO ls_m WITH KEY ent_up = lv_ent_up.
        IF sy-subrc = 0 AND ls_m-field IS NOT INITIAL.
          ls_out-delta_field   = ls_m-field.
          ls_out-delta_capable = abap_true.
        ELSE.
          READ TABLE lt_lcdtmap INTO ls_m WITH KEY ent_up = lv_ent_up.
          IF sy-subrc = 0 AND ls_m-field IS NOT INITIAL.
            ls_out-delta_field   = ls_m-field.
            ls_out-delta_capable = abap_true.
          ENDIF.
        ENDIF.

        IF io_delta_store IS BOUND.
          ls_out-last_delta_ts = io_delta_store->get_last( ls_out-entity_name ).
        ENDIF.

        APPEND ls_out TO rt_views.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
