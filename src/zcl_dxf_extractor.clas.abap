" Extract data from a CDS entity into a dynamic table.
"   Full  : SELECT * FROM (entity)
"   Delta : SELECT * FROM (entity) WHERE <change-ts field> > <last high-water>
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
ENDCLASS.


CLASS zcl_dxf_extractor IMPLEMENTATION.

  METHOD extract.
    IF iv_delta = abap_true AND iv_ts_field IS INITIAL.
      rs_result-status  = 'K'.
      rs_result-message = 'Delta not possible: no change-timestamp field'.
      RETURN.
    ENDIF.

    " High-water = start of this run (so concurrent changes are re-read, not lost).
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.

    TRY.
        DATA lr_tab TYPE REF TO data.
        CREATE DATA lr_tab TYPE TABLE OF (iv_entity).
        ASSIGN lr_tab->* TO FIELD-SYMBOL(<lt>).

        IF iv_delta = abap_true.
          " Dynamic WHERE. The value is embedded as a literal (verify the field's
          " literal format on your release if delta returns nothing/dumps).
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

ENDCLASS.
