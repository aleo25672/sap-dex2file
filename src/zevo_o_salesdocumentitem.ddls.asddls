@AbapCatalog.sqlViewName: 'ZEVOOSLSDOCIT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Document Item DEX (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@Metadata.ignorePropagatedAnnotations: true
define view ZEVO_O_SalesDocumentItem
  as select from C_SalesDocumentItemDEX
  association [0..*] to ZEVO_O_SalesDocSchedLine as _ScheduleLine
    on $projection.SalesDocument = _ScheduleLine.SalesDocument
   and $projection.SalesDocumentItem = _ScheduleLine.SalesDocumentItem
  association [0..*] to ZEVO_O_OutboundDelivItem as _OutboundDeliveryItem
    on $projection.SalesDocument = _OutboundDeliveryItem.ReferenceSDDocument
   and $projection.SalesDocumentItem = _OutboundDeliveryItem.ReferenceSDDocumentItem
  association [0..*] to ZEVO_O_BillingDocumentItem as _BillingDocumentItem
    on $projection.SalesDocument = _BillingDocumentItem.SalesDocument
   and $projection.SalesDocumentItem = _BillingDocumentItem.SalesDocumentItem
{
  key SalesDocument,
  key SalesDocumentItem,
      SDDocumentCategory,
      SalesDocumentType as SalesDocumentTypeCode,
      SalesDocumentItemCategory,
      CreationDate,
      CreationTime,
      @Semantics.systemDate.lastChangedAt: true
      LastChangeDate,
      // S/4 2023 (108): SalesOrganization, DistributionChannel, Division,
      // SoldToParty, ShipToParty, BillToParty, PayerParty not on local DEX
      Material,
      Product,
      SalesDocumentDate,
      OrderQuantity,
      OrderQuantityUnit,
      NetAmount,
      TransactionCurrency,
      ReferenceSDDocument,
      ReferenceSDDocumentCategory,
      _ScheduleLine,
      _OutboundDeliveryItem,
      _BillingDocumentItem
}
