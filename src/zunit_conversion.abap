REPORT zco_unit_conversion.
DATA: ok_code           TYPE sy-ucomm,
      lv_qty            TYPE bstmg,
      lv_price_local(6) TYPE p DECIMALS 2,
      gt_out            TYPE STANDARD TABLE OF zco_convert_unit_alv,
      gr_cont           TYPE REF TO  cl_gui_custom_container,
      gr_grid           TYPE REF TO  cl_gui_alv_grid.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_matnr TYPE matnr OBLIGATORY,
              p_qty   TYPE bstmg,
              p_unit  TYPE ekpo-meins.

  SELECTION-SCREEN SKIP 1.
  PARAMETERS: p_amt   TYPE bseg-dmbtr,
              p_waers TYPE bkpf-waers,
              p_date  TYPE sy-datum DEFAULT sy-datum,
              p_bukrs TYPE bkpf-bukrs DEFAULT '2310'.
SELECTION-SCREEN END OF BLOCK b01.

INITIALIZATION.

START-OF-SELECTION.
  CLEAR: lv_qty.

  DATA(ls_t001) = NEW cl_fin_cfin_utility( )->get_t001( p_bukrs ).

  SELECT SINGLE *
  FROM mara INTO @DATA(ls_mara)
  WHERE matnr = @p_matnr.
  IF sy-subrc <> 0.
    EXIT.
  ELSE.
    SELECT SINGLE * FROM makt WHERE matnr = @ls_mara-matnr
                         AND spras = @sy-langu
                         INTO @DATA(ls_makt).
  ENDIF.

  APPEND INITIAL LINE TO gt_out ASSIGNING FIELD-SYMBOL(<ls_out>).
  <ls_out>-matnr         = ls_mara-matnr.
  <ls_out>-maktx         = ls_makt-maktx.
  <ls_out>-mtart         = ls_mara-mtart.
  <ls_out>-meins         = ls_mara-meins.
  <ls_out>-exchange_date = p_date.
  <ls_out>-qty_entered   = p_qty.
  <ls_out>-amt_entered   = p_amt.

  CALL FUNCTION 'MD_CONVERT_MATERIAL_UNIT'
    EXPORTING
      i_matnr  = p_matnr
      i_in_me  = p_unit
      i_out_me = ls_mara-meins
      i_menge  = p_qty
    IMPORTING
      e_menge  = lv_qty.


  <ls_out>-qty_converted = lv_qty.

  CALL FUNCTION 'CONVERT_TO_LOCAL_CURRENCY'
    EXPORTING
      client           = sy-mandt
      date             = p_date
      foreign_amount   = p_amt
      foreign_currency = p_waers
      local_currency   = ls_t001-waers
      type_of_rate     = 'M'
      read_tcurr       = 'X'
    IMPORTING
      exchange_rate    = <ls_out>-exchange_rate
      local_amount     = lv_price_local
    EXCEPTIONS
      no_rate_found    = 1
      overflow         = 2
      no_factors_found = 3
      no_spread_found  = 4
      derived_2_times  = 5
      OTHERS           = 6.
  IF sy-subrc <> 0.
* Implement suitable error handling here
  ENDIF.

  <ls_out>-amt_converted = lv_price_local.

  CHECK gt_out[] IS NOT INITIAL.

  CALL SCREEN 0100.

*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STATUS_0100'.
  SET TITLEBAR 'TITLE_0100'.
  PERFORM show_alv.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Form show_alv
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM show_alv .
  DATA: lt_fcat     TYPE slis_t_fieldcat_alv.

  DATA(ls_variant) = VALUE disvariant( report     = sy-repid ).
  DATA(ls_layout)  = VALUE lvc_s_layo( col_opt    = abap_true
                                       no_merging = abap_true
                                       zebra      = abap_true
                                       cwidth_opt = abap_true
                                       sel_mode   = 'D' ).

  CREATE OBJECT gr_cont
    EXPORTING
      container_name = 'CONTAINER'.

  CREATE OBJECT gr_grid
    EXPORTING
      i_parent = gr_cont.

  gr_grid->set_table_for_first_display(
    EXPORTING
*     i_buffer_active               =                  " Pufferung aktiv
*     i_bypassing_buffer            =                  " Puffer ausschalten
*     i_consistency_check           =                  " Starte Konsistenzverprobung für Schnittstellefehlererkennung
      i_structure_name              = 'ZCO_CONVERT_UNIT_ALV'                 " Strukturname der internen Ausgabetabelle
      is_variant                    = ls_variant       " Anzeigevariante
      i_save                        = 'A'              " Anzeigevariante sichern
*     i_default                     = 'X'              " Defaultanzeigevariante
      is_layout                     = ls_layout        " Layout
*     is_print                      =                  " Drucksteuerung
*     it_special_groups             =                  " Feldgruppen
*     it_toolbar_excluding          =                  " excludierte Toolbarstandardfunktionen
*     it_hyperlink                  =                  " Hyperlinks
*     it_alv_graphics               =                  " Tabelle von der Struktur DTC_S_TC
*     it_except_qinfo               =                  " Tabelle für die Exception Quickinfo
*     ir_salv_adapter               =                  " Interface ALV Adapter
    CHANGING
      it_outtab                     = gt_out           " Ausgabetabelle
*     it_fieldcatalog               = lt_fcat          " Feldkatalog
*     it_sort                       =                  " Sortierkriterien
*     it_filter                     =                  " Filterkriterien
    EXCEPTIONS
      invalid_parameter_combination = 1                " Parameter falsch
      program_error                 = 2                " Programmfehler
      too_many_lines                = 3                " Zu viele Zeilen in eingabebereitem Grid.
      OTHERS                        = 4
  ).
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  CASE ok_code.
    WHEN 'BACK' OR 'CANCEL'.
      LEAVE TO SCREEN 0.
    WHEN 'EXIT'.
      LEAVE PROGRAM.
    WHEN OTHERS.
  ENDCASE.
ENDMODULE.