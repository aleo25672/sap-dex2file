@EndUserText.label: 'Goods Movement Document (C2P)'
@AccessControl.authorizationCheck: #CHECK
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MIXED }
define view entity ZEVO_C_GoodsMovementDoc
  as select from I_GoodsMovementDocumentDEX
  association [0..1] to ZEVO_C_PurchaseOrderItem as _PurchaseOrderItem
    on $projection.PurchaseOrder = _PurchaseOrderItem.PurchaseOrder
       and $projection.PurchaseOrderItem = _PurchaseOrderItem.PurchaseOrderItem
  association [0..1] to ZEVO_C_BusinessPartner as _Supplier
    on $projection.Supplier = _Supplier.BusinessPartner
{
  *,
  _PurchaseOrderItem,
  _Supplier
}
