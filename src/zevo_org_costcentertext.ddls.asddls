@AbapCatalog.sqlViewName: 'ZEVOORGCCTRT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Cost Center Text (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MASTER }
define view ZEVO_ORG_CostCenterText
  as select from I_CostCenterText
{
  key Language,
  key ControllingArea,
  key CostCenter,
  key ValidityEndDate,
      ValidityStartDate,
      CostCenterName,
      CostCenterDescription
}
