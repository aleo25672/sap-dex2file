@AbapCatalog.sqlViewName: 'ZEVOFIPCTR'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Profit Center (General Ledger)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MASTER }
define view ZEVO_FI_ProfitCenter
  as select from I_ProfitCenter
{
  key ControllingArea,
  key ProfitCenter,
  key ValidityEndDate,
      ValidityStartDate,
      ProfitCenterName,
      Segment
}
