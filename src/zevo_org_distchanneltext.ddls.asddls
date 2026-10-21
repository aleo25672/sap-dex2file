@AbapCatalog.sqlViewName: 'ZEVOORGDISTCHT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Distribution Channel Text (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_DistChannelText
  as select from I_DistributionChannelText
{
  key DistributionChannel,
  key Language,
      DistributionChannelName
}
