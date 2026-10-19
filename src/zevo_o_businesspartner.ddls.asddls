@AbapCatalog.sqlViewName: 'ZEVOOBPARTNER'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Business Partner lean (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MASTER }
define view ZEVO_O_BusinessPartner
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
