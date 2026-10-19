@AbapCatalog.sqlViewName: 'ZEVOOBILLITEM'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Billing Document Item DEX (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_O_BillingDocumentItem
  as select from I_BillingDocumentItemDEX
  association [0..1] to ZEVO_O_OutboundDelivery as _OutboundDelivery
    on $projection.ReferenceSDDocument = _OutboundDelivery.OutboundDelivery
  association [0..1] to ZEVO_O_BusinessPartner as _SoldToParty
    on $projection.SoldToParty = _SoldToParty.BusinessPartner
  association [0..1] to ZEVO_O_BusinessPartner as _BillToParty
    on $projection.BillToParty = _BillToParty.BusinessPartner
{
  key BillingDocument,
  key BillingDocumentItem,
      SalesDocumentItemCategory,
      CreatedByUser,
      CreationDate,
      CreationTime,
      BillingDocumentType as BillingDocumentTypeCode,
      BillingDocumentCategory,
      SDDocumentCategory,
      Material,
      Product,
      Plant,
      BillingQuantity,
      BillingQuantityUnit,
      NetAmount,
      GrossAmount,
      TaxAmount,
      TransactionCurrency,
      PricingDate,
      BillingDocumentDate,
      SalesOrganization,
      DistributionChannel,
      SoldToParty,
      ShipToParty,
      BillToParty,
      PayerParty,
      CompanyCode,
      SalesDocument,
      SalesDocumentItem,
      ReferenceSDDocument,
      ReferenceSDDocumentItem,
      ReferenceSDDocumentCategory,
      OverallSDProcessStatus,
      OverallBillingStatus,
      CancelledBillingDocument,
      _OutboundDelivery,
      _SoldToParty,
      _BillToParty
}
