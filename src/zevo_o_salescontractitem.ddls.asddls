@AbapCatalog.sqlViewName: 'ZEVOOSLSCITEM'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Contract Item (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@Metadata.ignorePropagatedAnnotations: true
define view ZEVO_O_SalesContractItem
  as select from I_SalesContractItem
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
      // S/4 2023 (108): org / partner columns not on local I_SalesContractItem
      SalesContractValidityStartDate,
      SalesContractValidityEndDate
}
