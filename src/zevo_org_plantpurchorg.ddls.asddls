@AbapCatalog.sqlViewName: 'ZEVOORGPLPUR'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Plant Purchasing Org (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_PlantPurchOrg
  as select from I_PlantPurchasingOrganization
  association [0..1] to ZEVO_ORG_Plant as _Plant
    on $projection.Plant = _Plant.Plant
  association [0..1] to ZEVO_ORG_PurchasingOrg as _PurchasingOrganization
    on $projection.PurchasingOrganization = _PurchasingOrganization.PurchasingOrganization
{
  key PurchasingOrganization,
  key Plant,
      _Plant,
      _PurchasingOrganization
}
