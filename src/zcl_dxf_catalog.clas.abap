" Discover CDS views for file extraction and, for each, detect the
" change-timestamp field used for timestamp-based delta.
"   - DEX : released extraction-enabled views from IXTRCTNENBLDVW.
"   - API : CDS DDL sources (TADIR object DDLS) named like I_*API*
"           (e.g. I_PurchaseOrderAPI01). OData service bindings such as
"           API_PURCHASEORDER_2 are not listed (not DDLS / name-filtered).
"   - Delta field resolution (first match wins):
"       1. element annotated @Semantics.systemDateTime.lastChangedAt (DDFIELDANNO)
"       2. element named LastChangeDateTime (DD03L / RTTI), common on API CDS
"     delta_capable = a delta field was found.
CLASS zcl_dxf_catalog DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_view,
        entity_name    TYPE c LENGTH 60,
        description    TYPE c LENGTH 60,
        source_type    TYPE c LENGTH 3,    " DEX | API
        family         TYPE c LENGTH 20,   " data class (@ObjectModel.usageType.dataClass)
        is_cdc_enabled TYPE abap_bool,
        delta_field    TYPE c LENGTH 30,   " change-timestamp element used for delta
        delta_capable  TYPE abap_bool,     " a change-timestamp field exists
        last_delta_ts  TYPE timestampl,    " stored high-water (last extracted up to)
        reason         TYPE string,
      END OF ty_view,
      ty_views TYPE STANDARD TABLE OF ty_view WITH DEFAULT KEY.

    " @parameter iv_name_pattern | DEX entity filter; plain text = contains, '*' = wildcard
    " @parameter iv_api_pattern  | API CDS name filter; empty defaults to I_*API*
    " @parameter iv_source       | 'D' = DEX, 'A' = API CDS, 'B' = Both (default D)
    " @parameter iv_dataclass    | data-class filter: ' ' = all, 'M' = MASTER, 'T' = TRANSACTIONAL
    " @parameter io_delta_store  | optional, fills the stored high-water per view
    METHODS get_views
      IMPORTING
        iv_name_pattern TYPE clike OPTIONAL
        iv_api_pattern  TYPE clike OPTIONAL
        iv_source       TYPE clike DEFAULT 'D'
        iv_dataclass    TYPE clike DEFAULT space
        io_delta_store  TYPE REF TO zcl_dxf_delta_store OPTIONAL
      RETURNING
        VALUE(rt_views) TYPE ty_views.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_fmap,
        ent_up TYPE string,
        field  TYPE c LENGTH 30,
      END OF ty_fmap,
      ty_fmaps TYPE SORTED TABLE OF ty_fmap WITH NON-UNIQUE KEY ent_up.

    " Prefer @Semantics.systemDateTime.lastChangedAt; else LastChangeDateTime.
    METHODS resolve_delta_field
      IMPORTING
        iv_entity   TYPE clike
        it_anno_map TYPE ty_fmaps
        it_lcdt_map TYPE ty_fmaps
      RETURNING
        VALUE(rv_field) TYPE c LENGTH 30.
ENDCLASS.


