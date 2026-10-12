@AbapCatalog.sqlViewName: 'ZEVOFIGLACCT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'G/L Account (General Ledger)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MASTER }
define view ZEVO_FI_GLAccount
  as select from I_GLAccount
{
  key ChartOfAccounts,
  // Strip SAKO search help (needs CompanyCode, not on I_GLAccount)
  key cast( GLAccount as abap.char(10) ) as GLAccount,
      GLAccountType
}
