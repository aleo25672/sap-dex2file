@AbapCatalog.sqlViewName: 'ZEVOORGVALAR'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Valuation Area (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_ValuationArea
  as select from I_ValuationArea
  association [0..1] to ZEVO_ORG_CompanyCode as _CompanyCode
    on $projection.CompanyCode = _CompanyCode.CompanyCode
{
  key ValuationArea,
      CompanyCode,
      _CompanyCode
}
