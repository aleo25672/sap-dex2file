" Discover released, extraction-enabled (DEX) CDS views and, for each, detect the
" change-timestamp field used for timestamp-based delta.
"   - Views come from IXTRCTNENBLDVW (released only).
"   - The delta field is the element annotated @Semantics.systemDateTime.lastChangedAt,
"     read from the field-annotation table DDFIELDANNO. delta_capable = such a field exists.
CLASS zcl_dxf_catalog DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_view,
        entity_name    TYPE c LENGTH 60,
        description    TYPE c LENGTH 60,
        family         TYPE c LENGTH 20,   " data class (@ObjectModel.usageType.dataClass)
        is_cdc_enabled TYPE abap_bool,
        delta_field    TYPE c LENGTH 30,   " @Semantics.systemDateTime.lastChangedAt element
        delta_capable  TYPE abap_bool,     " a change-timestamp field exists
        last_delta_ts  TYPE timestampl,    " stored high-water (last extracted up to)
        reason         TYPE string,
      END OF ty_view,
      ty_views TYPE STANDARD TABLE OF ty_view WITH DEFAULT KEY.

    " @parameter iv_name_pattern | optional entity filter; plain text = contains, '*' = wildcard
    " @parameter io_delta_store  | optional, fills the stored high-water per view
    " @parameter iv_dataclass | data-class filter: ' ' = all, 'M' = MASTER, 'T' = TRANSACTIONAL
    METHODS get_views
      IMPORTING
        iv_name_pattern TYPE clike OPTIONAL
        iv_dataclass    TYPE clike DEFAULT space
        io_delta_store  TYPE REF TO zcl_dxf_delta_store OPTIONAL
      RETURNING
        VALUE(rt_views) TYPE ty_views.
ENDCLASS.


CLASS zcl_dxf_catalog IMPLEMENTATION.

  METHOD get_views.
    " Name filter (case-sensitive): empty = all, '*' = wildcard, plain text = contains.
    DATA(lv_pattern) = condense( CONV string( iv_name_pattern ) ).
    IF lv_pattern IS INITIAL.
      lv_pattern = '%'.
    ELSEIF lv_pattern CA '*'.
      REPLACE ALL OCCURRENCES OF '*' IN lv_pattern WITH '%'.
    ELSE.
      lv_pattern = |%{ lv_pattern }%|.
    ENDIF.

    SELECT dataextractionviewname,
           dataextractionviewdescription,
           deltachgdatacaptureissupported
      FROM ixtrctnenbldvw
      WHERE issapreleasedview = @abap_true
        AND dataextractionviewname LIKE @lv_pattern
      ORDER BY dataextractionviewname
      INTO TABLE @DATA(lt_views).

    " Change-timestamp field per view (@Semantics.systemDateTime.lastChangedAt).
    " Verify the exact annotation NAME on the release (as with DDHEADANNO earlier).
    SELECT strucobjn, lfieldname
      FROM ddfieldanno
      WHERE upper( name ) = 'SEMANTICS.SYSTEMDATETIME.LASTCHANGEDAT'
      INTO TABLE @DATA(lt_ts).

    TYPES: BEGIN OF ty_map,
             ent_up TYPE string,
             field  TYPE c LENGTH 30,
           END OF ty_map.
    DATA lt_tsmap TYPE SORTED TABLE OF ty_map WITH NON-UNIQUE KEY ent_up.
    LOOP AT lt_ts INTO DATA(ls_ts).
      INSERT VALUE #( ent_up = to_upper( ls_ts-strucobjn )
                      field  = ls_ts-lfieldname ) INTO TABLE lt_tsmap.
    ENDLOOP.

    " Data class per view (@ObjectModel.usageType.dataClass, header annotation in
    " DDHEADANNO). The I_/C_ prefix does NOT indicate the category - read the real
    " annotation. VALUE looks like '#TRANSACTIONAL'; strip the leading '#'.
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

    LOOP AT lt_views INTO DATA(ls_view).
      DATA(ls_out) = VALUE ty_view(
        entity_name    = ls_view-dataextractionviewname
        description    = ls_view-dataextractionviewdescription
        is_cdc_enabled = ls_view-deltachgdatacaptureissupported ).

      " real data class from @ObjectModel.usageType.dataClass (MASTER / TRANSACTIONAL / ...)
      READ TABLE lt_dcmap INTO DATA(ls_dcm)
           WITH KEY ent_up = to_upper( ls_view-dataextractionviewname ).
      IF sy-subrc = 0.
        ls_out-family = ls_dcm-dclass.
      ENDIF.

      " optional data-class filter
      IF ( iv_dataclass = 'M' AND ls_out-family <> 'MASTER' )
      OR ( iv_dataclass = 'T' AND ls_out-family <> 'TRANSACTIONAL' ).
        CONTINUE.
      ENDIF.

      READ TABLE lt_tsmap INTO DATA(ls_m)
           WITH KEY ent_up = to_upper( ls_view-dataextractionviewname ).
      IF sy-subrc = 0 AND ls_m-field IS NOT INITIAL.
        ls_out-delta_field   = ls_m-field.
        ls_out-delta_capable = abap_true.
      ENDIF.

      IF io_delta_store IS BOUND.
        ls_out-last_delta_ts = io_delta_store->get_last( ls_out-entity_name ).
      ENDIF.

      APPEND ls_out TO rt_views.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
