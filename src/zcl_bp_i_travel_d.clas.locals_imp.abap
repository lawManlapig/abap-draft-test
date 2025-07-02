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

ENDCLASS.
