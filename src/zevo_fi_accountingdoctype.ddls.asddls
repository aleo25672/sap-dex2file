@AbapCatalog.sqlViewName: 'ZEVOFIDOCTYP'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Accounting Document Type (General Ledger)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_FI_AccountingDocType
  as select from I_AccountingDocumentType
{
  key AccountingDocumentType
}
