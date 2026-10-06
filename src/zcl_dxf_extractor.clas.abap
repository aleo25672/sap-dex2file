" Extract data from a CDS entity into a dynamic table.
"   Full   : SELECT * FROM (entity)
"   Delta  : SELECT * FROM (entity) WHERE <change-ts field> > <last high-water>
"   Bounded: SELECT * FROM (entity) WHERE <change-ts field> >= <from> [AND <= <to>]
" Delta and Bounded both need the change-timestamp field (delta-capable views only).
" Returns a ref to the table + row count + the new high-water (captured at run
" start, so a later delta never misses concurrent changes).
CLASS zcl_dxf_extractor DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_result,
        data_ref  TYPE REF TO data,
        row_count TYPE i,
        new_high  TYPE timestampl,
        status    TYPE c LENGTH 1,   " S ok | E error | K skipped
        message   TYPE string,
      END OF ty_result.

    " @parameter iv_entity   | CDS entity name
    " @parameter iv_delta    | abap_true = delta (rows changed after iv_last)
    " @parameter iv_bounded  | abap_true = bounded window on the change-timestamp field
    " @parameter iv_ts_field | change-timestamp field (delta / bounded only)
    " @parameter iv_last     | last high-water (delta only)
    " @parameter iv_from     | window start, inclusive (bounded only; initial = open)
    " @parameter iv_to       | window end,   inclusive (bounded only; initial = open)
    " @parameter iv_max_rows | 0 = unlimited
    METHODS extract
      IMPORTING
        iv_entity        TYPE clike
        iv_delta         TYPE abap_bool  DEFAULT abap_false
        iv_bounded       TYPE abap_bool  DEFAULT abap_false
        iv_ts_field      TYPE clike      OPTIONAL
        iv_last          TYPE timestampl OPTIONAL
        iv_from          TYPE timestampl OPTIONAL
        iv_to            TYPE timestampl OPTIONAL
        iv_max_rows      TYPE i          DEFAULT 0
      RETURNING
        VALUE(rs_result) TYPE ty_result.
ENDCLASS.


CLASS zcl_dxf_extractor IMPLEMENTATION.

  METHOD extract.
    " Delta and Bounded both filter on the change-timestamp field.
    DATA(lv_needs_ts) = xsdbool( iv_delta = abap_true OR iv_bounded = abap_true ).
    IF lv_needs_ts = abap_true AND iv_ts_field IS INITIAL.
      rs_result-status  = 'K'.
      rs_result-message = 'Delta/bounded not possible: no change-timestamp field'.
      RETURN.
    ENDIF.

    IF iv_bounded = abap_true AND iv_from IS INITIAL AND iv_to IS INITIAL.
      rs_result-status  = 'E'.
      rs_result-message = 'Bounded extract needs a from and/or to timestamp'.
      RETURN.
    ENDIF.

    " High-water = start of this run (so concurrent changes are re-read, not lost).
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.

    TRY.
        DATA lr_tab TYPE REF TO data.
        CREATE DATA lr_tab TYPE TABLE OF (iv_entity).
        ASSIGN lr_tab->* TO FIELD-SYMBOL(<lt>).

        " Dynamic WHERE on the change-timestamp field. Values are embedded as
        " literals (verify the field's literal format on your release if a run
        " returns nothing / dumps).
        DATA lv_where TYPE string.
        IF iv_delta = abap_true.
          lv_where = |{ iv_ts_field } > '{ condense( |{ iv_last }| ) }'|.
        ELSEIF iv_bounded = abap_true.
          IF iv_from IS NOT INITIAL.
            lv_where = |{ iv_ts_field } >= '{ condense( |{ iv_from }| ) }'|.
          ENDIF.
          IF iv_to IS NOT INITIAL.
            DATA(lv_hi) = |{ iv_ts_field } <= '{ condense( |{ iv_to }| ) }'|.
            lv_where = COND string( WHEN lv_where IS INITIAL THEN lv_hi
                                    ELSE |{ lv_where } AND { lv_hi }| ).
          ENDIF.
        ENDIF.

        IF lv_where IS NOT INITIAL.
          IF iv_max_rows > 0.
            SELECT * FROM (iv_entity) WHERE (lv_where)
              INTO TABLE @<lt> UP TO @iv_max_rows ROWS.
          ELSE.
            SELECT * FROM (iv_entity) WHERE (lv_where)
              INTO TABLE @<lt>.
          ENDIF.
        ELSE.
          IF iv_max_rows > 0.
            SELECT * FROM (iv_entity) INTO TABLE @<lt> UP TO @iv_max_rows ROWS.
          ELSE.
            SELECT * FROM (iv_entity) INTO TABLE @<lt>.
          ENDIF.
        ENDIF.

        rs_result-data_ref  = lr_tab.
        rs_result-row_count = lines( <lt> ).
        rs_result-new_high  = lv_now.
        rs_result-status    = 'S'.
        rs_result-message   = |{ rs_result-row_count } row(s) extracted|.

      CATCH cx_root INTO DATA(lx).
        rs_result-status  = 'E'.
        rs_result-message = lx->get_text( ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
