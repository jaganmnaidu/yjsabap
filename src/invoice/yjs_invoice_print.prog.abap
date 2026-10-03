*&---------------------------------------------------------------------*
*& Report YJS_INVOICE_PRINT
*&---------------------------------------------------------------------*
*& Print program for the Adobe form YJS_INVOICE_FORM.
*& Prints an invoice for one travel of the flight reference scenario:
*&   header  = /DMO/TRAVEL + /DMO/CUSTOMER (bill-to) + /DMO/AGENCY (seller)
*&   items   = /DMO/BOOKING with carrier name and route
*& Output: print preview, print to spool, or download as PDF.
*& Rendering requires Adobe Document Services (ADS).
*&---------------------------------------------------------------------*
REPORT yjs_invoice_print.

PARAMETERS p_travel TYPE /dmo/travel_id OBLIGATORY.
PARAMETERS p_dest   TYPE rspopname DEFAULT 'LP01'.
SELECTION-SCREEN SKIP.
PARAMETERS: p_prev  RADIOBUTTON GROUP out DEFAULT 'X',
            p_print RADIOBUTTON GROUP out,
            p_pdf   RADIOBUTTON GROUP out.

CLASS lcl_invoice_printer DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS c_form_name TYPE fpname VALUE 'YJS_INVOICE_FORM'.
    METHODS run.

  PRIVATE SECTION.
    DATA ms_header TYPE yjs_s_invoice_header.
    DATA mt_items  TYPE yjs_t_invoice_item.

    METHODS read_data RETURNING VALUE(rv_found) TYPE abap_bool.
    METHODS print_form.
    METHODS download_pdf IMPORTING iv_pdf TYPE xstring.
    METHODS show_last_message.
ENDCLASS.

