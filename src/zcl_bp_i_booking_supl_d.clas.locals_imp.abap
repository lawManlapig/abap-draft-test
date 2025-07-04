CLASS lhc_ZLAW_I_BkSuppl_D DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ZLAW_I_BkSuppl_D~calculateTotalPrice.

    METHODS setBookSupplNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR ZLAW_I_BkSuppl_D~setBookSupplNumber.
    METHODS validateSupplement FOR VALIDATE ON SAVE
      IMPORTING keys FOR ZLAW_I_BkSuppl_D~validateSupplement.

ENDCLASS.

CLASS lhc_ZLAW_I_BkSuppl_D IMPLEMENTATION.

  METHOD calculateTotalPrice.
    " Read all parent UUIDs
    READ ENTITIES OF ZLAW_I_Travel_D IN LOCAL MODE
      ENTITY ZLAW_I_BkSuppl_D BY \_Travel
        FIELDS ( TravelUUID  )
        WITH CORRESPONDING #(  keys  )
      RESULT DATA(travels).

    " Trigger Re-Calculation on Root Node
    MODIFY ENTITIES OF ZLAW_I_Travel_D IN LOCAL MODE
      ENTITY ZLAW_I_Travel_D
        EXECUTE reCalculateTotalPrice
          FROM CORRESPONDING  #( travels ).
  ENDMETHOD.

  METHOD setBookSupplNumber.
    DATA max_bookingsupplementid TYPE /dmo/booking_supplement_id.
    DATA bookingsupplements_update TYPE TABLE FOR UPDATE ZLAW_I_Travel_D\\ZLAW_I_BkSuppl_D.

    "Read all bookings for the requested booking supplements
    " If multiple booking supplements of the same booking are requested, the booking is returned only once.
    READ ENTITIES OF ZLAW_I_Travel_D IN LOCAL MODE
      ENTITY ZLAW_I_BkSuppl_D BY \_Booking
        FIELDS (  BookingUUID  )
        WITH CORRESPONDING #( keys )
      RESULT DATA(bookings).

    " Process all affected bookings. Read respective booking supplements for one booking
    LOOP AT bookings INTO DATA(ls_booking).
      READ ENTITIES OF ZLAW_I_Travel_D IN LOCAL MODE
        ENTITY ZLAW_I_Booking_D BY \_BookingSupplement
          FIELDS ( BookingSupplementID )
          WITH VALUE #( ( %tky = ls_booking-%tky ) )
        RESULT DATA(bookingsupplements).

      " find max used bookingID in all bookings of this travel
      max_bookingsupplementid = '00'.
      LOOP AT bookingsupplements INTO DATA(bookingsupplement).
        IF bookingsupplement-BookingSupplementID > max_bookingsupplementid.
          max_bookingsupplementid = bookingsupplement-BookingSupplementID.
        ENDIF.
      ENDLOOP.

      "Provide a booking supplement ID for all booking supplement of this booking that have none.
      LOOP AT bookingsupplements INTO bookingsupplement WHERE BookingSupplementID IS INITIAL.
        max_bookingsupplementid += 1.
        APPEND VALUE #( %tky                = bookingsupplement-%tky
                        bookingsupplementid = max_bookingsupplementid
                      ) TO bookingsupplements_update.

      ENDLOOP.
    ENDLOOP.

    " Provide a booking ID for all bookings that have none.
    MODIFY ENTITIES OF ZLAW_I_Travel_D IN LOCAL MODE
      ENTITY ZLAW_I_BkSuppl_D
        UPDATE FIELDS ( BookingSupplementID ) WITH bookingsupplements_update.

  ENDMETHOD.

  METHOD validateSupplement.

    READ ENTITIES OF ZLAW_I_Travel_D IN LOCAL MODE
             ENTITY ZLAW_I_BkSuppl_D
             FIELDS ( SupplementID )
             WITH CORRESPONDING #( keys )
             RESULT DATA(bookingsupplements)
             FAILED DATA(read_failed).

    failed = CORRESPONDING #( DEEP read_failed ).

    READ ENTITIES OF ZLAW_I_Travel_D IN LOCAL MODE
         ENTITY ZLAW_I_BkSuppl_D BY \_Booking
         FROM CORRESPONDING #( bookingsupplements )
         LINK DATA(booksuppl_booking_links).

    READ ENTITIES OF ZLAW_I_Travel_D IN LOCAL MODE
         ENTITY ZLAW_I_BkSuppl_D BY \_Travel
         FROM CORRESPONDING #( bookingsupplements )
         LINK DATA(booksuppl_travel_links).

    DATA supplements TYPE SORTED TABLE OF /dmo/supplement WITH UNIQUE KEY supplement_id.

    " Optimization of DB select: extract distinct non-initial customer IDs
    supplements = CORRESPONDING #( bookingsupplements DISCARDING DUPLICATES MAPPING supplement_id = SupplementID EXCEPT * ).
    DELETE supplements WHERE supplement_id IS INITIAL.

    IF supplements IS NOT INITIAL.
      " Check if customer ID exists
      SELECT FROM /dmo/supplement
        FIELDS supplement_id
        FOR ALL ENTRIES IN @supplements
        WHERE supplement_id = @supplements-supplement_id
        INTO TABLE @DATA(valid_supplements).
    ENDIF.

    LOOP AT bookingsupplements ASSIGNING FIELD-SYMBOL(<bookingsupplement>).

      APPEND VALUE #( %tky        = <bookingsupplement>-%tky
                      %state_area = 'VALIDATE_SUPPLEMENT' )
             TO reported-ZLAW_I_BkSuppl_D.

      IF <bookingsupplement>-SupplementID IS INITIAL.
        APPEND VALUE #( %tky = <bookingsupplement>-%tky ) TO failed-ZLAW_I_BkSuppl_D.

        APPEND VALUE #(
            %tky                  = <bookingsupplement>-%tky
            %state_area           = 'VALIDATE_SUPPLEMENT'
            %msg                  = NEW /dmo/cm_flight_messages( textid   = /dmo/cm_flight_messages=>enter_supplement_id
                                                                 severity = if_abap_behv_message=>severity-error )
            %path                 = VALUE #(
                ZLAW_I_Booking_D-%tky = booksuppl_booking_links[ KEY id
                                                             source-%tky = <bookingsupplement>-%tky ]-target-%tky
                ZLAW_I_Travel_D-%tky  = booksuppl_travel_links[  KEY id
                                                            source-%tky = <bookingsupplement>-%tky ]-target-%tky )
            %element-SupplementID = if_abap_behv=>mk-on )
               TO reported-ZLAW_I_BkSuppl_D.

      ELSEIF <bookingsupplement>-SupplementID IS NOT INITIAL AND NOT line_exists( valid_supplements[
                                                                                      supplement_id = <bookingsupplement>-SupplementID ] ).
        APPEND VALUE #( %tky = <bookingsupplement>-%tky ) TO failed-ZLAW_I_BkSuppl_D.

        APPEND VALUE #(
            %tky                  = <bookingsupplement>-%tky
            %state_area           = 'VALIDATE_SUPPLEMENT'
            %msg                  = NEW /dmo/cm_flight_messages( textid   = /dmo/cm_flight_messages=>supplement_unknown
                                                                 severity = if_abap_behv_message=>severity-error )
            %path                 = VALUE #(
                ZLAW_I_Booking_D-%tky = booksuppl_booking_links[ KEY id
                                                             source-%tky = <bookingsupplement>-%tky ]-target-%tky
                ZLAW_I_Travel_D-%tky  = booksuppl_travel_links[  KEY id
                                                            source-%tky = <bookingsupplement>-%tky ]-target-%tky )
            %element-SupplementID = if_abap_behv=>mk-on )
               TO reported-ZLAW_I_BkSuppl_D.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
