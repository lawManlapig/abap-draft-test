CLASS lhc_ZLAW_I_Travel_D DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR ZLAW_I_Travel_D RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ZLAW_I_Travel_D RESULT result.
    METHODS precheck_create FOR PRECHECK
      IMPORTING entities FOR CREATE ZLAW_I_Travel_D.

    METHODS precheck_update FOR PRECHECK
      IMPORTING entities FOR UPDATE ZLAW_I_Travel_D.
    METHODS acceptTravel FOR MODIFY
      IMPORTING keys FOR ACTION ZLAW_I_Travel_D~acceptTravel RESULT result.

    METHODS deductDiscount FOR MODIFY
      IMPORTING keys FOR ACTION ZLAW_I_Travel_D~deductDiscount RESULT result.

    METHODS reCalculateTotalPrice FOR MODIFY
      IMPORTING keys FOR ACTION ZLAW_I_Travel_D~reCalculateTotalPrice.

    METHODS rejectTravel FOR MODIFY
      IMPORTING keys FOR ACTION ZLAW_I_Travel_D~rejectTravel RESULT result.

ENDCLASS.

CLASS lhc_ZLAW_I_Travel_D IMPLEMENTATION.

  " Auth based on value of the instance
  METHOD get_instance_authorizations.
    DATA: lv_update TYPE abp_behv_auth,
          lv_delete TYPE abp_behv_auth.

    " Read Entities
    READ ENTITIES OF ZLAW_I_Travel_D
    IN LOCAL MODE
    ENTITY ZLAW_I_Travel_D
    FIELDS ( AgencyID )
    WITH CORRESPONDING #( keys )
*    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_read_result)
    FAILED failed.

    IF lt_read_result IS NOT INITIAL.
      SELECT FROM /dmo/a_travel_d AS a
      INNER JOIN /dmo/agency AS b
      ON a~agency_id = b~agency_id
      FIELDS a~travel_uuid, a~agency_id, b~country_code
      FOR ALL ENTRIES IN @lt_read_result
      WHERE a~travel_uuid = @lt_read_result-TravelUUID
      INTO TABLE @DATA(lt_agency_country_data).

      IF sy-subrc IS INITIAL.
        LOOP AT lt_read_result ASSIGNING FIELD-SYMBOL(<lfs_read_result>).
          ASSIGN lt_agency_country_data[ travel_uuid = <lfs_read_result>-TravelUUID ]
          TO FIELD-SYMBOL(<lfs_agency_details>).

          IF sy-subrc IS INITIAL.
            " Check Request
            IF requested_authorizations-%update EQ if_abap_behv=>mk-on.
              " Call the Auth Object
              AUTHORITY-CHECK OBJECT '/DMO/TRVL'
              ID '/DMO/CNTRY' FIELD <lfs_agency_details>-country_code
              ID 'ACTVT' FIELD '02'.

              lv_update = COND #( WHEN sy-subrc IS INITIAL THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized ).

              " Custom Message
              APPEND VALUE #(
                   %tky = <lfs_read_result>-%tky
                   %msg = NEW /dmo/cm_flight_messages(
                       textid = /dmo/cm_flight_messages=>not_authorized_for_agencyid
                       agency_id =  <lfs_read_result>-AgencyID
                       severity = if_abap_behv_message=>severity-error )
                   %element-agencyid = if_abap_behv=>mk-on
               ) TO reported-zlaw_i_travel_d.
            ENDIF.

            IF requested_authorizations-%delete EQ if_abap_behv=>mk-on.
              AUTHORITY-CHECK OBJECT '/DMO/TRVL'
              ID '/DMO/CNTRY' FIELD <lfs_agency_details>-country_code
              ID 'ACTVT' FIELD '06'.

              lv_delete = COND #( WHEN sy-subrc IS INITIAL THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized ).

              " Custom Message
              APPEND VALUE #(
                   %tky = <lfs_read_result>-%tky
                   %msg = NEW /dmo/cm_flight_messages(
                       textid = /dmo/cm_flight_messages=>not_authorized_for_agencyid
                       agency_id =  <lfs_read_result>-AgencyID
                       severity = if_abap_behv_message=>severity-error )
                   %element-agencyid = if_abap_behv=>mk-on
               ) TO reported-zlaw_i_travel_d.
            ENDIF.

          ENDIF.
          result = VALUE #( (
              TravelUUID = <lfs_read_result>-TravelUUID
              %update = COND #( WHEN sy-subrc IS INITIAL THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized
          ) ) ).

          APPEND VALUE #(
            TravelUUID = <lfs_read_result>-TravelUUID
            %update = lv_update
            %delete = lv_delete
          ) TO result.
        ENDLOOP.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  " Useful for CRUD restrictions
  METHOD get_global_authorizations.
