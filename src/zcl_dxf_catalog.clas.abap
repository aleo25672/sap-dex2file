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
        family         TYPE c LENGTH 13,   " TRANSACTIONAL / MASTER DATA / OTHER
        is_cdc_enabled TYPE abap_bool,
        delta_field    TYPE c LENGTH 30,   " @Semantics.systemDateTime.lastChangedAt element
        delta_capable  TYPE abap_bool,     " a change-timestamp field exists
        last_delta_ts  TYPE timestampl,    " stored high-water (last extracted up to)
        reason         TYPE string,
      END OF ty_view,
      ty_views TYPE STANDARD TABLE OF ty_view WITH DEFAULT KEY.

    " @parameter iv_name_pattern | optional entity filter; plain text = contains, '*' = wildcard
    " @parameter io_delta_store  | optional, fills the stored high-water per view
    " @parameter iv_family | family filter: ' ' = all, 'C' = C_*DEX, 'I' = I_*
    METHODS get_views
      IMPORTING
        iv_name_pattern TYPE clike OPTIONAL
        iv_family       TYPE clike DEFAULT space
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

    LOOP AT lt_views INTO DATA(ls_view).
      DATA(ls_out) = VALUE ty_view(
        entity_name    = ls_view-dataextractionviewname
        description    = ls_view-dataextractionviewdescription
        is_cdc_enabled = ls_view-deltachgdatacaptureissupported ).

      " family classification + optional filter
      IF ls_view-dataextractionviewname CP 'C_*DEX'.
        ls_out-family = 'TRANSACTIONAL'.
      ELSEIF ls_view-dataextractionviewname CP 'I_*'.
        ls_out-family = 'MASTER DATA'.
      ELSE.
        ls_out-family = 'OTHER'.
      ENDIF.

      IF ( iv_family = 'C' AND ls_out-family <> 'TRANSACTIONAL' )
      OR ( iv_family = 'I' AND ls_out-family <> 'MASTER DATA' ).
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
