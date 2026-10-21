@AbapCatalog.sqlViewName: 'ZEVOORGSALSOF'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Office (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_SalesOffice
  as select from I_SalesOffice
  association [0..*] to ZEVO_ORG_SalesOfficeText as _Text
    on $projection.SalesOffice = _Text.SalesOffice
{
  key SalesOffice,
      _Text
}
