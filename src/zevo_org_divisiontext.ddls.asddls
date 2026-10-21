@AbapCatalog.sqlViewName: 'ZEVOORGDIVT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Division Text (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_DivisionText
  as select from I_DivisionText
{
  key Division,
  key Language,
      DivisionName
}
