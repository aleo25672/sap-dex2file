@AbapCatalog.sqlViewName: 'ZEVOCPURCONTR'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Purchase Contract Header (C2P)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_PurchaseContract
  as select from C_PurchaseContractDEX
  association [0..*] to ZEVO_C_PurchContractItem as _Item
    on $projection.PurchaseContract = _Item.PurchaseContract
  association [0..1] to ZEVO_C_BusinessPartner as _Supplier
    on $projection.Supplier = _Supplier.BusinessPartner
  association [0..*] to ZEVO_C_BPSupplier as _BPSupplier
    on $projection.Supplier = _BPSupplier.Supplier
{
  key PurchaseContract,
      PurchaseContractType as PurchaseContractTypeCode,
      PurchasingGroup,
      PurchasingOrganization,
      ValidityStartDate,
      ValidityEndDate,
      Supplier,
      InvoicingParty,
      SupplyingSupplier,
      CreationDate,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangeDateTime,
      DocumentCurrency,
      ExchangeRate,
      PurchasingDocumentCategory,
      CompanyCode,
      IncotermsClassification,
      IncotermsTransferLocation,
      PaymentTerms,
      CashDiscount1Days,
      CashDiscount2Days,
      NetPaymentDays,
      CashDiscount1Percent,
      CashDiscount2Percent,
      PurchaseContractTargetAmount,
      ReleaseCode,
      CreatedByUser,
      PurchasingDocumentDeletionCode,
      ExchangeRateIsFixed,
      QuotationSubmissionDate,
      SupplierQuotation,
      CorrespncExternalReference,
      CorrespncInternalReference,
      SupplierRespSalesPersonName,
      SupplierPhoneNumber,
      IncotermsVersion,
      IncotermsLocation1,
      IncotermsLocation2,
      ReleaseIsNotCompleted,
      SupplierAddressId,
      _Item,
      _Supplier,
      _BPSupplier
}
