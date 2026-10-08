@AbapCatalog.sqlViewName: 'ZEVOCPURCHORD'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Purchase Order Header (C2P)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_PurchaseOrder
  as select from C_PurchaseOrderDEX
  association [0..*] to ZEVO_C_PurchaseOrderItem as _Item
    on $projection.PurchaseOrder = _Item.PurchaseOrder
  association [0..1] to ZEVO_C_BusinessPartner as _Supplier
    on $projection.Supplier = _Supplier.BusinessPartner
  association [0..*] to ZEVO_C_BPSupplier as _BPSupplier
    on $projection.Supplier = _BPSupplier.Supplier
{
  key PurchaseOrder,
      PurchaseOrderType,
      PurchaseOrderSubtype,
      PurchasingDocumentOrigin,
      CreatedByUser,
      CreationDate,
      PurchaseOrderDate,
      Language,
      CorrespncExternalReference,
      CorrespncInternalReference,
      PurchasingDocumentDeletionCode,
      ReleaseIsNotCompleted,
      PurchasingCompletenessStatus,
      PurchasingProcessingStatus,
      PurgReleaseSequenceStatus,
      ReleaseCode,
      CompanyCode,
      PurchasingOrganization,
      PurchasingGroup,
      Supplier,
      ManualSupplierAddressId,
      SupplierRespSalesPersonName,
      SupplierPhoneNumber,
      SupplyingSupplier,
      SupplyingPlant,
      InvoicingParty,
      Customer,
      SupplierQuotationExternalId,
      PaymentTerms,
      CashDiscount1Days,
      CashDiscount2Days,
      NetPaymentDays,
      CashDiscount1Percent,
      CashDiscount2Percent,
      DownPaymentType,
      DownPaymentPercentageOfTotAmt,
      DownPaymentAmount,
      DownPaymentDueDate,
      IncotermsClassification,
      IncotermsTransferLocation,
      IncotermsVersion,
      IncotermsLocation1,
      IncotermsLocation2,
      IsIntrastatReportingRelevant,
      IsIntrastatReportingExcluded,
      PricingDocument,
      PricingProcedure,
      DocumentCurrency,
      ValidityStartDate,
      ValidityEndDate,
      ExchangeRate,
      ExchangeRateIsFixed,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangeDateTime,
      TaxReturnCountry,
      VATRegistrationCountry,
      PurgReasonForDocCancellation,
      PurgReleaseTimeTotalAmount,
      _Item,
      _Supplier,
      _BPSupplier
}
