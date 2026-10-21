@AbapCatalog.sqlViewName: 'ZEVOORGSALES'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Organization (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_SalesOrg
  as select from I_SalesOrganization
  association [0..1] to ZEVO_ORG_CompanyCode as _CompanyCode
    on $projection.CompanyCode = _CompanyCode.CompanyCode
  association [0..*] to ZEVO_ORG_SalesOrgText as _Text
    on $projection.SalesOrganization = _Text.SalesOrganization
{
  key SalesOrganization,
      SalesOrganizationCurrency,
      CompanyCode,
      _CompanyCode,
      _Text
}
