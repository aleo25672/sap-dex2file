@AbapCatalog.sqlViewName: 'ZEVOORGCCTR'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Cost Center (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MASTER }
define view ZEVO_ORG_CostCenter
  as select from I_CostCenter
  association [0..1] to ZEVO_ORG_CompanyCode as _CompanyCode
    on $projection.CompanyCode = _CompanyCode.CompanyCode
  association [0..1] to ZEVO_ORG_ControllingArea as _ControllingArea
    on $projection.ControllingArea = _ControllingArea.ControllingArea
  association [0..*] to ZEVO_ORG_CostCenterText as _CostCenterText
    on $projection.ControllingArea = _CostCenterText.ControllingArea
   and $projection.CostCenter = _CostCenterText.CostCenter
   and $projection.ValidityEndDate = _CostCenterText.ValidityEndDate
{
  key ControllingArea,
  key CostCenter,
  key ValidityEndDate,
      ValidityStartDate,
      CompanyCode,
      CostCenterCategory,
      ProfitCenter,
      _CompanyCode,
      _ControllingArea,
      _CostCenterText
}
