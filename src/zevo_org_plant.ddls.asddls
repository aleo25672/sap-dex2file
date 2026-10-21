@AbapCatalog.sqlViewName: 'ZEVOORGPLANT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Plant (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_Plant
  as select from I_Plant
  association [0..1] to ZEVO_ORG_ValuationArea as _ValuationArea
    on $projection.ValuationArea = _ValuationArea.ValuationArea
{
  key Plant,
      PlantName,
      ValuationArea,
      PlantCustomer,
      PlantSupplier,
      FactoryCalendar,
      DefaultPurchasingOrganization,
      SalesOrganization,
      DistributionChannel,
      Division,
      AddressID,
      PlantCategory,
      _ValuationArea
}
