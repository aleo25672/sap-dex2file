" Serialize a dynamic (CDS-typed) table to a delimited text file on the frontend.
" The caller chooses the separator (`;`/`,`/tab) and the file name + extension
" (.csv / .txt / .xls), so this class is format-agnostic: header row from the
" component names, one delimited line per record, minimal CSV quoting.
CLASS zcl_dxf_file_writer DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    " @parameter ir_table | ref to the extracted (CDS-typed) internal table
    " @parameter iv_path  | full frontend path incl. file name + extension
    " @parameter iv_sep   | field separator (`;`, `,`, or a tab)
    METHODS download
      IMPORTING
        ir_table     TYPE REF TO data
        iv_path      TYPE string
        iv_sep       TYPE clike
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

  PRIVATE SECTION.
    METHODS build_text
      IMPORTING
        ir_table        TYPE REF TO data
        iv_sep          TYPE clike
      RETURNING
        VALUE(rt_lines) TYPE stringtab.
ENDCLASS.


CLASS zcl_dxf_file_writer IMPLEMENTATION.

  METHOD download.
    DATA(lt_lines) = build_text( ir_table = ir_table iv_sep = iv_sep ).

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        filename = iv_path
        filetype = 'ASC'
      CHANGING
        data_tab = lt_lines
      EXCEPTIONS
        OTHERS   = 1 ).

    rv_ok = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD build_text.
    FIELD-SYMBOLS <lt> TYPE ANY TABLE.
    ASSIGN ir_table->* TO <lt>.

    DATA(lo_tab)  = CAST cl_abap_tabledescr(
                      cl_abap_typedescr=>describe_by_data_ref( ir_table ) ).
    DATA(lo_line) = CAST cl_abap_structdescr( lo_tab->get_table_line_type( ) ).
    DATA(lt_comp) = lo_line->get_components( ).
    DATA(lv_sep)  = CONV string( iv_sep ).

    " header row = component (CDS element) names
    DATA lt_h TYPE stringtab.
    LOOP AT lt_comp INTO DATA(ls_comp).
      APPEND CONV string( ls_comp-name ) TO lt_h.
    ENDLOOP.
    APPEND concat_lines_of( table = lt_h sep = lv_sep ) TO rt_lines.

    " one delimited line per record
    LOOP AT <lt> ASSIGNING FIELD-SYMBOL(<row>).
      DATA lt_v TYPE stringtab.
      CLEAR lt_v.
      LOOP AT lt_comp INTO ls_comp.
        ASSIGN COMPONENT ls_comp-name OF STRUCTURE <row> TO FIELD-SYMBOL(<val>).
        DATA(lv_v) = |{ <val> }|.
        " minimal CSV quoting
        IF lv_v CS lv_sep OR lv_v CS '"' OR lv_v CS cl_abap_char_utilities=>newline.
          REPLACE ALL OCCURRENCES OF '"' IN lv_v WITH '""'.
          lv_v = |"{ lv_v }"|.
        ENDIF.
        APPEND lv_v TO lt_v.
      ENDLOOP.
      APPEND concat_lines_of( table = lt_v sep = lv_sep ) TO rt_lines.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