*    " Read the Auth Request
*    IF requested_authorizations-%create = if_abap_behv=>mk-on.
*      " Call the Auth Object
*      AUTHORITY-CHECK OBJECT '/DMO/TRVL'
*      ID '/DMO/CNTRY' DUMMY
*      ID 'ACTVT' FIELD '01'.
*
*      result-%create = COND #( WHEN sy-subrc IS INITIAL THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized ).
*    ENDIF.
*
*    IF requested_authorizations-%update = if_abap_behv=>mk-on.
*      AUTHORITY-CHECK OBJECT '/DMO/TRVL'
*      ID '/DMO/CNTRY' DUMMY
*      ID 'ACTVT' FIELD '02'.
*
*      result-%update = COND #( WHEN sy-subrc IS INITIAL THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized ).
*    ENDIF.
*
*    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
*      AUTHORITY-CHECK OBJECT '/DMO/TRVL'
*      ID '/DMO/CNTRY' DUMMY
*      ID 'ACTVT' FIELD '06'.
*
*      result-%delete = COND #( WHEN sy-subrc IS INITIAL THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized ).
*    ENDIF.
  ENDMETHOD.

  " Logic before saving
  " parang this.before sa CAP
  METHOD precheck_create.
*    " TEST LOGIC
*    TRY.
*        IF cl_abap_context_info=>get_user_formatted_name(  ) EQ 'LAW'.
*
*        ENDIF.
*      CATCH cx_abap_context_info_error.
*        "handle exception
*    ENDTRY.
  ENDMETHOD.

  METHOD precheck_update.
    DATA: lt_agency TYPE SORTED TABLE OF /dmo/agency WITH UNIQUE KEY agency_id.

    lt_agency = CORRESPONDING #( entities
        DISCARDING DUPLICATES
        MAPPING
            agency_id = AgencyID
        EXCEPT *
    ).

    IF lt_agency IS NOT INITIAL.
      SELECT FROM /dmo/agency
      FIELDS
          agency_id,
          country_code
      FOR ALL ENTRIES IN @lt_agency
      WHERE agency_id = @lt_agency-agency_id
      INTO TABLE @DATA(lt_agency_details).

      IF sy-subrc IS INITIAL.
        LOOP AT entities ASSIGNING FIELD-SYMBOL(<lfs_entities>).
          ASSIGN lt_agency_details[ agency_id = <lfs_entities>-AgencyID ]
          TO FIELD-SYMBOL(<lfs_agency_details>).

          IF sy-subrc IS INITIAL.
            AUTHORITY-CHECK OBJECT '/DMO/TRVL'
            ID '/DMO/CNTRY' FIELD <lfs_agency_details>-country_code
            ID 'ACTVT' FIELD '06'.

            IF sy-subrc IS NOT INITIAL.
              failed-zlaw_i_travel_d = VALUE #( ( %tky = <lfs_entities>-%tky ) ).

              " Custom Message
              APPEND VALUE #(
                   %tky = <lfs_entities>-%tky
                   %msg = NEW /dmo/cm_flight_messages(
                       textid = /dmo/cm_flight_messages=>not_authorized_for_agencyid
                       agency_id =  <lfs_entities>-AgencyID
                       severity = if_abap_behv_message=>severity-error )
                   %element-agencyid = if_abap_behv=>mk-on
               ) TO reported-zlaw_i_travel_d.
            ENDIF.
          ENDIF.
        ENDLOOP.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD acceptTravel.
    MODIFY ENTITIES OF ZLAW_I_Travel_D
    IN LOCAL MODE
    ENTITY ZLAW_I_Travel_D
    UPDATE FIELDS ( OverallStatus )
    WITH VALUE #( FOR key IN keys (
        %tky = key-%tky
        OverallStatus = 'A'
    ) ).

    " Read after modify
    READ ENTITIES OF zlaw_i_travel_d
    IN LOCAL MODE
    ENTITY zlaw_i_travel_d
    ALL FIELDS WITH
    CORRESPONDING #( keys )
    RESULT DATA(lt_read_result).

    result = VALUE #( FOR travel IN lt_read_result ( %tky = travel-%tky
    %param = travel ) ).

  ENDMETHOD.

  METHOD deductDiscount.
    DATA: lv_disc_float TYPE decfloat16.
    DATA: lt_travel_new TYPE TABLE FOR UPDATE ZLAW_I_Travel_D.
    DATA(lt_keys_tmp) = keys.

    LOOP AT lt_keys_tmp ASSIGNING FIELD-SYMBOL(<lfs_keys>)
    WHERE %param-discount IS INITIAL
    OR %param-discount GT 100
    OR %param-discount LE 0.

      APPEND VALUE #( %tky = <lfs_keys>-%tky ) TO failed-zlaw_i_travel_d.

      APPEND VALUE #(
        %tky = <lfs_keys>-%tky
        %msg = NEW /dmo/cm_flight_messages(
            textid = /dmo/cm_flight_messages=>discount_invalid
            severity = if_abap_behv_message=>severity-error
        )
        %element-bookingfee = if_abap_behv=>mk-on
        %action-deductDiscount = if_abap_behv=>mk-on
      ) TO reported-zlaw_i_travel_d.

      " NOT RECOMMENDED.. PERO FOR SAKE OF TRAINING, GAWIN NATIN
      DELETE lt_keys_tmp.
    ENDLOOP.

    IF lt_keys_tmp IS NOT INITIAL.
      " Read from TB
      READ ENTITIES OF ZLAW_i_Travel_D
      IN LOCAL MODE
      ENTITY ZLAW_I_Travel_D
      FIELDS ( BookingFee )
      WITH CORRESPONDING #( lt_keys_tmp )
      RESULT DATA(lt_result_read)
      FAILED DATA(lt_failed_read).

      IF lt_result_read IS NOT INITIAL.
        LOOP AT lt_result_read ASSIGNING FIELD-SYMBOL(<lfs_result_read>).


          DATA(lv_discount) = lt_keys_tmp[ KEY id %tky = <lfs_result_read>-%tky ]-%param-discount.
          lv_disc_float = lv_discount / 100.

          DATA(lv_disc_booking_fee) = <lfs_result_read>-bookingfee - ( <lfs_result_read>-bookingfee * lv_disc_float ).


          APPEND VALUE #(
               %tky = <lfs_result_read>-%tky
               BookingFee = lv_disc_booking_fee
          ) TO lt_travel_new.


        ENDLOOP.

        MODIFY ENTITIES OF ZLAW_I_Travel_D
        IN LOCAL MODE
        ENTITY ZLAW_I_Travel_D
        UPDATE
        FIELDS ( BookingFee )
        WITH lt_travel_new.

        " Read back
        READ ENTITIES OF ZLAW_I_Travel_D
        IN LOCAL MODE
        ENTITY ZLAW_I_Travel_D
        ALL FIELDS WITH CORRESPONDING #( lt_result_read )
        RESULT DATA(lt_modified_data).

        result = VALUE #( FOR ls_modified IN lt_modified_data (
            %tky = ls_modified-%tky
            %param = ls_modified
        ) ).

      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD reCalculateTotalPrice.
 TYPES: BEGIN OF ty_amount_per_currencycode,
             amount        TYPE /dmo/total_price,
             currency_code TYPE /dmo/currency_code,
           END OF ty_amount_per_currencycode.

    DATA: lt_amt_per_ccode TYPE STANDARD TABLE OF ty_amount_per_currencycode.

    " Read all relevant travel instances.
    READ ENTITIES OF ZLAW_I_Travel_D IN LOCAL MODE
         ENTITY ZLAW_I_Travel_D
            FIELDS ( BookingFee CurrencyCode )
            WITH CORRESPONDING #( keys )
         RESULT DATA(lt_travels).

    DELETE lt_travels WHERE CurrencyCode IS INITIAL.

    LOOP AT lt_travels ASSIGNING FIELD-SYMBOL(<travel>).
      " Set the start for the calculation by adding the booking fee.
      lt_amt_per_ccode = VALUE #( ( amount        = <travel>-BookingFee
                                           currency_code = <travel>-CurrencyCode ) ).

      " Read all associated bookings and add them to the total price.
      READ ENTITIES OF ZLAW_I_Travel_D IN LOCAL MODE
        ENTITY ZLAW_I_Travel_D BY \_Booking
          FIELDS ( FlightPrice CurrencyCode )
        WITH VALUE #( ( %tky = <travel>-%tky ) )
        RESULT DATA(lt_bookings).

      LOOP AT lt_bookings INTO DATA(booking) WHERE CurrencyCode IS NOT INITIAL.
        COLLECT VALUE ty_amount_per_currencycode( amount        = booking-FlightPrice
                                                  currency_code = booking-CurrencyCode ) INTO lt_amt_per_ccode.
      ENDLOOP.

