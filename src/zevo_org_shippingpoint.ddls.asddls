@AbapCatalog.sqlViewName: 'ZEVOORGSHIPPT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Shipping Point (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_ShippingPoint
  as select from I_ShippingPoint
  association [0..*] to ZEVO_ORG_ShippingPointText as _Text
    on $projection.ShippingPoint = _Text.ShippingPoint
{
  key ShippingPoint,
      _Text
}
