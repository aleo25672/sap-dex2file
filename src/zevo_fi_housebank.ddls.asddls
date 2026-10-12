@AbapCatalog.sqlViewName: 'ZEVOFIHBANK'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'House Bank (General Ledger)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_FI_HouseBank
  as select from I_HouseBank
{
  key CompanyCode,
  key HouseBank
}
