CLASS lhc_ZLAW_I_BkSuppl_D DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ZLAW_I_BkSuppl_D~calculateTotalPrice.

    METHODS setBookSupplNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR ZLAW_I_BkSuppl_D~setBookSupplNumber.

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

ENDCLASS.
