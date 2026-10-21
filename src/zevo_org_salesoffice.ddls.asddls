@AbapCatalog.sqlViewName: 'ZEVOORGSALSOF'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Office (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_SalesOffice
  as select from I_SalesOffice
{
  key SalesOffice
}
