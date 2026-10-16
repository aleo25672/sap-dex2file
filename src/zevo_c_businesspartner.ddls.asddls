@AbapCatalog.sqlViewName: 'ZEVOCBPARTNER'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Business Partner lean (C2P)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MASTER }
define view ZEVO_C_BusinessPartner
  as select from I_BusinessPartner
{
  key BusinessPartner,
      BusinessPartnerCategory,
      BusinessPartnerGrouping,
      BusinessPartnerName,
      BusinessPartnerFullName,
      OrganizationBPName1,
      FirstName,
      LastName,
      FormOfAddress,
      SearchTerm1,
      AuthorizationGroup,
      BusinessPartnerIsBlocked,
      IsActiveEntity,
      CreatedByUser,
      CreationDate,
      LastChangedByUser,
      @Semantics.systemDate.lastChangedAt: true
      LastChangeDate,
      LastChangeTime
}
