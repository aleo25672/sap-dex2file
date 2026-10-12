@AbapCatalog.sqlViewName: 'ZEVOFICOCODE'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Company Code (General Ledger)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_FI_CompanyCode
  as select from I_CompanyCode
{
  key CompanyCode,
      CompanyCodeName,
      Country,
      Currency,
      ChartOfAccounts,
      FiscalYearVariant,
      ControllingArea
}
