@AbapCatalog.sqlViewName: 'ZEVOORGPCTR'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Profit Center (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MASTER }
define view ZEVO_ORG_ProfitCenter
  as select from I_ProfitCenter
  association [0..1] to ZEVO_ORG_ControllingArea as _ControllingArea
    on $projection.ControllingArea = _ControllingArea.ControllingArea
{
  key ControllingArea,
  key ProfitCenter,
  key ValidityEndDate,
      ValidityStartDate,
      Segment,
      _ControllingArea
}
