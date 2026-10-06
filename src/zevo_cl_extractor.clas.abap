" Extract data from a CDS entity into a dynamic table.
"   Full   : SELECT * FROM (entity)
"   Delta  : SELECT * FROM (entity) WHERE <change-ts field> > <last high-water>
"   Bounded: SELECT * FROM (entity) WHERE <change-ts field> >= <from> [AND <= <to>]
"            (full extract if the view has no change-timestamp field)
"   extract_ex adds OData $filter (as OpenSQL WHERE), Skip/Top pagination,
"   totalCount, and maxChangedAt for caller-managed delta.
CLASS zevo_cl_extractor DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_default_top TYPE i VALUE 1000.
    CONSTANTS c_max_top     TYPE i VALUE 10000.

    TYPES:
      BEGIN OF ty_result,
        data_ref  TYPE REF TO data,
        row_count TYPE i,
        new_high  TYPE timestampl,
        status    TYPE c LENGTH 1,   " S ok | E error | K skipped
        message   TYPE string,
      END OF ty_result.

    TYPES:
      BEGIN OF ty_result_ex,
        data_ref       TYPE REF TO data,
        row_count      TYPE i,
        total_count    TYPE i,
        skip           TYPE i,
        top            TYPE i,
        delta_field    TYPE string,
        max_changed_at TYPE string,
        new_high       TYPE timestampl,
        status         TYPE c LENGTH 1,
        message        TYPE string,
      END OF ty_result_ex.

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

    " Extended extract for OData: optional OpenSQL WHERE, Skip/Top, total count.
    METHODS extract_ex
      IMPORTING
        iv_entity        TYPE clike
        iv_where         TYPE clike      OPTIONAL
        iv_delta         TYPE abap_bool  DEFAULT abap_false
        iv_ts_field      TYPE clike      OPTIONAL
        iv_last          TYPE timestampl OPTIONAL
        iv_skip          TYPE i          DEFAULT 0
        iv_top           TYPE i          DEFAULT c_default_top
      RETURNING
        VALUE(rs_result) TYPE ty_result_ex.

  PRIVATE SECTION.
    METHODS build_where
      IMPORTING
        iv_where         TYPE clike
        iv_delta         TYPE abap_bool
        iv_ts_field      TYPE clike
        iv_last          TYPE timestampl
      RETURNING
        VALUE(rv_where)  TYPE string.
    METHODS read_max_changed
      IMPORTING
        ir_data     TYPE REF TO data
        iv_ts_field TYPE clike
      RETURNING
        VALUE(rv_max) TYPE string.
ENDCLASS.


