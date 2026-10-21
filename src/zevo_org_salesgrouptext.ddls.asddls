@AbapCatalog.sqlViewName: 'ZEVOORGSALSGPT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Group Text (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_SalesGroupText
  as select from I_SalesGroupText
{
  key SalesGroup,
  key Language,
      SalesGroupName
}
