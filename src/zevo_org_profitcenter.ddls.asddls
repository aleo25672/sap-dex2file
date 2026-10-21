@AbapCatalog.sqlViewName: 'ZEVOORGPCTR'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Profit Center (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MASTER }
define view ZEVO_ORG_ProfitCenter
  as select from I_ProfitCenter
  association [0..1] to ZEVO_ORG_ControllingArea as _ControllingArea
    on $projection.ControllingArea = _ControllingArea.ControllingArea
  association [0..*] to ZEVO_ORG_ProfitCenterText as _Text
    on $projection.ControllingArea = _Text.ControllingArea
   and $projection.ProfitCenter = _Text.ProfitCenter
   and $projection.ValidityEndDate = _Text.ValidityEndDate
{
  key ControllingArea,
  key ProfitCenter,
  key ValidityEndDate,
      ValidityStartDate,
      Segment,
      _ControllingArea,
      _Text
}
