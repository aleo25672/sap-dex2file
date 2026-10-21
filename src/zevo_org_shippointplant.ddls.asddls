@AbapCatalog.sqlViewName: 'ZEVOORGSHPPL'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Shipping Point Plant (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_ShipPointPlant
  as select from tvswz
  association [0..1] to ZEVO_ORG_Plant as _Plant
    on $projection.Plant = _Plant.Plant
  association [0..1] to ZEVO_ORG_ShippingPoint as _ShippingPoint
    on $projection.ShippingPoint = _ShippingPoint.ShippingPoint
{
  key werks as Plant,
  key vstel as ShippingPoint,
      _Plant,
      _ShippingPoint
}
