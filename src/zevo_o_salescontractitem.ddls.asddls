@AbapCatalog.sqlViewName: 'ZEVOOSLSCITEM'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Contract Item (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_O_SalesContractItem
  as select from I_SalesContractItem
  association [0..1] to ZEVO_O_BusinessPartner as _SoldToParty
    on $projection.SoldToParty = _SoldToParty.BusinessPartner
{
  key SalesContract,
  key SalesContractItem,
      SalesContractItemCategory,
      CreatedByUser,
      CreationDate,
      CreationTime,
      @Semantics.systemDate.lastChangedAt: true
      LastChangeDate,
      Material,
      Product,
      Plant,
      OrderQuantity,
      OrderQuantityUnit,
      TargetQuantity,
      TargetQuantityUnit,
      NetAmount,
      TransactionCurrency,
      SalesOrganization,
      DistributionChannel,
      OrganizationDivision,
      SoldToParty,
      ShipToParty,
      BillToParty,
      PayerParty,
      SalesContractValidityStartDate,
      SalesContractValidityEndDate,
      _SoldToParty
}
