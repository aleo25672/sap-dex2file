@AbapCatalog.sqlViewName: 'ZEVOCSUPPITEM'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Supplier Invoice Item (C2P)'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_SupplierInvItem
  as select from C_SupplierInvoiceItemDEX
  association [1..1] to ZEVO_C_SupplierInvoice as _Header
    on $projection.SupplierInvoice = _Header.SupplierInvoice
       and $projection.FiscalYear = _Header.FiscalYear
  association [0..1] to ZEVO_C_PurchaseOrderItem as _PurchaseOrderItem
    on $projection.PurchaseOrder = _PurchaseOrderItem.PurchaseOrder
       and $projection.PurchaseOrderItem = _PurchaseOrderItem.PurchaseOrderItem
  association [0..*] to ZEVO_C_GoodsMovementDoc as _GoodsMovement
    on $projection.PrmthbReferenceDocument = _GoodsMovement.MaterialDocument
       and $projection.PrmthbReferenceDocumentFsclyr = _GoodsMovement.MaterialDocumentYear
{
  *,
  _Header,
  _PurchaseOrderItem,
  _GoodsMovement
}
