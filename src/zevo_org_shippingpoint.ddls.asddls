@AbapCatalog.sqlViewName: 'ZEVOORGSHIPPT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Shipping Point (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_ShippingPoint
  as select from I_ShippingPoint
{
  key ShippingPoint
}
