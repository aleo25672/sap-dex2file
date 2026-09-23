" Extract data from a CDS entity into a dynamic table.
"   Full  : SELECT * FROM (entity)
"   Delta : SELECT * FROM (entity) WHERE <change-ts field> > <last high-water>
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
    " @parameter iv_delta    | abap_true = delta, else full
    " @parameter iv_ts_field | change-timestamp field (delta only)
    " @parameter iv_last     | last high-water (delta only)
    " @parameter iv_max_rows | 0 = unlimited
    METHODS extract
      IMPORTING
        iv_entity        TYPE clike
        iv_delta         TYPE abap_bool  DEFAULT abap_false
        iv_ts_field      TYPE clike      OPTIONAL
        iv_last          TYPE timestampl OPTIONAL
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
    METHODS build_order_by
      IMPORTING iv_entity TYPE clike
      RETURNING VALUE(rv_order) TYPE string.
    METHODS read_max_changed
      IMPORTING
        ir_data     TYPE REF TO data
        iv_ts_field TYPE clike
      RETURNING
        VALUE(rv_max) TYPE string.
ENDCLASS.


CLASS zevo_cl_extractor IMPLEMENTATION.

  METHOD extract.
    IF iv_delta = abap_true AND iv_ts_field IS INITIAL.
      rs_result-status  = 'K'.
      rs_result-message = 'Delta not possible: no change-timestamp field'.
      RETURN.
    ENDIF.

    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.

    TRY.
        DATA lr_tab TYPE REF TO data.
        CREATE DATA lr_tab TYPE TABLE OF (iv_entity).
        ASSIGN lr_tab->* TO FIELD-SYMBOL(<lt>).

        IF iv_delta = abap_true.
          DATA(lv_where) = |{ iv_ts_field } > '{ condense( |{ iv_last }| ) }'|.
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

  METHOD extract_ex.
    CLEAR rs_result.
    rs_result-skip = COND i( WHEN iv_skip < 0 THEN 0 ELSE iv_skip ).
    DATA(lv_top) = iv_top.
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

    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.
    rs_result-new_high    = lv_now.
    rs_result-delta_field = CONV string( iv_ts_field ).

    DATA(lv_where) = build_where(
      iv_where    = iv_where
      iv_delta    = iv_delta
      iv_ts_field = iv_ts_field
      iv_last     = iv_last ).

    DATA(lv_order) = build_order_by( iv_entity ).

    TRY.
        " total count
        IF lv_where IS INITIAL.
          SELECT COUNT( * ) FROM (iv_entity) INTO @rs_result-total_count.
        ELSE.
          SELECT COUNT( * ) FROM (iv_entity) WHERE (lv_where)
            INTO @rs_result-total_count.
        ENDIF.

        DATA lr_tab TYPE REF TO data.
        CREATE DATA lr_tab TYPE TABLE OF (iv_entity).
        ASSIGN lr_tab->* TO FIELD-SYMBOL(<lt>).

        IF lv_where IS INITIAL.
          IF lv_order IS NOT INITIAL.
            SELECT * FROM (iv_entity)
              ORDER BY (lv_order)
              INTO TABLE @<lt>
              OFFSET @rs_result-skip UP TO @lv_top ROWS.
          ELSE.
            SELECT * FROM (iv_entity)
              INTO TABLE @<lt>
              OFFSET @rs_result-skip UP TO @lv_top ROWS.
          ENDIF.
        ELSE.
          IF lv_order IS NOT INITIAL.
            SELECT * FROM (iv_entity)
              WHERE (lv_where)
              ORDER BY (lv_order)
              INTO TABLE @<lt>
              OFFSET @rs_result-skip UP TO @lv_top ROWS.
          ELSE.
            SELECT * FROM (iv_entity)
              WHERE (lv_where)
              INTO TABLE @<lt>
              OFFSET @rs_result-skip UP TO @lv_top ROWS.
          ENDIF.
        ENDIF.

        rs_result-data_ref  = lr_tab.
        rs_result-row_count = lines( <lt> ).
        IF iv_ts_field IS NOT INITIAL.
          rs_result-max_changed_at = read_max_changed(
            ir_data = lr_tab iv_ts_field = iv_ts_field ).
        ENDIF.
        rs_result-status  = 'S'.
        rs_result-message = |{ rs_result-row_count } row(s), total { rs_result-total_count }|.

      CATCH cx_root INTO DATA(lx).
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
      lv_part = |( { lv_where } )|.
      APPEND lv_part TO lt_parts.
    ENDIF.
    IF iv_delta = abap_true AND iv_ts_field IS NOT INITIAL.
      lv_last = |{ iv_last }|.
      CONDENSE lv_last.
      lv_part = |{ iv_ts_field } > '{ lv_last }'|.
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

  METHOD build_order_by.
    DATA lt_dfies TYPE STANDARD TABLE OF dfies WITH DEFAULT KEY.
    DATA(lv_tab) = CONV ddobjname( iv_entity ).
    CALL FUNCTION 'DDIF_FIELDINFO_GET'
      EXPORTING
        tabname   = lv_tab
      TABLES
        dfies_tab = lt_dfies
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc = 0.
      LOOP AT lt_dfies INTO DATA(ls_dfies) WHERE keyflag = abap_true.
        IF rv_order IS INITIAL.
          rv_order = ls_dfies-fieldname.
        ELSE.
          rv_order = |{ rv_order } { ls_dfies-fieldname }|.
        ENDIF.
      ENDLOOP.
    ENDIF.
    IF rv_order IS INITIAL.
      " fallback: first component for stable paging when no DDIC keys
      TRY.
          DATA lr TYPE REF TO data.
          CREATE DATA lr TYPE (iv_entity).
          DATA(lo_s) = CAST cl_abap_structdescr(
                         cl_abap_typedescr=>describe_by_data_ref( lr ) ).
          DATA(lt_c) = lo_s->get_components( ).
          IF lt_c IS NOT INITIAL.
            READ TABLE lt_c INTO DATA(ls_c) INDEX 1.
            IF sy-subrc = 0.
              rv_order = ls_c-name.
            ENDIF.
          ENDIF.
        CATCH cx_root.
          CLEAR rv_order.
      ENDTRY.
    ENDIF.
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
