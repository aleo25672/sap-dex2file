@AbapCatalog.sqlViewName: 'ZEVOOSLSSCHED'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Document Schedule Line DEX (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_O_SalesDocSchedLine
  as select from C_SalesDocumentScheduleLineDEX
{
  key SalesDocument,
  key SalesDocumentItem,
  key ScheduleLine,
      CreationDate,
      CreationTime,
      @Semantics.systemDate.lastChangedAt: true
      LastChangeDate,
      SDDocumentCategory,
      SalesDocumentType as SalesDocumentTypeCode,
      SalesDocumentItemCategory,
      ScheduleLineCategory,
      SalesOrganization,
      DistributionChannel,
      Division,
      Material,
      Product,
      SoldToParty,
      ShipToParty,
      BillToParty,
      PayerParty,
      ScheduleLineOrderQuantity,
      OrderQuantityUnit,
      ConfdOrderQtyByMatlAvailCheck,
      DeliveryDate,
      RequestedDeliveryDate,
      ConfirmedDeliveryDate,
      IsConfirmedDelivSchedLine,
      IsRequestedDelivSchedLine,
      Plant,
      ShippingPoint
}
