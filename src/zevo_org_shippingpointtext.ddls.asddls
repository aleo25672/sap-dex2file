@AbapCatalog.sqlViewName: 'ZEVOORGSHIPPTT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Shipping Point Text (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_ShippingPointText
  as select from I_ShippingPointText
{
  key ShippingPoint,
  key Language,
      ShippingPointName
}
