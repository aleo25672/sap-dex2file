@AbapCatalog.sqlViewName: 'ZEVOMBPCUST'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Business Partner Customer Role (Master Data)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MASTER }
@Metadata.ignorePropagatedAnnotations: true
define view ZEVO_M_BPCustomer
  // S/4 2023 (108): I_BusinessPartnerCustomerDEX not available — use released I_* 
  as select from I_BusinessPartnerCustomer
  association [0..1] to ZEVO_M_Customer as _Customer
    on $projection.Customer = _Customer.Customer
{
  key BusinessPartner,
  key Customer,
      BusinessPartnerUUID,
      CustomerAccountGroup,
      AlternativePayerAccount,
      DataMediumExchangeIndicator,
      Supplier,
      CustomerClassification,
      VATLiability,
      PostingIsBlocked,
      DeliveryIsBlocked,
      BillingIsBlockedForCustomer,
      OrderIsBlockedForCustomer,
      IsNaturalPerson,
      AuthorizationGroup,
      CustomerCorporateGroup,
      DeletionIndicator,
      _Customer
}
