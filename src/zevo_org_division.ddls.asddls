@AbapCatalog.sqlViewName: 'ZEVOORGDIV'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Division (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_Division
  as select from I_Division
  association [0..*] to ZEVO_ORG_DivisionText as _Text
    on $projection.Division = _Text.Division
{
  key Division,
      _Text
}
