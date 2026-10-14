@AbapCatalog.sqlViewName: 'ZEVOMBPBANK'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Business Partner Bank (Master Data)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MASTER }
define view ZEVO_M_BPBank
  as select from I_BusinessPartnerBank
{
  key BusinessPartner,
  key BankIdentification,
      BankCountryKey,
      BankName,
      BankNumber,
      SWIFTCode,
      BankControlKey,
      BankAccountHolderName,
      BankAccountName,
      BankAccount,
      BankAccountReferenceText,
      CollectionAuthInd,
      IBAN,
      IBANValidityStartDate,
      ValidityStartDate,
      ValidityEndDate,
      BusinessPartnerExternalBankId,
      @Semantics.businessDate.at: true
      BPBankDetailsChangeDate,
      BPBankDetailsChangeTargetID,
      CityName,
      AuthorizationGroup
}
