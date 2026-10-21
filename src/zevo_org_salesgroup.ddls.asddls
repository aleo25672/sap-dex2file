@AbapCatalog.sqlViewName: 'ZEVOORGSALSGP'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Group (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_SalesGroup
  as select from I_SalesGroup
{
  key SalesGroup
}
