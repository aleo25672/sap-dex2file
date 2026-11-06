@AbapCatalog.sqlViewName: 'ZEVOMBPSUPPL'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Business Partner Supplier Role (Master Data)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MASTER }
@Metadata.ignorePropagatedAnnotations: true
define view ZEVO_M_BPSupplier
  // S/4 2023 (108): I_BusinessPartnerSupplierDEX not available — use released I_*
  as select from I_BusinessPartnerSupplier
  association [0..1] to ZEVO_M_Supplier as _Supplier
    on $projection.Supplier = _Supplier.Supplier
{
  key BusinessPartner,
  key Supplier,
      BusinessPartnerUUID,
      SupplierAccountGroup,
      Customer,
      PostingIsBlocked,
      PurchasingIsBlocked,
      VATLiability,
      PaymentIsBlockedForSupplier,
      AuthorizationGroup,
      SupplierCorporateGroup,
      DeletionIndicator,
      IsOneTimeAccount,
      _Supplier
}
