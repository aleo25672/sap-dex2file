@AbapCatalog.sqlViewName: 'ZEVOORGSALSOFT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Office Text (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_SalesOfficeText
  as select from I_SalesOfficeText
{
  key SalesOffice,
  key Language,
      SalesOfficeName
}
