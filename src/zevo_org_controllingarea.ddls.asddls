@AbapCatalog.sqlViewName: 'ZEVOORGCTRLA'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Controlling Area (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_ControllingArea
  as select from I_ControllingArea
{
  key ControllingArea,
      ControllingAreaName,
      FiscalYearVariant,
      ChartOfAccounts,
      ControllingAreaCurrency
}