CLASS zevo_cl_extractor IMPLEMENTATION.

  METHOD extract.
    " Delta still requires a change-timestamp (skip). Bounded without one
    " falls back to a full extract instead of skipping.
    DATA lv_full_fallback TYPE abap_bool.

    IF iv_delta = abap_true AND iv_ts_field IS INITIAL.
      rs_result-status  = 'K'.
      rs_result-message = 'Delta not possible: no change-timestamp field'.
      RETURN.
    ENDIF.

    lv_full_fallback = xsdbool( iv_bounded = abap_true AND iv_ts_field IS INITIAL ).

    IF iv_bounded = abap_true AND lv_full_fallback = abap_false
        AND iv_from IS INITIAL AND iv_to IS INITIAL.
      rs_result-status  = 'E'.
      rs_result-message = 'Bounded extract needs a from and/or to timestamp'.
      RETURN.
    ENDIF.

    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.

    TRY.
        DATA lr_tab TYPE REF TO data.
        CREATE DATA lr_tab TYPE TABLE OF (iv_entity).
        ASSIGN lr_tab->* TO FIELD-SYMBOL(<lt>).

        " Dynamic WHERE on the change-timestamp field. Conditions are not
        " wrapped in "( ... )" (dynamic OpenSQL on CDS entities rejects those).
        DATA lv_where TYPE string.
        IF iv_delta = abap_true.
          lv_where = |{ iv_ts_field } > '{ condense( |{ iv_last }| ) }'|.
        ELSEIF iv_bounded = abap_true AND lv_full_fallback = abap_false.
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
        IF lv_full_fallback = abap_true.
          rs_result-message = |{ rs_result-row_count } row(s) extracted (full: no change-timestamp for bounded)|.
        ELSE.
          rs_result-message = |{ rs_result-row_count } row(s) extracted|.
        ENDIF.

      CATCH cx_root INTO DATA(lx).
        rs_result-status  = 'E'.
        rs_result-message = lx->get_text( ).
    ENDTRY.
  ENDMETHOD.

  METHOD extract_ex.
    DATA lv_top   TYPE i.
    DATA lv_skip  TYPE i.
    DATA lv_now   TYPE timestampl.
    DATA lv_where TYPE string.
    DATA lv_fetch TYPE i.
    DATA lv_idx   TYPE i.
    DATA lr_tab   TYPE REF TO data.
    DATA lx       TYPE REF TO cx_root.
    FIELD-SYMBOLS <lt> TYPE STANDARD TABLE.

    CLEAR rs_result.

    IF iv_skip < 0.
      lv_skip = 0.
    ELSE.
      lv_skip = iv_skip.
    ENDIF.
    rs_result-skip = lv_skip.

    lv_top = iv_top.
    IF lv_top <= 0.
      lv_top = c_default_top.
    ENDIF.
    IF lv_top > c_max_top.
      lv_top = c_max_top.
    ENDIF.
    rs_result-top = lv_top.

    IF iv_delta = abap_true AND iv_ts_field IS INITIAL.
      rs_result-status  = 'K'.
      rs_result-message = 'Delta not possible: no change-timestamp field'.
      RETURN.
    ENDIF.

    GET TIME STAMP FIELD lv_now.
    rs_result-new_high = lv_now.
    rs_result-delta_field = iv_ts_field.

    lv_where = build_where(
      iv_where    = iv_where
      iv_delta    = iv_delta
      iv_ts_field = iv_ts_field
      iv_last     = iv_last ).

    TRY.
        IF lv_where IS INITIAL.
          SELECT COUNT( * ) FROM (iv_entity) INTO @rs_result-total_count.
        ELSE.
          SELECT COUNT( * ) FROM (iv_entity)
            WHERE (lv_where)
            INTO @rs_result-total_count.
        ENDIF.

        " STANDARD TABLE so OFFSET/UP TO and DELETE INDEX are allowed
        CREATE DATA lr_tab TYPE STANDARD TABLE OF (iv_entity).
        ASSIGN lr_tab->* TO <lt>.

        " Prefer ORDER BY PRIMARY KEY + OFFSET (no dynamic ORDER BY "(col)"
        " tokens — those trigger OpenSQL "(" parser errors on some CDS view
        " entities). Fall back to UP TO skip+top without ORDER BY.
        TRY.
            IF lv_where IS INITIAL.
              SELECT * FROM (iv_entity)
                ORDER BY PRIMARY KEY
                INTO TABLE @<lt>
                UP TO @lv_top ROWS OFFSET @lv_skip.
            ELSE.
              SELECT * FROM (iv_entity)
                WHERE (lv_where)
                ORDER BY PRIMARY KEY
                INTO TABLE @<lt>
                UP TO @lv_top ROWS OFFSET @lv_skip.
            ENDIF.
          CATCH cx_root.
            " PRIMARY KEY / OFFSET not accepted for this entity — page locally.
            CLEAR <lt>.
            lv_fetch = lv_skip + lv_top.
            IF lv_where IS INITIAL.
              SELECT * FROM (iv_entity)
                INTO TABLE @<lt>
                UP TO @lv_fetch ROWS.
            ELSE.
              SELECT * FROM (iv_entity)
                WHERE (lv_where)
                INTO TABLE @<lt>
                UP TO @lv_fetch ROWS.
            ENDIF.
            IF lv_skip > 0 AND lines( <lt> ) > 0.
              lv_idx = 1.
              WHILE lv_idx <= lv_skip AND <lt> IS NOT INITIAL.
                DELETE <lt> INDEX 1.
                lv_idx = lv_idx + 1.
              ENDWHILE.
            ENDIF.
        ENDTRY.

        rs_result-data_ref  = lr_tab.
        rs_result-row_count = lines( <lt> ).
        IF iv_ts_field IS NOT INITIAL.
          rs_result-max_changed_at = read_max_changed(
            ir_data = lr_tab iv_ts_field = iv_ts_field ).
        ENDIF.
        rs_result-status  = 'S'.
        rs_result-message = |{ rs_result-row_count } row(s), total { rs_result-total_count }|.

      CATCH cx_root INTO lx.
        rs_result-status  = 'E'.
        rs_result-message = lx->get_text( ).
    ENDTRY.
  ENDMETHOD.

  METHOD build_where.
    DATA lt_parts TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    DATA lv_part  TYPE string.
    DATA lv_1     TYPE string.
    DATA lv_2     TYPE string.
    DATA lv_where TYPE string.
    DATA lv_last  TYPE string.

    IF iv_where IS NOT INITIAL.
      lv_where = iv_where.
      CONDENSE lv_where.
      " Do not wrap in "( ... )" — dynamic OpenSQL on CDS view entities
      " rejects those parentheses ("(" is not valid here).
      APPEND lv_where TO lt_parts.
    ENDIF.
    IF iv_delta = abap_true AND iv_ts_field IS NOT INITIAL.
      lv_last = |{ iv_last }|.
      CONDENSE lv_last.
      lv_part = |{ to_upper( condense( CONV string( iv_ts_field ) ) ) } > '{ lv_last }'|.
      APPEND lv_part TO lt_parts.
    ENDIF.
    CASE lines( lt_parts ).
      WHEN 0.
        CLEAR rv_where.
      WHEN 1.
        READ TABLE lt_parts INTO rv_where INDEX 1.
      WHEN OTHERS.
        READ TABLE lt_parts INTO lv_1 INDEX 1.
        READ TABLE lt_parts INTO lv_2 INDEX 2.
        rv_where = |{ lv_1 } AND { lv_2 }|.
    ENDCASE.
  ENDMETHOD.

  METHOD read_max_changed.
    FIELD-SYMBOLS <lt> TYPE ANY TABLE.
    ASSIGN ir_data->* TO <lt>.
    DATA(lv_field) = to_upper( condense( CONV string( iv_ts_field ) ) ).
    LOOP AT <lt> ASSIGNING FIELD-SYMBOL(<ls>).
      ASSIGN COMPONENT lv_field OF STRUCTURE <ls> TO FIELD-SYMBOL(<v>).
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      DATA(lv_cur) = |{ <v> }|.
      CONDENSE lv_cur.
      IF rv_max IS INITIAL OR lv_cur > rv_max.
        rv_max = lv_cur.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
