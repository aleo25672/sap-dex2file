@AbapCatalog.sqlViewName: 'ZEVOORGPURGRP'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Purchasing Group (Org)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #S, dataClass: #MASTER }
define view ZEVO_ORG_PurchasingGroup
  as select from I_PurchasingGroup
{
  key PurchasingGroup,
      PurchasingGroupName
}
