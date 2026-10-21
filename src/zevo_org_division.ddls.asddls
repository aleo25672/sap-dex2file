@AbapCatalog.sqlViewName: 'ZEVOORGDIV'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Division (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_Division
  as select from I_Division
{
  key Division
}
