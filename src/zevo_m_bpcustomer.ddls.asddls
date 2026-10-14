@AbapCatalog.sqlViewName: 'ZEVOMBPCUST'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Business Partner Customer Role (Master Data)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MASTER }
define view ZEVO_M_BPCustomer
  as select from I_BusinessPartnerCustomerDEX
{
  key BusinessPartner,
  key Customer,
      CustomerAccountGroup,
      AuthorizationGroup,
      BillingIsBlockedForCustomer,
      OrderIsBlockedForCustomer,
      DeliveryIsBlocked,
      PostingIsBlocked,
      PaymentIsBlockedForCustomer,
      DeletionIndicator,
      IsOneTimeAccount,
      VATLiability,
      TaxNumberType,
      TaxNumber1,
      TaxNumber2,
      TaxNumber3,
      TaxNumber4,
      TaxNumber5,
      CustomerCorporateGroup,
      Supplier,
      Country,
      IsBusinessPurposeCompleted,
      DataMediumExchangeIndicator,
      AlternativePayeeIsAllowed,
      PaymentReason,
      DataControllerSet,
      DataController1,
      DataController2,
      DataController3,
      DataController4,
      DataController5,
      DataController6,
      DataController7,
      DataController8,
      DataController9,
      DataController10
}
