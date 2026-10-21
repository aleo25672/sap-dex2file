@AbapCatalog.sqlViewName: 'ZEVOORGDISTCH'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Distribution Channel (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_DistChannel
  as select from I_DistributionChannel
{
  key DistributionChannel
}
