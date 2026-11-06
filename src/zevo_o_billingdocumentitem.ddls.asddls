@AbapCatalog.sqlViewName: 'ZEVOOBILLITEM'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Billing Document Item (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@Metadata.ignorePropagatedAnnotations: true
define view ZEVO_O_BillingDocumentItem
  // S/4 2023 (108): I_BillingDocumentItemDEX missing — classic ODP Basic DEX
  as select from C_BillingDocumentItemBasicDEX
  association [0..1] to ZEVO_O_OutboundDelivery as _OutboundDelivery
    on $projection.ReferenceSDDocument = _OutboundDelivery.OutboundDelivery
{
  key BillingDocument,
  key BillingDocumentItem,
      SalesDocumentItemCategory,
      CreatedByUser,
      CreationDate,
      CreationTime,
      BillingDocumentType as BillingDocumentTypeCode,
      SDDocumentCategory,
      Material,
      Plant,
      BillingQuantity,
      BillingQuantityUnit,
      NetAmount,
      TaxAmount,
      TransactionCurrency,
      BillingDocumentDate,
      CompanyCode,
      SalesDocument,
      SalesDocumentItem,
      ReferenceSDDocument,
      ReferenceSDDocumentItem,
      ReferenceSDDocumentCategory,
      _OutboundDelivery
}
