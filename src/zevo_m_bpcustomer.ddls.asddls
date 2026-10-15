@AbapCatalog.sqlViewName: 'ZEVOMBPCUST'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Business Partner Customer Role (Master Data)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MASTER }
define view ZEVO_M_BPCustomer
  as select from I_BusinessPartnerCustomerDEX as Dex
  left outer join I_Customer as Cust
    on Dex.Customer = Cust.Customer
{
  key Dex.BusinessPartner,
  key Dex.Customer,
      Dex.CustomerAccountGroup,
      Dex.AuthorizationGroup,
      Dex.BillingIsBlockedForCustomer,
      Dex.OrderIsBlockedForCustomer,
      Dex.DeliveryIsBlocked,
      Dex.PostingIsBlocked,
      Dex.PaymentIsBlockedForCustomer,
      Dex.DeletionIndicator,
      Dex.IsOneTimeAccount,
      Dex.VATLiability,
      Dex.TaxNumberType,
      Dex.TaxNumber1,
      Dex.TaxNumber2,
      Dex.TaxNumber3,
      Dex.TaxNumber4,
      Dex.TaxNumber5,
      Dex.CustomerCorporateGroup,
      Dex.Supplier,
      Dex.Country,
      Dex.IsBusinessPurposeCompleted,
      Dex.DataMediumExchangeIndicator,
      Dex.AlternativePayeeIsAllowed,
      Dex.PaymentReason,
      Cust.TradingPartner,
      Dex.DataControllerSet,
      Dex.DataController1,
      Dex.DataController2,
      Dex.DataController3,
      Dex.DataController4,
      Dex.DataController5,
      Dex.DataController6,
      Dex.DataController7,
      Dex.DataController8,
      Dex.DataController9,
      Dex.DataController10
}
