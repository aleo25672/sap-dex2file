@AbapCatalog.sqlViewName: 'ZEVOORGSAPLT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Area Plant (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_SalesAreaPlant
  as select from tvkwz
  association [0..1] to ZEVO_ORG_Plant as _Plant
    on $projection.Plant = _Plant.Plant
  association [0..1] to ZEVO_ORG_SalesOrg as _SalesOrganization
    on $projection.SalesOrganization = _SalesOrganization.SalesOrganization
  association [0..1] to ZEVO_ORG_DistChannel as _DistributionChannel
    on $projection.DistributionChannel = _DistributionChannel.DistributionChannel
{
  key vkorg as SalesOrganization,
  key vtweg as DistributionChannel,
  key werks as Plant,
      _Plant,
      _SalesOrganization,
      _DistributionChannel
}
