@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'test CDS - Booking (Draft)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZLAW_I_Booking_D
  as select from /dmo/a_booking_d

  association        to parent ZLAW_I_Travel_D   as _Travel        on  $projection.TravelUUID = _Travel.TravelUUID
  composition [0..*] of ZLAW_I_BkSuppl_D         as _BookingSupplement

  association [1..1] to /DMO/I_Customer          as _Customer      on  $projection.CustomerID = _Customer.CustomerID
  association [1..1] to /DMO/I_Carrier           as _Carrier       on  $projection.AirlineID = _Carrier.AirlineID
  association [1..1] to /DMO/I_Connection        as _Connection    on  $projection.AirlineID    = _Connection.AirlineID
                                                                   and $projection.ConnectionID = _Connection.ConnectionID
  association [1..1] to /DMO/I_Booking_Status_VH as _BookingStatus on  $projection.BookingStatus = _BookingStatus.BookingStatus

{
  key booking_uuid          as BookingUUID,
      parent_uuid           as TravelUUID,

      booking_id            as BookingID,
      booking_date          as BookingDate,
      customer_id           as CustomerID,
      carrier_id            as AirlineID,
      connection_id         as ConnectionID,
      flight_date           as FlightDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      flight_price          as FlightPrice,
      currency_code         as CurrencyCode,
      booking_status        as BookingStatus,

      //local ETag field --> OData ETag
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      //Associations
      _Travel,
      _BookingSupplement,

      _Customer,
      _Carrier,
      _Connection,
      _BookingStatus
}
