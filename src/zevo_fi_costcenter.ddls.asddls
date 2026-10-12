@AbapCatalog.sqlViewName: 'ZEVOFICCTR'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Cost Center (General Ledger)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MASTER }
define view ZEVO_FI_CostCenter
  as select from I_CostCenter
{
  key ControllingArea,
  key CostCenter,
  key ValidityEndDate,
      ValidityStartDate,
      CompanyCode,
      CostCenterCategory,
      ProfitCenter
}
