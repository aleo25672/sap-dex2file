*&---------------------------------------------------------------------*
*& Report Z_DEX2FILE
*&---------------------------------------------------------------------*
*& Discover CDS views (DEX extraction-enabled and/or API CDS named like
*& I_*API*), then either display them or extract their data to a file -
*& FULL (SELECT *) or DELTA (rows whose change-timestamp is newer than
*& the last run).
*&
*& The action runs on ALL rows matching the selection-screen filter, so
*& narrow with the entity / API pattern to target a subset.
*&---------------------------------------------------------------------*
REPORT z_dex2file.

*----------------------------------------------------------------------*
* Selection screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b_src WITH FRAME TITLE TEXT-b06.
PARAMETERS p_dex  RADIOBUTTON GROUP src DEFAULT 'X'.  " DEX (extraction-enabled)
PARAMETERS p_api  RADIOBUTTON GROUP src.              " API CDS (I_*API*)
PARAMETERS p_both RADIOBUTTON GROUP src.              " Both
SELECTION-SCREEN END OF BLOCK b_src.

SELECTION-SCREEN BEGIN OF BLOCK b_sel WITH FRAME TITLE TEXT-b01.
PARAMETERS p_name   TYPE c LENGTH 40 LOWER CASE.  " DEX entity pattern (case-sensitive), * = wildcard
PARAMETERS p_apipat TYPE c LENGTH 40 LOWER CASE.  " API CDS pattern; empty = I_*API*
SELECTION-SCREEN END OF BLOCK b_sel.

SELECTION-SCREEN BEGIN OF BLOCK b_fam WITH FRAME TITLE TEXT-b05.
PARAMETERS p_all  RADIOBUTTON GROUP fam DEFAULT 'X'.  " all data classes
PARAMETERS p_mast RADIOBUTTON GROUP fam.              " master data
PARAMETERS p_tran RADIOBUTTON GROUP fam.              " transactional
SELECTION-SCREEN END OF BLOCK b_fam.

SELECTION-SCREEN BEGIN OF BLOCK b_act WITH FRAME TITLE TEXT-b02.
PARAMETERS p_disp RADIOBUTTON GROUP act DEFAULT 'X'.  " display list only
PARAMETERS p_ext  RADIOBUTTON GROUP act.              " extract to file
SELECTION-SCREEN END OF BLOCK b_act.

SELECTION-SCREEN BEGIN OF BLOCK b_mod WITH FRAME TITLE TEXT-b03.
PARAMETERS p_full  RADIOBUTTON GROUP mod DEFAULT 'X'. " full load
PARAMETERS p_delta RADIOBUTTON GROUP mod.             " delta (change-timestamp)
SELECTION-SCREEN END OF BLOCK b_mod.

SELECTION-SCREEN BEGIN OF BLOCK b_out WITH FRAME TITLE TEXT-b04.
PARAMETERS p_local  RADIOBUTTON GROUP tgt DEFAULT 'X'." download to local frontend
PARAMETERS p_srv    RADIOBUTTON GROUP tgt.            " write to application server (AL11)
PARAMETERS p_csv    RADIOBUTTON GROUP fmt DEFAULT 'X'." CSV  (.csv, delimiter)
PARAMETERS p_tab    RADIOBUTTON GROUP fmt.            " tab  (.txt)
PARAMETERS p_xls    RADIOBUTTON GROUP fmt.            " Excel (tab-delimited .xls)
PARAMETERS p_delim  TYPE c LENGTH 1 DEFAULT ';'.      " CSV delimiter
PARAMETERS p_folder TYPE string LOWER CASE DEFAULT 'C:\temp\'.
PARAMETERS p_lfn    TYPE c LENGTH 40.                 " logical file name (tx FILE) - overrides folder, implies server
PARAMETERS p_max    TYPE i DEFAULT 100000.            " 0 = unlimited
SELECTION-SCREEN END OF BLOCK b_out.

