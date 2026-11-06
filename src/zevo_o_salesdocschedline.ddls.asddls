@AbapCatalog.sqlViewName: 'ZEVOOSLSSCHED'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Document Schedule Line DEX (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@Metadata.ignorePropagatedAnnotations: true
define view ZEVO_O_SalesDocSchedLine
  as select from C_SalesDocumentSchedLineDEX
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
      // S/4 2023 (108): org / partner columns omitted if missing on local DEX
      Material,
      Product,
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
