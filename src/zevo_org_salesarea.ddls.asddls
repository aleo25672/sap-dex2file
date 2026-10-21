@AbapCatalog.sqlViewName: 'ZEVOORGSALSA'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Area (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_SalesArea
  as select from I_SalesArea
  association [0..1] to ZEVO_ORG_SalesOrg as _SalesOrganization
    on $projection.SalesOrganization = _SalesOrganization.SalesOrganization
  association [0..1] to ZEVO_ORG_DistChannel as _DistributionChannel
    on $projection.DistributionChannel = _DistributionChannel.DistributionChannel
  association [0..1] to ZEVO_ORG_Division as _Division
    on $projection.Division = _Division.Division
{
  key SalesOrganization,
  key DistributionChannel,
  key Division,
      _SalesOrganization,
      _DistributionChannel,
      _Division
}
