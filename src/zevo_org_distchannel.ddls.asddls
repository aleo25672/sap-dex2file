@AbapCatalog.sqlViewName: 'ZEVOORGDISTCH'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Distribution Channel (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_DistChannel
  as select from I_DistributionChannel
  association [0..*] to ZEVO_ORG_DistChannelText as _Text
    on $projection.DistributionChannel = _Text.DistributionChannel
{
  key DistributionChannel,
      _Text
}