CLASS lcl_invoice_printer IMPLEMENTATION.
  METHOD run.
    IF read_data( ) = abap_false.
      MESSAGE |Travel { p_travel ALPHA = OUT } does not exist| TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    print_form( ).
  ENDMETHOD.

  METHOD read_data.
    SELECT SINGLE * FROM /dmo/travel
      WHERE travel_id = @p_travel
      INTO @DATA(ls_travel).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rv_found = abap_true.

    SELECT SINGLE * FROM /dmo/customer
      WHERE customer_id = @ls_travel-customer_id
      INTO @DATA(ls_customer).

    SELECT SINGLE * FROM /dmo/agency
      WHERE agency_id = @ls_travel-agency_id
      INTO @DATA(ls_agency).

    ms_header = VALUE #(
      travel_id        = ls_travel-travel_id
      invoice_date     = sy-datum
      description      = ls_travel-description
      begin_date       = ls_travel-begin_date
      end_date         = ls_travel-end_date
      customer_id      = ls_travel-customer_id
      customer_name    = condense( |{ ls_customer-title } { ls_customer-first_name } { ls_customer-last_name }| )
      cust_street      = ls_customer-street
      cust_city_line   = |{ ls_customer-postal_code } { ls_customer-city }|
      cust_country     = ls_customer-country_code
      cust_email       = ls_customer-email_address
      agency_name      = ls_agency-name
      agency_street    = ls_agency-street
      agency_city_line = |{ ls_agency-postal_code } { ls_agency-city }|
      agency_country   = ls_agency-country_code
      agency_phone     = ls_agency-phone_number
      agency_email     = ls_agency-email_address
      agency_web       = ls_agency-web_address
      " The travel total already contains the booking fee, all flights and
      " supplements, converted to the travel currency
      booking_fee      = ls_travel-booking_fee
      flights_total    = ls_travel-total_price - ls_travel-booking_fee
      total_amount     = ls_travel-total_price
      currency_code    = ls_travel-currency_code ).

    SELECT b~booking_id, b~flight_date, b~carrier_id, b~connection_id,
           c~name AS carrier_name, n~airport_from_id, n~airport_to_id,
           b~flight_price, b~currency_code
      FROM /dmo/booking AS b
      LEFT OUTER JOIN /dmo/carrier AS c
        ON c~carrier_id = b~carrier_id
      LEFT OUTER JOIN /dmo/connection AS n
        ON  n~carrier_id    = b~carrier_id
        AND n~connection_id = b~connection_id
      WHERE b~travel_id = @ls_travel-travel_id
      ORDER BY b~booking_id
      INTO TABLE @DATA(lt_bookings).

    mt_items = VALUE #( FOR ls_booking IN lt_bookings
                        ( booking_id    = ls_booking-booking_id
                          flight_date   = ls_booking-flight_date
                          carrier_name  = ls_booking-carrier_name
                          flight_no     = |{ ls_booking-carrier_id } { ls_booking-connection_id }|
                          route         = |{ ls_booking-airport_from_id } - { ls_booking-airport_to_id }|
                          flight_price  = ls_booking-flight_price
                          currency_code = ls_booking-currency_code ) ).
  ENDMETHOD.

  METHOD print_form.
    DATA lv_fm_name    TYPE rs38l_fnam.
    DATA ls_outparams  TYPE sfpoutputparams.
    DATA ls_docparams  TYPE sfpdocparams.
    DATA ls_formoutput TYPE fpformoutput.

    " Each Adobe form is generated into a function module with a technical name
    TRY.
        CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
          EXPORTING
            i_name     = c_form_name
          IMPORTING
            e_funcname = lv_fm_name.
      CATCH cx_fp_api INTO DATA(lx_fp_api).
        DATA(lv_text) = lx_fp_api->get_text( ).
        MESSAGE lv_text TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    ls_outparams-dest     = p_dest.
    ls_outparams-nodialog = abap_true.
    CASE abap_true.
      WHEN p_prev.
        ls_outparams-preview = abap_true.
      WHEN p_print.
        ls_outparams-reqimm  = abap_true.
      WHEN p_pdf.
        ls_outparams-getpdf  = abap_true.
    ENDCASE.

    CALL FUNCTION 'FP_JOB_OPEN'
      CHANGING
        ie_outputparams = ls_outparams
      EXCEPTIONS
        cancel          = 1
        usage_error     = 2
        system_error    = 3
        internal_error  = 4
        OTHERS          = 5.
    IF sy-subrc <> 0.
      show_last_message( ).
      RETURN.
    ENDIF.

    ls_docparams-langu   = sy-langu.
    ls_docparams-country = 'US'.

    CALL FUNCTION lv_fm_name
      EXPORTING
        /1bcdwb/docparams  = ls_docparams
        is_header          = ms_header
        it_items           = mt_items
      IMPORTING
        /1bcdwb/formoutput = ls_formoutput
      EXCEPTIONS
        usage_error        = 1
        system_error       = 2
        internal_error     = 3
        OTHERS             = 4.
    DATA(lv_form_subrc) = sy-subrc.
    IF lv_form_subrc <> 0.
      " Typically raised when ADS is not configured or not reachable
      show_last_message( ).
    ENDIF.

    CALL FUNCTION 'FP_JOB_CLOSE'
      EXCEPTIONS
        usage_error    = 1
        system_error   = 2
        internal_error = 3
        OTHERS         = 4.

    IF lv_form_subrc = 0 AND p_pdf = abap_true.
      download_pdf( ls_formoutput-pdf ).
    ENDIF.
  ENDMETHOD.

  METHOD download_pdf.
    DATA lv_filename TYPE string.
    DATA lv_path     TYPE string.
    DATA lv_fullpath TYPE string.
    DATA lv_action   TYPE i.

    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING
        default_file_name = |Invoice_{ ms_header-travel_id ALPHA = OUT }.pdf|
        default_extension = `pdf`
        file_filter       = `PDF files (*.pdf)|*.pdf`
      CHANGING
        filename          = lv_filename
        path              = lv_path
        fullpath          = lv_fullpath
        user_action       = lv_action
      EXCEPTIONS
        OTHERS            = 1 ).
    IF sy-subrc <> 0 OR lv_action <> cl_gui_frontend_services=>action_ok.
      RETURN.
    ENDIF.

    DATA(lt_pdf_binary) = cl_bcs_convert=>xstring_to_solix( iv_pdf ).
    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize = xstrlen( iv_pdf )
        filename     = lv_fullpath
        filetype     = 'BIN'
      CHANGING
        data_tab     = lt_pdf_binary
      EXCEPTIONS
        OTHERS       = 1 ).
    IF sy-subrc = 0.
      MESSAGE |Invoice saved to { lv_fullpath }| TYPE 'S'.
    ELSE.
      MESSAGE |Could not save { lv_fullpath }| TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD show_last_message.
    IF sy-msgid IS INITIAL.
      MESSAGE 'Form output failed. Check that Adobe Document Services (ADS) is configured.'
        TYPE 'S' DISPLAY LIKE 'E'.
    ELSE.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  NEW lcl_invoice_printer( )->run( ).
