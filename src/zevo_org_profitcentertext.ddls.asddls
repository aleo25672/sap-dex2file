@AbapCatalog.sqlViewName: 'ZEVOORGPCTRT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Profit Center Text (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MASTER }
define view ZEVO_ORG_ProfitCenterText
  as select from I_ProfitCenterText
{
  key Language,
  key ControllingArea,
  key ProfitCenter,
  key ValidityEndDate,
      ValidityStartDate,
      ProfitCenterName,
      ProfitCenterLongName
}
