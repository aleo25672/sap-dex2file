" Translate a subset of OData $filter syntax into an OpenSQL WHERE clause.
" Supported: eq ne gt ge lt le, and, or, parentheses, string/number literals.
" Field names must appear in the allowlist (CDS components, case-insensitive).
CLASS zevo_cl_filter_parser DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_fields TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    TYPES:
      BEGIN OF ty_result,
        where_sql TYPE string,
        status    TYPE c LENGTH 1,  " S ok | E error
        message   TYPE string,
      END OF ty_result.

    METHODS parse
      IMPORTING
        iv_filter        TYPE clike
        it_allowed       TYPE ty_fields
      RETURNING
        VALUE(rs_result) TYPE ty_result.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_token,
        kind  TYPE c LENGTH 10,  " FIELD|OP|LIT|AND|OR|LP|RP|END
        value TYPE string,
      END OF ty_token,
      ty_tokens TYPE STANDARD TABLE OF ty_token WITH DEFAULT KEY.

    DATA mt_tokens  TYPE ty_tokens.
    DATA mv_idx     TYPE i.
    DATA mt_allowed TYPE ty_fields.
    DATA mv_error   TYPE string.

    METHODS tokenize
      IMPORTING iv_filter TYPE clike
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS parse_or
      RETURNING VALUE(rv_sql) TYPE string.
    METHODS parse_and
      RETURNING VALUE(rv_sql) TYPE string.
    METHODS parse_primary
      RETURNING VALUE(rv_sql) TYPE string.
    METHODS current
      RETURNING VALUE(rs_tok) TYPE ty_token.
    METHODS consume
      RETURNING VALUE(rs_tok) TYPE ty_token.
    METHODS expect
      IMPORTING iv_kind TYPE clike
      RETURNING VALUE(rs_tok) TYPE ty_token.
    METHODS map_op
      IMPORTING iv_op TYPE clike
      RETURNING VALUE(rv_sql) TYPE string.
    METHODS is_allowed
      IMPORTING iv_field TYPE clike
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS fail
      IMPORTING iv_msg TYPE clike.
ENDCLASS.


