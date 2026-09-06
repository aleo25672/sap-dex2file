" Discover CDS views for file extraction and detect the change-timestamp
" field used for timestamp-based delta.
"   - DEX : released extraction-enabled views from IXTRCTNENBLDVW
"   - API : CDS DDL sources (TADIR object DDLS) named like I_*API*
"           (example I_PurchaseOrderAPI01). OData bindings like
"           API_PURCHASEORDER_2 are not listed.
"   - Delta field (first match wins):
"       1. @Semantics.systemDateTime.lastChangedAt (DDFIELDANNO)
"       2. @Semantics.systemDateTime.localInstanceLastChangedAt
"       3. field named LastChangeDateTime (DDFIELDANNO / DD03L /
"          DDLDEPENDENCY SQL view / DDIF_FIELDINFO_GET fallback)
"   - Entity filters are select-option ranges (single values and CP wildcards).
"   - Last changed date/time comes from VRSD (DDLS version directory).
CLASS zcl_dxf_catalog DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_view,
        entity_name       TYPE c LENGTH 60,
        description       TYPE c LENGTH 60,
        source_type       TYPE c LENGTH 3,
        family            TYPE c LENGTH 20,
        is_cdc_enabled    TYPE abap_bool,
        delta_field       TYPE c LENGTH 30,
        delta_capable     TYPE abap_bool,
        last_delta_ts     TYPE timestampl,
        last_changed_date TYPE d,
        last_changed_time TYPE t,
        reason            TYPE string,
      END OF ty_view,
      ty_views TYPE STANDARD TABLE OF ty_view WITH DEFAULT KEY.

    TYPES ty_entity TYPE c LENGTH 40.
    TYPES ty_entity_range TYPE RANGE OF ty_entity.

    METHODS get_views
      IMPORTING
        it_name_range  TYPE ty_entity_range OPTIONAL
        it_api_range   TYPE ty_entity_range OPTIONAL
        iv_source      TYPE clike DEFAULT 'D'
        iv_dataclass   TYPE clike DEFAULT space
        io_delta_store TYPE REF TO zcl_dxf_delta_store OPTIONAL
      RETURNING
        VALUE(rt_views) TYPE ty_views.
ENDCLASS.


