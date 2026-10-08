@EndUserText.label: 'Purchase Order Header (C2P)'
@AccessControl.authorizationCheck: #CHECK
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MIXED }
define view entity ZEVO_C_PurchaseOrder
  as select from C_PurchaseOrderDEX
  association [0..*] to ZEVO_C_PurchaseOrderItem as _Item
    on $projection.PurchaseOrder = _Item.PurchaseOrder
  association [0..1] to ZEVO_C_BusinessPartner as _Supplier
    on $projection.Supplier = _Supplier.BusinessPartner
  association [0..*] to ZEVO_C_BPSupplier as _BPSupplier
    on $projection.Supplier = _BPSupplier.Supplier
{
  *,
  _Item,
  _Supplier,
  _BPSupplier
}
