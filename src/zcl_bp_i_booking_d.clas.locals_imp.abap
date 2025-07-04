CLASS lhc_ZLAW_I_Booking_D DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ZLAW_I_Booking_D~calculateTotalPrice.

    METHODS setBookingDate FOR DETERMINE ON SAVE
      IMPORTING keys FOR ZLAW_I_Booking_D~setBookingDate.

    METHODS setBookingNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR ZLAW_I_Booking_D~setBookingNumber.

ENDCLASS.

CLASS lhc_ZLAW_I_Booking_D IMPLEMENTATION.

  METHOD calculateTotalPrice.
    " Read all parent UUIDs
    READ ENTITIES OF zlaw_i_travel_d IN LOCAL MODE
         ENTITY ZLAW_I_Booking_D BY \_Travel
         FIELDS ( TravelUUID  )
         WITH CORRESPONDING #( keys )
         RESULT DATA(travels).

    " Trigger Re-Calculation on Root Node
    MODIFY ENTITIES OF zlaw_i_travel_d IN LOCAL MODE
           ENTITY zlaw_i_travel_d
           EXECUTE reCalculateTotalPrice
           FROM CORRESPONDING #( travels ).
  ENDMETHOD.

  METHOD setBookingDate.
    READ ENTITIES OF zlaw_i_travel_d IN LOCAL MODE
         ENTITY ZLAW_I_Booking_D
         FIELDS ( BookingDate )
         WITH CORRESPONDING #( keys )
         RESULT DATA(bookings).

    DELETE bookings WHERE BookingDate IS NOT INITIAL.
    IF bookings IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT bookings ASSIGNING FIELD-SYMBOL(<booking>).
      <booking>-BookingDate = cl_abap_context_info=>get_system_date( ).
    ENDLOOP.

    MODIFY ENTITIES OF zlaw_i_travel_d IN LOCAL MODE
           ENTITY ZLAW_I_Booking_D
           UPDATE FIELDS ( BookingDate )
           WITH CORRESPONDING #( bookings ).
  ENDMETHOD.

  METHOD setBookingNumber.
    DATA max_bookingid   TYPE /dmo/booking_id.
    DATA bookings_update TYPE TABLE FOR UPDATE zlaw_i_travel_d\\ZLAW_I_Booking_D.

    " Read all travels for the requested bookings
    " If multiple bookings of the same travel are requested, the travel is returned only once.
    READ ENTITIES OF zlaw_i_travel_d IN LOCAL MODE
         ENTITY ZLAW_I_Booking_D BY \_Travel
         FIELDS ( TravelUUID )
         WITH CORRESPONDING #( keys )
         RESULT DATA(travels).

    " Process all affected travels. Read respective bookings for one travel
    LOOP AT travels INTO DATA(travel).
      READ ENTITIES OF zlaw_i_travel_d IN LOCAL MODE
           ENTITY zlaw_i_travel_d BY \_Booking
           FIELDS ( BookingID )
           WITH VALUE #( ( %tky = travel-%tky ) )
           RESULT DATA(bookings).

      " find max used bookingID in all bookings of this travel
      max_bookingid = '0000'.
      LOOP AT bookings INTO DATA(booking).
        IF booking-BookingID > max_bookingid.
          max_bookingid = booking-BookingID.
        ENDIF.
      ENDLOOP.

      " Provide a booking ID for all bookings of this travel that have none.
      LOOP AT bookings INTO booking WHERE BookingID IS INITIAL.
        max_bookingid += 1.
        APPEND VALUE #( %tky      = booking-%tky
                        BookingID = max_bookingid )
               TO bookings_update.

      ENDLOOP.
    ENDLOOP.

    " Provide a booking ID for all bookings that have none.
    MODIFY ENTITIES OF zlaw_i_travel_d IN LOCAL MODE
           ENTITY ZLAW_I_Booking_D
           UPDATE FIELDS ( BookingID )
           WITH bookings_update.
  ENDMETHOD.

ENDCLASS.
