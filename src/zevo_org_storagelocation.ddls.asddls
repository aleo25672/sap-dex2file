@AbapCatalog.sqlViewName: 'ZEVOORGSLOC'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Storage Location (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MASTER }
define view ZEVO_ORG_StorageLocation
  as select from I_StorageLocation
  association [0..1] to ZEVO_ORG_Plant as _Plant
    on $projection.Plant = _Plant.Plant
{
  key Plant,
  key StorageLocation,
      StorageLocationName,
      _Plant
}
