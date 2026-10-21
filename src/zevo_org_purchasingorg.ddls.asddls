@AbapCatalog.sqlViewName: 'ZEVOORGPURCH'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Purchasing Organization (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_PurchasingOrg
  as select from I_PurchasingOrganization
  association [0..1] to ZEVO_ORG_CompanyCode as _CompanyCode
    on $projection.CompanyCode = _CompanyCode.CompanyCode
{
  key PurchasingOrganization,
      PurchasingOrganizationName,
      CompanyCode,
      _CompanyCode
}