CLASS zcl_dxf_catalog IMPLEMENTATION.

  METHOD get_views.
    DATA(lv_source) = to_upper( condense( CONV string( iv_source ) ) ).
    IF lv_source IS INITIAL.
      lv_source = 'D'.
    ENDIF.

    " 1) Annotation map: @Semantics.systemDateTime.lastChangedAt
    SELECT strucobjn, lfieldname
      FROM ddfieldanno
      WHERE upper( name ) = 'SEMANTICS.SYSTEMDATETIME.LASTCHANGEDAT'
      INTO TABLE @DATA(lt_ts).

    DATA lt_anno TYPE ty_fmaps.
    LOOP AT lt_ts INTO DATA(ls_ts).
      INSERT VALUE #( ent_up = to_upper( ls_ts-strucobjn )
                      field  = ls_ts-lfieldname ) INTO TABLE lt_anno.
    ENDLOOP.

    " 2) Field-name map: LastChangeDateTime (typical on API CDS views)
    SELECT tabname, fieldname
      FROM dd03l
      WHERE fieldname = 'LASTCHANGEDATETIME'
        AND as4local  = 'A'
      INTO TABLE @DATA(lt_lcdt).

    DATA lt_lcdt_map TYPE ty_fmaps.
    LOOP AT lt_lcdt INTO DATA(ls_lcdt).
      INSERT VALUE #( ent_up = to_upper( ls_lcdt-tabname )
                      field  = ls_lcdt-fieldname ) INTO TABLE lt_lcdt_map.
    ENDLOOP.

    SELECT strucobjn, value AS dclass
      FROM ddheadanno
      WHERE upper( name ) = 'OBJECTMODEL.USAGETYPE.DATACLASS'
      INTO TABLE @DATA(lt_dc).

    TYPES: BEGIN OF ty_dc,
             ent_up TYPE string,
             dclass TYPE c LENGTH 20,
           END OF ty_dc.
    DATA lt_dcmap TYPE SORTED TABLE OF ty_dc WITH NON-UNIQUE KEY ent_up.
    LOOP AT lt_dc INTO DATA(ls_dc).
      DATA(lv_dc) = to_upper( CONV string( ls_dc-dclass ) ).
      REPLACE ALL OCCURRENCES OF `#` IN lv_dc WITH ``.
      REPLACE ALL OCCURRENCES OF `'` IN lv_dc WITH ``.
      CONDENSE lv_dc.
      INSERT VALUE #( ent_up = to_upper( ls_dc-strucobjn )
                      dclass = lv_dc ) INTO TABLE lt_dcmap.
    ENDLOOP.

    SELECT strucobjn, value AS label
      FROM ddheadanno
      WHERE upper( name ) = 'ENDUSERTEXT.LABEL'
      INTO TABLE @DATA(lt_lab).

    TYPES: BEGIN OF ty_lab,
             ent_up TYPE string,
             label  TYPE c LENGTH 60,
           END OF ty_lab.
    DATA lt_labmap TYPE SORTED TABLE OF ty_lab WITH NON-UNIQUE KEY ent_up.
    LOOP AT lt_lab INTO DATA(ls_lab).
      DATA(lv_lab) = CONV string( ls_lab-label ).
      REPLACE ALL OCCURRENCES OF `'` IN lv_lab WITH ``.
      CONDENSE lv_lab.
      INSERT VALUE #( ent_up = to_upper( ls_lab-strucobjn )
                      label  = lv_lab ) INTO TABLE lt_labmap.
    ENDLOOP.

    " ------------------------------------------------------------------
    " DEX views (IXTRCTNENBLDVW, released only)
    " ------------------------------------------------------------------
    IF lv_source = 'D' OR lv_source = 'B'.
      DATA(lv_dex_pat) = condense( CONV string( iv_name_pattern ) ).
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
        DATA(ls_out) = VALUE ty_view(
          entity_name    = ls_dex-dataextractionviewname
          description    = ls_dex-dataextractionviewdescription
          source_type    = 'DEX'
          is_cdc_enabled = ls_dex-deltachgdatacaptureissupported ).

        DATA(lv_ent_up) = to_upper( ls_dex-dataextractionviewname ).

        READ TABLE lt_dcmap INTO DATA(ls_dcm) WITH KEY ent_up = lv_ent_up.
        IF sy-subrc = 0.
          ls_out-family = ls_dcm-dclass.
        ENDIF.

        IF ( iv_dataclass = 'M' AND ls_out-family <> 'MASTER' )
        OR ( iv_dataclass = 'T' AND ls_out-family <> 'TRANSACTIONAL' ).
          CONTINUE.
        ENDIF.

        ls_out-delta_field = resolve_delta_field(
          iv_entity   = ls_out-entity_name
          it_anno_map = lt_anno
          it_lcdt_map = lt_lcdt_map ).
        IF ls_out-delta_field IS NOT INITIAL.
          ls_out-delta_capable = abap_true.
        ENDIF.

        IF io_delta_store IS BOUND.
          ls_out-last_delta_ts = io_delta_store->get_last( ls_out-entity_name ).
        ENDIF.

        APPEND ls_out TO rt_views.
      ENDLOOP.
    ENDIF.

    " ------------------------------------------------------------------
    " API CDS views (TADIR DDLS, default pattern I_*API*)
    " ------------------------------------------------------------------
    IF lv_source = 'A' OR lv_source = 'B'.
      DATA(lv_api_pat) = condense( CONV string( iv_api_pattern ) ).
      IF lv_api_pat IS INITIAL.
        lv_api_pat = 'I_*API*'.
      ENDIF.
      IF lv_api_pat CA '*'.
        REPLACE ALL OCCURRENCES OF '*' IN lv_api_pat WITH '%'.
      ELSE.
        lv_api_pat = |%{ lv_api_pat }%|.
      ENDIF.

      " CDS DDL sources only - OData service bindings are other object types
      " (e.g. SRVB) and must not appear here.
      SELECT obj_name
        FROM tadir
        WHERE pgmid  = 'R3TR'
          AND object = 'DDLS'
          AND obj_name LIKE @lv_api_pat
        ORDER BY obj_name
        INTO TABLE @DATA(lt_api).

      LOOP AT lt_api INTO DATA(ls_api).
        DATA(lv_name) = CONV string( ls_api-obj_name ).
        " Extra guard: skip OData-style names like API_PURCHASEORDER_2.
        IF to_upper( lv_name ) CP 'API_*'.
          CONTINUE.
        ENDIF.

        " Both mode: skip if already listed as DEX.
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

        READ TABLE lt_labmap INTO DATA(ls_lbl) WITH KEY ent_up = lv_ent_up.
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

        ls_out-delta_field = resolve_delta_field(
          iv_entity   = ls_out-entity_name
          it_anno_map = lt_anno
          it_lcdt_map = lt_lcdt_map ).
        IF ls_out-delta_field IS NOT INITIAL.
          ls_out-delta_capable = abap_true.
        ENDIF.

        IF io_delta_store IS BOUND.
          ls_out-last_delta_ts = io_delta_store->get_last( ls_out-entity_name ).
        ENDIF.

        APPEND ls_out TO rt_views.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD resolve_delta_field.
    DATA(lv_ent_up) = to_upper( CONV string( iv_entity ) ).

    " 1. Prefer the Semantics annotation (works for many DEX views).
    READ TABLE it_anno_map INTO DATA(ls_anno) WITH KEY ent_up = lv_ent_up.
    IF sy-subrc = 0 AND ls_anno-field IS NOT INITIAL.
      rv_field = ls_anno-field.
      RETURN.
    ENDIF.

    " 2. Fall back to a field literally named LastChangeDateTime (DDIC).
    READ TABLE it_lcdt_map INTO DATA(ls_lcdt) WITH KEY ent_up = lv_ent_up.
    IF sy-subrc = 0 AND ls_lcdt-field IS NOT INITIAL.
      rv_field = ls_lcdt-field.
      RETURN.
    ENDIF.

    " 3. RTTI fallback for CDS entities not represented in DD03L.
    TRY.
        DATA(lo_type) = cl_abap_typedescr=>describe_by_name( lv_ent_up ).
        DATA(lo_struct) = CAST cl_abap_structdescr( lo_type ).
        DATA(lt_comp) = lo_struct->get_components( ).
        LOOP AT lt_comp INTO DATA(ls_comp).
          IF ls_comp-name = 'LASTCHANGEDATETIME'.
            rv_field = ls_comp-name.
            RETURN.
          ENDIF.
        ENDLOOP.
      CATCH cx_root.
        " Entity not describable here - leave non-delta-capable.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
