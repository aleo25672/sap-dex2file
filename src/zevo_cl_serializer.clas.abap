" Serialize a dynamic internal table (and optional envelope fields) to JSON or XML.
CLASS zevo_cl_serializer DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_field_meta,
        name        TYPE string,
        abap_type   TYPE c LENGTH 4,
        length      TYPE i,
        decimals    TYPE i,
        key_flag    TYPE abap_bool,
        description TYPE string,
      END OF ty_field_meta,
      ty_fields_meta TYPE STANDARD TABLE OF ty_field_meta WITH DEFAULT KEY.

    CLASS-METHODS serialize_extract
      IMPORTING
        iv_entity         TYPE clike
        iv_format         TYPE clike
        ir_data           TYPE REF TO data
        iv_row_count      TYPE i
        iv_total_count    TYPE i
        iv_skip           TYPE i
        iv_top            TYPE i
        iv_delta_field    TYPE clike OPTIONAL
        iv_max_changed_at TYPE clike OPTIONAL
      RETURNING
        VALUE(rv_payload) TYPE string.

    CLASS-METHODS serialize_cds_meta
      IMPORTING
        iv_entity        TYPE clike
        iv_format        TYPE clike
        iv_ddl_name      TYPE clike OPTIONAL
        iv_db_tabname    TYPE clike OPTIONAL
        iv_delta_field   TYPE clike OPTIONAL
        iv_delta_capable TYPE abap_bool OPTIONAL
        it_key_fields    TYPE stringtab OPTIONAL
        it_fields        TYPE ty_fields_meta
      RETURNING
        VALUE(rv_payload) TYPE string.

  PRIVATE SECTION.
    CLASS-METHODS json_escape
      IMPORTING iv_raw TYPE clike
      RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS xml_escape
      IMPORTING iv_raw TYPE clike
      RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS table_to_xml_items
      IMPORTING ir_data TYPE REF TO data
      RETURNING VALUE(rv_xml) TYPE string.
    CLASS-METHODS value_to_string
      IMPORTING iv_value TYPE any
      RETURNING VALUE(rv) TYPE string.
ENDCLASS.


