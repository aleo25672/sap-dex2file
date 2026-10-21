@AbapCatalog.sqlViewName: 'ZEVOORGCOCODE'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Company Code (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_CompanyCode
  as select from I_CompanyCode
  association [0..1] to ZEVO_ORG_ControllingArea as _ControllingArea
    on $projection.ControllingArea = _ControllingArea.ControllingArea
{
  key CompanyCode,
      CompanyCodeName,
      Country,
      Currency,
      ChartOfAccounts,
      FiscalYearVariant,
      ControllingArea,
      _ControllingArea
}
