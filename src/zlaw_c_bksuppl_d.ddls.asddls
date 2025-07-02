@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'test CDS - Booking Sp Projection (Draft)'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@Search.searchable: true
define view entity ZLAW_C_BkSuppl_D
  as projection on ZLAW_I_BkSuppl_D
{
  key BookSupplUUID,

      TravelUUID,

      BookingUUID,

      @Search.defaultSearchElement: true
      BookingSupplementID,

      @ObjectModel.text.element: ['SupplementDescription']
      @Consumption.valueHelpDefinition: [
          {  entity: {name: '/DMO/I_Supplement_StdVH', element: 'SupplementID' },
             additionalBinding: [ { localElement: 'BookSupplPrice',  element: 'Price',        usage: #RESULT },
                                  { localElement: 'CurrencyCode',    element: 'CurrencyCode', usage: #RESULT }]
              }
        ]
      SupplementID,
      _SupplementText.Description as SupplementDescription : localized,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      BookSupplPrice,

      @Consumption.valueHelpDefinition: [{entity: {name: 'I_CurrencyStdVH', element: 'Currency' }, useForValidation: true }]
      CurrencyCode,

      LocalLastChangedAt,

      /* Associations */
      _Booking : redirected to parent ZLAW_C_Booking_D,
      _Product,
      _SupplementText,
      _Travel  : redirected to ZLAW_C_Travel_D
}