*      " Read all associated booking supplements and add them to the total price.
*      READ ENTITIES OF ZLAW_I_Travel_D IN LOCAL MODE
*        ENTITY ZLAW_I_Travel_D BY \_BookingSupplement
*          FIELDS ( BookSupplPrice CurrencyCode )
*        WITH VALUE #( FOR rba_booking IN lt_bookings ( %tky = rba_booking-%tky ) )
*        RESULT DATA(lt_bookingsupplements).
*
*      LOOP AT lt_bookingsupplements INTO DATA(bookingsupplement) WHERE CurrencyCode IS NOT INITIAL.
*        COLLECT VALUE ty_amount_per_currencycode( amount        = bookingsupplement-BookSupplPrice
*                                                  currency_code = bookingsupplement-CurrencyCode ) INTO lt_amt_per_ccode.
*      ENDLOOP.

      CLEAR <travel>-TotalPrice.
      LOOP AT lt_amt_per_ccode INTO DATA(single_amount_per_currencycode).
        " If needed do a Currency Conversion
        IF single_amount_per_currencycode-currency_code = <travel>-CurrencyCode.
          <travel>-TotalPrice += single_amount_per_currencycode-amount.
        ELSE.
          /dmo/cl_flight_amdp=>convert_currency(
             EXPORTING
               iv_amount                   =  single_amount_per_currencycode-amount
               iv_currency_code_source     =  single_amount_per_currencycode-currency_code
               iv_currency_code_target     =  <travel>-CurrencyCode
               iv_exchange_rate_date       =  cl_abap_context_info=>get_system_date( )
             IMPORTING
               ev_amount                   = DATA(total_booking_price_per_curr)
            ).
          <travel>-TotalPrice += total_booking_price_per_curr.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    " write back the modified total_price of travels
    MODIFY ENTITIES OF ZLAW_I_Travel_D IN LOCAL MODE
      ENTITY ZLAW_I_Travel_D
        UPDATE FIELDS ( TotalPrice )
        WITH CORRESPONDING #( lt_travels ).
  ENDMETHOD.

  METHOD rejectTravel.
    MODIFY ENTITIES OF ZLAW_I_Travel_D
    IN LOCAL MODE
    ENTITY ZLAW_I_Travel_D
    UPDATE FIELDS ( OverallStatus )
    WITH VALUE #( FOR key IN keys (
        %tky = key-%tky
        OverallStatus = 'X'
    ) ).

    " Read after modify
    READ ENTITIES OF zlaw_i_travel_d
    IN LOCAL MODE
    ENTITY zlaw_i_travel_d
    ALL FIELDS WITH
    CORRESPONDING #( keys )
    RESULT DATA(lt_read_result).

    result = VALUE #( FOR travel IN lt_read_result ( %tky = travel-%tky
    %param = travel ) ).

  ENDMETHOD.

ENDCLASS.