CLASS zevo_cl_filter_parser IMPLEMENTATION.

  METHOD parse.
    DATA lv_filter TYPE string.
    DATA lv_sql    TYPE string.
    DATA ls_cur    TYPE ty_token.

    CLEAR rs_result.
    mt_allowed = it_allowed.
    CLEAR mt_tokens.
    CLEAR mv_error.
    mv_idx = 1.

    lv_filter = iv_filter.
    CONDENSE lv_filter.
    IF lv_filter IS INITIAL.
      rs_result-status = 'S'.
      RETURN.
    ENDIF.

    IF tokenize( lv_filter ) = abap_false.
      rs_result-status  = 'E'.
      rs_result-message = mv_error.
      RETURN.
    ENDIF.

    lv_sql = parse_or( ).
    IF mv_error IS NOT INITIAL.
      rs_result-status  = 'E'.
      rs_result-message = mv_error.
      RETURN.
    ENDIF.

    ls_cur = current( ).
    IF ls_cur-kind <> 'END'.
      rs_result-status  = 'E'.
      rs_result-message = |Unexpected token near '{ ls_cur-value }'|.
      RETURN.
    ENDIF.

    rs_result-where_sql = lv_sql.
    rs_result-status    = 'S'.
  ENDMETHOD.

  METHOD tokenize.
    DATA lv      TYPE string.
    DATA lv_len  TYPE i.
    DATA lv_pos  TYPE i.
    DATA lv_ch   TYPE c LENGTH 1.
    DATA lv_c    TYPE c LENGTH 1.
    DATA lv_start TYPE i.
    DATA lv_i    TYPE i.
    DATA lv_lit  TYPE string.
    DATA lv_esc  TYPE string.
    DATA lv_closed TYPE abap_bool.
    DATA lv_end  TYPE i.
    DATA lv_word TYPE string.
    DATA lv_low  TYPE string.
    DATA lv_two  TYPE c LENGTH 2.
    DATA lv_len_word TYPE i.
    DATA ls_tok  TYPE ty_token.

    rv_ok = abap_true.
    lv = iv_filter.
    lv_len = strlen( lv ).
    lv_pos = 0.

    WHILE lv_pos < lv_len.
      WHILE lv_pos < lv_len.
        lv_ch = lv+lv_pos( 1 ).
        IF lv_ch <> ' '.
          EXIT.
        ENDIF.
        lv_pos = lv_pos + 1.
      ENDWHILE.
      IF lv_pos >= lv_len.
        EXIT.
      ENDIF.

      CLEAR ls_tok.
      lv_ch = lv+lv_pos( 1 ).

      IF lv_ch = '('.
        ls_tok-kind  = 'LP'.
        ls_tok-value = '('.
        lv_pos = lv_pos + 1.
        APPEND ls_tok TO mt_tokens.
        CONTINUE.
      ELSEIF lv_ch = ')'.
        ls_tok-kind  = 'RP'.
        ls_tok-value = ')'.
        lv_pos = lv_pos + 1.
        APPEND ls_tok TO mt_tokens.
        CONTINUE.
      ELSEIF lv_ch = `'`.
        lv_start = lv_pos + 1.
        lv_i = lv_start.
        CLEAR lv_lit.
        lv_closed = abap_false.
        WHILE lv_i < lv_len.
          lv_ch = lv+lv_i( 1 ).
          IF lv_ch = `'`.
            IF lv_i + 1 < lv_len.
              lv_two = lv+lv_i( 2 ).
              IF lv_two = `''`.
                lv_lit = lv_lit && `'`.
                lv_i = lv_i + 2.
                CONTINUE.
              ENDIF.
            ENDIF.
            lv_closed = abap_true.
            lv_i = lv_i + 1.
            EXIT.
          ELSE.
            lv_lit = lv_lit && lv_ch.
            lv_i = lv_i + 1.
          ENDIF.
        ENDWHILE.
        IF lv_closed = abap_false.
          fail( 'Unclosed string literal in $filter' ).
          rv_ok = abap_false.
          RETURN.
        ENDIF.
        ls_tok-kind = 'LIT'.
        lv_esc = lv_lit.
        REPLACE ALL OCCURRENCES OF `'` IN lv_esc WITH `''`.
        ls_tok-value = |'{ lv_esc }'|.
        lv_pos = lv_i.
        APPEND ls_tok TO mt_tokens.
        CONTINUE.
      ENDIF.

      lv_end = lv_pos.
      WHILE lv_end < lv_len.
        lv_c = lv+lv_end( 1 ).
        IF lv_c = ' ' OR lv_c = '(' OR lv_c = ')' OR lv_c = `'`.
          EXIT.
        ENDIF.
        lv_end = lv_end + 1.
      ENDWHILE.
      lv_len_word = lv_end - lv_pos.
      lv_word = lv+lv_pos( lv_len_word ).
      lv_pos = lv_end.
      lv_low = to_lower( lv_word ).

      CASE lv_low.
        WHEN 'eq' OR 'ne' OR 'gt' OR 'ge' OR 'lt' OR 'le'.
          ls_tok-kind  = 'OP'.
          ls_tok-value = lv_low.
        WHEN 'and'.
          ls_tok-kind  = 'AND'.
          ls_tok-value = 'and'.
        WHEN 'or'.
          ls_tok-kind  = 'OR'.
          ls_tok-value = 'or'.
        WHEN 'true'.
          ls_tok-kind  = 'LIT'.
          ls_tok-value = `'X'`.
        WHEN 'false'.
          ls_tok-kind  = 'LIT'.
          ls_tok-value = `' '`.
        WHEN OTHERS.
          IF lv_word CO '0123456789.-'.
            ls_tok-kind  = 'LIT'.
            ls_tok-value = lv_word.
          ELSEIF lv_low CS 'datetime'.
            fail( |Unsupported literal/function '{ lv_word }' - use quoted timestamps| ).
            rv_ok = abap_false.
            RETURN.
          ELSEIF lv_low = 'contains' OR lv_low = 'startswith' OR lv_low = 'endswith'
              OR lv_low = 'substringof' OR lv_low = 'tolower' OR lv_low = 'toupper'
              OR lv_low = 'not' OR lv_low = 'null'.
            fail( |Unsupported $filter keyword '{ lv_word }'| ).
            rv_ok = abap_false.
            RETURN.
          ELSE.
            ls_tok-kind  = 'FIELD'.
            ls_tok-value = lv_word.
          ENDIF.
      ENDCASE.
      APPEND ls_tok TO mt_tokens.
    ENDWHILE.

    CLEAR ls_tok.
    ls_tok-kind = 'END'.
    APPEND ls_tok TO mt_tokens.
  ENDMETHOD.

  METHOD parse_or.
    DATA lv   TYPE string.
    DATA lv_r TYPE string.
    DATA ls_cur TYPE ty_token.

    lv = parse_and( ).
    IF mv_error IS NOT INITIAL.
      RETURN.
    ENDIF.
    ls_cur = current( ).
    WHILE ls_cur-kind = 'OR'.
      consume( ).
      lv_r = parse_and( ).
      IF mv_error IS NOT INITIAL.
        RETURN.
      ENDIF.
      lv = |({ lv }) OR ({ lv_r })|.
      ls_cur = current( ).
    ENDWHILE.
    rv_sql = lv.
  ENDMETHOD.

  METHOD parse_and.
    DATA lv   TYPE string.
    DATA lv_r TYPE string.
    DATA ls_cur TYPE ty_token.

    lv = parse_primary( ).
    IF mv_error IS NOT INITIAL.
      RETURN.
    ENDIF.
    ls_cur = current( ).
    WHILE ls_cur-kind = 'AND'.
      consume( ).
      lv_r = parse_primary( ).
      IF mv_error IS NOT INITIAL.
        RETURN.
      ENDIF.
      lv = |({ lv }) AND ({ lv_r })|.
      ls_cur = current( ).
    ENDWHILE.
    rv_sql = lv.
  ENDMETHOD.

  METHOD parse_primary.
    DATA lv_inner TYPE string.
    DATA ls_cur   TYPE ty_token.
    DATA ls_field TYPE ty_token.
    DATA ls_op    TYPE ty_token.
    DATA ls_lit   TYPE ty_token.
    DATA lv_field TYPE string.

    ls_cur = current( ).
    IF ls_cur-kind = 'LP'.
      consume( ).
      lv_inner = parse_or( ).
      IF mv_error IS NOT INITIAL.
        RETURN.
      ENDIF.
      expect( 'RP' ).
      IF mv_error IS NOT INITIAL.
        RETURN.
      ENDIF.
      rv_sql = |({ lv_inner })|.
      RETURN.
    ENDIF.

    ls_field = expect( 'FIELD' ).
    IF mv_error IS NOT INITIAL.
      RETURN.
    ENDIF.
    IF is_allowed( ls_field-value ) = abap_false.
      fail( |Field '{ ls_field-value }' is not part of the CDS entity| ).
      RETURN.
    ENDIF.

    ls_op = expect( 'OP' ).
    IF mv_error IS NOT INITIAL.
      RETURN.
    ENDIF.
    ls_lit = expect( 'LIT' ).
    IF mv_error IS NOT INITIAL.
      RETURN.
    ENDIF.

    lv_field = to_upper( ls_field-value ).
    rv_sql = |{ lv_field } { map_op( ls_op-value ) } { ls_lit-value }|.
  ENDMETHOD.

  METHOD current.
    READ TABLE mt_tokens INTO rs_tok INDEX mv_idx.
    IF sy-subrc <> 0.
      CLEAR rs_tok.
      rs_tok-kind = 'END'.
    ENDIF.
  ENDMETHOD.

  METHOD consume.
    rs_tok = current( ).
    mv_idx = mv_idx + 1.
  ENDMETHOD.

  METHOD expect.
    rs_tok = consume( ).
    IF rs_tok-kind <> iv_kind.
      fail( |Expected { iv_kind }, got '{ rs_tok-value }'| ).
    ENDIF.
  ENDMETHOD.

  METHOD map_op.
    DATA lv_op TYPE string.
    lv_op = to_lower( iv_op ).
    CASE lv_op.
      WHEN 'eq'.
        rv_sql = '='.
      WHEN 'ne'.
        rv_sql = '<>'.
      WHEN 'gt'.
        rv_sql = '>'.
      WHEN 'ge'.
        rv_sql = '>='.
      WHEN 'lt'.
        rv_sql = '<'.
      WHEN 'le'.
        rv_sql = '<='.
      WHEN OTHERS.
        rv_sql = '='.
    ENDCASE.
  ENDMETHOD.

  METHOD is_allowed.
    DATA lv TYPE string.
    lv = iv_field.
    lv = to_upper( lv ).
    READ TABLE mt_allowed WITH TABLE KEY table_line = lv TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      rv_ok = abap_true.
    ELSE.
      rv_ok = abap_false.
    ENDIF.
  ENDMETHOD.

  METHOD fail.
    IF mv_error IS INITIAL.
      mv_error = iv_msg.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
