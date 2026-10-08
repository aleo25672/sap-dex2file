@AbapCatalog.sqlViewName: 'ZEVOCPUROHIST'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Purchase Order History (C2P)'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_PurchaseOrderHist
  as select from C_PurchaseOrderHistoryDEX
  association [1..1] to ZEVO_C_PurchaseOrderItem as _PurchaseOrderItem
    on $projection.PurchaseOrder = _PurchaseOrderItem.PurchaseOrder
       and $projection.PurchaseOrderItem = _PurchaseOrderItem.PurchaseOrderItem
  association [0..*] to ZEVO_C_GoodsMovementDoc as _GoodsMovement
    on $projection.PurchasingHistoryDocument = _GoodsMovement.MaterialDocument
       and $projection.PurchasingHistoryDocumentYear = _GoodsMovement.MaterialDocumentYear
       and $projection.PurchaseOrder = _GoodsMovement.PurchaseOrder
       and $projection.PurchaseOrderItem = _GoodsMovement.PurchaseOrderItem
  association [0..1] to ZEVO_C_SupplierInvoice as _SupplierInvoice
    on $projection.PurchasingHistoryDocument = _SupplierInvoice.SupplierInvoice
       and $projection.PurchasingHistoryDocumentYear = _SupplierInvoice.FiscalYear
{
  *,
  _PurchaseOrderItem,
  _GoodsMovement,
  _SupplierInvoice
}
