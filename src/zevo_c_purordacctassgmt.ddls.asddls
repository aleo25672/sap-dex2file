@EndUserText.label: 'PO Account Assignment (C2P)'
@AccessControl.authorizationCheck: #CHECK
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MIXED }
define view entity ZEVO_C_PurOrdAcctAssgmt
  as select from C_PurOrdAccountAssignmentDEX
  association [1..1] to ZEVO_C_PurchaseOrderItem as _PurchaseOrderItem
    on $projection.PurchaseOrder = _PurchaseOrderItem.PurchaseOrder
       and $projection.PurchaseOrderItem = _PurchaseOrderItem.PurchaseOrderItem
{
  *,
  _PurchaseOrderItem
}
