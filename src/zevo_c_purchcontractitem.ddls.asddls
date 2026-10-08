@AbapCatalog.sqlViewName: 'ZEVOCPURCITEM'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Purchase Contract Item (C2P)'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_PurchContractItem
  as select from C_PurchaseContractItemDEX
  association [1..1] to ZEVO_C_PurchaseContract as _Header
    on $projection.PurchaseContract = _Header.PurchaseContract
  association [0..*] to ZEVO_C_PurchContractHist as _History
    on $projection.PurchaseContract = _History.PurchaseContract
       and $projection.PurchaseContractItem = _History.PurchaseContractItem
  association [0..*] to ZEVO_C_PurchaseOrderItem as _PurchaseOrderItem
    on $projection.PurchaseContract = _PurchaseOrderItem.PurchaseContract
       and $projection.PurchaseContractItem = _PurchaseOrderItem.PurchaseContractItem
{
  *,
  _Header,
  _History,
  _PurchaseOrderItem
}