CLASS zevo_cl_serializer IMPLEMENTATION.

  METHOD serialize_extract.
    DATA(lv_fmt) = to_lower( condense( CONV string( iv_format ) ) ).
    IF lv_fmt IS INITIAL.
      lv_fmt = 'json'.
    ENDIF.

    FIELD-SYMBOLS <lt> TYPE ANY TABLE.
    IF ir_data IS BOUND.
      ASSIGN ir_data->* TO <lt>.
    ENDIF.

    IF lv_fmt = 'xml'.
      DATA(lv_items) = ``.
      IF ir_data IS BOUND.
        lv_items = table_to_xml_items( ir_data ).
      ENDIF.
      rv_payload =
        |<?xml version="1.0" encoding="utf-8"?>| &&
        |<extract>| &&
        |<entity>{ xml_escape( iv_entity ) }</entity>| &&
        |<format>xml</format>| &&
        |<rowCount>{ iv_row_count }</rowCount>| &&
        |<totalCount>{ iv_total_count }</totalCount>| &&
        |<skip>{ iv_skip }</skip>| &&
        |<top>{ iv_top }</top>| &&
        |<deltaField>{ xml_escape( iv_delta_field ) }</deltaField>| &&
        |<maxChangedAt>{ xml_escape( iv_max_changed_at ) }</maxChangedAt>| &&
        |<data>{ lv_items }</data>| &&
        |</extract>|.
      RETURN.
    ENDIF.

    DATA lv_data_json TYPE string.
    IF ir_data IS BOUND.
      lv_data_json = /ui2/cl_json=>serialize(
        data        = <lt>
        compress    = abap_false
        pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
    ELSE.
      lv_data_json = `[]`.
    ENDIF.

    rv_payload =
      |\{| &&
      |"entity":"{ json_escape( iv_entity ) }",| &&
      |"format":"json",| &&
      |"rowCount":{ iv_row_count },| &&
      |"totalCount":{ iv_total_count },| &&
      |"skip":{ iv_skip },| &&
      |"top":{ iv_top },| &&
      |"deltaField":"{ json_escape( iv_delta_field ) }",| &&
      |"maxChangedAt":"{ json_escape( iv_max_changed_at ) }",| &&
      |"data":{ lv_data_json }| &&
      |\}|.
  ENDMETHOD.

  METHOD serialize_cds_meta.
    DATA(lv_fmt) = to_lower( condense( CONV string( iv_format ) ) ).
    IF lv_fmt IS INITIAL.
      lv_fmt = 'json'.
    ENDIF.

    DATA(lv_delta_cap) = COND string( WHEN iv_delta_capable = abap_true THEN `true` ELSE `false` ).

    IF lv_fmt = 'xml'.
      DATA(lv_keys) = ``.
      LOOP AT it_key_fields INTO DATA(lv_key).
        lv_keys = lv_keys && |<key>{ xml_escape( lv_key ) }</key>|.
      ENDLOOP.
      DATA(lv_fields_xml) = ``.
      LOOP AT it_fields INTO DATA(ls_f).
        DATA(lv_key_flag) = COND string( WHEN ls_f-key_flag = abap_true THEN `true` ELSE `false` ).
        lv_fields_xml = lv_fields_xml &&
          |<field>| &&
          |<name>{ xml_escape( ls_f-name ) }</name>| &&
          |<abapType>{ xml_escape( ls_f-abap_type ) }</abapType>| &&
          |<length>{ ls_f-length }</length>| &&
          |<decimals>{ ls_f-decimals }</decimals>| &&
          |<key>{ lv_key_flag }</key>| &&
          |<description>{ xml_escape( ls_f-description ) }</description>| &&
          |</field>|.
      ENDLOOP.
      rv_payload =
        |<?xml version="1.0" encoding="utf-8"?>| &&
        |<cdsMetadata>| &&
        |<entity>{ xml_escape( iv_entity ) }</entity>| &&
        |<ddlName>{ xml_escape( iv_ddl_name ) }</ddlName>| &&
        |<dbTabName>{ xml_escape( iv_db_tabname ) }</dbTabName>| &&
        |<deltaField>{ xml_escape( iv_delta_field ) }</deltaField>| &&
        |<deltaCapable>{ lv_delta_cap }</deltaCapable>| &&
        |<keyFields>{ lv_keys }</keyFields>| &&
        |<fields>{ lv_fields_xml }</fields>| &&
        |</cdsMetadata>|.
      RETURN.
    ENDIF.

    DATA(lv_keys_json) = `[`.
    DATA(lv_first) = abap_true.
    LOOP AT it_key_fields INTO lv_key.
      IF lv_first = abap_false.
        lv_keys_json = lv_keys_json && `,`.
      ENDIF.
      lv_first = abap_false.
      lv_keys_json = lv_keys_json && |"{ json_escape( lv_key ) }"|.
    ENDLOOP.
    lv_keys_json = lv_keys_json && `]`.

    DATA(lv_fields_json) = /ui2/cl_json=>serialize(
      data        = it_fields
      compress    = abap_false
      pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

    rv_payload =
      |\{| &&
      |"entity":"{ json_escape( iv_entity ) }",| &&
      |"ddlName":"{ json_escape( iv_ddl_name ) }",| &&
      |"dbTabName":"{ json_escape( iv_db_tabname ) }",| &&
      |"deltaField":"{ json_escape( iv_delta_field ) }",| &&
      |"deltaCapable":{ lv_delta_cap },| &&
      |"keyFields":{ lv_keys_json },| &&
      |"fields":{ lv_fields_json }| &&
      |\}|.
  ENDMETHOD.

  METHOD json_escape.
    DATA lv_crlf TYPE c LENGTH 2.
    DATA lv_cr   TYPE c LENGTH 1.
    DATA lv_lf   TYPE c LENGTH 1.
    lv_crlf = cl_abap_char_utilities=>cr_lf.
    lv_cr   = lv_crlf+0( 1 ).
    lv_lf   = cl_abap_char_utilities=>newline.
    rv = iv_raw.
    REPLACE ALL OCCURRENCES OF `\` IN rv WITH `\\`.
    REPLACE ALL OCCURRENCES OF `"` IN rv WITH `\"`.
    REPLACE ALL OCCURRENCES OF lv_lf IN rv WITH `\n`.
    REPLACE ALL OCCURRENCES OF lv_cr IN rv WITH `\r`.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN rv WITH `\t`.
  ENDMETHOD.

  METHOD xml_escape.
    rv = CONV string( iv_raw ).
    REPLACE ALL OCCURRENCES OF `&` IN rv WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<` IN rv WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>` IN rv WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF `"` IN rv WITH `&quot;`.
    REPLACE ALL OCCURRENCES OF `'` IN rv WITH `&apos;`.
  ENDMETHOD.

  METHOD table_to_xml_items.
    FIELD-SYMBOLS <lt> TYPE ANY TABLE.
    ASSIGN ir_data->* TO <lt>.

    DATA(lo_tab)  = CAST cl_abap_tabledescr(
                      cl_abap_typedescr=>describe_by_data_ref( ir_data ) ).
    DATA(lo_line) = CAST cl_abap_structdescr( lo_tab->get_table_line_type( ) ).
    DATA(lt_comp) = lo_line->get_components( ).

    LOOP AT <lt> ASSIGNING FIELD-SYMBOL(<ls>).
      rv_xml = rv_xml && `<item>`.
      LOOP AT lt_comp INTO DATA(ls_comp).
        ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls> TO FIELD-SYMBOL(<v>).
        IF sy-subrc = 0.
          rv_xml = rv_xml &&
            |<{ ls_comp-name }>{ xml_escape( value_to_string( <v> ) ) }</{ ls_comp-name }>|.
        ENDIF.
      ENDLOOP.
      rv_xml = rv_xml && `</item>`.
    ENDLOOP.
  ENDMETHOD.

  METHOD value_to_string.
    DATA lv_type TYPE c LENGTH 1.
    DESCRIBE FIELD iv_value TYPE lv_type.
    CASE lv_type.
      WHEN 'P' OR 'I' OR '8' OR 'F'.
        rv = |{ iv_value }|.
      WHEN 'X'.
        IF iv_value = abap_true.
          rv = `true`.
        ELSE.
          rv = `false`.
        ENDIF.
      WHEN OTHERS.
        rv = |{ iv_value }|.
    ENDCASE.
    CONDENSE rv.
  ENDMETHOD.

ENDCLASS.
