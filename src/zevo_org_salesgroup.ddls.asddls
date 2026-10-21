@AbapCatalog.sqlViewName: 'ZEVOORGSALSGP'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Group (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_SalesGroup
  as select from I_SalesGroup
  association [0..*] to ZEVO_ORG_SalesGroupText as _Text
    on $projection.SalesGroup = _Text.SalesGroup
{
  key SalesGroup,
      _Text
}
