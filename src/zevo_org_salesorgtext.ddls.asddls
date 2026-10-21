@AbapCatalog.sqlViewName: 'ZEVOORGSALEST'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Organization Text (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_SalesOrgText
  as select from I_SalesOrganizationText
{
  key SalesOrganization,
  key Language,
      SalesOrganizationName
}
