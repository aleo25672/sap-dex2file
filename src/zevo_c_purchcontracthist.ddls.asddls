@AbapCatalog.sqlViewName: 'ZEVOCPURCHIST'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Purchase Contract History (C2P)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_PurchContractHist
  as select from C_PurchaseContractHistoryDEX
  association [1..1] to ZEVO_C_PurchContractItem as _ContractItem
    on $projection.PurchaseContract = _ContractItem.PurchaseContract and $projection.PurchaseContractItem = _ContractItem.PurchaseContractItem
  association [0..1] to ZEVO_C_PurchaseOrder as _PurchaseOrder
    on $projection.ReleaseOrder = _PurchaseOrder.PurchaseOrder
  association [0..1] to ZEVO_C_PurchaseOrderItem as _PurchaseOrderItem
    on $projection.ReleaseOrder = _PurchaseOrderItem.PurchaseOrder and $projection.ReleaseOrderItem = _PurchaseOrderItem.PurchaseOrderItem
{
  key PurchaseContract,
  key PurchaseContractItem,
  key ReleaseOrder,
  key ReleaseOrderItem,
      ReleaseOrderItemOrderQuantity,
      ReleaseOrderItemNetAmount,
      ReleaseOrderItemIsDeleted,
      ReleaseOrderDate,
      ReleaseOrderItemQuantityUnit,
      ReleaseOrderCurrency,
      ReleaseOrderItemLastChgDate,
      ExchangeRate,
      CompanyCode,
      Plant,
      PurchasingOrganization,
      PurchaseContractType,
      PurchasingGroup,
      _ContractItem,
      _PurchaseOrder,
      _PurchaseOrderItem
}
