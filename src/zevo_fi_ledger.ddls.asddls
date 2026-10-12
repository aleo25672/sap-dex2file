@AbapCatalog.sqlViewName: 'ZEVOFILEDGER'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger (General Ledger)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_FI_Ledger
  as select from I_Ledger
{
  key Ledger,
      IsLeadingLedger
}
