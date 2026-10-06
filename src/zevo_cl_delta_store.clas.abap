" Persist the delta high-water timestamp per CDS view (table ZEVO_DELTA).
" A delta run reads the stored high-water, extracts rows changed after it, and
" (only after the file is written) stores the new high-water.
CLASS zevo_cl_delta_store DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Stored high-water for a view (0 if the view was never extracted).
    METHODS get_last
      IMPORTING iv_view        TYPE clike
      RETURNING VALUE(rv_last) TYPE timestampl.

    " Persist a new high-water (call after a successful download).
    METHODS set_last
      IMPORTING iv_view TYPE clike
                iv_last TYPE timestampl.
ENDCLASS.


CLASS zevo_cl_delta_store IMPLEMENTATION.

  METHOD get_last.
    SELECT SINGLE last_ts FROM zevo_delta
      WHERE viewname = @iv_view
      INTO @rv_last.
  ENDMETHOD.

  METHOD set_last.
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.

    DATA(ls_row) = VALUE zevo_delta(
      viewname  = iv_view
      last_ts   = iv_last
      last_run  = lv_now
      last_user = sy-uname ).

    MODIFY zevo_delta FROM @ls_row.
    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.