CLASS zcl_dxf_catalog IMPLEMENTATION.

  METHOD get_views.

    TYPES: BEGIN OF ty_map,
             ent_up TYPE c LENGTH 40,
             field  TYPE c LENGTH 30,
           END OF ty_map.
    TYPES: BEGIN OF ty_dc,
             ent_up TYPE c LENGTH 40,
             dclass TYPE c LENGTH 20,
           END OF ty_dc.
    TYPES: BEGIN OF ty_lab,
             ent_up TYPE c LENGTH 40,
             label  TYPE c LENGTH 60,
           END OF ty_lab.
    TYPES: BEGIN OF ty_dep,
             ddl_up TYPE c LENGTH 40,
             obj_up TYPE c LENGTH 40,
           END OF ty_dep.
    " Last-changed via VRSD. Use RANGE (not FOR ALL ENTRIES) to avoid
    " release-dependent OBJNAME length mismatches.
    TYPES: BEGIN OF ty_vrs,
             objname TYPE vrsd-objname,
             versno  TYPE vrsd-versno,
             datum   TYPE vrsd-datum,
             zeit    TYPE vrsd-zeit,
           END OF ty_vrs.

    DATA lt_deltamap TYPE SORTED TABLE OF ty_map WITH UNIQUE KEY ent_up.
    DATA lt_dcmap    TYPE SORTED TABLE OF ty_dc  WITH NON-UNIQUE KEY ent_up.
    DATA lt_labmap   TYPE SORTED TABLE OF ty_lab WITH NON-UNIQUE KEY ent_up.
    DATA lt_depmap   TYPE SORTED TABLE OF ty_dep WITH NON-UNIQUE KEY ddl_up.
    DATA lt_latest   TYPE SORTED TABLE OF ty_vrs WITH UNIQUE KEY objname.
    DATA lt_vrsd     TYPE STANDARD TABLE OF ty_vrs WITH DEFAULT KEY.
    DATA lt_dfies    TYPE STANDARD TABLE OF dfies WITH DEFAULT KEY.
    DATA lt_api_sel  TYPE ty_entity_range.
    DATA lt_name_sel TYPE ty_entity_range.
    DATA lt_obj_rng  TYPE RANGE OF vrsd-objname.

    DATA ls_out    TYPE ty_view.
    DATA ls_m      TYPE ty_map.
    DATA ls_dcm    TYPE ty_dc.
    DATA ls_lbl    TYPE ty_lab.
    DATA ls_dep    TYPE ty_dep.
    DATA ls_latest TYPE ty_vrs.
    DATA ls_vrsd   TYPE ty_vrs.
    DATA ls_dfies  TYPE dfies.
    DATA ls_range   TYPE LINE OF ty_entity_range.
    DATA ls_obj_rng LIKE LINE OF lt_obj_rng.

    DATA lv_source  TYPE c LENGTH 1.
    DATA lv_ent_up  TYPE c LENGTH 40.
    DATA lv_name    TYPE c LENGTH 40.
    DATA lv_dc      TYPE c LENGTH 20.
    DATA lv_lab     TYPE c LENGTH 60.
    DATA lv_objname TYPE vrsd-objname.
    DATA lv_tab     TYPE ddobjname.

    FIELD-SYMBOLS <view> TYPE ty_view.

    lv_source = to_upper( condense( CONV string( iv_source ) ) ).
    IF lv_source IS INITIAL.
      lv_source = 'D'.
    ENDIF.

    " Normalize select-options: EQ with * / + -> CP.
    lt_name_sel = it_name_range.
    LOOP AT lt_name_sel INTO ls_range.
      IF ( ls_range-option = 'EQ' OR ls_range-option = 'CP' )
         AND ( ls_range-low CS '*' OR ls_range-low CS '+' ).
        ls_range-option = 'CP'.
        MODIFY lt_name_sel FROM ls_range.
      ENDIF.
    ENDLOOP.

    lt_api_sel = it_api_range.
    LOOP AT lt_api_sel INTO ls_range.
      IF ( ls_range-option = 'EQ' OR ls_range-option = 'CP' )
         AND ( ls_range-low CS '*' OR ls_range-low CS '+' ).
        ls_range-option = 'CP'.
        MODIFY lt_api_sel FROM ls_range.
      ENDIF.
    ENDLOOP.

    " 1) @Semantics.systemDateTime.lastChangedAt
    SELECT strucobjn, lfieldname
      FROM ddfieldanno
      WHERE upper( name ) = 'SEMANTICS.SYSTEMDATETIME.LASTCHANGEDAT'
      INTO TABLE @DATA(lt_ts).
    LOOP AT lt_ts INTO DATA(ls_ts).
      CLEAR ls_m.
      ls_m-ent_up = to_upper( ls_ts-strucobjn ).
      ls_m-field  = ls_ts-lfieldname.
      INSERT ls_m INTO TABLE lt_deltamap.
    ENDLOOP.

    " 2) @Semantics.systemDateTime.localInstanceLastChangedAt
    SELECT strucobjn, lfieldname
      FROM ddfieldanno
      WHERE upper( name ) = 'SEMANTICS.SYSTEMDATETIME.LOCALINSTANCELASTCHANGEDAT'
      INTO TABLE @DATA(lt_ts_loc).
    LOOP AT lt_ts_loc INTO DATA(ls_ts_loc).
      CLEAR ls_m.
      ls_m-ent_up = to_upper( ls_ts_loc-strucobjn ).
      ls_m-field  = ls_ts_loc-lfieldname.
      INSERT ls_m INTO TABLE lt_deltamap.
    ENDLOOP.

    " 3) Annotated element named LastChangeDateTime
    SELECT strucobjn, lfieldname
      FROM ddfieldanno
      WHERE upper( lfieldname ) = 'LASTCHANGEDATETIME'
      INTO TABLE @DATA(lt_anno_lcdt).
    LOOP AT lt_anno_lcdt INTO DATA(ls_anno_lcdt).
      CLEAR ls_m.
      ls_m-ent_up = to_upper( ls_anno_lcdt-strucobjn ).
      ls_m-field  = ls_anno_lcdt-lfieldname.
      INSERT ls_m INTO TABLE lt_deltamap.
    ENDLOOP.

    " 4) DDIC field LastChangeDateTime
    SELECT tabname, fieldname
      FROM dd03l
      WHERE fieldname = 'LASTCHANGEDATETIME'
        AND as4local  = 'A'
      INTO TABLE @DATA(lt_lcdt).
    LOOP AT lt_lcdt INTO DATA(ls_lcdt).
      CLEAR ls_m.
      ls_m-ent_up = to_upper( ls_lcdt-tabname ).
      ls_m-field  = ls_lcdt-fieldname.
      INSERT ls_m INTO TABLE lt_deltamap.
    ENDLOOP.

    " 5) CDS DDL name <-> SQL/DDIC object via DDLDEPENDENCY
    SELECT ddlname, objectname
      FROM ddldependency
      WHERE objecttype = 'VIEW'
         OR objecttype = 'STOB'
      INTO TABLE @DATA(lt_dep).
    LOOP AT lt_dep INTO DATA(ls_dep_row).
      CLEAR ls_dep.
      ls_dep-ddl_up = to_upper( CONV string( ls_dep_row-ddlname ) ).
      ls_dep-obj_up = to_upper( CONV string( ls_dep_row-objectname ) ).
      INSERT ls_dep INTO TABLE lt_depmap.

      READ TABLE lt_deltamap INTO ls_m WITH TABLE KEY ent_up = ls_dep-obj_up.
      IF sy-subrc = 0.
        ls_m-ent_up = ls_dep-ddl_up.
        INSERT ls_m INTO TABLE lt_deltamap.
      ENDIF.

      READ TABLE lt_deltamap INTO ls_m WITH TABLE KEY ent_up = ls_dep-ddl_up.
      IF sy-subrc = 0.
        ls_m-ent_up = ls_dep-obj_up.
        INSERT ls_m INTO TABLE lt_deltamap.
      ENDIF.
    ENDLOOP.

    SELECT strucobjn, value AS dclass
      FROM ddheadanno
      WHERE upper( name ) = 'OBJECTMODEL.USAGETYPE.DATACLASS'
      INTO TABLE @DATA(lt_dc).
    LOOP AT lt_dc INTO DATA(ls_dc).
      CLEAR ls_dcm.
      lv_dc = to_upper( CONV string( ls_dc-dclass ) ).
      REPLACE ALL OCCURRENCES OF `#` IN lv_dc WITH space.
      REPLACE ALL OCCURRENCES OF `'` IN lv_dc WITH space.
      CONDENSE lv_dc NO-GAPS.
      ls_dcm-ent_up = to_upper( ls_dc-strucobjn ).
      ls_dcm-dclass = lv_dc.
      INSERT ls_dcm INTO TABLE lt_dcmap.
    ENDLOOP.

    SELECT strucobjn, value AS label
      FROM ddheadanno
      WHERE upper( name ) = 'ENDUSERTEXT.LABEL'
      INTO TABLE @DATA(lt_lab).
    LOOP AT lt_lab INTO DATA(ls_lab).
      CLEAR ls_lbl.
      lv_lab = CONV string( ls_lab-label ).
      REPLACE ALL OCCURRENCES OF `'` IN lv_lab WITH space.
      CONDENSE lv_lab.
      ls_lbl-ent_up = to_upper( ls_lab-strucobjn ).
      ls_lbl-label  = lv_lab.
      INSERT ls_lbl INTO TABLE lt_labmap.
    ENDLOOP.

    " ------------------------------------------------------------------
    " DEX
    " ------------------------------------------------------------------
    IF lv_source = 'D' OR lv_source = 'B'.
      IF lt_name_sel IS INITIAL.
        SELECT dataextractionviewname,
               dataextractionviewdescription,
               deltachgdatacaptureissupported
          FROM ixtrctnenbldvw
          WHERE issapreleasedview = @abap_true
          ORDER BY dataextractionviewname
          INTO TABLE @DATA(lt_dex).
      ELSE.
        SELECT dataextractionviewname,
               dataextractionviewdescription,
               deltachgdatacaptureissupported
          FROM ixtrctnenbldvw
          WHERE issapreleasedview = @abap_true
            AND dataextractionviewname IN @lt_name_sel
          ORDER BY dataextractionviewname
          INTO TABLE @lt_dex.
      ENDIF.

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

        READ TABLE lt_deltamap INTO ls_m WITH TABLE KEY ent_up = lv_ent_up.
        IF sy-subrc = 0 AND ls_m-field IS NOT INITIAL.
          ls_out-delta_field   = ls_m-field.
          ls_out-delta_capable = abap_true.
        ELSE.
          CLEAR lt_dfies.
          lv_tab = lv_ent_up.
          CALL FUNCTION 'DDIF_FIELDINFO_GET'
            EXPORTING
              tabname   = lv_tab
            TABLES
              dfies_tab = lt_dfies
            EXCEPTIONS
              not_found = 1
              OTHERS    = 2.
          IF sy-subrc = 0.
            READ TABLE lt_dfies INTO ls_dfies
                 WITH KEY fieldname = 'LASTCHANGEDATETIME'.
            IF sy-subrc = 0.
              ls_out-delta_field   = ls_dfies-fieldname.
              ls_out-delta_capable = abap_true.
              CLEAR ls_m.
              ls_m-ent_up = lv_ent_up.
              ls_m-field  = ls_dfies-fieldname.
              INSERT ls_m INTO TABLE lt_deltamap.
            ENDIF.
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
      IF lt_api_sel IS INITIAL.
        APPEND VALUE #( sign = 'I' option = 'CP' low = 'I_*API*' ) TO lt_api_sel.
      ENDIF.

      SELECT obj_name
        FROM tadir
        WHERE pgmid  = 'R3TR'
          AND object = 'DDLS'
          AND obj_name IN @lt_api_sel
        ORDER BY obj_name
        INTO TABLE @DATA(lt_api).

      LOOP AT lt_api INTO DATA(ls_api).
        lv_name = ls_api-obj_name.
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

        READ TABLE lt_deltamap INTO ls_m WITH TABLE KEY ent_up = lv_ent_up.
        IF sy-subrc = 0 AND ls_m-field IS NOT INITIAL.
          ls_out-delta_field   = ls_m-field.
          ls_out-delta_capable = abap_true.
        ELSE.
          LOOP AT lt_depmap INTO ls_dep WHERE ddl_up = lv_ent_up.
            READ TABLE lt_deltamap INTO ls_m WITH TABLE KEY ent_up = ls_dep-obj_up.
            IF sy-subrc = 0 AND ls_m-field IS NOT INITIAL.
              ls_out-delta_field   = ls_m-field.
              ls_out-delta_capable = abap_true.
              CLEAR ls_m.
              ls_m-ent_up = lv_ent_up.
              ls_m-field  = ls_out-delta_field.
              INSERT ls_m INTO TABLE lt_deltamap.
              EXIT.
            ENDIF.
          ENDLOOP.
        ENDIF.

        IF ls_out-delta_capable = abap_false.
          CLEAR lt_dfies.
          lv_tab = lv_ent_up.
          CALL FUNCTION 'DDIF_FIELDINFO_GET'
            EXPORTING
              tabname   = lv_tab
            TABLES
              dfies_tab = lt_dfies
            EXCEPTIONS
              not_found = 1
              OTHERS    = 2.
          IF sy-subrc <> 0.
            LOOP AT lt_depmap INTO ls_dep WHERE ddl_up = lv_ent_up.
              CLEAR lt_dfies.
              lv_tab = ls_dep-obj_up.
              CALL FUNCTION 'DDIF_FIELDINFO_GET'
                EXPORTING
                  tabname   = lv_tab
                TABLES
                  dfies_tab = lt_dfies
                EXCEPTIONS
                  not_found = 1
                  OTHERS    = 2.
              IF sy-subrc = 0.
                EXIT.
              ENDIF.
            ENDLOOP.
          ENDIF.
          IF lt_dfies IS NOT INITIAL.
            READ TABLE lt_dfies INTO ls_dfies
                 WITH KEY fieldname = 'LASTCHANGEDATETIME'.
            IF sy-subrc = 0.
              ls_out-delta_field   = ls_dfies-fieldname.
              ls_out-delta_capable = abap_true.
              CLEAR ls_m.
              ls_m-ent_up = lv_ent_up.
              ls_m-field  = ls_dfies-fieldname.
              INSERT ls_m INTO TABLE lt_deltamap.
            ENDIF.
          ENDIF.
        ENDIF.

        IF io_delta_store IS BOUND.
          ls_out-last_delta_ts = io_delta_store->get_last( ls_out-entity_name ).
        ENDIF.

        APPEND ls_out TO rt_views.
      ENDLOOP.
    ENDIF.

    " ------------------------------------------------------------------
    " Repository last-changed (VRSD) - compare A_* vs A_*_2 etc.
    " Use IN range (no FOR ALL ENTRIES) so OBJNAME length cannot mismatch.
    " ------------------------------------------------------------------
    IF rt_views IS NOT INITIAL.
      CLEAR: lt_obj_rng, lt_latest, lt_vrsd.

      LOOP AT rt_views INTO ls_out.
        CLEAR ls_obj_rng.
        ls_obj_rng-sign   = 'I'.
        ls_obj_rng-option = 'EQ'.
        ls_obj_rng-low    = to_upper( ls_out-entity_name ).
        APPEND ls_obj_rng TO lt_obj_rng.
      ENDLOOP.
      SORT lt_obj_rng BY low.
      DELETE ADJACENT DUPLICATES FROM lt_obj_rng COMPARING low.

      IF lt_obj_rng IS NOT INITIAL.
        SELECT objname versno datum zeit
          FROM vrsd
          INTO TABLE lt_vrsd
          WHERE objtype = 'DDLS'
            AND objname IN lt_obj_rng.
      ENDIF.

      LOOP AT lt_vrsd INTO ls_vrsd.
        READ TABLE lt_latest INTO ls_latest
             WITH TABLE KEY objname = ls_vrsd-objname.
        IF sy-subrc <> 0.
          INSERT ls_vrsd INTO TABLE lt_latest.
        ELSEIF ls_vrsd-datum > ls_latest-datum
           OR ( ls_vrsd-datum = ls_latest-datum
                AND ls_vrsd-zeit > ls_latest-zeit )
           OR ( ls_vrsd-datum = ls_latest-datum
                AND ls_vrsd-zeit = ls_latest-zeit
                AND ls_vrsd-versno > ls_latest-versno ).
          DELETE TABLE lt_latest WITH TABLE KEY objname = ls_vrsd-objname.
          INSERT ls_vrsd INTO TABLE lt_latest.
        ENDIF.
      ENDLOOP.

      LOOP AT rt_views ASSIGNING <view>.
        lv_objname = to_upper( <view>-entity_name ).
        READ TABLE lt_latest INTO ls_latest
             WITH TABLE KEY objname = lv_objname.
        IF sy-subrc = 0.
          <view>-last_changed_date = ls_latest-datum.
          <view>-last_changed_time = ls_latest-zeit.
        ENDIF.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