*----------------------------------------------------------------------*
* Application (local) class
*----------------------------------------------------------------------*
CLASS lcl_app DEFINITION CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS run.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_res,
        entity  TYPE c LENGTH 60,
        mode    TYPE c LENGTH 5,
        rows    TYPE i,
        file    TYPE string,
        status  TYPE c LENGTH 1,   " S ok | E error | K skipped
        message TYPE string,
      END OF ty_res,
      ty_res_tab TYPE STANDARD TABLE OF ty_res WITH DEFAULT KEY.

    DATA mt_views TYPE zcl_dxf_catalog=>ty_views.

    METHODS display_grid.
    METHODS extract_all
      IMPORTING io_store TYPE REF TO zcl_dxf_delta_store.
    METHODS show_results
      IMPORTING it_res TYPE ty_res_tab.
    METHODS set_col_text
      IMPORTING io_cols TYPE REF TO cl_salv_columns_table
                iv_col  TYPE lvc_fname
                iv_text TYPE string.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.

  METHOD run.
    DATA(lo_store) = NEW zcl_dxf_delta_store( ).
    DATA(lv_dc) = COND string( WHEN p_mast = abap_true THEN `M`
                               WHEN p_tran = abap_true THEN `T`
                               ELSE ` ` ).
    DATA(lv_src) = COND string( WHEN p_api  = abap_true THEN `A`
                                WHEN p_both = abap_true THEN `B`
                                ELSE `D` ).
    mt_views = NEW zcl_dxf_catalog( )->get_views(
      iv_name_pattern = p_name
      iv_api_pattern  = p_apipat
      iv_source       = lv_src
      iv_dataclass    = lv_dc
      io_delta_store  = lo_store ).

    IF mt_views IS INITIAL.
      MESSAGE 'No CDS views found for the source / filter'(m01)
              TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    IF p_ext = abap_true.
      extract_all( lo_store ).
    ELSE.
      display_grid( ).
    ENDIF.
  ENDMETHOD.

  METHOD display_grid.
    DATA lo_alv TYPE REF TO cl_salv_table.
    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = lo_alv
          CHANGING  t_table      = mt_views ).
      CATCH cx_salv_msg INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'E'.
    ENDTRY.

    lo_alv->get_functions( )->set_all( abap_true ).
    DATA(lo_cols) = lo_alv->get_columns( ).
    lo_cols->set_optimize( abap_true ).
    set_col_text( io_cols = lo_cols iv_col = 'ENTITY_NAME'    iv_text = 'CDS Entity' ).
    set_col_text( io_cols = lo_cols iv_col = 'DESCRIPTION'    iv_text = 'Description' ).
    set_col_text( io_cols = lo_cols iv_col = 'SOURCE_TYPE'    iv_text = 'Source' ).
    set_col_text( io_cols = lo_cols iv_col = 'FAMILY'         iv_text = 'Data class' ).
    set_col_text( io_cols = lo_cols iv_col = 'IS_CDC_ENABLED' iv_text = 'CDC' ).
    set_col_text( io_cols = lo_cols iv_col = 'DELTA_FIELD'    iv_text = 'Delta field' ).
    set_col_text( io_cols = lo_cols iv_col = 'DELTA_CAPABLE'  iv_text = 'Delta?' ).
    set_col_text( io_cols = lo_cols iv_col = 'LAST_DELTA_TS'  iv_text = 'Last delta pos' ).
    DATA(lv_hdr) = COND string(
      WHEN p_api  = abap_true THEN `API CDS views`
      WHEN p_both = abap_true THEN `DEX + API CDS views`
      ELSE `DEX CDS views` ).
    lo_alv->get_display_settings( )->set_list_header(
      |{ lv_hdr } - { lines( mt_views ) } rows| ).
    lo_alv->display( ).
  ENDMETHOD.

  METHOD extract_all.
    DATA(lo_ext)   = NEW zcl_dxf_extractor( ).
    DATA(lo_wr)    = NEW zcl_dxf_file_writer( ).
    DATA(lv_delta) = xsdbool( p_delta = abap_true ).

    " separator + file extension from the chosen format
    DATA lv_sep TYPE string.
    DATA lv_ext TYPE string.
    IF p_tab = abap_true.
      lv_sep = cl_abap_char_utilities=>horizontal_tab.  lv_ext = 'txt'.
    ELSEIF p_xls = abap_true.
      lv_sep = cl_abap_char_utilities=>horizontal_tab.  lv_ext = 'xls'.
    ELSE.
      lv_sep = COND string( WHEN p_delim IS NOT INITIAL THEN p_delim ELSE ';' ).
      lv_ext = 'csv'.
    ENDIF.

    " a logical file name (transaction FILE) resolves to a server path -> server write
    DATA(lv_srv) = xsdbool( p_srv = abap_true OR p_lfn IS NOT INITIAL ).

    " target folder (ensure trailing path separator: '/' on server, '\' on frontend)
    DATA(lv_folder) = condense( |{ p_folder }| ).
    IF lv_folder IS NOT INITIAL.
      IF lv_srv = abap_true.
        IF NOT lv_folder CP '*/'.  lv_folder = |{ lv_folder }/|.  ENDIF.
      ELSE.
        IF NOT lv_folder CP '*\'.  lv_folder = |{ lv_folder }\\|. ENDIF.
      ENDIF.
    ENDIF.

    DATA lt_res TYPE ty_res_tab.
    LOOP AT mt_views INTO DATA(ls_v).
      DATA(ls_r) = VALUE ty_res(
        entity = ls_v-entity_name
        mode   = COND #( WHEN lv_delta = abap_true THEN 'DELTA' ELSE 'FULL' ) ).

      " target path: logical file name (transaction FILE) or built folder path
      DATA lv_file TYPE string.
      CLEAR lv_file.
      IF p_lfn IS NOT INITIAL.
        CALL FUNCTION 'FILE_GET_NAME'
          EXPORTING
            logical_filename = p_lfn
            parameter_1      = ls_v-entity_name
            parameter_2      = COND string( WHEN lv_delta = abap_true THEN `DELTA` ELSE `FULL` )
          IMPORTING
            file_name        = lv_file
          EXCEPTIONS
            file_not_found   = 1
            OTHERS           = 2.
        IF sy-subrc <> 0.
          ls_r-status  = 'E'.
          ls_r-message = |Logical file name { p_lfn } not resolved (transaction FILE)|.
          APPEND ls_r TO lt_res.
          CONTINUE.
        ENDIF.
      ELSE.
        lv_file = |{ lv_folder }{ ls_v-entity_name }_| &&
                  |{ COND string( WHEN lv_delta = abap_true THEN `delta` ELSE `full` ) }_| &&
                  |{ sy-datum }_{ sy-uzeit }.{ lv_ext }|.
      ENDIF.

      DATA(ls_ex) = lo_ext->extract(
        iv_entity   = ls_v-entity_name
        iv_delta    = lv_delta
        iv_ts_field = ls_v-delta_field
        iv_last     = ls_v-last_delta_ts
        iv_max_rows = p_max ).

      ls_r-rows    = ls_ex-row_count.
      ls_r-status  = ls_ex-status.
      ls_r-message = ls_ex-message.

      IF ls_ex-status = 'S'.
        IF lo_wr->save( ir_table  = ls_ex-data_ref
                        iv_path   = lv_file
                        iv_sep    = lv_sep
                        iv_server = lv_srv ) = abap_true.
          ls_r-file = lv_file.
          " advance the delta marker only after a successful save
          io_store->set_last( iv_view = ls_v-entity_name iv_last = ls_ex-new_high ).
        ELSE.
          ls_r-status  = 'E'.
          ls_r-message = COND #( WHEN lv_srv = abap_true
                                 THEN 'Server write failed (path / S_DATASET auth?)'
                                 ELSE 'Download failed / cancelled' ).
        ENDIF.
      ENDIF.

      APPEND ls_r TO lt_res.
    ENDLOOP.

    show_results( lt_res ).
  ENDMETHOD.

  METHOD show_results.
    DATA lt_res TYPE ty_res_tab.
    lt_res = it_res.
    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = DATA(lo_res)
          CHANGING  t_table      = lt_res ).
        lo_res->get_functions( )->set_all( abap_true ).
        DATA(lo_cols) = lo_res->get_columns( ).
        lo_cols->set_optimize( abap_true ).
        set_col_text( io_cols = lo_cols iv_col = 'ENTITY'  iv_text = 'CDS Entity' ).
        set_col_text( io_cols = lo_cols iv_col = 'MODE'    iv_text = 'Mode' ).
        set_col_text( io_cols = lo_cols iv_col = 'ROWS'    iv_text = 'Rows' ).
        set_col_text( io_cols = lo_cols iv_col = 'FILE'    iv_text = 'File' ).
        set_col_text( io_cols = lo_cols iv_col = 'STATUS'  iv_text = 'Status' ).
        set_col_text( io_cols = lo_cols iv_col = 'MESSAGE' iv_text = 'Message' ).
        lo_res->get_display_settings( )->set_list_header(
          |Extraction results ({ COND string( WHEN p_delta = abap_true THEN `delta` ELSE `full` ) })| ).
        lo_res->display( ).
      CATCH cx_salv_msg INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

  METHOD set_col_text.
    TRY.
        DATA(lo_col) = io_cols->get_column( iv_col ).
        lo_col->set_short_text(  CONV scrtext_s( iv_text ) ).
        lo_col->set_medium_text( CONV scrtext_m( iv_text ) ).
        lo_col->set_long_text(   CONV scrtext_l( iv_text ) ).
      CATCH cx_salv_not_found.
        " unknown column: ignore
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* F4 value help for the logical file name (transaction FILE)
*----------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_lfn.
  TYPES: BEGIN OF ty_lfn,
           fileintern TYPE filenameci-fileintern,
         END OF ty_lfn.
  DATA lt_lfn TYPE STANDARD TABLE OF ty_lfn.
  DATA lt_ret TYPE STANDARD TABLE OF ddshretval.

  SELECT fileintern FROM filenameci
    ORDER BY fileintern
    INTO TABLE @lt_lfn.

  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield        = 'FILEINTERN'
      dynpprog        = sy-repid
      dynpnr          = sy-dynnr
      dynprofield     = 'P_LFN'
      value_org       = 'S'
    TABLES
      value_tab       = lt_lfn
      return_tab      = lt_ret
    EXCEPTIONS
      parameter_error = 1
      no_values_found = 2
      OTHERS          = 3.

  READ TABLE lt_ret INTO DATA(ls_ret) INDEX 1.
  IF sy-subrc = 0.
    p_lfn = ls_ret-fieldval.
  ENDIF.

*----------------------------------------------------------------------*
START-OF-SELECTION.
  NEW lcl_app( )->run( ).
